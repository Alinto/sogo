/* NSString+Crypto.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Nicolas Höft
 * Copyright (C) 2012-2019 Inverse inc.
 *
 * Author: Nicolas Höft
 *         Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSValue.h>

#import "NSString+Crypto.h"
#import "NSData+Crypto.h"
#import <NGExtensions/NGBase64Coding.h>

#import "aes.h"
#define AES_SIZE  8096
#define AES_KEY_SIZE  16

static const NSString *kAES128ECError = @"kAES128ECError";

@implementation NSString (SOGoCryptoExtension)

/**
 * Extracts the scheme from a string formed "{scheme}pass".
 *
 * @return The scheme or an empty string if the string did not contained a scheme in the format above
 */
- (NSString *) extractCryptScheme
{
  NSRange r;
  int len;

  len = [self length];
  if (len == 0)
     return @"";
  if ([self characterAtIndex:0] != '{')
    return @"";

  r = [self rangeOfString:@"}" options:(NSLiteralSearch)];
  if (r.length == 0)
    return @"";

  r.length   = (r.location - 1);
  r.location = 1;
  return [[self substringWithRange:r] lowercaseString];
}


/**
 * Split a password of the form {scheme}pass into an array of its components:
 * {NSString *scheme, NString *pass, NSInteger encoding}, where encoding is
 * the enum keyEncoding converted to an integer value.
 *
 * @param defaultScheme If no scheme is given in cryptedPassword, fall back to this scheme
 * @see asCryptedPassUsingScheme
 * @see keyEncoding
 * @return NSArray with the three elements described above
 */
- (NSArray *) splitPasswordWithDefaultScheme: (NSString *) defaultScheme
{
  NSString *scheme;
  NSString *pass;
  NSArray *encodingAndScheme;

  NSRange range;
  int selflen, len;

  selflen = [self length];

  scheme = [self extractCryptScheme];
  len = [scheme length];
  if (len > 0)
    range = NSMakeRange (len+2, selflen-len-2);
  else
    range = NSMakeRange (0, selflen);
  if (len == 0)
    scheme = defaultScheme;

  encodingAndScheme = [NSString getDefaultEncodingForScheme: scheme];

  pass = [self substringWithRange: range];

  // Returns an array with [scheme, password, encoding]
  return [NSArray arrayWithObjects: [encodingAndScheme objectAtIndex: 1], pass, [encodingAndScheme objectAtIndex: 0], nil];
}

/**
 * Compare the hex or base64 encoded password with an encrypted password
 *
 * @param cryptedPassword The password to compare with, format {scheme}pass , "{scheme}" is optional
 * @param theScheme If no scheme is given in cryptedPassword, fall back to this scheme
 * @see asCryptedPassUsingScheme
 * @return YES if the passwords are identical using this encryption scheme
 */
- (BOOL) isEqualToCrypted: (NSString *) cryptedPassword
        withDefaultScheme: (NSString *) theScheme
                  keyPath: (NSString *) theKeyPath
{
  NSArray *passInfo;
  NSString *pass;
  NSString *scheme;
  NSData *decodedData;
  NSData *passwordData;
  keyEncoding encoding;

  // split scheme and pass
  passInfo = [cryptedPassword splitPasswordWithDefaultScheme: theScheme];

  scheme   = [passInfo objectAtIndex: 0];
  pass     = [passInfo objectAtIndex: 1];
  encoding = [[passInfo objectAtIndex: 2] intValue];

  if (encoding == encHex)
    {
      decodedData = [NSData decodeDataFromHexString: pass];

      if (decodedData == nil)
        {
          decodedData = [NSData data];
        }
      else
       {
          // decoding was successful, now make sure
          // that the pass is in lowercase since decodeDataFromHexString uses
          // lowercase charaters, too
          pass = [pass lowercaseString];
       }
    }
  else if (encoding == encBase64)
    {
      decodedData = [pass dataByDecodingBase64];
      if (decodedData == nil)
        {
          decodedData = [NSData data];
        }
    }
  else
    {
      decodedData = [pass dataUsingEncoding: NSUTF8StringEncoding];
    }

  passwordData = [self dataUsingEncoding: NSUTF8StringEncoding];
  return [decodedData verifyUsingScheme: scheme
                           withPassword: passwordData
                            keyPath: theKeyPath];
}

