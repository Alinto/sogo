/* sogo-tests.m - this file is part of SOGo
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

#import <Foundation/Foundation.h>

#import "SOGoTest.h"

@interface SOGoTestRunner : NSObject
@end

@implementation SOGoTestRunner

+ (SOGoTestRunner *) testRunner
{
  SOGoTestRunner *testRunner;

  testRunner = [self new];
  [testRunner autorelease];

  return testRunner;
}

- (int) run
{
  NSEnumerator *allTestClasses;
  NSString *class;
  SOGoTest *test;
  NSAutoreleasePool *pool;
  int rc;

  rc = 0;
  pool = [NSAutoreleasePool currentPool];

  [self retain];
  allTestClasses = [[SOGoTest allTestClasses] objectEnumerator];
  [allTestClasses retain];
  while ((class = [allTestClasses nextObject]))
    {
      test = [NSClassFromString (class) new];
      if (![test run])
        rc |= -1;
      [pool emptyPool];
    }
  [allTestClasses autorelease];
  [self autorelease];

  return rc;
}

@end

int main()
{
  NSAutoreleasePool *pool;
  int rc;

  pool = [NSAutoreleasePool new];
  rc = [[SOGoTestRunner testRunner] run];
  [pool release];

  return rc;
}
