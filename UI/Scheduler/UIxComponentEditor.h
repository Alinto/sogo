/* UIxComponentEditor.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2022 Inverse inc.
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

#import <SOGoUI/SOGoDirectAction.h>

@class NSDictionary;

@class iCalRepeatableEntityObject;

@interface UIxComponentEditor : SOGoDirectAction
{
  iCalRepeatableEntityObject *component;
  SOGoAppointmentFolder *componentCalendar;
}

- (BOOL) isEditable;
- (BOOL) isErasable;
- (BOOL) userHasRSVP;
- (NSNumber *) reply;
- (BOOL) isChildOccurrence;
- (void) setAttributes: (NSDictionary *) attributes;

- (NSDictionary *) alarm;
- (NSArray *) attachUrls;
+ (NSArray *) reminderValues;

@end

#endif /* UIXCOMPONENTEDITOR_H */
