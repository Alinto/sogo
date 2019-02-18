/* NGVList.m - this file is part of NGCards
 *
 * Copyright (C) 2008-2019 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "NGVCardReference.h"

#import "NGVList.h"

@implementation NGVList

+ (id) listWithUid: (NSString *) _uid
{
  NGVList *newList;

  newList = [[self alloc] initWithUid: _uid];
  [newList autorelease];

  return newList;
}

- (id) initWithUid: (NSString *) _uid
{
  if ((self = [self init]))
    {
      [self setTag: @"vlist"];
      [self setUid: _uid];
      [self setVersion: @"1.0"];
    }

  return self;
}

/* class mapping */
- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  tagClass = Nil;
  if ([classTag isEqualToString: @"PRODID"]
      || [classTag isEqualToString: @"VERSION"]
      || [classTag isEqualToString: @"UID"]
      || [classTag isEqualToString: @"CLASS"]
      || [classTag isEqualToString: @"FN"]
      || [classTag isEqualToString: @"NICKNAME"]
      || [classTag isEqualToString: @"DESCRIPTION"])
    tagClass = [CardElement class];
  else if ([classTag isEqualToString: @"CARD"])
    tagClass = [NGVCardReference class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

- (void) setProdID: (NSString *) newProdID
{
  [[self uniqueChildWithTag: @"prodid"] setSingleValue: newProdID forKey: @""];
}

- (NSString *) prodID
{
  return [[self uniqueChildWithTag: @"prodid"] flattenedValuesForKey: @""];
}

- (void) setVersion: (NSString *) newVersion
{
  [[self uniqueChildWithTag: @"version"] setSingleValue: newVersion
                                                 forKey: @""];
}

- (NSString *) version
{
  return [[self uniqueChildWithTag: @"version"] flattenedValuesForKey: @""];
}

- (void) setUid: (NSString *) newUid
{
  [[self uniqueChildWithTag: @"uid"] setSingleValue: newUid
                                             forKey: @""];
}

- (NSString *) uid
{
  return [[self uniqueChildWithTag: @"uid"] flattenedValuesForKey: @""];
}

- (void) setAccessClass: (NSString *) newAccessClass
{
  [[self uniqueChildWithTag: @"class"] setSingleValue: newAccessClass
                                               forKey: @""];
}

- (NSString *) accessClass
{
  return [[self uniqueChildWithTag: @"class"] flattenedValuesForKey: @""];
}

- (NGCardsAccessClass) symbolicAccessClass
{
  NGCardsAccessClass symbolicAccessClass;
  NSString *accessClass;

  accessClass = [[self accessClass] uppercaseString];
  if ([accessClass isEqualToString: @"PRIVATE"])
    symbolicAccessClass = NGCardsAccessPrivate;
  else if ([accessClass isEqualToString: @"CONFIDENTIAL"])
    symbolicAccessClass = NGCardsAccessConfidential;
  else
    symbolicAccessClass = NGCardsAccessPublic;

  return symbolicAccessClass;
}

- (BOOL) isPublic
{
  return ([self symbolicAccessClass] == NGCardsAccessPublic);
}

- (void) setFn: (NSString *) newFn
{
  [[self uniqueChildWithTag: @"fn"] setSingleValue: newFn forKey: @""];
}

- (NSString *) fn
{
  return [[self uniqueChildWithTag: @"fn"] flattenedValuesForKey: @""];
}

- (void) setNickname: (NSString *) newNickname
{
  [[self uniqueChildWithTag: @"nickname"] setSingleValue: newNickname
                                                  forKey: @""];
}

- (NSString *) nickname
{
  return [[self uniqueChildWithTag: @"nickname"] flattenedValuesForKey: @""];
}

- (void) setDescription: (NSString *) newDescription
{
  [[self uniqueChildWithTag: @"description"] setSingleValue: newDescription
                                                     forKey: @""];
}

- (NSString *) description
{
  return [[self uniqueChildWithTag: @"description"] flattenedValuesForKey: @""];
}

- (void) addCardReference: (NGVCardReference *) newCardRef
{
  [self addChild: newCardRef];
}

- (void) deleteCardReference: (NGVCardReference *) cardRef
{
  NSEnumerator *cardReferences;
  NGVCardReference *currentRef;
  NSMutableArray *deletedRefs;

  deletedRefs = [NSMutableArray array];
  cardReferences
    = [[self childrenWithTag: @"card"] objectEnumerator];
  while ((currentRef = [cardReferences nextObject]))
    if ([[currentRef reference]
	  isEqualToString: [cardRef reference]])
      [deletedRefs addObject: currentRef];

  [children removeObjectsInArray: deletedRefs];
}

- (NSArray *) cardReferences
{
  return [self childrenWithTag: @"card"];
}

@end
