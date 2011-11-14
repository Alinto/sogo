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
  CardElement *element;
  id tmp;

  entry = [NSMutableDictionary dictionary];

  [entry setObject: [NSString stringWithFormat: @"cn=%@,mail=%@", 
                     [self fn], [self preferredEMail]]
            forKey: @"dn"];
  [entry setObject: [NSArray arrayWithObjects: @"top", @"person", 
                     @"organizationalPerson", @"inetOrgPerson", 
                     @"mozillaAbPersonObsolete", nil]
            forKey: @"objectclass"];

  element = [self n];
  tmp = [element flattenedValueAtIndex: 1 forKey: @""];
  if ([tmp length] > 0)
    [entry setObject: tmp  forKey: @"givenName"];
  
  tmp = [element flattenedValueAtIndex: 0 forKey: @""];
  if ([tmp length] > 0)
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
      buffer = [[marray objectAtIndex: [marray count]-1]
                 flattenedValuesForKey: @""];

      if ([buffer caseInsensitiveCompare: [self preferredEMail]] != NSOrderedSame)
        [entry setObject: buffer forKey: @"mozillaSecondEmail"];
    }

  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] flattenedValuesForKey: @""]
              forKey: @"homePhone"];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"fax"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] flattenedValuesForKey: @""]
              forKey: @"fax"];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"cell"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] flattenedValuesForKey: @""]
              forKey: @"mobile"];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"pager"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] flattenedValuesForKey: @""]
              forKey: @"pager"];

  array = [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    {
      tmp = [array objectAtIndex: 0];
      [entry setObject: [tmp flattenedValueAtIndex: 1 forKey: @""]
                forKey: @"mozillaHomeStreet2"];
      [entry setObject: [tmp flattenedValueAtIndex: 2 forKey: @""]
                forKey: @"homeStreet"];
      [entry setObject: [tmp flattenedValueAtIndex: 3 forKey: @""]
                forKey: @"mozillaHomeLocalityName"];
      [entry setObject: [tmp flattenedValueAtIndex: 4 forKey: @""]
                forKey: @"mozillaHomeState"];
      [entry setObject: [tmp flattenedValueAtIndex: 5 forKey: @""]
                forKey: @"mozillaHomePostalCode"];
      [entry setObject: [tmp flattenedValueAtIndex: 6 forKey: @""]
                forKey: @"mozillaHomeCountryName"];
    }

  element = [self org];
  tmp = [element flattenedValueAtIndex: 0 forKey: @""];
  if ([tmp length] > 0)
    [entry setObject: tmp forKey: @"o"];

  array = [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    {
      tmp = [array objectAtIndex: 0];
      [entry setObject: [tmp flattenedValueAtIndex: 1 forKey: @""]
                forKey: @"mozillaWorkStreet2"];
      [entry setObject: [tmp flattenedValueAtIndex: 2 forKey: @""]
                forKey: @"street"];
      [entry setObject: [tmp flattenedValueAtIndex: 3 forKey: @""]
                forKey: @"l"];
      [entry setObject: [tmp flattenedValueAtIndex: 4 forKey: @""]
                forKey: @"st"];
      [entry setObject: [tmp flattenedValueAtIndex: 5 forKey: @""]
                forKey: @"postalCode"];
      [entry setObject: [tmp flattenedValueAtIndex: 6 forKey: @""]
                forKey: @"c"];
    }

  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] flattenedValuesForKey: @""] 
              forKey: @"telephoneNumber"];

  array = [self childrenWithTag: @"url" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] flattenedValuesForKey: @""] 
              forKey: @"workurl"];

  array = [self childrenWithTag: @"url" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    [entry setObject: [[array objectAtIndex: 0] flattenedValuesForKey: @""] 
              forKey: @"homeurl"];

  tmp = [self note];
  if (tmp && [tmp length])
    [entry setObject: tmp forKey: @"description"];

  rc = [NSMutableString stringWithString: [entry userRecordAsLDIFEntry]];
  [rc appendFormat: @"\n"];

  return rc;
}

@end /* NGVCard */
