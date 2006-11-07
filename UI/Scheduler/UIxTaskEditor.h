/* UIxTaskEditor.h - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#ifndef UIXTASKEDITOR_H
#define UIXTASKEDITOR_H

#import "UIxComponentEditor.h"

@class NSString;
@class iCalPerson;
@class iCalRecurrenceRule;
@class iCalToDo;

@interface UIxTaskEditor : UIxComponentEditor
{
  NSCalendarDate *dueDate;
  BOOL hasStartDate;
  BOOL hasDueDate;
  BOOL newTask;
}

- (void) setTaskStartDate: (NSCalendarDate *) _date;
- (NSCalendarDate *) taskStartDate;

- (void) setTaskDueDate: (NSCalendarDate *) _date;
- (NSCalendarDate *) taskDueDate;

/* iCal */

- (NSString *) iCalStringTemplate;

/* new */

- (id) newAction;

/* save */

- (void) loadValuesFromTask: (iCalToDo *) _task;
- (void) saveValuesIntoTask: (iCalToDo *) _task;
- (iCalToDo *) taskFromString: (NSString *) _iCalString;

/* conflict management */

- (BOOL) containsConflict: (id) _task;
- (id <WOActionResults>) defaultAction;
- (id <WOActionResults>) saveAction;
- (id) changeStatusAction;
- (id) acceptAction;
- (id) declineAction;

- (NSString *) saveUrl;

// TODO: add tentatively

- (id) acceptOrDeclineAction: (BOOL) _accept;

@end

#endif /* UIXTASKEDITOR_H */
