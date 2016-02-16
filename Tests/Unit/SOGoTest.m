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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>

#import "SOGoTestRunner.h"

#import "SOGoTest.h"

static NSString *SOGoTestAssertException = @"SOGoTestAssertException";

/* Helper function for diffForString:andString */
static NSString *_stringForCharacterAtIndex(NSUInteger index, NSString *str, NSUInteger length)
{
  NSString *chrStr;
  unichar chr;
  if (index < length)
    {
      chr = [str characterAtIndex: index];
      if (isprint(chr)) 
        {
          chrStr = [NSString stringWithFormat: @"%c", chr];
        }
      else
        {
          if (chr == 10) 
            chrStr = @"[NL]";
          else if (chr == 0)
            chrStr = @"[\0]";
          else    
            chrStr = [NSString stringWithFormat: @"[NP: %u]", chr];
        }
    }
  else
    {
      chrStr = @"[none]";
    }

  return chrStr;
}

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

  [testRunner incrementTestCounter: failureCode
                       afterMethod: NSStringFromSelector (testMethod)];
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

/*
  Returns a string with a very verbose diff of the two strings.
  In case the strings are equal it returns an empty string.
  Example output for the strings 'flower' and 'flotera':
  <begin of example>
0 |f|
1 |l|
2 |o|
3 |w|t|<--
4 |e|
5 |r|
6 |[none]|a|<--
  <end of example>
*/
- (NSString*) stringFromDiffBetween: (NSString*) str1
                                and: (NSString*) str2
{
  BOOL differencesFound = NO;
  NSString *finalSTR = @"";
  NSUInteger i, length1, length2;
  NSString *sc1, *sc2;

  length1 = [str1 length];
  length2 = [str2 length];
  for (i = 0; i < length1 || i < length2; i++)
    {
      sc1 = _stringForCharacterAtIndex(i, str1, length1);
      sc2 = _stringForCharacterAtIndex(i, str2, length2);

      if ([sc1 isEqualToString: sc2]) 
        finalSTR = [finalSTR stringByAppendingFormat: @"%lu |%@|\n", i, sc1];
      else
        {
          finalSTR = [finalSTR stringByAppendingFormat: @"%lu |%@|%@|<--\n", i, sc1, sc2];
          differencesFound = YES;
        }
    }

  if (!differencesFound)
    return @"";

  return finalSTR;
}


@end