/**
 * Calls asCryptedPassUsingScheme:withSalt:andEncoding: with an empty salt and uses
 * the default encoding.
 *
 * @param passwordScheme: The password scheme to hash the cleartext password.
 * @return If successful, the encrypted and encoded NSString of the format {scheme}pass, or nil if the scheme did not exists or an error occured
 */
- (NSString *) asCryptedPassUsingScheme: (NSString *) passwordScheme
                                keyPath: (NSString *) theKeyPath
{
  return [self asCryptedPassUsingScheme: passwordScheme
                               withSalt: [NSData data]
                            andEncoding: encDefault
                                keyPath: theKeyPath];
}

/**
 * Uses NSData -asCryptedPassUsingScheme to encrypt the string and converts the
 * binary data back to a readable string using userEncoding
 *
 * @param passwordScheme The scheme to use
 * @param theSalt The binary data of the salt
 * @param userEncoding The encoding (plain, hex, base64) to be used. If set to
 *        encDefault, the encoding will be detected from scheme name.
 * @return If successful, the encrypted and encoded NSString of the format {scheme}pass,
 *         or nil if the scheme did not exists or an error occured.
 */
- (NSString *) asCryptedPassUsingScheme: (NSString *) passwordScheme
                               withSalt: (NSData *) theSalt
                            andEncoding: (keyEncoding) userEncoding
                                keyPath: (NSString *) theKeyPath
{
  keyEncoding dataEncoding;
  NSData* cryptedData;

  // use default encoding scheme, when set to default
  if (userEncoding == encDefault)
    {
      // the encoding needs to be detected before crypting,
      // to get the plain scheme (without encoding identifier)
      NSArray* encodingAndScheme;
      encodingAndScheme = [NSString getDefaultEncodingForScheme: passwordScheme];
      dataEncoding = [[encodingAndScheme objectAtIndex: 0] intValue];
      passwordScheme = [encodingAndScheme objectAtIndex: 1];
    }
  else
    {
      dataEncoding = userEncoding;
    }

  // convert NSString to NSData and apply encryption scheme
  cryptedData = [self dataUsingEncoding: NSUTF8StringEncoding];
  cryptedData = [cryptedData asCryptedPassUsingScheme: passwordScheme
                                             withSalt: theSalt
                                              keyPath: theKeyPath];

  // abort on unsupported scheme or error
  if (cryptedData == nil)
    return nil;

  if (dataEncoding == encHex)
    {
      // hex encoding
      return [NSData encodeDataAsHexString: cryptedData];
    }
  else if (dataEncoding == encBase64)
    {
       // base64 encoding
      NSString *s = [[NSString alloc] initWithData: [cryptedData dataByEncodingBase64WithLineLength: 1024]
                                          encoding: NSASCIIStringEncoding];
      return [s autorelease];
    }

  // plain string
  return [[[NSString alloc] initWithData: cryptedData encoding: NSUTF8StringEncoding] autorelease];
}

/**
 * Returns the encoding for a specified scheme
 *
 * @param passwordScheme The scheme for which to get the encoding. Can be "scheme.encoding" in which case the encoding is returned
 * @see keyEncoding
 * @return returns NSArray with elements {NSNumber encoding, NSString* scheme} where scheme is the 'real' scheme without the ".encoding" part.
 * 'encoding' is stored as NSNumber in the array. If the encoding was not detected, encPlain is used for encoding.
 */
