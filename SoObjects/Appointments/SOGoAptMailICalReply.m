/* SOGoAptMailICalReply - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSCharacterSet.h>

#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>

#import "iCalPerson+SOGo.h"
#import "SOGoAptMailICalReply.h"

@implementation SOGoAptMailICalReply

- (id) init
{
  if ((self = [super init]))
    {
      attendee = nil;
    }

  return self;
}

- (void) dealloc
{
  [attendee release];
  [super dealloc];
}

- (void) setAttendee: (iCalPerson *) newAttendee
{
  ASSIGN (attendee, newAttendee);
}

- (iCalPerson *) attendee
{
  return attendee;
}

- (NSString *) attendeeName
{
  NSString *name;

  name = [attendee cn];

  if (name && [name length])
    return name;

  return [attendee rfc822Email];
}

- (void) setupValues
{
  NSDictionary *sentByValues;
  NSString *sentBy, *sentByText;

  [super setupValues];

  [values setObject: [self attendeeName] forKey: @"Attendee"];

  sentBy = [attendee sentBy];
  if ([sentBy length])
    {
      sentByValues = [NSDictionary dictionaryWithObject: sentBy
                                                 forKey: @"SentBy"];
      sentByText
        = [sentByValues keysWithFormat: [self
                                          labelForKey: @"(sent by %{SentBy}) "
                                            inContext: context]];
    }
  else
    sentByText = @"";
  [values setObject: sentByText forKey: @"SentByText"];
}

/* Generate Response */

- (NSString *) getSubject
{
  NSString *subjectFormat;
  NSString *partStat;

  if (!values)
    [self setupValues];

  partStat = [[attendee partStat] lowercaseString];

  if ([partStat isEqualToString: @"accepted"])
    subjectFormat = [self labelForKey: @"Accepted invitation: \"%{Summary}\""
                            inContext: context];
  else if ([partStat isEqualToString: @"declined"])
    subjectFormat = [self labelForKey: @"Declined invitation: \"%{Summary}\""
                            inContext: context];
  else if ([partStat isEqualToString: @"delegated"])
    subjectFormat = [self labelForKey: @"Delegated invitation: \"%{Summary}\""
                            inContext: context];
  else
    subjectFormat = [self labelForKey: @"Not yet decided on invitation: \"%{Summary}\""
                            inContext: context];

  return [values keysWithFormat: subjectFormat];
}

- (NSString *) bodyStartText
{
  NSString *bodyFormat;
  NSString *partStat, *delegate;

  partStat = [[attendee partStat] lowercaseString];
  if ([partStat isEqualToString: @"accepted"])
    bodyFormat = @"%{Attendee} %{SentByText}has accepted your event invitation.";
  else if ([partStat isEqualToString: @"declined"])
    bodyFormat = @"%{Attendee} %{SentByText}has declined your event invitation.";
  else if ([partStat isEqualToString: @"delegated"])
    {
      bodyFormat = @"%{Attendee} %{SentByText}has delegated the invitation"
        @" to %{Delegate}.";
      delegate = [attendee delegatedTo];
      if ([delegate length] > 7)
        {
          delegate = [delegate substringFromIndex: 7];
          if ([delegate characterAtIndex: 0] == '"' && [delegate hasSuffix: @"\""])
            delegate = [delegate substringWithRange: NSMakeRange(1, [delegate length]-2)];
          
          [values setObject: delegate forKey: @"Delegate"];
        }
    }
  else
    bodyFormat = @"%{Attendee} %{SentByText}has not yet decided upon your event invitation.";

  return  [values keysWithFormat: [self labelForKey: bodyFormat inContext: context]];
}

- (NSString *) getBody
{
  NSString *body;

  if (!values)
    [self setupValues];

  body = [[self generateResponse] contentAsString];
  
  return [body stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
