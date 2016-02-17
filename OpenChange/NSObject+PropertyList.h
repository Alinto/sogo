/* dbmsgdump.m - this file is part of SOGo
 *
 * Copyright (C) 2014 Kamen Mazdrashki <kmazdrashki@zentyal.com>
 *
 * Based on implementation done by Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

/*
 * A format-agnostic dump extensions for:
 *   NSArray
 *   NSObject
 *   NSDictionary
 */

#ifndef NSOBJECT_PROPERTYLIST_H
#define NSOBJECT_PROPERTYLIST_H

#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>


@interface NSObject (plext)

- (void) displayWithIndentation: (NSInteger) anInt;

@end


@interface NSDictionary (plext)

- (void) displayKey: (NSString *) key
    withIndentation: (NSInteger) anInt;

- (void) displayWithIndentation: (NSInteger) anInt;

@end


@interface NSArray (plext)

- (void) displayCount: (NSUInteger) count
      withIndentation: (NSInteger) anInt;

- (void) displayWithIndentation: (NSInteger) anInt;

@end

#endif /* NSOBJECT_PROPERTYLIST_H */
