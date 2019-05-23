/* SOGoContactGCSList.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import <NGCards/NGVList.h>

#import "SOGoContactGCSList.h"

@implementation SOGoContactGCSList

- (id) init
{
  if ((self = [super init]))
    {
      list = nil;
    }

  return self;
}

- (void) dealloc
{
  [list release];
  [super dealloc];
}

- (Class *) parsingClass
{
  return (Class *)[NGVList class];
}


/* content */

- (NGVList *) vList
{
  if (!list)
    {
      if ([[content uppercaseString] hasPrefix: @"BEGIN:VLIST"])
        list = [NGVList parseSingleFromSource: content];
      else
        list = [NGVList listWithUid: [self nameInContainer]];
      [list retain];
    }

  return list;
}

- (NSException *) copyToFolder: (SOGoGCSFolder *) newFolder
{
  NGVList *newList;
  NSString *newUID;
  SOGoContactGCSList *newGList;

  // Change the contact UID
  newUID = [self globallyUniqueObjectId];
  newList = [self vList];

  [newList setUid: newUID];

  newGList = [[self class] objectWithName:
                [NSString stringWithFormat: @"%@.vlf", newUID]
                               inContainer: newFolder];

  return [newGList saveComponent: newList];
}

- (NSException *) moveToFolder: (SOGoGCSFolder *) newFolder
{
  NSException *ex;

  ex = [self copyToFolder: newFolder];

  if (!ex)
    ex = [self delete];

  return ex;
}

/* DAV */

- (NSString *) davContentType
{
  return @"text/x-vlist";
}

- (NSString *) davAddressData
{
  return [self contentAsString];
}

/* specialized actions */

- (void) save
{
  NGVList *vlist;

  vlist = [self vList];

  [self saveComponent: vlist];
}

@end
