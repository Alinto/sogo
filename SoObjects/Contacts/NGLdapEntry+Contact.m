/* NGLdapEntry+Contact.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGLdap/NGLdapAttribute.h>

#import "NGLdapEntry+Contact.h"

@implementation NGLdapEntry (SOGoContactExtension)

- (NSString *) singleAttributeWithName: (NSString *) key
{
  return  [[self attributeWithName: key]
            stringValueAtIndex: 0];
}

- (NSDictionary *) asDictionaryWithAttributeNames: (NSArray *) attributeNames
                                         andCName: (NSString *) cName
{
  NSMutableDictionary *valuesDict;
  NSEnumerator *attrEnum;
  NSString *attribute;

  if (!attributeNames)
    attributeNames = [self attributeNames];

  valuesDict = [NSMutableDictionary dictionaryWithCapacity: [attributeNames count]];
  attrEnum = [attributeNames objectEnumerator];
  attribute = [attrEnum nextObject];
  while (attribute)
    {
      [valuesDict setObject: [[self attributeWithName: attribute]
                               stringValueAtIndex: 0]
                  forKey: attribute];
      attribute = [attrEnum nextObject];
    }
  [valuesDict setObject: [[self attributeWithName: cName]
                           stringValueAtIndex: 0]
              forKey: @"c_name"];

  return valuesDict;
}

@end
