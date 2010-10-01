/* SOGoGCSFolder+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import "SOGoGCSFolder+MAPIStore.h"

@implementation SOGoGCSFolder (MAPIStore)

- (NSArray *) componentKeysWithType: (NSString *) component
{
  NSArray *records;
  NSMutableArray *keys;
  NSInteger count, max;
  NSDictionary *record;

  [self toOneRelationshipKeys];

  records = [childRecords allValues];
  max = [records count];
  keys = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      record = [records objectAtIndex: count];
      if ([[record objectForKey: @"c_component"]
            isEqualToString: component])
        [keys addObject: [record objectForKey: @"c_name"]];
    }

  return keys;
}

@end
