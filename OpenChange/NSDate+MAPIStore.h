/* NSDate+MAPIStore.h - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#ifndef NSCALENDARDATE_MAPISTORE_H
#define NSCALENDARDATE_MAPISTORE_H

#import <Foundation/NSDate.h>

@interface NSDate (MAPIStoreDataTypes)

+ (id) dateFromMinutesSince1601: (uint32_t) minutes;
- (uint32_t) asMinutesSince1601;

+ (id) dateFromFileTime: (const struct FILETIME *) timeValue;
- (struct FILETIME *) asFileTimeInMemCtx: (void *) memCtx;

- (BOOL) isNever; /* occurs on 4500-12-31 */

@end

#endif /* NSCALENDARDATE+MAPISTORE_H */
