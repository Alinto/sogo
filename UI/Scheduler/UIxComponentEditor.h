/* UIxComponentEditor.h - this file is part of SOGo
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

#ifndef UIXCOMPONENTEDITOR_H
#define UIXCOMPONENTEDITOR_H

#import <SOGoUI/UIxComponent.h>

@class NSArray;
@class NSCalendarDate;
@class NSDictionary;
@class NSFormatter;
@class NSString;

@class iCalPerson;
@class iCalRecurrenceRule;
@class iCalRepeatableEntityObject;

@interface UIxComponentEditor : UIxComponent
{
  iCalRepeatableEntityObject *component;
  id item;

  NSString *saveURL;
  NSMutableArray *calendarList;
  
  /* individual values */
  NSCalendarDate *cycleUntilDate;
  NSString *title;
  NSString *location;
  NSString *comment;
  NSString *url;
  NSString *priority;
  NSString *privacy;
  NSString *status;
  NSArray *categories;
  NSDictionary *cycle;
  NSString *cycleEnd;
  iCalPerson *organizer;
  NSString *componentOwner;

  NSString *attendeesNames;
  NSString *attendeesEmails;
}

- (void) setComponent: (iCalRepeatableEntityObject *) newComponent;

- (void) setSaveURL: (NSString *) newSaveURL;
- (NSString *) saveURL;

- (NSArray *) categoryList;
- (void) setCategories: (NSArray *) _categories;
- (NSArray *) categories;
- (NSString *) itemCategoryText;

- (NSArray *) priorities;
- (void) setPriority: (NSString *) _priority;
- (NSString *) priority;
- (NSString *) itemPriorityText;

- (NSArray *) privacyClasses;
- (void) setPrivacy: (NSString *) _privacy;
- (NSString *) privacy;
- (NSString *) itemPrivacyText;

- (NSArray *) statusTypes;
- (void) setStatus: (NSString *) _status;
- (NSString *) status;
- (NSString *) itemStatusText;

- (void) setItem: (id) _item;
- (id) item;
- (NSString *) itemPriorityText;

- (void) setTitle: (NSString *) _value;
- (NSString *) title;

- (void) setLocation: (NSString *) _value;
- (NSString *) location;

- (void) setComment: (NSString *) _value;
- (NSString *) comment;

- (void) setUrl: (NSString *) _url;
- (NSString *) url;

- (void) setAttendeesNames: (NSString *) newAttendeesNames;
- (NSString *) attendeesNames;

- (void) setAttendeesEmails: (NSString *) newAttendeesEmails;
- (NSString *) attendeesEmails;

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

/* access */
- (BOOL) isMyComponent;
- (BOOL) canEditComponent;

/* helpers */
- (NSFormatter *) titleDateFormatter;
- (NSString *) completeURIForMethod: (NSString *) _method;
- (BOOL) isWriteableClientObject;
- (NSException *) validateObjectForStatusChange;

@end

#endif /* UIXCOMPONENTEDITOR_H */
