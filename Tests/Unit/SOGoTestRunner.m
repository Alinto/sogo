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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>

#import "SOGoTest.h"

#import "SOGoTestRunner.h"

#define EXPECTED_FAILURES 0

@implementation SOGoTestRunner

+ (SOGoTestRunner *) testRunnerWithFormat: (SOGoTestOutputFormat) reportFormat
{
  SOGoTestRunner *testRunner;

  testRunner = [self new];
  [testRunner setReportFormat: reportFormat];
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
      performedTests = [NSMutableArray new];
      reportFormat = SOGoTestTextOutputFormat;
    }

  return self;
}

- (void) dealloc
{
  [performedTests release];
  [super dealloc];
}

- (void) setReportFormat: (SOGoTestOutputFormat) format
{
  reportFormat = format;
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
                  afterMethod: (NSString *) methodName
{
  static char failureChars[] = { '.', 'F', 'E' };

  testCount++;
  if (reportFormat == SOGoTestTextOutputFormat)
    fprintf (stderr, "%c", failureChars[failureCode]);
  if (failureCode == SOGoTestFailureSuccess)
    [performedTests addObject: [NSArray arrayWithObjects: methodName, @"", nil]];
  /* else has been added by reportException method */
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

  [performedTests addObject:
                    [NSArray arrayWithObjects: methodName, message, [NSNumber numberWithInt: failureCode], nil]];
}

- (void) displayTextReport
{
  static NSString *separator = @"\n======================================================================\n";
  NSArray *performedTest;
  NSMutableArray *messages;
  NSString *reportMessage;
  NSUInteger i, max;

  messages = [NSMutableArray new];
  max = [performedTests count];
  for (i = 0; i < max; i++)
    {
      performedTest = [performedTests objectAtIndex: i];
      if ([[performedTest objectAtIndex: 1] length] > 0)
        [messages addObject: [performedTest objectAtIndex: 1]];
    }

  if ([messages count])
    {
      fprintf (stderr, "%s", [separator UTF8String]);
      reportMessage = [messages componentsJoinedByString: separator];
      fprintf (stderr, "%s", [reportMessage UTF8String]);
    }

  [messages release];

  fprintf (stderr,
           "\n----------------------------------------------------------------------\n"
           "Ran %d tests\n\n", testCount);
  if (hasFailed)
    fprintf (stderr, "FAILED (%d failures, %d errors)\n",
             failuresCount, errorsCount);
  else
    fprintf (stderr, "OK\n");
}

- (void) displayJUnitReport
{
  /* Follow JUnit.xsd defined by Apache-Ant project */
  NSArray *performedTest;
  NSMutableString *reportMessage;
  NSUInteger i, max;

  /* Header */
  reportMessage = [NSMutableString stringWithFormat: @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                                   @"<testsuite "
                                   @"name=\"%@\" id=\"0\" tests=\"%d\" errors=\"%d\" failures=\"%d\" "
                                   @"timestamp=\"%@\">\n"
                                   @"<desc>%@</desc>\n",
                                   @"SOGoUnitTests", testCount, errorsCount, failuresCount,
                                   [NSDate date],
                                   @"SOGo and SOPE Unit tests"];

  /* Test cases */
  max = [performedTests count];
  for (i = 0; i < max; i++)
    {
      performedTest = [performedTests objectAtIndex: i];
      [reportMessage appendFormat: @"<testcase name=\"%@\">\n", [performedTest objectAtIndex: 0]];
      if ([[performedTest objectAtIndex: 1] length] > 0)
        {
          if ([performedTest count] > 2 && [[performedTest objectAtIndex: 2] intValue] == SOGoTestFailureFailure)
            [reportMessage appendFormat: @"<failure>%@</failure>\n", [performedTest objectAtIndex: 1]];
          else
            [reportMessage appendFormat: @"<error>%@</error>\n", [performedTest objectAtIndex: 1]];
        }
      [reportMessage appendString: @"</testcase>\n"];
    }

  /* End */
  [reportMessage appendString: @"</testsuite>"];

  fprintf (stdout, "%s", [reportMessage UTF8String]);
}

- (void) displayReport
{
  switch (reportFormat)
    {
    case SOGoTestTextOutputFormat:
      [self displayTextReport];
      break;
      ;;
    case SOGoTestJUnitOutputFormat:
      [self displayJUnitReport];
      break;
      ;;
    }
}

@end
