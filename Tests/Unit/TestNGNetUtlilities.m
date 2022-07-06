/* TestNGNetUtilities.m - this file is part of SOGo
 *
 * Copyright (C) 2022 Nicolas Höft
 * Copyright (C) Inverse Inc.
 *
 * Author: Nicolas Höft <nicolas@hoeft.de>
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

#import <NGStreams/NGNetUtilities.h>
#import <NGStreams/NGInternetSocketAddress.h>

#import "SOGoTest.h"

@interface TestNGNetUtilities : SOGoTest
@end

@implementation TestNGNetUtilities

- (void) test_NGInternetSocketAddressFromString
{
  NSArray *cases = [NSArray arrayWithObjects:
    // input, host, port, isWildcard, isIpV4
    [NSArray arrayWithObjects: @"127.0.0.1:1000", @"127.0.0.1", [NSNumber numberWithInt: 1000], [NSNumber numberWithBool:NO], [NSNumber numberWithBool:YES], nil],
    [NSArray arrayWithObjects: @"*:1001", @"*", [NSNumber numberWithInt:1001], [NSNumber numberWithBool:YES], [NSNumber numberWithBool:YES], nil],
    [NSArray arrayWithObjects: @"0.0.0.0:1001", @"0.0.0.0", [NSNumber numberWithInt:1001], [NSNumber numberWithBool:YES], [NSNumber numberWithBool:YES], nil],
    [NSArray arrayWithObjects: @"localhost:1001", @"localhost", [NSNumber numberWithInt:1001], [NSNumber numberWithBool:NO], [NSNumber numberWithBool:YES], nil],
    [NSArray arrayWithObjects: @"localhost:echo", @"localhost", [NSNumber numberWithInt:7], [NSNumber numberWithBool:NO], [NSNumber numberWithBool:YES], nil],
    [NSArray arrayWithObjects: @"[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:1234", @"2001:0db8:85a3:0000:0000:8a2e:0370:7334", [NSNumber numberWithInt:1234], [NSNumber numberWithBool:NO], [NSNumber numberWithBool:NO], nil],
    [NSArray arrayWithObjects: @"[::1]:echo", @"::1", [NSNumber numberWithInt:7], [NSNumber numberWithBool:NO], [NSNumber numberWithBool:NO], nil],
    [NSArray arrayWithObjects: @"[::]:echo", @"::", [NSNumber numberWithInt:7], [NSNumber numberWithBool:YES], [NSNumber numberWithBool:NO], nil],
    nil
  ];
  int i;
  for (i = 0; i < [cases count]; i++)
    {
        NSString *error;

        NSArray *currentCase = [cases objectAtIndex: i];
        NSString *input = [currentCase objectAtIndex: 0];
        NSString *expectedHost = [currentCase objectAtIndex: 1];
        int expectedPort = [[currentCase objectAtIndex: 2] intValue];
        bool expectedIsWildcard = [[currentCase objectAtIndex: 3] boolValue];
        bool expectedIsIpV4 = [[currentCase objectAtIndex: 4] boolValue];
        NGInternetSocketAddress *addr =  (NGInternetSocketAddress *)NGSocketAddressFromString(input);
        NSString *host = [addr hostName];
        if (host == nil)
            host = @"*";

        error = [NSString stringWithFormat:
          @"Hostname mismatch. Expected: '%@', result: '%@'. Test url: '%@'",
          expectedHost, host, input];
        testWithMessage([host isEqualToString: expectedHost], error);

        int port = [addr port];
        error = [NSString stringWithFormat:
          @"Port mismatch. Expected: '%d', result: '%d'. Test url: '%@'",
          expectedPort, port, input];
        testWithMessage(port == expectedPort, error);

        BOOL isWildcard = [addr isWildcardAddress];
        error = [NSString stringWithFormat:
          @"isWildcard mismatch. Expected: '%d', result: '%d'. Test url: '%@'",
          expectedIsWildcard, isWildcard, input];
        testWithMessage(isWildcard == expectedIsWildcard, error);


        BOOL isIPv4 = [addr isIPv4];
        error = [NSString stringWithFormat:
          @"isIpv4 mismatch. Expected: '%d', result: '%d'. Test url: '%@'",
          expectedIsIpV4, isIPv4, input];
        testWithMessage(isIPv4 == expectedIsIpV4, error);
    }
}

@end
