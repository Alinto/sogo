/* NSDictionary+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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
#import <Foundation/NSData.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSCharacterSet.h>

#import <NGExtensions/NGBase64Coding.h>
#import <SoObjects/SOGo/NSString+Utilities.h>

#import "NSArray+Utilities.h"
#import "NSObject+Utilities.h"
#import "NSDictionary+Utilities.h"

@implementation NSDictionary (SOGoDictionaryUtilities)

+ (NSDictionary *) dictionaryFromStringsFile: (NSString *) file
{
  NSString *serialized;
  NSMutableData *content;
  NSDictionary *newDictionary;

  content = [NSMutableData new];
  [content appendBytes: "{" length: 1];
  [content appendData: [NSData dataWithContentsOfFile: file]];
  [content appendBytes: "}" length: 1];
  serialized = [[NSString alloc] initWithData: content
				 encoding: NSUTF8StringEncoding];
  [content release];
  newDictionary = [serialized propertyList];
  [serialized release];

  return newDictionary;
}

- (NSString *) jsonRepresentation
{
  NSMutableArray *values;
  NSString *representation, *currentKey, *currentValue, *currentPair;
  NSEnumerator *keys;

  values = [NSMutableArray new];
  keys = [[self allKeys] objectEnumerator];
  currentKey = [keys nextObject];
  while (currentKey)
    {
      currentValue = [[self objectForKey: currentKey] jsonRepresentation];
      currentPair = [NSString stringWithFormat: @"%@: %@",
			      [currentKey jsonRepresentation], currentValue];
      [values addObject: currentPair];
      currentKey = [keys nextObject];
    }
  representation = [NSString stringWithFormat: @"{%@}",
			     [values componentsJoinedByString: @", "]];
  [values release];

  return representation;
}

- (NSString *) keysWithFormat: (NSString *) keyFormat
{
  NSArray *keys, *allKeys;
  unsigned int count, max;
  NSMutableString *keysWithFormat;
  id value;

  keysWithFormat = [NSMutableString stringWithString: keyFormat];

  allKeys = [self allKeys];
  keys = [allKeys stringsWithFormat: @"%{%@}"];

  max = [allKeys count];
  for (count = 0; count < max; count++)
    {
      value = [self objectForKey: [allKeys objectAtIndex: count]];
      if ([value isKindOfClass: [NSNull class]])
	[keysWithFormat replaceString: [keys objectAtIndex: count]
			withString: @""];
      else
	[keysWithFormat replaceString: [keys objectAtIndex: count]
			withString: [value description]];
    }

  return keysWithFormat;
}

- (NSComparisonResult) caseInsensitiveDisplayNameCompare: (NSDictionary *) theDictionary
{
  return [[self objectForKey: @"cn"] caseInsensitiveCompare: [theDictionary objectForKey: @"cn"]];
}

// LDIF Methods
- (void) _appendLDIFKey: (NSString *) key
                  value: (NSString *) value
               toString: (NSMutableString *) ldifString
{
  if ([value _isLDIFSafe])
    [ldifString appendFormat: @"%@: %@\n", key, value];
  else
    [ldifString appendFormat: @"%@:: %@\n",
                key, [value stringByEncodingBase64]];
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

  classes = [[self objectForKey: @"objectClasses"] objectEnumerator];
  while ((currentClass = [classes nextObject]))
    [self _appendLDIFKey: @"objectClass" value: currentClass
                toString: ldifString];
}

- (NSString *) userRecordAsLDIFEntry
{
  NSMutableString *ldifString;
  NSEnumerator *keys;
  NSString *currentKey;

// {CalendarAccess = YES; MailAccess = YES; c_cn = "Wolfgang Sourdeau"; c_emails = ("wolfgang@test.com"); c_name = "wolfgang@test.com"; c_uid = "wolfgang@test.com"; cn = "wolfgang@test.com"; displayName = "Wolfgang Sourdeau"; dn = "cn=wolfgang@test.com,ou=evariste,o=inverse.ca"; givenName = Wolfgang; mail = "wolfgang@test.com"; objectClass = organizationalPerson; sn = Sourdeau; }

  ldifString = [NSMutableString string];
  [self _appendLDIFKey: @"dn" toString: ldifString];
  [self _appendObjectClassesToString: ldifString];

  keys = [[self allKeys] objectEnumerator];
  while ((currentKey = [keys nextObject]))
    {
      if (!([currentKey isEqualToString: @"CalendarAccess"]
            || [currentKey isEqualToString: @"MailAccess"]
            || [currentKey isEqualToString: @"ContactAccess"]
            || [currentKey hasPrefix: @"objectClass"]
            || [currentKey hasPrefix: @"c_"]
            || [currentKey isEqualToString: @"dn"]))
        [self _appendLDIFKey: currentKey toString: ldifString];
    }

  return ldifString;
}


@end

@implementation NSMutableDictionary (SOGoDictionaryUtilities)

- (void) setObjects: (NSArray *) objects
	    forKeys: (NSArray *) keys
{
  unsigned int count, max;

  max = [objects count];
  if ([keys count] == max)
    for (count = 0; count < max; count++)
      [self setObject: [objects objectAtIndex: count]
	    forKey: [keys objectAtIndex: count]];
  else
    [NSException raise: NSInvalidArgumentException
		 format: @"Number of objects does not match"
		 @" the number of keys."];
}


@end