+ (NSArray *) getDefaultEncodingForScheme: (NSString *) passwordScheme
{
  NSArray *schemeComps;
  NSString *trueScheme;
  keyEncoding encoding = encPlain;

  // get the encoding which may be part of the scheme
  // e.g. ssha.hex forces a hex encoded ssha scheme
  // possible is "b64" or "hex"
  schemeComps = [passwordScheme componentsSeparatedByString: @"."];
  if ([schemeComps count] == 2)
    {
      trueScheme = [schemeComps objectAtIndex: 0];
      NSString *stringEncoding;
      // encoding string is second item
      stringEncoding = [schemeComps objectAtIndex: 1];
      if ([stringEncoding caseInsensitiveCompare: @"hex"] == NSOrderedSame)
        {
          encoding = encHex;
        }
      else if ([stringEncoding caseInsensitiveCompare: @"b64"] == NSOrderedSame ||
               [stringEncoding caseInsensitiveCompare: @"base64"] == NSOrderedSame)
        {
          encoding = encBase64;
        }
    }
   else
    {
      trueScheme = passwordScheme;
    }

  // in order to keep backwards-compatibility, hex encoding is used for sha1 here
  if ([passwordScheme caseInsensitiveCompare: @"md4"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"md5"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"plain-md5"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"sha"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"cram-md5"] == NSOrderedSame)
    {
      encoding = encHex;
    }
  else if ([passwordScheme caseInsensitiveCompare: @"smd5"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ldap-md5"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ssha"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"sha256"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ssha256"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"sha512"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ssha512"] == NSOrderedSame)
    {
      encoding = encBase64;
    }

  return [NSArray arrayWithObjects: [NSNumber numberWithInt: encoding], trueScheme, nil];
}

/**
 * Encrypts the data with SHA1 scheme and returns the hex-encoded data
 *
 * @return If successful, sha1 encrypted and with hex encoded string
 */
- (NSString *) asSHA1String;
{
  NSData *cryptData;
  cryptData = [self dataUsingEncoding: NSUTF8StringEncoding];
  return [NSData encodeDataAsHexString: [cryptData asSHA1]];
}

/**
 * Encrypts the data with Plain MD5 scheme and returns the hex-encoded data
 *
 * @return If successful, MD5 encrypted and with hex encoded string
 */
- (NSString *) asMD5String;
{
  NSData *cryptData;
  cryptData = [self dataUsingEncoding: NSUTF8StringEncoding];
  return [NSData encodeDataAsHexString: [cryptData asMD5]];
}

/**
 * Encrypts the data using the NT-hash password scheme.
 *
 * @return If successful, NT-hash encrypted and with hex encoded string
 */
- (NSString *) asNTHash
{
  NSData *d;

  d = [self dataUsingEncoding: NSUTF16LittleEndianStringEncoding];

  return [[NSData encodeDataAsHexString: [d asMD4]] uppercaseString];
}

/**
 * Encrypts the data using the LM-hash password scheme.
 *
 * @return If successful, LM-hash encrypted and with hex encoded string
 */
- (NSString *) asLMHash
{
  NSData *d;

  // See http://en.wikipedia.org/wiki/LM_hash#Algorithm
  d = [[self uppercaseString] dataUsingEncoding: NSWindowsCP1252StringEncoding];

  return [[NSData encodeDataAsHexString: [d asLM]] uppercaseString];
}

/**
 * Encrypts the data using AES 128 ECB mechanism
 *
 * @param passwordScheme The 128 bits password key
 * @param encodedURL YES if the special base64 characters shall be escaped for URL
 * @param ex Exception pointer
 * @return If successful, encrypted string in base64
 */
