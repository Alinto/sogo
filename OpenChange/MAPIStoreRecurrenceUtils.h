/* MAPIStoreRecurrenceUtils.h - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#ifndef MAPISTORERECURRENCEUTILS_H
#define MAPISTORERECURRENCEUTILS_H

#include <talloc.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalRecurrenceRule.h>

@class NSTimeZone;

@class iCalEvent;
@class iCalRepeatableEntityObject;
@class iCalRecurrenceRule;

#define SOGoMinutesPerHour 60
#define SOGoHoursPerDay 24
#define SOGoMinutesPerDay (SOGoMinutesPerHour * SOGoHoursPerDay)

@interface iCalCalendar (MAPIStoreRecurrence)

- (void) setupRecurrenceWithMasterEntity: (iCalRepeatableEntityObject *) entity
                   fromRecurrencePattern: (struct RecurrencePattern *) rp;

@end

@interface iCalRecurrenceRule (MAPIStoreRecurrence)

- (void) fillRecurrencePattern: (struct RecurrencePattern *) rp
                     withEvent: (iCalEvent *) event
                    inTimeZone: (NSTimeZone *) timeZone
                      inMemCtx: (TALLOC_CTX *) memCtx;

@end

#endif /* MAPISTORERECURRENCEUTILS_H */
