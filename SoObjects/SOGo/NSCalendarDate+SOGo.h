/* NSCalendarDate+SOGo.h - this file is part of SOGo
 *
 * Copyright (C) 2019 Inverse inc.
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

#ifndef NSCALENDARDATE_SCHEDULER_H
#define NSCALENDARDATE_SCHEDULER_H

#import <Foundation/NSCalendarDate.h>

@class NSCalendarDate;
@class NSString;
@class NSTimeZone;
@class SOGoUser;

@interface NSCalendarDate (SOGoExtensions)

+ (id) dateFromShortDateString: (NSString *) dateString
            andShortTimeString: (NSString *) timeString
                    inTimeZone: (NSTimeZone *) timeZone;

- (BOOL) isDateInSameMonth: (NSCalendarDate *) _other;
- (NSCalendarDate *) beginOfDayForUser: (SOGoUser *) user;

- (NSString *) shortDateString;
- (NSString *) rfc822DateString;
- (NSString *) iso8601DateString;

+ (id) distantFuture;
+ (id) distantPast;

@end

#endif /* NSCALENDARDATE_SCHEDULER_H */
