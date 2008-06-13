/* NSArray+Utilities.h - this file is part of SOGo
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

#ifndef NSARRAY_UTILITIES_H
#define NSARRAY_UTILITIES_H

#import <Foundation/NSArray.h>

@class NSString;

@interface NSArray (SOGoArrayUtilities)

- (id *) asPointersOfObjects;

- (NSString *) jsonRepresentation;

- (NSArray *) stringsWithFormat: (NSString *) format;
- (NSArray *) keysWithFormat: (NSString *) format;
- (NSArray *) objectsForKey: (NSString *) key;
- (NSArray *) flattenedArray;

- (NSArray *) uniqueObjects;

- (BOOL) containsCaseInsensitiveString: (NSString *) match;

#ifdef GNUSTEP_BASE_LIBRARY
- (void) makeObjectsPerform: (SEL) selector
                 withObject: (id) object1
                 withObject: (id) object2;
#endif

@end

@interface NSMutableArray (SOGoArrayUtilities)

- (void) addObjectUniquely: (id) object;

- (void) addRange: (NSRange) newRange;
- (BOOL) hasRangeIntersection: (NSRange) testRange;

@end

#endif /* NSARRAY_UTILITIES_H */
