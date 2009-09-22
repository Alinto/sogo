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

#import <SOGo/NSDictionary+Utilities.h>

#import "NGVCard+SOGo.h"

@implementation NGVCard (SOGoExtensions)

- (NSString *) ldifString
{
  NSMutableString *rc;
  NSString *buffer;
  NSArray *array;
  NSMutableArray *marray;
  NSMutableDictionary *entry;
  id tmp;

  entry = [NSMutableDictionary dictionary];

  [entry setObject: [NSString stringWithFormat: @"cn=%@,mail=%@", 
                     [self fn], [self preferredEMail]]
            forKey: @"dn"];
  [entry setObject: [NSArray arrayWithObjects: @"top", @"person", 
                     @"organizationalPerson", @"inetOrgPerson", 
                     @"mozillaAbPersonObsolete", nil]
            forKey: @"objectclass"];
  
  tmp = ([[self n] count] > 1 ? [[self n] objectAtIndex: 1] : nil);
  if (tmp)
    [entry setObject: tmp  forKey: @"givenName"];
  
  tmp = ([[self n] count] ? [[self n] objectAtIndex: 0] : nil);
  if (tmp)
    [entry setObject: tmp  forKey: @"sn"];

  tmp = [self fn];
  if (tmp)
    [entry setObject: tmp  forKey: @"cn"];
  
  tmp = [self preferredEMail];
  if (tmp)
    [entry setObject: tmp forKey: @"mail"];
  
  [entry setObject: @"0Z" forKey: @"modifytimestamp"];

  buffer = [self nickname];
  if (buffer && [buffer length] > 0)
    [entry setObject: buffer forKey: @"mozillaNickname"];

  marray = [NSMutableArray arrayWithArray: [self childrenWithTag: @"email"]];
  [marray removeObjectsInArray: [self childrenWithTag: @"email"
                 andAttribute: @"type"
                  havingValue: @"pref"]];
  if ([marray count])
    {
      buffer = [[marray objectAtIndex: [marray count]-1] value: 0];

      if ([buffer caseInsensitiveCompare: [self preferredEMail]] != NSOrderedSame)
        [entry setObject: buffer forKey: @"mozillaSecondEmail"];
    }

  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] value: 0] forKey: @"homePhone"];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"fax"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] value: 0] forKey: @"fax"];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"cell"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] value: 0] forKey: @"mobile"];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"pager"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] value: 0] forKey: @"pager"];

  array = [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    {
      tmp = [array objectAtIndex: 0];
      [entry setObject: [tmp value: 0] forKey: @"homeStreet"];
      [entry setObject: [tmp value: 1] forKey: @"mozillaHomeLocalityName"];
      [entry setObject: [tmp value: 2] forKey: @"mozillaHomeState"];
      [entry setObject: [tmp value: 3] forKey: @"mozillaHomePostalCode"];
      [entry setObject: [tmp value: 4] forKey: @"mozillaHomeCountryName"];
    }

  array = [self org];
  if (array && [array count])
    [entry setObject: [array objectAtIndex: 0] forKey: @"o"];

  array = [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    {
      tmp = [array objectAtIndex: 0];
      [entry setObject: [tmp value: 0] forKey: @"street"];
      [entry setObject: [tmp value: 1] forKey: @"l"];
      [entry setObject: [tmp value: 2] forKey: @"st"];
      [entry setObject: [tmp value: 3] forKey: @"postalCode"];
      [entry setObject: [tmp value: 4] forKey: @"c"];
    }

  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] value: 0] 
              forKey: @"telephoneNumber"];

  array = [self childrenWithTag: @"url" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] value: 0] 
              forKey: @"workurl"];

  array = [self childrenWithTag: @"url" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] value: 0] 
              forKey: @"homeurl"];

  tmp = [self note];
  if (tmp && [tmp length])
    [entry setObject: tmp forKey: @"description"];

  rc = [NSMutableString stringWithString: [entry userRecordAsLDIFEntry]];
  [rc appendFormat: @"\n"];

  return rc;
}

@end /* NGVCard */
