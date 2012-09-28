/* NSArray+Scheduler.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
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

#ifndef	NSARRAY_SCHEDULER_H
#define	NSARRAY_SCHEDULER_H

#import <Foundation/NSArray.h>

// See [UIxCalListingActions initialize]
#define eventNameIndex              0
#define eventFolderIndex            1
#define eventCalendarNameIndex      2
#define eventStatusIndex            3
#define eventTitleIndex             4
#define eventStartDateIndex         5
#define eventEndDateIndex           6
#define eventLocationIndex          7
#define eventIsAllDayIndex          8
#define eventClassificationIndex    9
#define eventCategoryIndex         10
#define eventPartMailsIndex        11
#define eventPartStatesIndex       12
#define eventOwnerIndex            13
#define eventIsCycleIndex          14
#define eventNextAlarmIndex        15
#define eventRecurrenceIdIndex     16
#define eventIsExceptionIndex      17
#define eventEditableIndex         18
#define eventErasableIndex         19
#define eventOwnerIsOrganizerIndex 20

// See [UIxCalListingActions initialize]
#define taskNameIndex               0
#define taskFolderIndex             1
#define taskCalendarNameIndex       2
#define taskStatusIndex             3
#define taskTitleIndex              4
#define taskEndDateIndex            5
#define taskClassificationIndex     6
#define taskLocationIndex           7
#define taskCategoryIndex           8
#define taskEditableIndex           9
#define taskErasableIndex          10
#define taskPriorityIndex          11

@interface NSArray (SOGoEventComparison)

- (NSComparisonResult) compareEventsStartDateAscending: (NSArray *) otherEvent;
- (NSComparisonResult) compareEventsEndDateAscending: (NSArray *) otherEvent;
- (NSComparisonResult) compareEventsTitleAscending: (NSArray *) otherEvent;
- (NSComparisonResult) compareEventsLocationAscending: (NSArray *) otherEvent;
- (NSComparisonResult) compareEventsCalendarNameAscending: (NSArray *) otherEvent;
- (NSComparisonResult) compareTasksAscending: (NSArray *) otherTask;
- (NSComparisonResult) compareTasksPriorityAscending: (NSArray *) otherTask;
- (NSComparisonResult) compareTasksTitleAscending: (NSArray *) otherTask;
- (NSComparisonResult) compareTasksEndAscending: (NSArray *) otherTask;
- (NSComparisonResult) compareTasksLocationAscending: (NSArray *) otherTask;
- (NSComparisonResult) compareTasksCategoryAscending: (NSArray *) otherTask;
- (NSComparisonResult) compareTasksCalendarNameAscending: (NSArray *) otherTask;
- (NSArray *) reversedArray;

@end

@interface NSMutableArray (SOGoEventComparison)

- (void) reverseArray;

@end

#endif	/* NSARRAY_SCHEDULER_H */
