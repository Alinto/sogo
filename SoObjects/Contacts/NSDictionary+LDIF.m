/* NSDictionary+LDIF.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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
#import <Foundation/NSString.h>
#import <NGExtensions/NGBase64Coding.h>

#import "NSString+LDIF.h"

#import "NSDictionary+LDIF.h"

@implementation NSDictionary (SOGoLDIF)

- (void) _appendLDIFKey: (NSString *) key
                  value: (NSString *) value
               toString: (NSMutableString *) ldifString
{
  if ([value isKindOfClass: [NSString class]] && [value length] > 0)
    {
      if ([value mustEncodeLDIFValue])
	[ldifString appendFormat: @"%@:: %@\n",
		    key, [value stringByEncodingBase64]];
      else
	[ldifString appendFormat: @"%@: %@\n", key, value];
    }
}

- (void) _appendLDIFKey: (NSString *) key
               toString: (NSMutableString *) ldifString
{
  id value;
  int count, max;

  value = [self objectForKey: key];
  if ([value isKindOfClass: [NSArray class]])
    {
      max = [value count];
      for (count = 0; count < max; count++)
        [self _appendLDIFKey: key value: [value objectAtIndex: count]
                    toString: ldifString];
    }
  else
    [self _appendLDIFKey: key value: [self objectForKey: key]
                toString: ldifString];
}

- (void) _appendObjectClassesToString: (NSMutableString *) ldifString
{
  NSEnumerator *classes;
  NSString *currentClass;
  NSArray *objectClass;

  objectClass = [self objectForKey: @"objectClass"];
  if ([objectClass isKindOfClass: [NSString class]])
    [self _appendLDIFKey: @"objectClass" value: (NSString *) objectClass
                toString: ldifString];
  else
    {
      classes = [objectClass objectEnumerator];
      while ((currentClass = [classes nextObject]))
        [self _appendLDIFKey: @"objectClass" value: currentClass
                    toString: ldifString];
    }
}

- (NSString *) ldifRecordAsString
{
  NSArray *keys;
  NSMutableString *ldifString;
  NSUInteger count, max;
  NSString *currentKey;

// {CalendarAccess = YES; MailAccess = YES; c_cn = "Wolfgang Sourdeau"; c_emails = ("wolfgang@test.com"); c_name = "wolfgang@test.com"; c_uid = "wolfgang@test.com"; cn = "wolfgang@test.com"; displayName = "Wolfgang Sourdeau"; dn = "cn=wolfgang@test.com,ou=evariste,o=inverse.ca"; givenName = Wolfgang; mail = "wolfgang@test.com"; objectClass = organizationalPerson; sn = Sourdeau; }

  ldifString = [NSMutableString string];
  [self _appendLDIFKey: @"dn" toString: ldifString];
  [self _appendObjectClassesToString: ldifString];

  keys = [self allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      currentKey = [keys objectAtIndex: count];
      if (!([currentKey hasPrefix: @"objectClass"]
            || [currentKey isEqualToString: @"dn"]))
        [self _appendLDIFKey: currentKey toString: ldifString];
    }

  return ldifString;
}

@end
