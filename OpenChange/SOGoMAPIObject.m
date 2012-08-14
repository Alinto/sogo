/* SOGoMAPIObject.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSCalendarDate.h>

#import "SOGoMAPIObject.h"

@implementation SOGoMAPIObject

- (id) init
{
  if ((self = [super init]))
    {
      isNew = NO;
      creationDate = [NSCalendarDate date];
      [creationDate retain];
      lastModified = [creationDate copy];
      properties = [NSMutableDictionary new];
    }

  return self;
}

- (void) dealloc
{
  [creationDate release];
  [lastModified release];
  [properties release];
  [super dealloc];
}

- (void) setIsNew: (BOOL) newIsNew
{
  isNew = newIsNew;
}

- (BOOL) isNew
{
  return isNew;
}

- (void) adjustLastModified
{
  ASSIGN (lastModified, [NSCalendarDate date]);
}

- (BOOL) isFolderish
{
  return NO;
}

- (NSMutableDictionary *) properties
{
  return properties;
}

- (NSCalendarDate *) creationDate
{
  return creationDate;
}

- (NSCalendarDate *) lastModified
{
  return lastModified;
}

@end
