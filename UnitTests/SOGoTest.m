/* SOGoTest.m - this file is part of SOGo
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

static NSString *SOGoTestAssertException = @"SOGoTestAssertException";

@implementation SOGoTest

+ (NSArray *) allTestClasses
{
  NSMutableArray *allTestClasses;
  NSArray *allSubClasses;
  NSString *class;
  int count, max;

  allSubClasses = GSObjCAllSubclassesOfClass (self);
  max = [allSubClasses count];
  allTestClasses = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      class = NSStringFromClass ([allSubClasses objectAtIndex: count]);
      if ([class hasPrefix: @"Test"])
        [allTestClasses addObject: class];
    }

  return allTestClasses;
}

- (id) init
{
  if ((self = [super init]))
    {
      messages = [NSMutableArray new];
      testCount = 0;
      failuresCount = 0;
      errorsCount = 0;
      hasFailed = NO;
    }

  return self;
}

- (void) dealloc
{
  [messages release];
  [super dealloc];
}

- (void) setUp
{
}

- (void) tearDown
{
}

- (void) test: (BOOL) condition
      message: (NSString *) message
         file: (const char *) file
         line: (int) line
{
  NSDictionary *fileInfo;

  if (!condition)
    {
      if (file)
        fileInfo = [NSDictionary dictionaryWithObject:
                           [NSString stringWithFormat: @"%s:%d", file, line]
                                               forKey: @"fileInfo"];
      else
        fileInfo = nil;
      [[NSException exceptionWithName: SOGoTestAssertException
                               reason: message
                             userInfo: fileInfo] raise];
    }
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

- (void) performTest: (SEL) testMethod
{
  static char failureChars[] = { '.', 'F', 'E' };
  SOGoTestFailureCode failureCode;

  failureCode = SOGoTestFailureSuccess;
  NS_DURING
    {
      [self setUp];
    }
  NS_HANDLER
    {
      failureCode = SOGoTestFailureError;
      [self reportException: localException
                     method: @"setUp"
                   withCode: failureCode];
    }
  NS_ENDHANDLER;

  if (failureCode == SOGoTestFailureSuccess)
    {
      NS_DURING
        {
          [self performSelector: testMethod];
        }
      NS_HANDLER
        {
          if ([[localException name]
                isEqualToString: SOGoTestAssertException])
            failureCode = SOGoTestFailureFailure;
          else
            failureCode = SOGoTestFailureError;
          [self reportException: localException
                         method: NSStringFromSelector (testMethod)
                       withCode: failureCode];
        }
      NS_ENDHANDLER;
    }

  NS_DURING
    {
      [self tearDown];
    }
  NS_HANDLER
    {
      failureCode = SOGoTestFailureError;
      [self reportException: localException
                     method: @"tearDown"
                   withCode: failureCode];
    }
  NS_ENDHANDLER;

  testCount++;
  fprintf (stderr, "%c", failureChars[failureCode]);
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

- (BOOL) run
{
  NSArray *methods;
  NSString *method;
  int count, max;
  SEL testMethod;

  methods = GSObjCMethodNames (self);
  max = [methods count];
  for (count = 0; count < max; count++)
    {
      method = [methods objectAtIndex: count];
      if ([method hasPrefix: @"test"]
          && [method rangeOfString: @":"].location == NSNotFound)
        {
          testMethod = NSSelectorFromString (method);
          [self performTest: testMethod];
        }
    }

  [self displayReport];

  return YES;
}

@end
