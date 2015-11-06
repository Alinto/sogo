/* TestRTFHandler.m
 *
 * Copyright (C) 2014 Zentyal
 *
 * Author: Jesús García Sáez <jgarcia@zentyal.org>
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

/* This file is encoded in utf-8. */

#import "RTFHandler.h"
#import <Foundation/NSFileManager.h>
#import "SOGoTest.h"

@interface TestRTFHandler : SOGoTest
@end

@implementation TestRTFHandler


- (NSString *) rtf2html: (NSData *) rtf
{
  NSString *html;
  if (!rtf) return @"nil";
  RTFHandler *handler = [[RTFHandler alloc] initWithData: rtf];
  NSMutableData *data2 = [handler parse];
  html = [[NSString alloc] initWithData: data2 encoding: NSUTF8StringEncoding];
  if (html == nil) {
    html = [[NSString alloc] initWithData: data2 encoding: NSASCIIStringEncoding];
  }
  if (html == nil) {
    html = [[NSString alloc] initWithData: data2 encoding: NSISOLatin1StringEncoding];
  }
  if (html == nil) {
    NSString *error = [NSString stringWithFormat: @"Couldn't convert parsed data"];
    testWithMessage(false, error);
  }
  return html;
}

- (NSData *) dataWithContentsOfFixture: (NSString*) name
{
    NSString *file_path = [NSString stringWithFormat: @"Fixtures/%@", name];

    if(![[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
        NSString *error = [NSString stringWithFormat: @"File %@ doesn't exist", file_path];
        testWithMessage(false, error);
    }
    return [NSData dataWithContentsOfFile: file_path];    
}

- (NSData *) dataWithContentsOfZentyalCrash: (unsigned int) number
{
  NSString *fixture = [NSString stringWithFormat: @"zentyal_crash_%u.rtf", number];
  return [self dataWithContentsOfFixture: fixture];

}

- (void) checkDoesNotCrash: (unsigned int) number
{
  // FIXME fork
  [self rtf2html: [self dataWithContentsOfZentyalCrash: number]];
}

- (void) checkHTMLConversionOfRTFFile: (NSString*) file
                  againstExpectedHTML: (NSString*) expected
{
  NSData *in = nil;
  NSString *out = nil, *error = nil;

  in = [self dataWithContentsOfFixture: file];
  out = [self rtf2html: in];
  error = [NSString stringWithFormat:
                      @"Html from rtf result is not what we expected.\nActual:\n%@\n Expected:\n%@\n", out, expected];
  testWithMessage([out isEqualToString: expected], error);
}


- (void) test_zentyal_crash_2058
{
  [self checkDoesNotCrash: 2058];
  // Output is not correct... but the original issue was segfault
}

- (void) test_zentyal_crash_2089
{
  NSData *in = nil;
  NSString *out = nil, *error = nil, *expected = nil;

  in = [self dataWithContentsOfZentyalCrash: 2089];
  expected = @"<html><meta charset='utf-8'><body><font color=\"#000000\">Lorem Ipsum</font></body></html>";
  out = [self rtf2html: in];
  error = [NSString stringWithFormat:
                    @"Html from rtf result `%@` is not what we expected", out];
  testWithMessage([out isEqualToString: expected], error);
}

- (void) test_zentyal_crash_6330
{
  [self checkDoesNotCrash: 6330];
}

- (void) test_zentyal_crash_8346
{
  [self checkDoesNotCrash: 8346];
}

- (void) test_zentyal_crash_6977
{
  [self checkDoesNotCrash: 6977];
}

- (void) test_zentyal_crash_7067
{
  [self checkDoesNotCrash: 7067];
}

- (void) test_mini_russian
{
  NSString *file =@"mini_russian.rtf";
  NSString *expected=@"<html><meta charset='utf-8'><body><font face=\"Calibri\"><font face=\"Calibri Cyr\"><font color=\"#000000\">XXзык польски, польщизнаXX</font></font></font></body></html>";
  [self checkHTMLConversionOfRTFFile: file
                      againstExpectedHTML: expected];  
}

@end
