/* TestNSString+Crypto.m - this file is part of SOGo
 *
 * Copyright (C) 2011, 2012 Jeroen Dekkers
 * Copyright (C) 2020 Nicolas Höft
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

#import "SOGo/NSString+Crypto.h"

#import "SOGoTest.h"

@interface TestNSData_plus_Crypto : SOGoTest
@end

@implementation TestNSData_plus_Crypto

- (void) test_dataCrypto
{
  const char *inStrings[] = { "SOGoSOGoSOGoSOGo", "éléphant", "2š", NULL };
  const char **inString;
  NSString *MD5Strings[] = { @"d3e8072c49511f099d254cc740c7e12a", @"bc6a1535589d6c3cf7999ac37018c11e", @"886ae9b58817fb8a63902feefcd18812" };
  NSString *SHA1Strings[] = { @"b7d891e0f3b42898fa66627b5cfa3d80501bae46", @"99a02f8802f8ea7e3ad91c4cc4d3ef5a7257c88f", @"32b89f3a9e6078db554cdd39f8571c09de7e8b21" };
  NSString **MD5String;
  NSString **SHA1String;
  NSString *result, *error;

  inString = inStrings;
  MD5String = MD5Strings;
  SHA1String = SHA1Strings;
  while (*inString)
    {
      result = [[NSString stringWithUTF8String: *inString] asMD5String];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong MD5: '%@' (expected '%@')",
                        *inString, result, *MD5String];
      testWithMessage([result isEqualToString: *MD5String], error);
      result = [[NSString stringWithUTF8String: *inString] asSHA1String];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA1: '%@' (expected '%@')",
                        *inString, result, *SHA1String];
      testWithMessage([result isEqualToString: *SHA1String], error);
      inString++;
      MD5String++;
      SHA1String++;
    }
}

- (void) test_blowfish
{
  NSString *error;
  // well-known comparison
  NSString *blf_key = @"123456";
  NSString *blf_hash = @"{BLF-CRYPT}$2a$05$tLVuFQTgdwrZmixu.QMxoedUAUEeIFIBv89Ur5mQ6F1vBL8Vw1mXO";
  error = [NSString stringWithFormat:
                          @"string '%@' wrong BLF-CRYPT: '%@'",
                        blf_key, blf_hash];
  testWithMessage([blf_key isEqualToCrypted:blf_hash withDefaultScheme: @"CRYPT" keyPath: nil], error);

  // generate a new blowfish-crypt key
  NSString *blf_prefix = @"$2y$05$";

  NSString *blf_result = [blf_key asCryptedPassUsingScheme: @"blf-crypt" keyPath: nil];

  error = [NSString stringWithFormat:
                          @"returned hash '%@' has incorrect BLF-CRYPT prefix: '%@'",
                        blf_result, blf_prefix];

  testWithMessage([blf_result hasPrefix: blf_prefix], error);

  test([blf_key isEqualToCrypted:blf_result withDefaultScheme: @"BLF-CRYPT" keyPath: nil]);
}

- (void) test_pbkdf2
{
  NSString *error;
  // well-known comparison
  NSString *pbkdf2_key = @"123456";
  NSString *pbkdf2_hash = @"{PBKDF2}$1$xbhnwhLxltdS9L5M$5001$f1699047a6132383490817d6e58a5284f13339f0";
  NSString *pkbf2_prefix;
  NSString *pkbf2_result;

  error = [NSString stringWithFormat:
                          @"string '%@' wrong PBKDF2: '%@'",
                        pbkdf2_key, pbkdf2_hash];
  testWithMessage([pbkdf2_key isEqualToCrypted:pbkdf2_hash withDefaultScheme: @"CRYPT" keyPath: nil], error);

  // generate a new pbkdf2-crypt key
  pkbf2_prefix = @"$1$";
  pkbf2_result = [pbkdf2_key asCryptedPassUsingScheme: @"PBKDF2" keyPath: nil];

  error = [NSString stringWithFormat:
                          @"returned hash '%@' has incorrect PBKDF2 prefix: '%@'",
                        pkbf2_result, pkbf2_prefix];

  testWithMessage([pkbf2_result hasPrefix: pkbf2_prefix], error);
  test([pbkdf2_key isEqualToCrypted:pkbf2_result withDefaultScheme: @"PBKDF2" keyPath: nil]);
}

#ifdef HAVE_SODIUM
- (void) test_argon2
{
  NSString *error;
  // well-known comparison
  NSString *cleartext = @"123456";
  NSString *hash = @"{ARGON2I}$argon2i$v=19$m=32768,t=4,p=1$HWg68rEbwmY6yrdByJ7U1g$z1c06BysT+51u1RXGtYIknTpA9jAHUfw1dAqPgTiQJ8";
  NSString *prefix;
  NSString *crypted_hash;

  error = [NSString stringWithFormat:
                          @"string '%@' wrong ARGON2ID: '%@'",
                        cleartext, hash];
  testWithMessage([cleartext isEqualToCrypted:hash withDefaultScheme: @"CRYPT" keyPath: nil], error);

  // generate a new argon2id key
  prefix = @"$argon2id$";
  crypted_hash = [cleartext asCryptedPassUsingScheme: @"ARGON2ID" keyPath: nil];
  fprintf(stdout, "hash = %s\n", [crypted_hash UTF8String]);

  error = [NSString stringWithFormat:
                          @"returned hash '%@' has incorrect ARGON2ID prefix: '%@'",
                        crypted_hash, prefix];

  testWithMessage([crypted_hash hasPrefix: prefix], error);
  test([cleartext isEqualToCrypted:crypted_hash withDefaultScheme: @"ARGON2ID" keyPath: nil]);
}
#endif /* HAVE_SODUM */

@end
