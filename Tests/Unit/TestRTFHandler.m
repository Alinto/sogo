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

//#import "../../OpenChange/RTFHandler.h"
#import <Foundation/NSFileManager.h>
#import "SOGoTest.h"
#import "RTFHandler.h"
#import <Foundation/NSException.h>

#include <string.h>


@interface TestRTFHandler : SOGoTest
@end

@implementation TestRTFHandler


- (NSString *) rtf2html: (NSData *) rtf
{
  NSString *html;
  if (!rtf) 
    return nil;

  RTFHandler *handler = [[RTFHandler alloc] initWithData: rtf];
  NSMutableData *data2 = [handler parse];
  if (data2 == nil)
    {
      NSString *error = [NSString stringWithFormat: @"Couldn't parse RTF data:\n %s",
                         (char *)[rtf bytes]];           
      testWithMessage(NO, error);
    }

  html = [[NSString alloc] initWithData: data2 encoding: NSUTF8StringEncoding];
  if (html == nil) 
    {
      html = [[NSString alloc] initWithData: data2 encoding: NSASCIIStringEncoding];
    }
  if (html == nil) 
    {
      html = [[NSString alloc] initWithData: data2 encoding: NSISOLatin1StringEncoding];
    }
  if (html == nil) 
    {
      NSString *error = [NSString stringWithFormat: @"Couldn't convert parsed data"];
      testWithMessage(NO, error);
    }
  return html;
}

- (NSData *) open_fixture: (NSString*) name
{
    NSString *file_path = [NSString stringWithFormat: @"Fixtures/%@", name];

    if(![[NSFileManager defaultManager] fileExistsAtPath: file_path]) {
        NSString *error = [NSString stringWithFormat: @"File %@ doesn't exist", file_path];
        testWithMessage(false, error);
    }
    return [NSData dataWithContentsOfFile: file_path];    
}

- (NSData *) get_zentyal_crash_contents_of: (unsigned int) number
{
  NSString *fixture = [NSString stringWithFormat: @"zentyal_crash_%u.rtf", number];
  return [self open_fixture: fixture];

}

- (void) test_does_not_crash: (unsigned int) number
{
  // FIXME fork
  [self rtf2html: [self get_zentyal_crash_contents_of: number]];
}

- (void) test_html_conversion_of_rtf_file: (NSString*) file
                       with_expected_html: (NSString*) expected
{
  NSData *in = nil;
  NSString *out = nil, *error = nil;

  in = [self open_fixture: file];
  out = [self rtf2html: in];
  error = [NSString stringWithFormat:
                      @"Html from rtf result is not what we expected.\n>> Actual:\n%@\n>> Expected:\n%@\n", out, expected];
  testWithMessage([out isEqualToString: expected], error);
}

- (void) test_font_table_parsing_of_rtf_file: (NSString*) file
                         with_expected_table: (NSString*) expected
{
  NSData *in = nil;   
  char *in_bytes;
  char *table_pointer;
  int newCurrentPos;
  RTFHandler *handler;
  RTFFontTable *out_table;
  NSString *out_description, *error = nil;

  in = [self open_fixture: file];
  in_bytes = (char *) [in bytes];
  table_pointer = strstr(in_bytes, "{\\fonttbl");
  if (table_pointer == NULL)
    {
      [NSException raise: @"NSInvalidArgumentException"
                  format: @"No font table in RTF file"];
    }
  newCurrentPos = table_pointer - in_bytes;

  handler = [[RTFHandler alloc] initWithData: in];

  [handler mangleInternalStateWithBytesPtr: table_pointer
                             andCurrentPos: newCurrentPos];
  out_table = [handler parseFontTable];
  out_description = [out_table description];
  if ([out_description isEqualToString: expected]) 
    {
      testWithMessage(YES, @"no error");
    }
  else
    {
      error = [NSString stringWithFormat:
                      @"Font table is not what we expected.\n>> Actual:\n%@\n>> Expected:\n%@\n", out_description, expected];
      testWithMessage(NO, error);
    }

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
  expected =@"<html><meta charset='utf-8'><body><font face=\"Calibri\"><font color=\"#000000\">Lorem Ipsum</font><font color=\"#000000\"><br></font></body></html>";
  out = [self rtf2html: in];
  error = [NSString stringWithFormat:
                      @"Html from rtf result:\n%@\n is not what we expected:\n%@", out, expected];
  testWithMessage([out isEqualToString: expected], error);
}

