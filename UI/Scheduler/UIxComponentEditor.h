/* UIxComponentEditor.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2010 Inverse inc.
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

#ifndef UIXCOMPONENTEDITOR_H
#define UIXCOMPONENTEDITOR_H

#import <SOGoUI/UIxComponent.h>

@class NSArray;
@class NSCalendarDate;
@class NSDictionary;
@class NSString;

@class iCalPerson;
@class iCalRecurrenceRule;
@class iCalRepeatableEntityObject;

@interface UIxComponentEditor : UIxComponent
{
  iCalRepeatableEntityObject *component;
  id item;
  id attendee;

  NSString *saveURL;
  NSMutableArray *calendarList;
  //NSMutableArray *organizerList;
  //NSDictionary *organizerIdentity;
  NSDictionary *organizerProfile;
  
  /* individual values */
  NSCalendarDate *cycleUntilDate;
  NSString *title;
  NSString *location;
  SOGoAppointmentFolder *componentCalendar;
  NSString *comment;
  NSString *attachUrl;
  NSString *priority;
  NSString *classification;
  NSString *status;
  NSString *category;
  NSArray *categories;
  NSDictionary *cycle;
  NSString *cycleEnd;
  iCalPerson *organizer;
  iCalPerson *ownerAsAttendee;
  NSString *componentOwner;
  NSString *dateFormat;

  NSMutableDictionary *jsonAttendees;

  NSString *reminder;
  NSString *reminderQuantity;
  NSString *reminderUnit;
  NSString *reminderRelation;
  NSString *reminderReference;
  NSString *reminderAction;
  BOOL reminderEmailOrganizer;
  BOOL reminderEmailAttendees;
  
  /* ugly */
  NSString *repeat;

  NSString *repeatType;
  NSString *repeat1;
  NSString *repeat2;
  NSString *repeat3;
  NSString *repeat4;
  NSString *repeat5;
  NSString *repeat6;
  NSString *repeat7;
  
  NSString *range1;
  NSString *range2;
}

- (NSString *) toolbar;
- (void) setComponent: (iCalRepeatableEntityObject *) newComponent;

- (void) setSaveURL: (NSString *) newSaveURL;
- (NSString *) saveURL;

- (void) setItem: (id) _item;
- (id) item;

- (SOGoAppointmentFolder *) componentCalendar;

- (NSArray *) calendarList;
- (NSString *) calendarsFoldersList;
- (NSString *) calendarDisplayName;

- (SOGoAppointmentFolder *) componentCalendar;
- (void) setComponentCalendar: (SOGoAppointmentFolder *) _componentCalendar;

- (NSArray *) categoryList;
- (void) setCategories: (NSArray *) _categories;
- (NSArray *) categories;

- (NSArray *) priorities;
- (void) setPriority: (NSString *) _priority;
- (NSString *) priority;
- (NSString *) itemPriorityText;

- (NSArray *) classificationClasses;
- (void) setClassification: (NSString *) _classification;
- (NSString *) classification;
- (NSString *) itemClassificationText;

- (void) setStatus: (NSString *) _status;
- (NSString *) status;
- (NSString *) itemStatusText;

- (void) setTitle: (NSString *) _value;
- (NSString *) title;

- (void) setLocation: (NSString *) _value;
- (NSString *) location;

- (NSString *) location;

- (void) setComment: (NSString *) _value;
- (NSString *) comment;

- (void) setAttach: (NSString *) _attachUrl;
- (NSString *) attach;

- (BOOL) hasAttendees;

- (NSString *) jsonAttendees;

- (NSString *) repeat;
- (void) setRepeat: (NSString *) newRepeat;

- (NSString *) reminder;
- (void) setReminder: (NSString *) newReminder;

////////////////////////////////// JUNK ////////////////////////////////////////
////////////////////////////////// JUNK ////////////////////////////////////////
////////////////////////////////// JUNK ////////////////////////////////////////
- (NSArray *) cycles;
- (void) setCycle: (NSDictionary *) _cycle;
- (NSDictionary *) cycle;
- (BOOL) hasCycle;
- (NSString *) cycleLabel;
- (void) setCycleUntilDate: (NSCalendarDate *) _cycleUntilDate;
- (NSCalendarDate *) cycleUntilDate;
- (iCalRecurrenceRule *) rrule;
- (void) adjustCycleControlsForRRule: (iCalRecurrenceRule *) _rrule;
- (NSDictionary *) cycleMatchingRRule: (iCalRecurrenceRule *) _rrule;
- (NSArray *) cycleEnds;
- (void) setCycleEnd: (NSString *) _cycleEnd;
- (NSString *) cycleEnd;
- (BOOL) isCycleEndUntil;
- (void) setIsCycleEndUntil;
- (void) setIsCycleEndNever;
////////////////////////////////// JUNK ////////////////////////////////////////
////////////////////////////////// JUNK ////////////////////////////////////////
////////////////////////////////// JUNK ////////////////////////////////////////

/* access */
- (BOOL) isMyComponent;
- (BOOL) canEditComponent;

/* helpers */
- (NSString *) completeURIForMethod: (NSString *) _method;
- (BOOL) isWriteableClientObject;
- (NSException *) validateObjectForStatusChange;

@end

#endif /* UIXCOMPONENTEDITOR_H */
