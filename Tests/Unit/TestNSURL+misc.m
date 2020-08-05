/* TestNSURL+miscm - this file is part of SOGo
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
#import <Foundation/NSDictionary.h>

#import <NGStreams/NGInternetSocketAddress.h>
#import <NGExtensions/NSURL+misc.h>

#import "SOGoTest.h"

@interface TestNSURL_plusmisc : SOGoTest
@end

@implementation TestNSURL_plusmisc

- (void) test_queryComponents
{
  NSString *urlStr;
  NSString *error;
  NSURL *url;
  NSDictionary *queryComp;

  urlStr = @"http://domain/path?key=value";

  url = [NSURL URLWithString: urlStr];
  queryComp = [url queryComponents];

  error = [NSString stringWithFormat:
                          @"expected '%@' to have 1 entry", urlStr];
  testWithMessage([queryComp count] == 1, error);

  test([[queryComp valueForKey: @"key"] isEqualToString: @"value"]);

  urlStr = @"http://domain/path?key1=value123&key2=val2&";
  url = [NSURL URLWithString: urlStr];
  queryComp = [url queryComponents];
  error = [NSString stringWithFormat:
                          @"expected '%@' to have 2 entries, got %d", urlStr, [queryComp count]];
  testWithMessage([queryComp count] == 2, error);

  test([[queryComp valueForKey: @"key1"] isEqualToString: @"value123"]);
  test([[queryComp valueForKey: @"key2"] isEqualToString: @"val2"]);

}

@end
