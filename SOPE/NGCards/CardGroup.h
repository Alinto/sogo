/* CardGroup.h - this file is part of SOPE
 *
 * Copyright (C) 2006 Inverse inc.
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

#ifndef CARDGROUP_H
#define CARDGROUP_H

#import "CardElement.h"

@class NSArray;
@class NSMutableArray;
@class NSString;

@interface CardGroup : CardElement <NSCopying, NSMutableCopying>
{
  NSMutableArray *children;
}

+ (id) parseSingleFromSource: (id) source;
+ (NSArray *) parseFromSource: (id) source;

+ (id) groupWithTag: (NSString *) aTag;
+ (id) groupWithTag: (NSString *) aTag
           children: (NSArray *) someChildren;

- (Class) classForTag: (NSString *) tagClass;

- (CardElement *) uniqueChildWithTag: (NSString *) aTag;
- (void) setUniqueChild: (CardElement *) aChild;

- (NSMutableArray *) children;

- (void) addChild: (CardElement *) aChild;
- (void) addChildren: (NSArray *) someChildren;
- (void) removeChild: (CardElement *) aChild;
- (void) removeChildren: (NSArray *) someChildren;

- (void) cleanupEmptyChildren;

- (CardElement *) firstChildWithTag: (NSString *) aTag;
- (NSArray *) childrenWithTag: (NSString *) aTag;
- (NSArray *) childrenWithAttribute: (NSString *) anAttribute
                        havingValue: (NSString *) aValue;
- (NSArray *) childrenWithTag: (NSString *) aTag
                 andAttribute: (NSString *) anAttribute
                  havingValue: (NSString *) aValue;
- (NSArray *) childrenGroupWithTag: (NSString *) aTag
                         withChild: (NSString *) aChild
                 havingSimpleValue: (NSString *) aValue;

- (void) addChildWithTag: (NSString *) aTag
                   types: (NSArray *) someTypes
             singleValue: (NSString *) aValue;

- (void) setChildrenAsCopy: (NSMutableArray *) someChildren;

- (void) replaceThisElement: (CardElement *) oldElement
                withThisOne: (CardElement *) newElement;

@end

#endif /* CARDGROUP_H */