- (void) test_zentyal_crash_6330
{
  [self test_does_not_crash: 6330];
}

- (void) test_zentyal_crash_8346
{
  [self test_does_not_crash: 8346];
}

- (void) test_zentyal_crash_6977
{
  [self test_does_not_crash: 6977];
}

- (void) test_zentyal_crash_7067
{
  [self test_does_not_crash: 7067];
}


- (void) test_mini_russian_font_table
{
  NSString *file =@"mini_russian.rtf";
  NSMutableString *expected = [NSMutableString stringWithFormat: @"Number of fonts: 84\n"];
  [expected appendString: @"0 name=Times New Roman family=roman charset=0 pitch=2\n"];
  [expected appendString: @"31500 name=Times New Roman family=roman charset=0 pitch=2\n"];
  [expected appendString: @"31501 name=Times New Roman family=roman charset=0 pitch=2\n"];
  [expected appendString: @"31502 name=Cambria family=roman charset=0 pitch=2\n"];
  [expected appendString: @"37 name=Calibri family=swiss charset=0 pitch=2\n"];
  [expected appendString: @"31503 name=Times New Roman family=roman charset=0 pitch=2\n"];
  [expected appendString: @"39 name=Times New Roman CE family=roman charset=238 pitch=2\n"];
  [expected appendString: @"31504 name=Times New Roman family=roman charset=0 pitch=2\n"];
  [expected appendString: @"40 name=Times New Roman Cyr family=roman charset=204 pitch=2\n"];
  [expected appendString: @"31505 name=Times New Roman family=roman charset=0 pitch=2\n"];
  [expected appendString: @"31506 name=Calibri family=swiss charset=0 pitch=2\n"];
  [expected appendString: @"42 name=Times New Roman Greek family=roman charset=161 pitch=2\n"];
  [expected appendString: @"31507 name=Times New Roman family=roman charset=0 pitch=2\n"];
  [expected appendString: @"31508 name=Times New Roman CE family=roman charset=238 pitch=2\n"];
  [expected appendString: @"43 name=Times New Roman Tur family=roman charset=162 pitch=2\n"];
  [expected appendString: @"31509 name=Times New Roman Cyr family=roman charset=204 pitch=2\n"];
  [expected appendString: @"44 name=Times New Roman (Hebrew) family=roman charset=177 pitch=2\n"];
  [expected appendString: @"45 name=Times New Roman (Arabic) family=roman charset=178 pitch=2\n"];
  [expected appendString: @"31511 name=Times New Roman Greek family=roman charset=161 pitch=2\n"];
  [expected appendString: @"46 name=Times New Roman Baltic family=roman charset=186 pitch=2\n"];
  [expected appendString: @"31512 name=Times New Roman Tur family=roman charset=162 pitch=2\n"];
  [expected appendString: @"47 name=Times New Roman (Vietnamese) family=roman charset=163 pitch=2\n"];
  [expected appendString: @"31513 name=Times New Roman (Hebrew) family=roman charset=177 pitch=2\n"];
  [expected appendString: @"31514 name=Times New Roman (Arabic) family=roman charset=178 pitch=2\n"];
  [expected appendString: @"31515 name=Times New Roman Baltic family=roman charset=186 pitch=2\n"];
  [expected appendString: @"31516 name=Times New Roman (Vietnamese) family=roman charset=163 pitch=2\n"];
  [expected appendString: @"31518 name=Times New Roman CE family=roman charset=238 pitch=2\n"];
  [expected appendString: @"31519 name=Times New Roman Cyr family=roman charset=204 pitch=2\n"];
  [expected appendString: @"31521 name=Times New Roman Greek family=roman charset=161 pitch=2\n"];
  [expected appendString: @"31522 name=Times New Roman Tur family=roman charset=162 pitch=2\n"];
  [expected appendString: @"31523 name=Times New Roman (Hebrew) family=roman charset=177 pitch=2\n"];
  [expected appendString: @"31524 name=Times New Roman (Arabic) family=roman charset=178 pitch=2\n"];
  [expected appendString: @"31525 name=Times New Roman Baltic family=roman charset=186 pitch=2\n"];
  [expected appendString: @"31526 name=Times New Roman (Vietnamese) family=roman charset=163 pitch=2\n"];
  [expected appendString: @"31528 name=Cambria CE family=roman charset=238 pitch=2\n"];
  [expected appendString: @"31529 name=Cambria Cyr family=roman charset=204 pitch=2\n"];
  [expected appendString: @"31531 name=Cambria Greek family=roman charset=161 pitch=2\n"];
  [expected appendString: @"31532 name=Cambria Tur family=roman charset=162 pitch=2\n"];
  [expected appendString: @"31535 name=Cambria Baltic family=roman charset=186 pitch=2\n"];
  [expected appendString: @"31536 name=Cambria (Vietnamese) family=roman charset=163 pitch=2\n"];
  [expected appendString: @"31538 name=Times New Roman CE family=roman charset=238 pitch=2\n"];
  [expected appendString: @"31539 name=Times New Roman Cyr family=roman charset=204 pitch=2\n"];
  [expected appendString: @"31541 name=Times New Roman Greek family=roman charset=161 pitch=2\n"];
  [expected appendString: @"31542 name=Times New Roman Tur family=roman charset=162 pitch=2\n"];
  [expected appendString: @"31543 name=Times New Roman (Hebrew) family=roman charset=177 pitch=2\n"];
  [expected appendString: @"31544 name=Times New Roman (Arabic) family=roman charset=178 pitch=2\n"];
  [expected appendString: @"31545 name=Times New Roman Baltic family=roman charset=186 pitch=2\n"];
  [expected appendString: @"31546 name=Times New Roman (Vietnamese) family=roman charset=163 pitch=2\n"];
  [expected appendString: @"31548 name=Times New Roman CE family=roman charset=238 pitch=2\n"];
  [expected appendString: @"31549 name=Times New Roman Cyr family=roman charset=204 pitch=2\n"];
  [expected appendString: @"31551 name=Times New Roman Greek family=roman charset=161 pitch=2\n"];
  [expected appendString: @"31552 name=Times New Roman Tur family=roman charset=162 pitch=2\n"];
  [expected appendString: @"31553 name=Times New Roman (Hebrew) family=roman charset=177 pitch=2\n"];
  [expected appendString: @"31554 name=Times New Roman (Arabic) family=roman charset=178 pitch=2\n"];
  [expected appendString: @"31555 name=Times New Roman Baltic family=roman charset=186 pitch=2\n"];
  [expected appendString: @"31556 name=Times New Roman (Vietnamese) family=roman charset=163 pitch=2\n"];
  [expected appendString: @"31558 name=Times New Roman CE family=roman charset=238 pitch=2\n"];
  [expected appendString: @"31559 name=Times New Roman Cyr family=roman charset=204 pitch=2\n"];
  [expected appendString: @"31561 name=Times New Roman Greek family=roman charset=161 pitch=2\n"];
  [expected appendString: @"31562 name=Times New Roman Tur family=roman charset=162 pitch=2\n"];
  [expected appendString: @"31563 name=Times New Roman (Hebrew) family=roman charset=177 pitch=2\n"];
  [expected appendString: @"31564 name=Times New Roman (Arabic) family=roman charset=178 pitch=2\n"];
  [expected appendString: @"31565 name=Times New Roman Baltic family=roman charset=186 pitch=2\n"];
  [expected appendString: @"31566 name=Times New Roman (Vietnamese) family=roman charset=163 pitch=2\n"];
  [expected appendString: @"31568 name=Calibri CE family=swiss charset=238 pitch=2\n"];
  [expected appendString: @"31569 name=Calibri Cyr family=swiss charset=204 pitch=2\n"];
  [expected appendString: @"31571 name=Calibri Greek family=swiss charset=161 pitch=2\n"];
  [expected appendString: @"31572 name=Calibri Tur family=swiss charset=162 pitch=2\n"];
  [expected appendString: @"31575 name=Calibri Baltic family=swiss charset=186 pitch=2\n"];
  [expected appendString: @"31576 name=Calibri (Vietnamese) family=swiss charset=163 pitch=2\n"];
  [expected appendString: @"31578 name=Times New Roman CE family=roman charset=238 pitch=2\n"];
  [expected appendString: @"31579 name=Times New Roman Cyr family=roman charset=204 pitch=2\n"];
  [expected appendString: @"31581 name=Times New Roman Greek family=roman charset=161 pitch=2\n"];
  [expected appendString: @"31582 name=Times New Roman Tur family=roman charset=162 pitch=2\n"];
  [expected appendString: @"31583 name=Times New Roman (Hebrew) family=roman charset=177 pitch=2\n"];
  [expected appendString: @"31584 name=Times New Roman (Arabic) family=roman charset=178 pitch=2\n"];
  [expected appendString: @"409 name=Calibri CE family=swiss charset=238 pitch=2\n"];
  [expected appendString: @"31585 name=Times New Roman Baltic family=roman charset=186 pitch=2\n"];
  [expected appendString: @"410 name=Calibri Cyr family=swiss charset=204 pitch=2\n"];
  [expected appendString: @"31586 name=Times New Roman (Vietnamese) family=roman charset=163 pitch=2\n"];
  [expected appendString: @"412 name=Calibri Greek family=swiss charset=161 pitch=2\n"];
  [expected appendString: @"413 name=Calibri Tur family=swiss charset=162 pitch=2\n"];
  [expected appendString: @"416 name=Calibri Baltic family=swiss charset=186 pitch=2\n"];
  [expected appendString: @"417 name=Calibri (Vietnamese) family=swiss charset=163 pitch=2\n"];

[self test_font_table_parsing_of_rtf_file: file
                      with_expected_table: expected];
}

- (void) test_mini_russian
{
  NSString *file =@"mini_russian.rtf";
  NSString *expected=@"<html><meta charset='utf-8'><body><font face=\"Calibri\"><font face=\"Calibri Cyr\"><font color=\"#000000\">XXзык польски, польщизнаXX</font></font></font></body></html>";
  [self test_html_conversion_of_rtf_file: file
                      with_expected_html: expected];  
}

- (void) test_escapes
{
  NSString *file =@"escapes.rtf";
  NSString *expected=@"<html><meta charset='utf-8'><body><font face=\"Calibri\"><font color=\"#000000\">x341x351x372x355x363x361x</font><font color=\"#000000\">S SS-S\\S</font><font color=\"#000000\">U老UřU</font><font color=\"#000000\"><br></font></font></body></html>";
  [self test_html_conversion_of_rtf_file: file
                      with_expected_html: expected];  
}

- (void) test_acentos
{
  NSString *file =@"acentos.rtf";
  NSString *expected=@"<html><meta charset='utf-8'><body><font face=\"Calibri\"><font color=\"#000000\">xñxáxéxíxóxú</font><font color=\"#000000\"><br></font></font></body></html>";

  [self test_html_conversion_of_rtf_file: file
                      with_expected_html: expected];  
}

@end
