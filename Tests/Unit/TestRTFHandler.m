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

- (NSData *) get_zentyal_crash_contents_of: (unsigned int) number
{
    NSString *file_path = [NSString stringWithFormat: @"Fixtures/zentyal_crash_%u.rtf", number];

    if(![[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
        NSString *error = [NSString stringWithFormat: @"File %@ doesn't exist", file_path];
        testWithMessage(false, error);
    }

    return [NSData dataWithContentsOfFile: file_path];
}

- (void) test_does_not_crash: (unsigned int) number
{
  // FIXME fork
  [self rtf2html: [self get_zentyal_crash_contents_of: number]];
}

- (void) test_zentyal_crash_2058
{
  [self test_does_not_crash: 2058];
  // Output is not correct... but the original issue was segfault
}

- (void) test_zentyal_crash_2089
{
  NSData *in = nil;
  NSString *out = nil, *error = nil, *expected = nil;

  in = [self get_zentyal_crash_contents_of: 2089];
  expected = @"<html><meta charset='utf-8'><body><font color=\"#000000\">Lorem Ipsum</font></body></html>";
  out = [self rtf2html: in];
  error = [NSString stringWithFormat:
                    @"Html from rtf result `%@` is not what we expected", out];
  testWithMessage([out isEqualToString: expected], error);
}

- (void) test_zentyal_crash_6330
{
  [self test_does_not_crash: 6330];
}

@end
