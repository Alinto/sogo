/* NSArray+Scheduler.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
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


// See [UIxCalListingActions initialize]
#define eventNameIndex              0
#define eventFolderIndex            1
#define eventCalendarNameIndex      2
#define eventStatusIndex            3
#define eventIsOpaqueIndex          4
#define eventTitleIndex             5
#define eventStartDateIndex         6
#define eventStartHourIndex         7
#define eventEndDateIndex           8
#define eventLocationIndex          9
#define eventIsAllDayIndex         10
#define eventClassificationIndex   11
#define eventCategoryIndex         12
#define eventPriorityIndex         13
#define eventPartMailsIndex        14
#define eventPartStatesIndex       15
#define eventOwnerIndex            16
#define eventIsCycleIndex          17
#define eventNextAlarmIndex        18
#define eventRecurrenceIdIndex     19
#define eventIsExceptionIndex      20
#define eventEditableIndex         21
#define eventErasableIndex         22
#define eventOwnerIsOrganizerIndex 23

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
#define taskOwnerIndex             12
#define taskIsCycleIndex           13
#define taskNextAlarmIndex         14
#define taskRecurrenceIdIndex      15
#define taskIsExceptionIndex       16
#define taskDescriptionIndex       17

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