- (NSString *) encodeAES128ECBBase64:(NSString *)passwordScheme encodedURL:(BOOL)encodedURL exception:(NSException **)ex
{
  NSData *inputData, *keyData, *outputData;

  if (AES_KEY_SIZE != [passwordScheme length]) {
    *ex = [NSException exceptionWithName:kAES128ECError reason: [NSString stringWithFormat:@"Key must be %d bits", (AES_KEY_SIZE * 8)] userInfo: nil];
    return nil;
  }
  
  NSString *value;
  int size, i;
  uint8_t  output[AES_SIZE], input[AES_SIZE];

  inputData = [self dataUsingEncoding: NSUnicodeStringEncoding];
  keyData = [passwordScheme dataUsingEncoding: NSUnicodeStringEncoding];
  size = [inputData length] + 16; // Add one unicode char size 16 bits (NUL)

  if (inputData == nil) {
    *ex = [NSException exceptionWithName:kAES128ECError reason: @"Invalid input data (encrypt)" userInfo: nil];
    return nil;
  }

  if (((AES_SIZE / 2) - 16) < [self length]) {
    *ex = [NSException exceptionWithName:kAES128ECError reason: [NSString stringWithFormat:@"Invalid size (encrypt). max size is %d. Current size : %d", ((AES_SIZE / 2) - 16), [self length]] userInfo: nil];
    return nil;
  }

  memset(output, 0x00, AES_SIZE);
  memset(input, 0x00, AES_SIZE);

  [inputData getBytes: input length: [inputData length]];
  input[[inputData length]] = '\0'; // Add NUL
  

  for(i = 0 ; i < (AES_SIZE / 16) ; ++i)
  {
      AES128_ECB_encrypt(input + (i*16), [keyData bytes], output+(i*16));
  }

  outputData = [NSData dataWithBytes: (char *)output length: size];
  
  if (outputData) {
    value = [outputData stringByEncodingBase64];
    if (encodedURL) {
      value = [value stringByReplacingOccurrencesOfString: @"+" withString: @"."];
      value = [value stringByReplacingOccurrencesOfString: @"/" withString: @"_"];
      value = [value stringByReplacingOccurrencesOfString: @"=" withString: @"-"];
    }

    return value;
  } else {
    *ex = [NSException exceptionWithName:kAES128ECError reason:@"Empty data" userInfo: nil];
  }
  
  return nil;
}

/**
 * Decrypts the base64 data using AES 128 ECB mechanism
 *
 * @param passwordScheme The 128 bits password key
 * @param encodedURL YES if the special base64 characters has been escaped for URL
 * @param ex Exception pointer
 * @return If successful, decrypted string
 */
- (NSString *) decodeAES128ECBBase64:(NSString *)passwordScheme encodedURL:(BOOL)encodedURL exception:(NSException **)ex
{
  NSData *inputData, *keyData, *outputData;
  NSString *value, *inputString, *tmpStr;
  int i;
  uint8_t output[AES_SIZE];

  if (AES_KEY_SIZE != [passwordScheme length]) {
    *ex = [NSException exceptionWithName:kAES128ECError reason: [NSString stringWithFormat:@"Key must be %d bits", (AES_KEY_SIZE * 8)] userInfo: nil];
    return nil;
  }
  

  value = nil;
  keyData = [passwordScheme dataUsingEncoding: NSUnicodeStringEncoding];
  memset(output, 0x00, AES_SIZE);

  inputString = [NSString stringWithString: self];
  if (encodedURL) {
    inputString = [inputString stringByReplacingOccurrencesOfString: @"." withString: @"+"];
    inputString = [inputString stringByReplacingOccurrencesOfString: @"_" withString: @"/"];
    inputString = [inputString stringByReplacingOccurrencesOfString: @"-" withString: @"="];
  }

  inputData = [inputString dataByDecodingBase64];

  if (inputData == nil) {
    *ex = [NSException exceptionWithName:kAES128ECError reason: @"Invalid input data (decrypt)" userInfo: nil];
    return nil;
  }

  if ((AES_SIZE) < [inputData length]) {
    *ex = [NSException exceptionWithName:kAES128ECError reason: [NSString stringWithFormat:@"Invalid size (decrypt). max size is %d. Current size : %d", AES_SIZE, [inputData length]] userInfo: nil];
    return nil;
  }

  for(i = 0; i < (AES_SIZE / 16); ++i)
  {
    AES128_ECB_decrypt([inputData bytes] + (i*16), [keyData bytes], output + (i*16));
  }

  outputData = [NSData dataWithBytes: output length:([inputData length] - 16)];
  if (outputData) {
    tmpStr = [[NSString alloc] initWithData: outputData encoding: NSUnicodeStringEncoding];
    if (tmpStr) {
      value = [NSString stringWithUTF8String: [tmpStr UTF8String]];
    } else {
      *ex = [NSException exceptionWithName:kAES128ECError reason:@"Empty converted decrypted data" userInfo: nil];
      value = nil;
    }
    [tmpStr release];
  } else {
    *ex = [NSException exceptionWithName:kAES128ECError reason:@"Empty data" userInfo: nil];
  }
  
  return value;
}

@end
