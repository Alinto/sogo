/* TestNSString+MD5SHA1.m - this file is part of SOGo
 *
 * Copyright (C) 2011, 2012 Jeroen Dekkers
 *
 * Author: Jeroen Dekkers <jeroen@dekkers.ch>
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
#import <Foundation/NSData.h>
#import "SOGo/NSData+Crypto.h"

#import "SOGoTest.h"

@interface TestNSString_plus_Crypto : SOGoTest
@end

@implementation TestNSString_plus_Crypto

- (void) test_stringCrypto
{
  const char *inStrings[] = { "SOGoSOGoSOGoSOGo", "éléphant", "2š", NULL };
  const char **inString;
  NSString *MD5Strings[] = { @"d3e8072c49511f099d254cc740c7e12a", @"bc6a1535589d6c3cf7999ac37018c11e", @"886ae9b58817fb8a63902feefcd18812" };
  NSString *CramMD5Strings[] = { @"807cf6d4995482060b2e9b1bc3fe1507a42c51dc97d86302b460f7878f0551e2", @"72a6cb4f15711350c3e3d83a9cb631eb0dcc06e56776bed15766e65e0fdb7694",
				 @"14bef22dd8c749f6ff3ebbfa51261291e3c1dc42e3dc13ae3771d01de8e53ccd" };
  NSString *SHA1Strings[] = { @"b7d891e0f3b42898fa66627b5cfa3d80501bae46", @"99a02f8802f8ea7e3ad91c4cc4d3ef5a7257c88f", @"32b89f3a9e6078db554cdd39f8571c09de7e8b21" };
  NSString *SHA256Strings[] = { @"3d5c087342ad6208e7f4bc353c5e739dcd14137f6e4159779347fea2e7f562bf", @"c941ae685f62cbe7bb47d0791af7154788fd9e873e5c57fd2449d1454ed5b16f",
				@"f89a911feceaf3d9c28f4e431edff50c265933102476b1814f83704a7bc46890" };
  NSString *SHA512Strings[] = { @"e003b24f05d1b007e5f5a87f726668cb47301d1366cd8d8632646483b1e570335feae34e1e88213a53bab78a876eb805317f290fbf71a1ac79d1275d4a24dee7",
				@"c6f2bb64ee795ad613b4521cd65618d2a036ae6423513a22eddc1bb8a88e5486add61fc1f3a0fc592ce9c24598a23b4ec854f96ccdf73808f701dced2a9b0d64",
				@"49d72f3626d6a56483b3cb4a6da336c423825dbe92d5e225ea2fd69fca1b28d8bceb1544b85847c4fac5c5e0c378b4384f2ac7c230c73dd389061d1b0198c14c" };
  NSString **MD5String;
  NSString **CramMD5String;
  NSString **SHA1String;
  NSString **SHA256String;
  NSString **SHA512String;
  NSData *result;
  NSString *error;

  inString = inStrings;
  CramMD5String = CramMD5Strings;
  MD5String = MD5Strings;
  SHA1String = SHA1Strings;
  SHA256String = SHA256Strings;
  SHA512String = SHA512Strings;
  while (*inString)
    {
      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asMD5];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong MD5: '%@' (expected '%@')",
                        *inString, result, *MD5String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *MD5String], error);

      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asCramMD5];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong CramMD5: '%@' (expected '%@')",
                        *inString, result, *CramMD5String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *CramMD5String], error);

      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asSHA1];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA1: '%@' (expected '%@')",
                        *inString, result, *SHA1String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *SHA1String], error);

      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asSHA256];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA256: '%@' (expected '%@')",
                        *inString, result, *SHA256String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *SHA256String], error);

      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asSHA512];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA512: '%@' (expected '%@')",
                        *inString, result, *SHA512String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *SHA512String], error);
      inString++;
      MD5String++;
      CramMD5String++;
      SHA1String++;
      SHA256String++;
      SHA512String++;
    }
}

@end
