/* SOGoTestRunner.h - this file is part of SOGo
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

#ifndef SOGOTESTRUNNER_H
#define SOGOTESTRUNNER_H

#import <Foundation/NSObject.h>

@class NSException;
@class NSMutableArray;
@class NSString;

typedef enum {
  SOGoTestFailureSuccess = 0,
  SOGoTestFailureFailure = 1,
  SOGoTestFailureError = 2,
} SOGoTestFailureCode;

typedef enum {
  SOGoTestTextOutputFormat = 0,
  SOGoTestJUnitOutputFormat
} SOGoTestOutputFormat;

@interface SOGoTestRunner : NSObject
{
  /* An array of arrays whose components are the method name and the
     failure message if any */
  NSMutableArray *performedTests;
  int testCount;
  int failuresCount;
  int errorsCount;
  BOOL hasFailed;
  SOGoTestOutputFormat reportFormat;
}

+ (SOGoTestRunner *) testRunnerWithFormat: (SOGoTestOutputFormat) reportFormat;

- (void) setReportFormat: (SOGoTestOutputFormat) format;

- (int) run;

- (void) incrementTestCounter: (SOGoTestFailureCode) failureCode
                  afterMethod: (NSString *) methodName;
- (void) reportException: (NSException *) exception
                  method: (NSString *) methodName
                withCode: (SOGoTestFailureCode) failureCode;

- (void) displayReport;

@end

#endif /* SOGOTESTRUNNER_H */
