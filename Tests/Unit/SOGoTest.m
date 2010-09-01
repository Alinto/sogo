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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import "SOGoTestRunner.h"

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
      testRunner = nil;
    }

  return self;
}

- (void) dealloc
{
  [testRunner release];
  [super dealloc];
}

- (void) setTestRunner: (SOGoTestRunner *) newTestRunner
{
  ASSIGN (testRunner, newTestRunner);
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

- (void) performTest: (SEL) testMethod
{
  SOGoTestFailureCode failureCode;

  failureCode = SOGoTestFailureSuccess;
  NS_DURING
    {
      [self setUp];
    }
  NS_HANDLER
    {
      failureCode = SOGoTestFailureError;
      [testRunner reportException: localException
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
          [testRunner reportException: localException
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
      [testRunner reportException: localException
                           method: @"tearDown"
                         withCode: failureCode];
    }
  NS_ENDHANDLER;

  [testRunner incrementTestCounter: failureCode];
}

- (BOOL) run
{
  NSArray *methods;
  NSString *method;
  int count, max;
  SEL testMethod;

#if ((GNUSTEP_BASE_MAJOR_VERSION > 1)                                   \
     || ((GNUSTEP_BASE_MAJOR_VERSION == 1) && (GNUSTEP_BASE_MINOR_VERSION >= 20)))
  methods = GSObjCMethodNames (self, NO);
#else
  methods = GSObjCMethodNames (self);
#endif
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

  return YES;
}

@end
