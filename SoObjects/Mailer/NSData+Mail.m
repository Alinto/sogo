/* NSData+Mail.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <Foundation/NSString.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>

#import "NSData+Mail.h"

@implementation NSData (SOGoMailUtilities)

- (NSData *) bodyDataFromEncoding: (NSString *) encoding
{
  NSString *realEncoding;
  NSData *decodedData;

  realEncoding = [encoding lowercaseString];

  if ([realEncoding isEqualToString: @"7bit"]
      || [realEncoding isEqualToString: @"8bit"])
    decodedData = self;
  else if ([realEncoding isEqualToString: @"base64"])
    decodedData = [self dataByDecodingBase64];
  else if ([realEncoding isEqualToString: @"quoted-printable"])
    decodedData = [self dataByDecodingQuotedPrintable];
  else
    {
      decodedData = nil;
      NSLog (@"encoding '%@' unknown, returning nil data", realEncoding);
    }

  return decodedData;
}

@end
