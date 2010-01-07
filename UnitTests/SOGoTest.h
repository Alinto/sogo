/* SOGoTest.h - this file is part of SOGo
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

#ifndef SOGOTEST_H
#define SOGOTEST_H

#import <Foundation/NSObject.h>

@class NSArray;
@class NSMutableArray;

typedef enum {
  SOGoTestFailureSuccess = 0,
  SOGoTestFailureFailure = 1,
  SOGoTestFailureError = 2,
} SOGoTestFailureCode;

@interface SOGoTest : NSObject
{
  NSMutableArray *messages;
  int testCount;
  int failuresCount;
  int errorsCount;
  BOOL hasFailed;
}

+ (NSArray *) allTestClasses;

- (void) setUp;
- (void) tearDown;

- (void) test: (BOOL) condition
      message: (NSString *) message
         file: (const char *) file
         line: (int) line;

- (BOOL) run;

@end

#define test(c) { \
    [self test: (c) message: @"assertion failure" \
          file: __FILE__ line: __LINE__]; \
  }

#define testWithMessage(c,m) { \
    [self test: (c) message: (m) \
          file: __FILE__ line: __LINE__]; \
  }

#define failIf(c) test(!c)

#define testEquals(a,b) \
  testWithMessage(([a isEqual: b]), \
                  ([NSString stringWithFormat: @"objects %@ and %@ differs", a, b]))

#define testEqualsWithMessage(a,b,m) \
  testWithMessage(([a isEqual: b]), (m))

#endif /* SOGOTEST_H */
