/* unittest.m - this file is part of $PROJECT_NAME_HERE$
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
#import <Foundation/NSString.h>

#import "unittest.h"

@implementation unittest

- (NSArray *) _testMethods
{
  Class testClass;
  MethodList *methodList;
  NSMutableArray *methods;
  NSString *methodName;
  unsigned int count, max;

  testClass = [self class];

  methods = [NSMutableArray new];
  [methods autorelease];

  while (testClass)
    {
      methodList = testClass->methods;
      max = methodList->method_count;

      for (count = 0; count < max; count++)
        {
          methodName
            = NSStringFromSelector (methodList->method_list[count].method_name);
          if ([methodName hasPrefix: @"test"])
            [methods addObject: methodName];
        }

      testClass = testClass->super_class;
    }

  return methods;
}

- (void) run
{
  NSEnumerator *methods;
  NSString *methodName;
  unsigned int count, successes, failures;
  BOOL success;

  methods = [[self _testMethods] objectEnumerator];
  methodName = [methods nextObject];

  count = 0;
  successes = 0;
  failures = 0;
  NSLog (@"-- start: %@", NSStringFromClass([self class]));
  while (methodName)
    {
      count++;
      if ([self respondsToSelector: @selector (setUp)])
        [self setUp];
      success
        = (BOOL) [self performSelector: NSSelectorFromString (methodName)];
      NSLog (@"%@ '%@'",
             ((success) ? @"PASSED" : @"FAILED"), methodName);
      if ([self respondsToSelector: @selector (tearDown)])
        [self tearDown];
      if (success)
        successes++;
      else
        failures++;
      methodName = [methods nextObject];
    }

  NSLog (@"-- end: %d methods, %d successes, %d failures",
         count, successes, failures);
}

@end
