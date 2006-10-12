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

#import <SOGoUI/UIxComponent.h>

@class NSString;
@class iCalPerson;
@class iCalRecurrenceRule;

@interface UIxTaskEditor : UIxComponent
{
  NSString *iCalString;
  NSString *errorText;
  id item;
  
  /* individual values */
  NSCalendarDate *startDate;
  NSCalendarDate *dueDate;
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

- (NSString *)iCalStringTemplate;
- (NSString *)iCalString;

- (void)setIsPrivate:(BOOL)_yn;
- (void)setAccessClass:(NSString *)_class;

- (void)setCheckForConflicts:(BOOL)_checkForConflicts;
- (BOOL)checkForConflicts;

- (BOOL)hasCycle;
- (iCalRecurrenceRule *)rrule;
- (void)adjustCycleControlsForRRule:(iCalRecurrenceRule *)_rrule;
- (NSDictionary *)cycleMatchingRRule:(iCalRecurrenceRule *)_rrule;

- (BOOL)isCycleEndUntil;
- (void)setIsCycleEndUntil;
- (void)setIsCycleEndNever;

- (NSString *)_completeURIForMethod:(NSString *)_method;

- (NSArray *)getICalPersonsFromFormValues:(NSArray *)_values
  treatAsResource:(BOOL)_isResource;

- (NSString *)iCalParticipantsAndResourcesStringFromQueryParameters;
- (NSString *)iCalParticipantsStringFromQueryParameters;
- (NSString *)iCalResourcesStringFromQueryParameters;
- (NSString *)iCalStringFromQueryParameter:(NSString *)_qp
              format:(NSString *)_format;
- (NSString *)iCalOrganizerString;

- (id)acceptOrDeclineAction:(BOOL)_accept;

@end

#endif /* UIXTASKEDITOR_H */
