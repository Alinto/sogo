/* SOGoDefaultsSource.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#define NEEDS_DEFAULTS_SOURCE_INTERNAL 1
#import "SOGoDefaultsSource.h"

NSString *SOGoDefaultsSourceInvalidSource = @"SOGoDefaultsSourceInvalidSource";
NSString *SOGoDefaultsSourceUnmutableSource = @"SOGoDefaultsSourceUnmutableSource";

static Class NSArrayKlass = Nil;
static Class NSDataKlass = Nil;
static Class NSDictionaryKlass = Nil;
static Class NSStringKlass = Nil;

@implementation SOGoDefaultsSource

+ (void) initialize
{
  if (!NSArrayKlass)
    NSArrayKlass = [NSArray class];
  if (!NSDataKlass)
    NSDataKlass = [NSData class];
  if (!NSDictionaryKlass)
    NSDictionaryKlass = [NSDictionary class];
  if (!NSStringKlass)
    NSStringKlass = [NSString class];
}

+ (id) defaultsSourceWithSource: (id) newSource
                andParentSource: (SOGoDefaultsSource *) newParentSource
{
  SOGoDefaultsSource *sogoDefaultsSource;

  sogoDefaultsSource = [self new];
  [sogoDefaultsSource autorelease];
  [sogoDefaultsSource setSource: newSource];
  [sogoDefaultsSource setParentSource: newParentSource];

  if ([sogoDefaultsSource migrate])
    [sogoDefaultsSource synchronize];

  return sogoDefaultsSource;
}

- (id) init
{
  if ((self = [super init]))
    {
      source = nil;
      parentSource = nil;
      isMutable = NO;
    }

  return self;
}

- (void) dealloc
{
  [source release];
  [parentSource release];
  [super dealloc];
}

- (void) setSource: (id) newSource
{
  if ([newSource respondsToSelector: @selector (objectForKey:)])
    {
      ASSIGN (source, newSource);
      isMutable = [source respondsToSelector: @selector (setObject:forKey:)];
    }
  else
    [NSException raise: SOGoDefaultsSourceInvalidSource
                format: @"UserDefaults source '%@'"
                 @" does not respond to 'object:forKey:'", newSource];
}

- (id) source
{
  return source;
}

- (void) setParentSource: (SOGoDefaultsSource *) newParentSource
{
  ASSIGN (parentSource, newParentSource);
}

- (void) setObject: (id) value
	    forKey: (NSString *) key
{ 
  if (isMutable)
    [source setObject: value forKey: key];
  else
    [NSException raise: SOGoDefaultsSourceUnmutableSource
                format: @"UserDefaults source '%@' is not mutable", source];
}

- (id) objectForKey: (NSString *) objectKey
{
  id objectForKey;

  objectForKey = [source objectForKey: objectKey];
  if (!objectForKey)
    objectForKey = [parentSource objectForKey: objectKey];

  return objectForKey;
}

- (void) removeObjectForKey: (NSString *) key
{
  [source removeObjectForKey: key];
}

- (void) setBool: (BOOL) value
	  forKey: (NSString *) key
{
  [self setInteger: (value ? 1: 0) forKey: key];
}

- (BOOL) boolForKey: (NSString *) key
{
  id boolForKey;
  BOOL value;

  boolForKey = [self objectForKey: key];
  if (boolForKey)
    {
      if ([boolForKey respondsToSelector: @selector (boolValue)])
        value = [boolForKey boolValue];
      else
        {
          [self warnWithFormat: @"expected a boolean for '%@' (ignored)",
                key];
          value = NO;
        }
    }
  else
    value = NO;

  return value;
}

- (void) setFloat: (float) value
	   forKey: (NSString *) key
{
  [self setObject: [NSNumber numberWithFloat: value]
	forKey: key];
}

- (float) floatForKey: (NSString *) key
{
  id floatForKey;
  float value;

  floatForKey = [self objectForKey: key];
  if (floatForKey)
    {
      if ([floatForKey respondsToSelector: @selector (floatValue)])
        value = [floatForKey floatValue];
      else
        {
          [self warnWithFormat: @"expected a float for '%@' (ignored)",
                key];
          value = 0.0;
        }
    }
  else
    value = 0.0;

  return value;
}

- (void) setInteger: (int) value
	     forKey: (NSString *) key
{
  [self setObject: [NSString stringWithFormat: @"%d", value]
	forKey: key];
}

- (int) integerForKey: (NSString *) key
{
  id intForKey;
  int value;

  intForKey = [self objectForKey: key];
  if (intForKey)
    {
      if ([intForKey respondsToSelector: @selector (intValue)])
        value = [intForKey intValue];
      else
        {
          [self warnWithFormat: @"expected an integer for '%@' (ignored)",
                key];
          value = 0;
        }
    }
  else
    value = 0;

  return value;
}

- (NSData *) dataForKey: (NSString *) key
{
  NSData *dataForKey;

  dataForKey = [self objectForKey: key];
  if (dataForKey && ![dataForKey isKindOfClass: NSDataKlass])
    {
      [self warnWithFormat: @"expected an NSData for '%@' (ignored)",
            key];
      dataForKey = nil;
    }

  return dataForKey;
}

- (NSString *) stringForKey: (NSString *) key
{
  NSString *stringForKey;

  stringForKey = [self objectForKey: key];
  if (stringForKey && ![stringForKey isKindOfClass: NSStringKlass])
    {
      [self warnWithFormat: @"expected an NSString for '%@' (ignored)",
            key];
      stringForKey = nil;
    }

  return stringForKey;
}

- (NSDictionary *) dictionaryForKey: (NSString *) key
{
  NSDictionary *dictionaryForKey;

  /* Dictionaries are a special case for which we don't allow searches in the
     parent source. Each level can thus have its own set of dictionary
     values. */
  dictionaryForKey = [source objectForKey: key];
  if (dictionaryForKey
      && ![dictionaryForKey isKindOfClass: NSDictionaryKlass])
    {
      [self warnWithFormat: @"expected an NSDictionary for '%@' (ignored)",
            key];
      dictionaryForKey = nil;
    }

  return dictionaryForKey;
}

