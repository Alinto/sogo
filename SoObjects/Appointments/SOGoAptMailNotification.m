/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2006-2008 Inverse inc.

  This file is part of OpenGroupware.org.
 
  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimeZone.h>

#import <NGObjWeb/WOActionResults.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalEntityObject.h>
#import <NGCards/iCalPerson.h>

#import <SoObjects/SOGo/NSString+Utilities.h>

#import "SOGoAptMailNotification.h"

@interface SOGoAptMailNotification (PrivateAPI)

- (BOOL) isSubject;
- (void) setIsSubject: (BOOL) newIsSubject;

@end

@implementation SOGoAptMailNotification

static NSCharacterSet *wsSet = nil;
static NSTimeZone *UTC = nil;

+ (void) initialize
{
  if (!wsSet)
    {
      wsSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
      UTC = [[NSTimeZone timeZoneWithAbbreviation: @"UTC"] retain];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      apt = nil;
    }

  return self;
}

- (void) dealloc
{
  [apt release];
  [super dealloc];
}

- (iCalEntityObject *) apt
{
  return apt;
}

- (void) setApt: (iCalEntityObject *) newApt
{
  ASSIGN (apt, newApt);
}


- (BOOL) isSubject
{
  return isSubject;
}

- (void) setIsSubject: (BOOL) newIsSubject
{
  isSubject = newIsSubject;
}

- (NSString *) summary
{
  return [apt summary];
}

- (NSString *) organizerName
{
  return [[apt organizer] cn];
}

/* Helpers */

/* Generate Response */

- (NSString *) getSubject
{
  NSString *subject;

  [self setIsSubject: YES];
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
  [self setIsSubject:NO];

  return [[self generateResponse] contentAsString];
}

@end
