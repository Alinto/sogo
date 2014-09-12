/* SOGoEMailAlarmsManager.h - this file is part of SOGo
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

#ifndef SOGOEMAILALARMSMANAGER_H
#define SOGOEMAILALARMSMANAGER_H

#import <Foundation/NSObject.h>

@class NSCalendarDate;

@class iCalCalendar;

@class SOGoCalendarComponent;

@interface SOGoEMailAlarmsManager : NSObject

+ (id) sharedEMailAlarmsManager;

/* PUT */
- (void) handleAlarmsInCalendar: (iCalCalendar *) calendar
                  fromComponent: (SOGoCalendarComponent *) component;

/* DELETE */
- (void) deleteAlarmsFromComponent: (SOGoCalendarComponent *) component;

/* fetch and cleanup */
- (NSArray *) scheduledAlarmsFromDate: (NSCalendarDate *) fromDate
                               toDate: (NSCalendarDate *) toDate
                           withOwners: (NSMutableArray **) owners;
- (void) deleteAlarmsUntilDate: (NSCalendarDate *) untilDate;

@end

#endif /* SOGOEMAILALARMSMANAGER_H */
