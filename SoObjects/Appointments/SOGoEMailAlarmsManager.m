/* SOGoEMailAlarmsManager.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2016 Inverse inc.
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalToDo.h>

#import <GDLContentStore/GCSAlarmsFolder.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>

#import "SOGoAppointmentFolder.h"
#import "SOGoAppointmentFolders.h"
#import "SOGoCalendarComponent.h"

#import "SOGoEMailAlarmsManager.h"

@implementation SOGoEMailAlarmsManager

+ (id) sharedEMailAlarmsManager
{
  static id sharedEMailAlarmsManager = nil;

  if (!sharedEMailAlarmsManager)
    sharedEMailAlarmsManager = [self new];

  return sharedEMailAlarmsManager;
}

//
// This method is called SOGoCalendarCompoent: -prepareDelete when
// a component is being deleted. We of course remove all associated
// when an event or task is being deleted.
//
- (void) deleteAlarmsFromComponent: (SOGoCalendarComponent *) component
{
  GCSAlarmsFolder *af;
  NSString *path;

  af = [[GCSFolderManager defaultFolderManager] alarmsFolder];
  path = [[component container] ocsPath];
  [af deleteRecordForEntryWithCName: [component nameInContainer]
                   inCalendarAtPath: path];
}

- (iCalCalendar *) _lookupCalendarMatchingRecord: (NSDictionary *) record
{
  iCalCalendar *calendar;
  GCSFolder *folder;
  GCSFolderManager *fm;
  NSDictionary *eventRecord;

  fm = [GCSFolderManager defaultFolderManager];
  folder = [fm folderAtPath: [record objectForKey: @"c_path"]];
  eventRecord = [folder recordOfEntryWithName: [record objectForKey: @"c_name"]];
  calendar = [iCalCalendar parseSingleFromSource:
                       [eventRecord objectForKey: @"c_content"]];

  return calendar;
}

- (iCalEntityObject *) _lookupEntityMatchingRecord: (NSDictionary *) record
                                        inCalendar: (iCalCalendar *) calendar
{
  NSArray *entities;
  NSCalendarDate *testRecId;
  iCalEntityObject *entity, *testEntity;
  int count, max, testRecIdSecs;

  entity = nil;

  entities = [calendar events];
  max = [entities count];
  if (max == 0)
    {
      entities = [calendar todos];
      max = [entities count];
    }

  if (max > 0)
    {
      for (count = 0; !entity && count < max; count++)
        {
          testEntity = [entities objectAtIndex: count];
	  testRecId = [testEntity recurrenceId];
          testRecIdSecs = testRecId? [[testEntity recurrenceId] timeIntervalSince1970] : 0;
          if ([[record objectForKey: @"c_recurrence_id"] intValue] == testRecIdSecs)
            entity = testEntity;
        }
    }
  else
    [self errorWithFormat:
            @"(inconsistency) no handled entity found for record: %@",
          record];

  return entity;
}

- (void) _extractOwner: (NSString **) owner
              fromPath: (NSString *) path
{
  NSArray *parts;

  parts = [path componentsSeparatedByString: @"/"];
  if ([parts count] > 2)
    *owner = [parts objectAtIndex: 2];
}

- (void) _extractContainer: (NSString **) container
		  fromPath: (NSString *) path
{
  NSArray *parts;

  parts = [path componentsSeparatedByString: @"/"];
  if ([parts count] > 4)
    *container = [parts objectAtIndex: 4];
}

- (SOGoAppointmentFolder *) _lookupContainerMatchingRecord: (NSDictionary *) record
{
  SOGoAppointmentFolders *folders;
  SOGoAppointmentFolder *calendar;
  NSString *container, *owner;
  SOGoUser *user;
  WOContext *context;

  [self _extractOwner: &owner  fromPath: [record objectForKey: @"c_path"]];
  [self _extractContainer: &container  fromPath: [record objectForKey: @"c_path"]];
  user = [SOGoUser userWithLogin: owner];

  context = [WOContext context];
  [context setActiveUser: user];

  folders = [user calendarsFolderInContext: context];

  calendar = [folders lookupPersonalFolder: container  ignoringRights: YES];

  return calendar;
}

- (iCalAlarm *) _lookupAlarmMatchingRecord: (NSDictionary *) record
                                 withOwner: (NSString **) owner
                                withEntity: (iCalEntityObject **) entity
{
  iCalCalendar *calendar;
  iCalAlarm *alarm;
  NSArray *alarms;
  int alarmNbr;

  calendar = [self _lookupCalendarMatchingRecord: record];
  *entity = [self _lookupEntityMatchingRecord: record inCalendar: calendar];
  alarmNbr = [[record objectForKey: @"c_alarm_number"] intValue];
  alarms = [*entity alarms];
  if (alarmNbr < [alarms count])
    {
      alarm = [alarms objectAtIndex: alarmNbr];
      [self _extractOwner: owner
                 fromPath: [record objectForKey: @"c_path"]];
    }
  else
    {
      [self errorWithFormat: @"alarm number mismatch for record: %@", record];
      alarm = nil;
    }

  return alarm;
}

- (NSArray *) scheduledAlarmsFromDate: (NSCalendarDate *) fromDate
                               toDate: (NSCalendarDate *) toDate
			 withMetadata: (NSMutableArray *) metadata
{
  SOGoAppointmentFolder *container;
  iCalEntityObject *entity;
  GCSAlarmsFolder *af;
  GCSFolderManager *fm;
  iCalAlarm *alarm;
  NSMutableArray *alarms;
  NSDictionary *record;
  NSArray *records;
  int count, max;
  NSString *owner;

  fm = [GCSFolderManager defaultFolderManager];
  af = [fm alarmsFolder];
  records = [af recordsForEntriesFromDate: fromDate toDate: toDate];
  max = [records count];
  alarms = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      record = [records objectAtIndex: count];
      alarm = [self _lookupAlarmMatchingRecord: record
                                     withOwner: &owner
				    withEntity: &entity];
      if (alarm)
        {
	  container = [self _lookupContainerMatchingRecord: record];
          [alarms addObject: alarm];
	  [metadata addObject: [NSDictionary dictionaryWithObjectsAndKeys: owner, @"owner",
					     record, @"record",
					     container, @"container",
					     entity, @"entity",
					     nil]];
        }
    }

  return alarms;  
}

@end
