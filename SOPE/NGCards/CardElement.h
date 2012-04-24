/* CardElement.h - this file is part of SOPE
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

#ifndef CARDELEMENT_H
#define CARDELEMENT_H

#import <Foundation/NSObject.h>

@class NSArray;
@class NSDictionary;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSString;

@class CardGroup;

@interface CardElement : NSObject <NSCopying, NSMutableCopying>
{
  NSString *tag;
  NSMutableDictionary *values;
  NSMutableDictionary *attributes;
  NSString *group;
  CardGroup *parent;
}

+ (id) elementWithTag: (NSString *) aTag;

+ (id) simpleElementWithTag: (NSString *) aTag
                      value: (NSString *) aValue;

+ (id) simpleElementWithTag: (NSString *) aTag
                 singleType: (NSString *) aType
                      value: (NSString *) aValue;

- (void) setParent: (CardGroup *) aParent;
- (id) parent;

- (void) setTag: (NSString *) aTag;
- (NSString *) tag;

- (void) setGroup: (NSString *) aGroup;
- (NSString *) group;

- (BOOL) isVoid;

- (void) setValues: (NSMutableDictionary *) newValues;
- (NSMutableDictionary *) values;

/* ELEM:...;value1,value2,...;... */
- (void) setValues: (NSMutableArray *) newValues
           atIndex: (NSUInteger) idx
            forKey: (NSString *) key;

/* ELEM:...;value;... */
- (void) setSingleValue: (NSString *) newValue
                atIndex: (NSUInteger) idx
                 forKey: (NSString *) key;
/* ELEM:value */
- (void) setSingleValue: (NSString *) newValue
                 forKey: (NSString *) key;

- (NSMutableArray *) valuesForKey: (NSString *) key;
- (NSMutableArray *) valuesAtIndex: (NSUInteger) idx
                            forKey: (NSString *) key;

/* This joins all subvalues with "," and ordered values with ";". Handy for
   retrieving data from clients which don't escape their data properly. */
- (NSString *) flattenedValuesForKey: (NSString *) key;
- (NSString *) flattenedValueAtIndex: (NSUInteger) idx
                              forKey: (NSString *) key;

/* attribute values */
- (void) setValue: (unsigned int) anInt
      ofAttribute: (NSString *) anAttribute
               to: (NSString *) aValue;
- (NSString *) value: (unsigned int) anInt
         ofAttribute: (NSString *) anAttribute;

- (void) addAttribute: (NSString *) anAttribute
                value: (NSString *) aValue;
- (void) addAttributes: (NSDictionary *) someAttributes;
- (void) removeValue: (NSString *) aValue
       fromAttribute: (NSString *) anAttribute;
- (NSMutableDictionary *) attributes;
- (BOOL) hasAttribute: (NSString *) aType
          havingValue: (NSString *) aValue;

- (void) addType: (NSString *) aType;

/* rendering */
- (NSArray *) orderOfAttributeKeys;
- (NSArray *) orderOfValueKeys;
- (NSString *) versitString;

- (CardGroup *) searchParentOfClass: (Class) parentClass;

/* conversion */
- (id) elementWithClass: (Class) elementClass;

/* copy */
- (void) setAttributesAsCopy: (NSMutableDictionary *) someAttributes;
- (NSMutableArray *) deepCopyOfArray: (NSArray *) oldArray
			    withZone: (NSZone *) aZone;
- (NSMutableDictionary *) deepCopyOfDictionary: (NSDictionary *) oldDictionary
				      withZone: (NSZone *) aZone;

@end

#define IS_EQUAL(a,b,sel) \
  _iCalSafeCompareObjects (a, b, @selector(sel))

static __inline__ BOOL _iCalSafeCompareObjects(id a, id b, SEL comparator)
{
  id va = a;
  id vb = b;
  BOOL (*compm)(id, SEL, id);

  if((!va && vb) || (va && !vb))
    return NO;
  else if(va == vb)
    return YES;
  compm = (BOOL (*)( id, SEL, id)) [va methodForSelector: comparator];

  return compm(va, comparator, vb);
}

#endif /* CARDELEMENT_H */
