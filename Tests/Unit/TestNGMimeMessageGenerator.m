/* TestNGMimeMessageGenerator.m - this file is part of SOGo
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
#import <NGMail/NGMimeMessageGenerator.h>


@interface TestNGMimeMessageGenerator : SOGoTest
@end

@implementation TestNGMimeMessageGenerator

/*
  This test is actually for SOPE library, not SOGo
*/
- (void) test_generateDataForHeaderField_value
{
  NSArray *cases = [NSArray arrayWithObjects:
    [NSArray arrayWithObjects:@"Message-ID",
                              @"<CADCKkzo+9X1SniJFY3yc7YGafNrmAts419RmcqNkMzd-PBqNbA@mail.gmail.com>",
                              @"<CADCKkzo+9X1SniJFY3yc7YGafNrmAts419RmcqNkMzd-PBqNbA@mail.gmail.com>", nil],
    [NSArray arrayWithObjects:@"Content-Type",
                              @"text/plain; charset=utf-8; format=flowed",
                              @"text/plain; charset=utf-8; format=flowed", nil],
    [NSArray arrayWithObjects:@"X-FullHeaderOneHebrewOneLatin",
                              @"עs",
                              @"=?utf-8?q?=D7=A2s?=", nil],
    [NSArray arrayWithObjects:@"X-FullHeaderOneLatineOneHebrew",
                              @"sע",
                              @"=?utf-8?q?s=D7=A2?=", nil],
    [NSArray arrayWithObjects:@"X-FullHeaderOneCharacterHebrew",
                              @"ע",
                              @"=?utf-8?q?=D7=A2?=", nil],
    [NSArray arrayWithObjects:@"X-FullHeaderOneCharacterRussian",
                              @"Б",
                              @"=?utf-8?q?=D0=91?=", nil],
    [NSArray arrayWithObjects:@"X-FullHeaderParameter",
                              @"parameter=ע",
                              @"parameter==?utf-8?q?=D7=A2?=", nil],
    [NSArray arrayWithObjects:@"X-MixedHeaderParameters",
                              @"plain; parameter=ע; parameter-plain; parameter2=ea",
                              @"plain;\n parameter==?utf-8?q?=D7=A2?=;\n parameter-plain; parameter2=ea", nil],
    [NSArray arrayWithObjects:@"X-MixedHeaderAndNoParameter",
                              @"plain; parameter=ע; parameter-plain; ע",
                              @"plain;\n parameter==?utf-8?q?=D7=A2?=; parameter-plain;\n =?utf-8?q?=D7=A2?=", nil],
    [NSArray arrayWithObjects:@"X-MixedHeaderAndTwoParameter",
                              @"plain; parameter=ע; parameter-plain; z=ע",
                              @"plain;\n parameter==?utf-8?q?=D7=A2?=; parameter-plain;\n z==?utf-8?q?=D7=A2?=", nil],
    [NSArray arrayWithObjects:@"X-MixedHeaderExtrablanks",
                              @"plain;  parameter=ע; parameter  2spaces; parameter2=ea",
                              @"plain;\n \\ parameter==?utf-8?q?=D7=A2?=;\n parameter  2spaces; parameter2=ea", nil],
    [NSArray arrayWithObjects:@"X-Encoded-Unbalanced-Paramter-Quote",
                              @"text/plain; name=\"ע",
                              @"text/plain;\n name==?utf-8?q?=22=D7=A2?=", nil],
    [NSArray arrayWithObjects:@"content-type",
                              @"text/plain; name=\"АБВГДЕЁЖЗИЙ, КЛМНОПРСТУФ y ЦЧШЩЪЫЬЭЮЯ.txt\"",
                              @"text/plain;\n name=\"=?utf-8?q?=D0=90=D0=91=D0=92=D0=93=D0=94=D0=95=D0=81=D0=96=D0=97=D0=98=D0=99=2C_=D0=9A=D0"
                              @"=9B=D0=9C=D0=9D=D0=9E=D0=9F=D0=A0=D0=A1=D0=A2=D0=A3=D0=A4_y_=D0=A6=D0=A7=D0=A8"
                              @"=D0=A9=D0=AA=D0=AB=D0=AC=D0=AD=D0=AE=D0=AF=2Etxt?=\"", nil],
    [NSArray arrayWithObjects:@"content-disposition",
                              @"attachment; filename=\"АБВГДЕЁЖЗИЙ, КЛМНОПРСТУФ y ЦЧШЩЪЫЬЭЮЯ.txt\"",
                              @"attachment;\n filename=\"=?utf-8?q?=D0=90=D0=91=D0=92=D0=93=D0=94=D0=95=D0=81=D0=96=D0=97=D0=98=D0=99=2C_=D0=9A=D0"
                              @"=9B=D0=9C=D0=9D=D0=9E=D0=9F=D0=A0=D0=A1=D0=A2=D0=A3=D0=A4_y_=D0=A6=D0=A7=D0=A8"
                              @"=D0=A9=D0=AA=D0=AB=D0=AC=D0=AD=D0=AE=D0=AF=2Etxt?=\"", nil],
    [NSArray arrayWithObjects:@"content-length", @"2912", @"2912", nil],
    [NSArray arrayWithObjects:@"content-transfer-encoding", @"quoted-printable", @"quoted-printable", nil],
    nil
  ];

  [NGMimeMessageGenerator initialize];
  NGMimeMessageGenerator *generator = [[NGMimeMessageGenerator alloc] init];
  [generator autorelease];

  NSArray *testCase;
  int i;

  for (i = 0; i < [cases count]; i++)
    {
      testCase = [cases objectAtIndex: i];
      NSString *header = [testCase objectAtIndex: 0];
      NSData *headerData =  [testCase objectAtIndex: 1];
      NSString *expected = [testCase objectAtIndex: 2];
      NSData *result = [generator generateDataForHeaderField: header
                                                       value: headerData];
      if (result == nil)
        result = [@"[nil]" dataUsingEncoding: NSUTF8StringEncoding];

      NSMutableData *resultWithNulByte = [result mutableCopy];
      [resultWithNulByte appendBytes: "\0" length: 1];
      NSString *resultString =  [NSString stringWithCString:[resultWithNulByte bytes]];

      BOOL testResult = [resultString isEqualToString: expected];

      NSString *diff = [self stringFromDiffBetween: resultString and: expected];

      NSString *testErrorMsg = [NSString stringWithFormat:
        @">> For %@ header received:\n%@[END]\n"
        @">> instead of:\n%@[END]\n"
        @">> for:\n%@\n>> diff:\n%@\n"
        @">> lengthReceived: %lu lengthExpected: %lu", header, resultString,
        expected, headerData, diff, [resultString length], [expected length]];

      testWithMessage(testResult, testErrorMsg);
    }
}

@end
