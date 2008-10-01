/* SOGoAptMailICalReply - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimeZone.h>

#import <NGObjWeb/WOActionResults.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalEntityObject.h>
#import <NGCards/iCalPerson.h>

#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "SOGoAptMailICalReply.h"

@interface SOGoAptMailICalReply (PrivateAPI)

- (BOOL) isSubject;

@end

@implementation SOGoAptMailICalReply

static NSCharacterSet *wsSet  = nil;

+ (void) initialize
{
  static BOOL didInit = NO;

  if (!didInit)
    {
      didInit = YES;
      wsSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      apt = nil;
      attendee = nil;
    }

  return self;
}

- (void) dealloc
{
  [apt release];
  [attendee release];
  [super dealloc];
}

- (void) setApt: (iCalEntityObject *) newApt
{
  ASSIGN (apt, newApt);
}

- (iCalEntityObject *) apt
{
  return apt;
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
  return [attendee cn];
}

- (BOOL) hasAccepted
{
  NSString *partStat;

  partStat = [[attendee partStat] lowercaseString];

  return [partStat isEqualToString: @"accepted"];
}

- (BOOL) hasDeclined
{
  NSString *partStat;

  partStat = [[attendee partStat] lowercaseString];

  return [partStat isEqualToString: @"declined"];
}

- (NSCalendarDate *) startDate
{
  NSCalendarDate *date;
  SOGoUser *user;

  date = [apt startDate];
  user = [[self context] activeUser];
  [date setTimeZone: [user timeZone]];

  return date;
}

- (BOOL) isSubject
{
  return isSubject;
}

/* Generate Response */

- (NSString *) getSubject
{
  NSString *subject;

  isSubject = YES;
  subject = [[[self generateResponse] contentAsString]
	      stringByTrimmingCharactersInSet: wsSet];
  if (!subject)
    {
      [self errorWithFormat:@"Failed to properly generate subject! Please check "
	    @"template for component '%@'!",
	    [self name]];
      subject = @"ERROR: missing subject!";
    }

  return [subject asQPSubjectString: @"utf-8"];
}

- (NSString *) getBody
{
  isSubject = NO;
  return [[self generateResponse] contentAsString];
}

@end

@interface SOGoAptMailEnglishICalReply : SOGoAptMailICalReply
@end

@implementation SOGoAptMailEnglishICalReply
@end

@interface SOGoAptMailFrenchICalReply : SOGoAptMailICalReply
@end

@implementation SOGoAptMailFrenchICalReply
@end

@interface SOGoAptMailGermanICalReply : SOGoAptMailICalReply
@end

@implementation SOGoAptMailGermanICalReply
@end

@interface SOGoAptMailItalianICalReply : SOGoAptMailICalReply
@end

@implementation SOGoAptMailItalianICalReply
@end

