/* LDAPSourceSchema.m - this file is part of SOGo
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <EOControl/EOQualifier.h>

#import <NGLdap/NGLdapConnection.h>
#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapEntry.h>

#import "LDAPSourceSchema.h"
#import "NSDictionary+Utilities.h"

static EOQualifier *allOCQualifier = nil;

@implementation LDAPSourceSchema

+ (void) initialize
{
  allOCQualifier = [[EOKeyValueQualifier alloc]
                            initWithKey: @"objectClass"
                       operatorSelector: EOQualifierOperatorEqual
                                  value: @"*"];
}

- (id) init
{
  if ((self = [super init]))
    {
      schema = nil;
    }

  return self;
}

- (void) dealloc
{
  [schema release];
  [super dealloc];
}

static NSArray *
schemaTokens (NSString *schema)
{
  unichar *characters;
  NSUInteger count, max, parenLevel = 0, firstChar = (NSUInteger) -1;
  NSMutableArray *arrayString, *parentArray, *currentArray = nil;
  NSArray *topArray = nil;
  NSString *token;

  arrayString = [NSMutableArray array];

  max = [schema length];
  characters = malloc ((max + 1) * sizeof (unichar));
  characters[max] = 0;
  [schema getCharacters: characters];

  for (count = 0; count < max; count++)
    {
      switch (characters[count])
        {
        case '(':
          // NSLog (@"increase");
          parenLevel++;
          parentArray = currentArray;
          currentArray = [NSMutableArray array];
          if (parentArray == nil)
            topArray = currentArray;
          [parentArray addObject: currentArray];
          [arrayString addObject: currentArray];
          break;
        case ')':
          // NSLog (@"decrease");
          parenLevel--;
          [arrayString removeLastObject];
          currentArray = [arrayString lastObject];
          break;
        case ' ':
          if (firstChar != (NSUInteger) -1)
            {
              token = [NSString stringWithCharacters: characters + firstChar
                                              length: (count - firstChar)];
              if (![token isEqualToString: @"$"])
                [currentArray addObject: token];
              // NSLog (@"added token: %@", token);
              firstChar = (NSUInteger) -1;
            }
          break;
        default:
          if (currentArray && (firstChar == (NSUInteger) -1))
            firstChar = count;
        }
    }

  free (characters);

  return topArray;
}

static inline id
schemaValue (NSArray *tokens, NSString *key)
{
  NSUInteger idx;
  id value;

  idx = [tokens indexOfObject: key];
  if (idx != NSNotFound)
    value = [tokens objectAtIndex: (idx + 1)];
  else
    value = nil;

  return value;
}

static NSMutableDictionary *
parseSchema (NSString *schema)
{
  NSArray *tokens;
  NSMutableDictionary *schemaDict;
  NSMutableArray *fields;
  id value;

  schemaDict = [NSMutableDictionary dictionaryWithCapacity: 6];
  tokens = schemaTokens (schema);
  // [schemaDict setObject: [tokens objectAtIndex: 0]
  //                forKey: @"oid"];
  value = schemaValue (tokens, @"NAME");
  if (value)
    {
      /* sometimes, objectClasses can have two names */
      if ([value isKindOfClass: [NSString class]])
        value = [NSArray arrayWithObject: value];
      [schemaDict setObject: value forKey: @"names"];
    }

  value = schemaValue (tokens, @"SUP");
  if (value)
    [schemaDict setObject: value forKey: @"sup"];

  fields = [NSMutableArray new];
  [schemaDict setObject: fields forKey: @"fields"];
  [fields release];
  value = schemaValue (tokens, @"MUST");
  if (value)
    {
      if ([value isKindOfClass: [NSArray class]])
        [fields addObjectsFromArray: value];
      else
        [fields addObject: value];
    }
  value = schemaValue (tokens, @"MAY");
  if (value)
    {
      if ([value isKindOfClass: [NSArray class]])
        [fields addObjectsFromArray: value];
      else
        [fields addObject: value];
    }

  return schemaDict;
}

static void
fillSchemaFromEntry (NSMutableDictionary *schema, NGLdapEntry *entry)
{
  NSEnumerator *strings;
  NGLdapAttribute *attr;
  NSMutableDictionary *schemaDict;
  NSArray *names;
  NSString *string, *name;
  NSUInteger count, max;

  attr = [entry attributeWithName: @"objectclasses"];
  strings = [attr stringValueEnumerator];
  while ((string = [strings nextObject]))
    {
      schemaDict = parseSchema (string);
      names = [schemaDict objectForKey: @"names"];
      max = [names count];
      for (count = 0; count < max; count++)
        {
          name = [[names objectAtIndex: count] lowercaseString];
          if ([name hasPrefix: @"'"] && [name hasSuffix: @"'"])
            name
              = [name substringWithRange: NSMakeRange (1, [name length] - 2)];
          [schema setObject: schemaDict forKey: name];
        }
      /* the list of names is no longer required from the schema itself */
      [schemaDict removeObjectForKey: @"names"];
    }
}

- (void) readSchemaFromConnection: (NGLdapConnection *) conn
{
  NSEnumerator *entries;
  NGLdapEntry *entry;
  NSString *dn;

  ASSIGN (schema, [NSMutableDictionary new]);
  [schema release];

  entries = [conn baseSearchAtBaseDN: @""
                           qualifier: allOCQualifier
                          attributes: [NSArray arrayWithObject: @"subschemaSubentry"]];
  entry = [entries nextObject];
  if (entry)
    {
      dn = [[entry attributeWithName: @"subschemaSubentry"]
             stringValueAtIndex: 0];
      if (dn)
        {
          entries = [conn baseSearchAtBaseDN: dn
                                   qualifier: allOCQualifier
                                  attributes: [NSArray arrayWithObject: @"objectclasses"]];
          entry = [entries nextObject];
          if (entry)
            fillSchemaFromEntry (schema, entry);
        }
    }
}

static void
fillFieldsForClass (NSMutableDictionary *schema, NSString *schemaName,
                    NSMutableArray *fields)
{
  NSDictionary *schemaDict;
  NSString *sup;
  NSArray *schemaFields;

  schemaDict = [schema objectForKey: [schemaName lowercaseString]];
  if (schemaDict)
    {
      schemaFields = [schemaDict objectForKey: @"fields"];
      if ([schemaFields count] > 0)
        [fields addObjectsFromArray: schemaFields];
      sup = [schemaDict objectForKey: @"sup"];
      if ([sup length] > 0)
        fillFieldsForClass (schema, sup, fields);
    }
}

- (NSArray *) fieldsForClass: (NSString *) className
{
  NSMutableArray *fields;

  fields = [NSMutableArray arrayWithCapacity: 128];
  fillFieldsForClass (schema, className, fields);

  return fields;
}

- (NSArray *) fieldsForClasses: (NSArray *) classNames
{
  NSMutableDictionary *fieldHash;
  NSNumber *yesValue;
  NSString *name;
  NSUInteger count, max;

  yesValue = [NSNumber numberWithBool: YES];

  fieldHash = [NSMutableDictionary dictionary];
  max = [classNames count];
  for (count = 0; count < max; count++)
    {
      name = [classNames objectAtIndex: count];
      [fieldHash setObject: yesValue forKeys: [self fieldsForClass: name]];
    }

  return [fieldHash allKeys];
}

@end
