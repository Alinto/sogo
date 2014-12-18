/* iCalAlarm+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2014 Inverse inc.
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

#import "iCalAlarm+SOGo.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/SOGoUser.h>

#import <NGCards/iCalPerson.h>
#import <NGCards/iCalTrigger.h>

@implementation iCalAlarm (SOGoExtensions)

- (void) _appendAttendees: (NSArray *) attendees
             toEmailAlarm: (iCalAlarm *) alarm
{
  NSMutableArray *aAttendees;
  int count, max;
  iCalPerson *currentAttendee, *aAttendee;

  max = [attendees count];
  aAttendees = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentAttendee = [attendees objectAtIndex: count];
      aAttendee = [iCalPerson elementWithTag: @"attendee"];
      [aAttendee setCn: [currentAttendee cn]];
      [aAttendee setEmail: [currentAttendee rfc822Email]];
      [aAttendees addObject: aAttendee];
    }
  [alarm setAttendees: aAttendees];
}

- (void) _appendOrganizerToEmailAlarm: (iCalAlarm *) alarm
                                owner: (NSString *) uid
{
  NSDictionary *ownerIdentity;
  iCalPerson *aAttendee;

  ownerIdentity = [[SOGoUser userWithLogin: uid roles: nil]
                    defaultIdentity];
  aAttendee = [iCalPerson elementWithTag: @"attendee"];
  [aAttendee setCn: [ownerIdentity objectForKey: @"fullName"]];
  [aAttendee setEmail: [ownerIdentity objectForKey: @"email"]];
  [alarm addChild: aAttendee];
}

+ (id) alarmForEvent: (iCalRepeatableEntityObject *) theEntity
               owner: (NSString *) theOwner
              action: (NSString *) reminderAction
                unit: (NSString *) reminderUnit
            quantity: (NSString *) reminderQuantity
           reference: (NSString *) reminderReference
    reminderRelation: (NSString *) reminderRelation
      emailAttendees: (BOOL) reminderEmailAttendees
      emailOrganizer: (BOOL) reminderEmailOrganizer
{
  iCalTrigger *aTrigger;
  iCalAlarm *anAlarm;
  NSString *aValue;

  anAlarm = [[self alloc] init];

  aTrigger = [iCalTrigger elementWithTag: @"TRIGGER"];
  [aTrigger setValueType: @"DURATION"];
  [anAlarm setTrigger: aTrigger];
  
  if ([reminderAction length] > 0 && [reminderUnit length] > 0)
    {
      [anAlarm setAction: [reminderAction uppercaseString]];
      if ([reminderAction isEqualToString: @"email"])
        {
          [anAlarm removeAllAttendees];
          if (reminderEmailAttendees)
            [anAlarm _appendAttendees: [theEntity attendees]
                         toEmailAlarm: anAlarm];
          if (reminderEmailOrganizer)
            [anAlarm _appendOrganizerToEmailAlarm: anAlarm  owner: theOwner];
          [anAlarm setSummary: [theEntity summary]];
          [anAlarm setComment: [theEntity comment]];
        }
      
      if ([reminderReference caseInsensitiveCompare: @"BEFORE"] == NSOrderedSame)
        aValue = [NSString stringWithString: @"-P"];
      else
        aValue = [NSString stringWithString: @"P"];
      
      if ([reminderUnit caseInsensitiveCompare: @"MINUTES"] == NSOrderedSame ||
          [reminderUnit caseInsensitiveCompare: @"HOURS"] == NSOrderedSame)
        aValue = [aValue stringByAppendingString: @"T"];
      
      aValue = [aValue stringByAppendingFormat: @"%i%@",			 
                       [reminderQuantity intValue],
                [reminderUnit substringToIndex: 1]];
      [aTrigger setSingleValue: aValue forKey: @""];
      [aTrigger setRelationType: reminderRelation];
    }
  else
    {
      [anAlarm release];
      anAlarm = nil;
    }
  
  return AUTORELEASE(anAlarm);
}

@end
