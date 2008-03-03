/* NGVList.m - this file is part of NGCards
 *
 * Copyright (C) 2008 Inverse groupe conseil
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

#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
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
  [[self uniqueChildWithTag: @"prodid"] setValue: 0 to: newProdID];
}

- (NSString *) prodID
{
  return [[self uniqueChildWithTag: @"prodid"] value: 0];
}

- (void) setVersion: (NSString *) newVersion
{
  [[self uniqueChildWithTag: @"version"] setValue: 0
					 to: newVersion];
}

- (NSString *) version
{
  return [[self uniqueChildWithTag: @"version"] value: 0];
}

- (void) setUid: (NSString *) newUid
{
  [[self uniqueChildWithTag: @"uid"] setValue: 0
				     to: newUid];
}

- (NSString *) uid
{
  return [[self uniqueChildWithTag: @"uid"] value: 0];
}

- (void) setAccessClass: (NSString *) newAccessClass
{
  [[self uniqueChildWithTag: @"class"] setValue: 0
				       to: newAccessClass];
}

- (NSString *) accessClass
{
  return [[self uniqueChildWithTag: @"class"] value: 0];
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
  [[self uniqueChildWithTag: @"fn"] setValue: 0 to: newFn];
}

- (NSString *) fn
{
  return [[self uniqueChildWithTag: @"fn"] value: 0];
}

- (void) setNickname: (NSString *) newNickname
{
  [[self uniqueChildWithTag: @"nickname"] setValue: 0
					  to: newNickname];
}

- (NSString *) nickname
{
  return [[self uniqueChildWithTag: @"nickname"] value: 0];
}

- (void) setDescription: (NSString *) newDescription
{
  [[self uniqueChildWithTag: @"description"] setValue: 0
					     to: newDescription];
}

- (NSString *) description
{
  return [[self uniqueChildWithTag: @"description"] value: 0];
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
