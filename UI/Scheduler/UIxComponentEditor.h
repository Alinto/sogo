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
@private
  NSString *iCalString;
  NSString *errorText;
  id item;
  
  /* individual values */
  NSCalendarDate *startDate;
  NSCalendarDate *cycleUntilDate;
  NSString *title;
  NSString *location;
  NSString *comment;
  iCalPerson *organizer;
  NSArray *participants;     /* array of iCalPerson's */
  NSArray *resources;        /* array of iCalPerson's */
  NSString *priority;
  NSArray *categories;
  NSString *accessClass;
  BOOL isPrivate;         /* default: NO */
  BOOL checkForConflicts; /* default: NO */
  NSDictionary *cycle;
  NSString *cycleEnd;
}

- (void) setAccessClass: (NSString *) _class;
- (NSString *) accessClass;

- (void) setIsPrivate: (BOOL) _yn;
- (BOOL) isPrivate;

- (NSArray *) categoryItems;
- (void) setCategories: (NSArray *) _categories;
- (NSArray *) categories;
- (NSString *) itemCategoryText;

- (NSArray *) priorities;
- (void) setPriority: (NSString *) _priority;
- (NSString *) priority;

- (void) setItem: (id) _item;
- (id) item;
- (NSString *) itemPriorityText;

- (void) setErrorText: (NSString *) _txt;
- (NSString *) errorText;
- (BOOL) hasErrorText;

- (void) setICalString: (NSString *) _s;
- (NSString *) iCalString;

- (void) setStartDate: (NSCalendarDate *) _date;
- (NSCalendarDate *) startDate;

- (void) setTitle: (NSString *) _value;
- (NSString *) title;

- (void) setLocation: (NSString *) _value;
- (NSString *) location;

- (void) setComment: (NSString *) _value;
- (NSString *) comment;

- (void) setParticipants: (NSArray *) _parts;
- (NSArray *) participants;

- (void) setResources: (NSArray *) _res;
- (NSArray *) resources;

- (void) setCheckForConflicts: (BOOL) _checkForConflicts;
- (BOOL) checkForConflicts;

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
- (BOOL) canAccessComponent;
- (BOOL) canEditComponent;

/* helpers */
- (NSFormatter *) titleDateFormatter;
- (NSString *) completeURIForMethod: (NSString *) _method;
- (BOOL) isWriteableClientObject;
- (NSException *) validateObjectForStatusChange;

/* subclasses */
- (void) loadValuesFromComponent: (iCalRepeatableEntityObject *) component;

- (NSString *) iCalStringTemplate;
- (NSString *) iCalParticipantsAndResourcesStringFromQueryParameters;
- (NSString *) iCalParticipantsStringFromQueryParameters;
- (NSString *) iCalResourcesStringFromQueryParameters;
- (NSString *) iCalStringFromQueryParameter: (NSString *) _qp
                                     format: (NSString *) _format;
- (NSString *) iCalOrganizerString;

@end

#endif /* UIXCOMPONENTEDITOR_H */
