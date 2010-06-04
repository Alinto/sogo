 /* SOGoAppointmentFolderObject.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalTimeZone.h>

#import "SOGoAppointmentFolder.h"
#import "SOGoCalendarComponent.h"

#import "SOGoAppointmentFolderObject.h"

@implementation SOGoAppointmentFolderObject

- (id) init
{
  if ((self = [super init]))
    {
      folder = nil;
    }

  return self;
}

- (void) dealloc
{
  [folder release];
  [super dealloc];
}

- (BOOL) isFolderish
{
  return NO;
}

- (SOGoAppointmentFolder *) _folder
{
  NSString *folderName;
  int length;

  if (!folder)
    {
      length = [nameInContainer length];
      if (length > 3)
        {
          folderName = [nameInContainer substringToIndex: length - 4];
          folder = [container lookupName: folderName
                               inContext: context
                                 acquire: NO];
          [folder retain];
        }
    }

  return folder;
}

- (NSArray *) aclsForUser: (NSString *) login
{
  return [[self _folder] aclsForUser: login];
}

- (void) _extractTimeZones: (NSArray *) timeZones
            intoDictionary: (NSMutableDictionary *) tzDict
{
  int count, max;
  iCalTimeZone *timeZone;
  NSString *tzId;

  max = [timeZones count];
  for (count = 0; count < max; count++)
    {
      timeZone = [timeZones objectAtIndex: count];
      tzId = [timeZone tzId];
      if (![tzDict objectForKey: tzId])
        [tzDict setObject: timeZone forKey: tzId];
    }
}

- (void) _extractCalendarsData: (NSArray *) calendars
                 intoTimeZones: (NSMutableDictionary *) timeZones
                 andComponents: (NSMutableArray *) components
{
  int count, max;
  iCalCalendar *calendar;

  max = [calendars count];
  for (count = 0; count < max; count++)
    {
      calendar = [calendars objectAtIndex: count];
      [self _extractTimeZones: [calendar timezones]
               intoDictionary: timeZones];
      [components addObjectsFromArray: [calendar allObjects]];
    }
}

- (NSArray *) _folderCalendars
{
  NSArray *names;
  int count, max;
  SOGoCalendarComponent *component;
  NSMutableArray *calendars;

  names = [[self _folder] toOneRelationshipKeys];
  max = [names count];
  calendars = [NSMutableArray arrayWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      component = [folder lookupName: [names objectAtIndex: count]
                           inContext: context
                             acquire: NO];
      [calendars addObject: [component calendar: NO secure: YES]];
    }

  return calendars;
}

- (iCalCalendar *) contentCalendar
{
  NSArray *calendars;
  iCalCalendar *calendar;
  NSMutableDictionary *timeZones;
  NSMutableArray *components;

  calendars = [self _folderCalendars];
  timeZones = [NSMutableDictionary dictionaryWithCapacity: 16];
  components = [NSMutableArray arrayWithCapacity: [calendars count] * 2];
  [self _extractCalendarsData: calendars
                intoTimeZones: timeZones andComponents: components];
  
  calendar = [iCalCalendar groupWithTag: @"vcalendar"];
  [calendar setMethod: @"PUBLISH"];
  [calendar setVersion: @"2.0"];
  [calendar setProdID: @"-//Inverse inc./SOGo 1.0//EN"];
  [calendar addChildren: [timeZones allValues]];
  [calendar addChildren: components];

  return calendar;
}

- (id) davEntityTag
{
  return [[self _folder] davCollectionTag];
}

- (NSString *) contentAsString
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSString *) davContentType
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