- (NSArray *) arrayForKey: (NSString *) key
{
  NSArray *arrayForKey;

  arrayForKey = [self objectForKey: key];
  if (arrayForKey && ![arrayForKey isKindOfClass: NSArrayKlass])
    {
      [self warnWithFormat: @"expected an NSArray for '%@' (ignored)",
            key];
      arrayForKey = nil;
    }

  return arrayForKey;
}

- (NSArray *) stringArrayForKey: (NSString *) key
{
  NSArray *stringArray;
  int count, max;

  stringArray = [self arrayForKey: key];
  max = [stringArray count];
  for (count = 0; stringArray && count < max; count++)
    if (![[stringArray objectAtIndex: count] isKindOfClass: NSStringKlass])
      {
        [self warnWithFormat: @"expected string values in array for '%@'"
              @", value %d is not a string (ignored)",
              key, count];
        stringArray = nil;
      }

  return stringArray;
}

- (BOOL) migrate
{
  return NO;
}

- (BOOL) migrateOldDefaultsWithDictionary: (NSDictionary *) migratedKeys
{
  NSArray *allKeys;
  id currentValue;
  NSString *oldName, *newName;
  int count, max;
  BOOL requireSync;

  requireSync = NO;

  allKeys = [migratedKeys allKeys];
  max = [allKeys count];
  for (count = 0; count < max; count++)
    {
      oldName = [allKeys objectAtIndex: count];
      currentValue = [source objectForKey: oldName];
      if (currentValue)
        {
          newName = [migratedKeys objectForKey: oldName];
          requireSync = YES;
          [source setObject: currentValue forKey: newName];
          [source removeObjectForKey: oldName];
          [self warnWithFormat: @"defaults key '%@' was renamed to '%@'",
                oldName, newName];
        }
    }

  return requireSync;
}

- (BOOL) synchronize
{
  BOOL rc;

  if ([source respondsToSelector: @selector (synchronize)])
    rc = [source synchronize];
  else
    {
      [self errorWithFormat: @"current source cannot synchronize defaults"];
      rc = NO;
    }

  return rc;
}

@end
