/* SOGoEMailAlarmsManager.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2014 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEntityObject.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalToDo.h>

#import <GDLContentStore/GCSAlarmsFolder.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import "SOGoAppointmentFolder.h"
#import "SOGoCalendarComponent.h"

#import "SOGoEMailAlarmsManager.h"

@interface iCalEntityObject (SOGoAlarmsExtension)

- (void) findSoonerEMailAlarmAfterDate: (NSCalendarDate *) refDate
                               inAlarm: (iCalAlarm **) alarm;

@end

@interface iCalCalendar (SOGoAlarmsExtension)

- (void) findSoonerEMailAlarmAfterDate: (NSCalendarDate *) refDate
                               inAlarm: (iCalAlarm **) alarm;

@end

@implementation iCalEntityObject (SOGoAlarmsExtension)

- (void) findSoonerEMailAlarmAfterDate: (NSCalendarDate *) refDate
                               inAlarm: (iCalAlarm **) alarm
{
  int count, max;
  NSArray *alarms;
  iCalAlarm *currentAlarm;
  NSString *action;
  NSCalendarDate *soonerDate, *testDate;

  soonerDate = [*alarm nextAlarmDate];

  alarms = [self alarms];
  max = [alarms count];
  for (count = 0; count < max; count++)
    {
      currentAlarm = [alarms objectAtIndex: count];
      action = [[currentAlarm action] uppercaseString];
      if ([action isEqualToString: @"EMAIL"])
        {
          testDate = [currentAlarm nextAlarmDate];
          if (testDate
              && [refDate earlierDate: testDate] == refDate
              && (!soonerDate
                  || [soonerDate earlierDate: testDate] == testDate))
            {
              *alarm = currentAlarm;
              soonerDate = testDate;
            }
        }
    }
}

@end

@implementation iCalCalendar (SOGoAlarmsExtension)

- (void) findSoonerEMailAlarmAfterDate: (NSCalendarDate *) refDate
                               inAlarm: (iCalAlarm **) alarm
{
  int count, max;
  iCalEntityObject *child;
  BOOL done;

  /* Here we only search for email alarms in the first event. This
     should be fixed sometime. */
  done = NO;
  max = [children count];
  for (count = 0; !done && count < max; count++)
    {
      child = [children objectAtIndex: count];
      if ([child isKindOfClass: [iCalEvent class]]
          || [child isKindOfClass: [iCalToDo class]])
        {
          [child findSoonerEMailAlarmAfterDate: refDate inAlarm: alarm];
          done = YES;
        }
    }
}

@end

@implementation SOGoEMailAlarmsManager

+ (id) sharedEMailAlarmsManager
{
  static id sharedEMailAlarmsManager = nil;

  if (!sharedEMailAlarmsManager)
    sharedEMailAlarmsManager = [self new];

  return sharedEMailAlarmsManager;
}

- (void) _writeAlarmCoordinates: (iCalAlarm *) alarm
                  fromComponent: (SOGoCalendarComponent *) component
{
  GCSAlarmsFolder *af;
  NSString *path, *cname;
  iCalEntityObject *entity;
  int alarmNbr;

  af = [[GCSFolderManager defaultFolderManager] alarmsFolder];

  path = [[component container] ocsPath];
  cname = [component nameInContainer];
  if (alarm)
    {
      entity = [alarm parent];
      alarmNbr = [[entity alarms] indexOfObject: alarm];

      [af writeRecordForEntryWithCName: cname
                      inCalendarAtPath: path
                                forUID: [entity uid]
                          recurrenceId: [entity recurrenceId]
                           alarmNumber: [NSNumber numberWithInt: alarmNbr]
                          andAlarmDate: [alarm nextAlarmDate]];
    }
  else
    [af deleteRecordForEntryWithCName: cname
                     inCalendarAtPath: path];
}

- (void) handleAlarmsInCalendar: (iCalCalendar *) calendar
                  fromComponent: (SOGoCalendarComponent *) component
{
  iCalAlarm *alarm;
  NSCalendarDate *now;

  now = [NSCalendarDate calendarDate];

  alarm = nil;
  [calendar findSoonerEMailAlarmAfterDate: now
                                  inAlarm: &alarm];
  [self _writeAlarmCoordinates: alarm
                 fromComponent: component];
}

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
  NSDictionary *eventRecord;

  folder = [[GCSFolderManager defaultFolderManager]
             folderAtPath: [record objectForKey: @"c_path"]];
  eventRecord = [folder
                  recordOfEntryWithName: [record objectForKey: @"c_name"]];
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

- (iCalAlarm *) _lookupAlarmMatchingRecord: (NSDictionary *) record
                                 withOwner: (NSString **) owner
{
  iCalCalendar *calendar;
  iCalEntityObject *entity;
  iCalAlarm *alarm;
  NSArray *alarms;
  int alarmNbr;

  calendar = [self _lookupCalendarMatchingRecord: record];
  entity = [self _lookupEntityMatchingRecord: record inCalendar: calendar];
  alarmNbr = [[record objectForKey: @"c_alarm_number"] intValue];
  alarms = [entity alarms];
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
                           withOwners: (NSMutableArray **) owners
{
  GCSAlarmsFolder *af;
  iCalAlarm *alarm;
  NSMutableArray *alarms;
  NSDictionary *record;
  NSArray *records;
  int count, max;
  NSString *owner;

  af = [[GCSFolderManager defaultFolderManager] alarmsFolder];
  records = [af recordsForEntriesFromDate: fromDate toDate: toDate];
  max = [records count];
  alarms = [NSMutableArray arrayWithCapacity: max];
  if (owners)
    *owners = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      record = [records objectAtIndex: count];
      alarm = [self _lookupAlarmMatchingRecord: record
                                     withOwner: &owner];
      if (alarm)
        {
          [alarms addObject: alarm];
          if (owners)
            [*owners addObject: owner];
        }
    }

  return alarms;  
}

- (void) deleteAlarmsUntilDate: (NSCalendarDate *) untilDate
{
  GCSAlarmsFolder *af;

  af = [[GCSFolderManager defaultFolderManager] alarmsFolder];
  
  [af deleteRecordsForEntriesUntilDate: untilDate];
}

@end
