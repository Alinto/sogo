/* iCalToDo+SOGo.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2017 Inverse inc.
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

#ifndef ICALTODO_SOGO_H
#define ICALTODO_SOGO_H

#import <NGCards/iCalToDo.h>

#define taskStatusCompleted 1
#define taskStatusInProcess 2
#define taskStatusCancelled 3
#define taskStatusNeedsAction 4

@class NSMutableArray;

@interface iCalToDo (SOGoExtensions)

+ (NSString *) statusForCode: (int) statusCode;

@end

#endif /* ICALTODO_SOGO_H */
