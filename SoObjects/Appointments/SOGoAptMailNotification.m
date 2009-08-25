/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2006-2009 Inverse inc.

  This file is part of SOGo.
 
  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
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

#import "iCalPerson+SOGo.h"
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
  [previousApt release];
  [organizerName release];
  [viewTZ release];
  [oldStartDate release];
  [newStartDate release];
  [super dealloc];
}

- (iCalEntityObject *) apt
{
  return apt;
}

- (void) setApt: (iCalEntityObject *) theApt
{
  ASSIGN(apt, theApt);
}

- (iCalEntityObject *) previousApt
{
  return previousApt;
}

- (void) setPreviousApt: (iCalEntityObject *) theApt
{
  ASSIGN(previousApt, theApt);
}

- (BOOL) hasNewLocation
{
  return ([[apt location] length] > 0);
}

- (BOOL) hasOldLocation
{
  return ([[previousApt location] length] > 0);
}

- (NSTimeZone *) viewTZ 
{
  if (self->viewTZ) return self->viewTZ;
  return UTC;
}
- (void) setViewTZ: (NSTimeZone *) _viewTZ
{
  ASSIGN(self->viewTZ, _viewTZ);
}

- (NSCalendarDate *) oldStartDate
{
  if (!self->oldStartDate)
    {
      ASSIGN(self->oldStartDate, [[self previousApt] startDate]);
      [self->oldStartDate setTimeZone: [self viewTZ]];
    }
  return self->oldStartDate;
}

- (NSCalendarDate *) newStartDate
{
  if (!self->newStartDate)
    {
      ASSIGN(self->newStartDate, [[self apt] startDate]);
      [self->newStartDate setTimeZone:[self viewTZ]];
    }
  return self->newStartDate;
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

- (void) setOrganizerName: (NSString *) theString
{
  ASSIGN(organizerName, theString);
}

- (NSString *) organizerName
{
  return organizerName;
}

- (BOOL) hasSentBy
{
  return [[apt organizer] hasSentBy];
}

- (NSString *) sentBy
{
  return [[apt organizer] sentBy];
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
  NSString *body;

  [self setIsSubject:NO];

  body = [[self generateResponse] contentAsString];

  return [body stringByTrimmingCharactersInSet: wsSet];
}

@end
