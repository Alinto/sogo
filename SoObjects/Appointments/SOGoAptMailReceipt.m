/* SOGoAptMailReceipt.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2012 Inverse inc.
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSCharacterSet.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "SOGoAptMailReceipt.h"

static SOGoUserManager *um = nil;
static NSCharacterSet *wsSet = nil;

@implementation SOGoAptMailReceipt

+ (void) initialize
{
  if (!um)
    um = [SOGoUserManager sharedUserManager];

  if (!wsSet)
    wsSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
}

- (id) init
{
  if ((self = [super init]))
    {
      originator = nil;
      recipients = nil;
      isSubject = NO;
    }

  return self;
}

- (void) dealloc
{
  [originator release];
  [recipients release];
  [super dealloc];
}


- (NSString *) getSubject
{
  NSString *subject;

  if (!values)
    [self setupValues];

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
  NSString *body;

  if (!values)
    [self setupValues];

  isSubject = NO;

  body = [[self generateResponse] contentAsString];

  return [body stringByTrimmingCharactersInSet: wsSet];
}

- (void) setOriginator: (NSString *) newOriginator
{
  ASSIGN (originator, newOriginator);
}

- (void) setRecipients: (NSArray *) newRecipients
{
  ASSIGN (recipients, newRecipients);
}

- (NSArray *) recipients
{
  return recipients;
}

- (void) setCurrentRecipient: (iCalPerson *) newCurrentRecipient
{
  ASSIGN (currentRecipient, newCurrentRecipient);
}

- (iCalPerson *) currentRecipient
{
  return currentRecipient;
}

- (NSString *) _formattedUserDate: (NSCalendarDate *) date
{
  SOGoDateFormatter *formatter;
  NSCalendarDate *tzDate;
  SOGoUser *currentUser;

  currentUser = [context activeUser];

  tzDate = [date copy];
  [tzDate setTimeZone: viewTZ];
  [tzDate autorelease];

  formatter = [currentUser dateFormatterInContext: context];

  if ([apt isAllDay])
    return [formatter formattedDate: tzDate];
  else
    return [NSString stringWithFormat: @"%@ - %@",
             [formatter formattedDate: tzDate],
             [formatter formattedTime: tzDate]];
}

- (NSString *) aptStartDate
{
  return [self _formattedUserDate: [apt startDate]];
}

- (NSString *) aptEndDate
{
  return [self _formattedUserDate: [(iCalEvent *) apt endDate]];
}

@end

@implementation SOGoAptMailInvitationReceipt : SOGoAptMailReceipt

@end

@implementation SOGoAptMailUpdateReceipt : SOGoAptMailReceipt

@end

@implementation SOGoAptMailDeletionReceipt : SOGoAptMailReceipt

@end
