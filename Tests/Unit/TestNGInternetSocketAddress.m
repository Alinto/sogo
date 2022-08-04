/* TestNGInternetSocketAddress.m - this file is part of SOGo
 *
 * Copyright (C) 2020 Nicolas Höft
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

#import <NGStreams/NGInternetSocketAddress.h>

#import "SOGoTest.h"

@interface TestNGInternetSocketAddress : SOGoTest
@end

@implementation TestNGInternetSocketAddress

- (void) test_isLocalhost
{
  NSString *addrStr[] = { @"127.0.0.1", @"127.1.2.3", @"localhost",  @"something.localhost", @"localhost.", @"::1", nil };
  NSString **curHost;
  BOOL is_localhost;
  NSString *error;

  curHost = addrStr;
  while (*curHost)
    {
      NGInternetSocketAddress *addr;
      addr = [NGInternetSocketAddress addressWithPort: 1234
                                 onHost: *curHost];
      is_localhost = [addr isLocalhost];

      error = [NSString stringWithFormat:
                          @"expected '%@' to be a localhost address. Is libnss-myhostname installed and activated in /etc/nsswitch.conf?", *curHost];
      testWithMessage(is_localhost, error);

      curHost++;
    }
}

@end
