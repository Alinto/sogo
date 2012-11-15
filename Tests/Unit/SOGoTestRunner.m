/* SOGoTestRunner.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

#import "SOGoTestRunner.h"

#define EXPECTED_FAILURES 3

@implementation SOGoTestRunner

+ (SOGoTestRunner *) testRunner
{
  SOGoTestRunner *testRunner;

  testRunner = [self new];
  [testRunner autorelease];

  return testRunner;
}

- (id) init
{
  if ((self = [super init]))
    {
      testCount = 0;
      failuresCount = 0;
      errorsCount = 0;
      hasFailed = NO;
      messages = [NSMutableArray new];
    }

  return self;
}

- (void) dealloc
{
  [messages release];
  [super dealloc];
}

- (int) run
{
  NSEnumerator *allTestClasses;
  NSString *class;
  SOGoTest *test;
  int rc;

  rc = 0;

  [self retain];
  allTestClasses = [[SOGoTest allTestClasses] objectEnumerator];
  [allTestClasses retain];
  while ((class = [allTestClasses nextObject]))
    {
      test = [NSClassFromString (class) new];
      [test setTestRunner: self];
      if (![test run])
        rc |= -1;
      [test release];
    }

  [self displayReport];

  [allTestClasses autorelease];
  [self autorelease];

  return (failuresCount + errorsCount != EXPECTED_FAILURES);
}

- (void) incrementTestCounter: (SOGoTestFailureCode) failureCode
{
  static char failureChars[] = { '.', 'F', 'E' };

  testCount++;
  fprintf (stderr, "%c", failureChars[failureCode]);
}

- (void) reportException: (NSException *) exception
                  method: (NSString *) methodName
                withCode: (SOGoTestFailureCode) failureCode
{
  static NSString *failurePrefixs[] = { @"", @"FAIL", @"ERROR" };
  NSMutableString *message;
  NSString *fileInfo;

  hasFailed = YES;

  message = [NSMutableString stringWithFormat: @"%@: %@",
                             failurePrefixs[failureCode], methodName];
  fileInfo = [[exception userInfo] objectForKey: @"fileInfo"];
  if (fileInfo)
    [message appendFormat: @" (%@)\n", fileInfo];
  else
    [message appendString: @"\n"];
  [message appendString: @"----------------------------------------------------------------------\n"];
    
  if (failureCode == SOGoTestFailureFailure)
    {
      [message appendString: [exception reason]];
      failuresCount++;
    }
  else if (failureCode == SOGoTestFailureError)
    {
      [message appendFormat: @"an exception occured: %@\n"
                 @"  reason: %@",
               [exception name], [exception reason]];
      errorsCount++;
    }
  [message appendString: @"\n"];
  [messages addObject: message];
}

- (void) displayReport
{
  static NSString *separator = @"\n======================================================================\n";
  NSString *reportMessage;

  if ([messages count])
    {
      fprintf (stderr, "%s", [separator UTF8String]);
      reportMessage = [messages componentsJoinedByString: separator];
      fprintf (stderr, "%s", [reportMessage UTF8String]);
    }
  fprintf (stderr,
           "\n----------------------------------------------------------------------\n"
           "Ran %d tests\n\n", testCount);
  if (hasFailed)
    fprintf (stderr, "FAILED (%d failures, %d errors)\n",
             failuresCount, errorsCount);
  else
    fprintf (stderr, "OK\n");
}

@end
