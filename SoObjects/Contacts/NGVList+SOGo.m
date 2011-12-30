/* NGVCard+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Cyril Robert <crobert@inverse.ca>
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import <NGCards/NGVCardReference.h>

#import "NSDictionary+LDIF.h"

#import "NGVList+SOGo.h"

@implementation NGVList (SOGoExtensions)

- (NSString *) ldifString
{
  NSMutableString *rc;
  NSArray *array;
  NSMutableArray *members;
  NGVCardReference *tmp;
  NSMutableDictionary *entry;
  int i, count;

  entry = [NSMutableDictionary dictionary];

  [entry setObject: [NSString stringWithFormat: @"cn=%@", [self fn]]
            forKey: @"dn"];
  [entry setObject: [NSArray arrayWithObjects: @"top", @"groupOfNames", nil]
            forKey: @"objectclass"];
  [entry setObject: [self fn] forKey: @"cn"];
  if ([self nickname])
    [entry setObject: [self nickname] forKey: @"mozillaNickname"];
  if ([self description])
    [entry setObject: [self description] forKey: @"description"];

  array = [self cardReferences];
  count = [array count];
  members = [NSMutableArray array];
  for (i = 0; i < count; i++)
    {
      tmp = [array objectAtIndex: i];
      [members addObject: [NSString stringWithFormat: 
                           @"cn=%@,mail=%@", [tmp fn], [tmp email]]];
    }
  [entry setObject: members forKey: @"member"];

  rc = [NSMutableString stringWithString: [entry ldifRecordAsString]];
  [rc appendFormat: @"\n"];

  return rc;
}

@end /* NGVList */
