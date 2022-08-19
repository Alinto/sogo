/* TestNGMimeHeaderFieldGenerator.m - this file is part of SOGo
 *
 * Copyright (C) 2015 Jesús García Sáez <jgarcia@zentyal.com>
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

#import "SOGoTest.h"
#import <NGMime/NGMimeHeaderFieldGenerator.h>

@interface TestNGMimeHeaderFieldGenerator : SOGoTest
@end

@implementation TestNGMimeHeaderFieldGenerator

/*
  This test is actually for SOPE library, not SOGo
*/
- (void) test_encodeQPsubject
{
  NSArray *cases = [NSArray arrayWithObjects:
    [NSArray arrayWithObjects: @"hello", @"hello", nil],
    [NSArray arrayWithObjects: @"holá", @"=?utf-8?q?hol=C3=A1?=", nil],
    [NSArray arrayWithObjects:
      @"АБВГДЕЁЖЗИАБВГДЕЁЖЗИАБВГДЕЁЖЗИАБВГДЕЁЖЗИ"
      @"АБВГДЕЁЖЗИАБВГДЕЁЖЗИАБВГДЕЁЖЗИАБВГДЕЁЖЗИ",
      @"=?utf-8?q?=D0=90=D0=91=D0=92=D0=93=D0=94=D0=95=D0=81=D0=96=D0=97=D0=98?=\n"
      @" =?utf-8?q?=D0=90=D0=91=D0=92=D0=93=D0=94=D0=95=D0=81=D0=96=D0=97=D0=98=D0=90?=\n"
      @" =?utf-8?q?=D0=91=D0=92=D0=93=D0=94=D0=95=D0=81=D0=96=D0=97=D0=98=D0=90=D0=91?=\n"
      @" =?utf-8?q?=D0=92=D0=93=D0=94=D0=95=D0=81=D0=96=D0=97=D0=98=D0=90=D0=91=D0=92?=\n"
      @" =?utf-8?q?=D0=93=D0=94=D0=95=D0=81=D0=96=D0=97=D0=98=D0=90=D0=91=D0=92=D0=93?=\n"
      @" =?utf-8?q?=D0=94=D0=95=D0=81=D0=96=D0=97=D0=98=D0=90=D0=91=D0=92=D0=93=D0=94?=\n"
      @" =?utf-8?q?=D0=95=D0=81=D0=96=D0=97=D0=98=D0=90=D0=91=D0=92=D0=93=D0=94=D0=95?=\n"
      @" =?utf-8?q?=D0=81=D0=96=D0=97=D0=98?=", nil],
    [NSArray arrayWithObjects:
      @"hello АБВ hi АБВ hi АБВ hi АБВ hi АБВ",
      @"hello =?utf-8?q?=D0=90=D0=91=D0=92?= hi =?utf-8?q?=D0=90=D0=91=D0=92?= hi \n"
      @" =?utf-8?q?=D0=90=D0=91=D0=92?= hi =?utf-8?q?=D0=90=D0=91=D0=92?= hi \n"
      @" =?utf-8?q?=D0=90=D0=91=D0=92?=", nil],
    [NSArray arrayWithObjects:
      @"hello АБВ                АБВ ",
      @"hello =?utf-8?q?=D0=90=D0=91=D0=92?=\n"
      @" =?utf-8?q?________________=D0=90=D0=91=D0=92?= ", nil],
    [NSArray arrayWithObjects: @"   hello", @"   hello", nil],
    [NSArray arrayWithObjects: @"hello    ", @"hello    ", nil],
    [NSArray arrayWithObjects:
      @"hello АБВ    ",
      @"hello =?utf-8?q?=D0=90=D0=91=D0=92?=    ", nil],
    [NSArray arrayWithObjects:
      @"ьььььььььььььььььььььььььььььььььььььььььььььььььь"
      @"ьььььььььььььььььььььььььььььььььььььььььььььььььь"
      @"ьььььььььььььььььььььььььььььььььььььььььььььььььь"
      @"ьььььььььььььььььььььььььььььььььььььььььььььььььь",
      @"=?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C=D1=8C?=\n"
      @" =?utf-8?q?=D1=8C=D1=8C=D1=8C?=", nil],
    [NSArray arrayWithObjects:
      @"aжжжжжжжжжжж",
      @"=?utf-8?q?a=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6?=\n"
      @" =?utf-8?q?=D0=B6=D0=B6?=", nil],
    [NSArray arrayWithObjects:
      @"aжжжжжжжжжжжжжжжжжжжжжж",
      @"=?utf-8?q?a=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6?=\n"
      @" =?utf-8?q?=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6=D0=B6?=\n"
      @" =?utf-8?q?=D0=B6=D0=B6?=", nil],
    nil
  ];
  NSArray *caseData;
  int i;
  for (i = 0; i < [cases count]; i++)
    {
      caseData = [cases objectAtIndex: i];
      NSString *input = [caseData objectAtIndex: 0];
      NSString *expected = [caseData objectAtIndex: 1];
      NSString *output = [NGMimeHeaderFieldGenerator encodeQuotedPrintableText: input];
      BOOL testResult = [output isEqualToString: expected];

      NSString *diff = [self stringFromDiffBetween: output and: expected];

      NSString *testErrorMsg = [NSString stringWithFormat:
          @">> For input `%@`\n>> We got    `%@`\n>> Expected  `%@`\n%@",
          input, output, expected, diff];

      testWithMessage (testResult, testErrorMsg);
    }
}

@end
