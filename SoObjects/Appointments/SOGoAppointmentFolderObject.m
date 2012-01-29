 /* SOGoAppointmentFolderObject.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalTimeZone.h>

#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>

#import "SOGoAppointmentFolder.h"
#import "SOGoCalendarComponent.h"

#import "SOGoAppointmentFolderObject.h"

static NSArray *contentFields = nil;

@implementation SOGoAppointmentFolderObject

+ (void) initialize
{
  if (!contentFields)
    contentFields = [[NSArray alloc] initWithObjects: @"c_name", @"c_version",
                                     @"c_lastmodified", @"c_creationdate",
                                     @"c_component", @"c_content", nil];
}

- (id) init
{
  int davCalendarStartTimeLimit;
  SOGoUser *user;

  if ((self = [super init]))
    {
      folder = nil;

      user = [context activeUser];
      davCalendarStartTimeLimit
        = [[user domainDefaults] davCalendarStartTimeLimit];
      /* 43200 = 60 * 60 * 24 / 2 */
      davTimeHalfLimitSeconds = davCalendarStartTimeLimit * 43200;
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

- (NSArray *) _fetchFolderRecords
{
  NSCalendarDate *start, *end;

  if (davTimeHalfLimitSeconds)
    {
      start = [[NSCalendarDate date] addYear: 0
                                       month: 0
                                         day: 0
                                        hour: 0
                                      minute: 0
                                      second: -davTimeHalfLimitSeconds];
      end = [start addYear: 0
                     month: 0
                       day: 0
                      hour: 0
                    minute: 0
                    second: (2 * davTimeHalfLimitSeconds)];
    }
  else
    {
      start = nil;
      end = nil;
    }

  return [[self _folder] bareFetchFields: contentFields
                                    from: start
                                      to: end
                                   title: nil
                               component: nil
                       additionalFilters: nil];
}

- (NSArray *) _folderCalendars
{
  NSArray *records;
  NSMutableArray *calendars;
  SOGoCalendarComponent *component;
  NSAutoreleasePool *pool;
  int count, max;
  iCalCalendar *calendar;
  NSString *name;

  records = [self _fetchFolderRecords];
  max = [records count];
  calendars = [NSMutableArray arrayWithCapacity: max];
  pool = nil;

  // This can consume a significant amount of memory so
  // we use a local autorelease pool to avoid running
  // out of memory.
  for (count = 0; count < max; count++)
    {
      if (count % 100 == 0)
	{
	  RELEASE(pool);
	  pool = [[NSAutoreleasePool alloc] init];
	}

      name = [[records objectAtIndex: count] objectForKey: @"c_name"];
      component = [folder lookupName: name
                           inContext: context
                             acquire: NO];
      calendar = [component calendar: NO secure: !activeUserIsOwner];
      if (calendar)
        [calendars addObject: calendar];
      else
        [self errorWithFormat: @"record with c_name '%@' should obviously not"
              @" be listed here", name];
    }

  RELEASE(pool);

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
  [calendar setProdID: [NSString stringWithFormat:
                                   @"-//Inverse inc./SOGo %@//EN",
                                 SOGoVersion]];
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

- (NSString *) displayName
{
  return [[self _folder] displayName];
}

- (NSString *) davDisplayName
{
  return [self displayName];
}

@end
