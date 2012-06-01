/* NSString+Crypto.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Nicolas Höft
 * Copyright (C) 2012 Inverse inc.
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
  NSArray *schemeComps;
  keyEncoding encoding;
  
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

  encoding = [NSString getDefaultEncodingForScheme: scheme];

  // get the encoding which may be part of the scheme
  // e.g. ssha.hex forces a hex encoded ssha scheme
  // possible is "b64" or "hex"
  schemeComps = [scheme componentsSeparatedByString: @"."];
  if ([schemeComps count] == 2)
    {
      NSString *stringEncoding;
      // scheme without encoding string is the first item
      scheme = [schemeComps objectAtIndex: 0];
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

  pass = [self substringWithRange: range];
  return [NSArray arrayWithObjects: scheme, pass, [NSNumber numberWithInt: encoding], nil];
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
{
  NSArray *passInfo;
  NSString *selfCrypted;
  NSString *pass;
  NSString *scheme;
  NSData *salt;
  NSData *decodedData;
  NSNumber *encodingNumber;
  keyEncoding encoding;

  // split scheme and pass
  passInfo = [cryptedPassword splitPasswordWithDefaultScheme: theScheme];

  scheme   = [passInfo objectAtIndex: 0];
  pass     = [passInfo objectAtIndex: 1];
  encodingNumber = [passInfo objectAtIndex: 2];
  encoding = [encodingNumber intValue];

  if (encoding == encHex)
    {
      decodedData = [NSData decodeDataFromHexString: pass];
      
      if(decodedData == nil)
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
  else if(encoding == encBase64)
    {
      decodedData = [pass dataByDecodingBase64];
      if(decodedData == nil)
        {
          decodedData = [NSData data];
        }
    }
  else
    {
      decodedData = [pass dataUsingEncoding: NSUTF8StringEncoding];
    }

  salt = [decodedData extractSalt: scheme];

  // encrypt self with the salt an compare the results
  selfCrypted = [self asCryptedPassUsingScheme: scheme
                           withSalt: salt
                           andEncoding: encoding];
  // return always false when there was a problem
  if (selfCrypted == nil)
    return NO;

  if ([selfCrypted isEqualToString: pass] == YES)
    return YES;
  return NO;
}

/**
 * Calls asCryptedPassUsingScheme:withSalt:andEncoding: with an empty salt and uses
 * the default encoding.
 *
 * @param passwordScheme 
 * @return If successful, the encrypted and encoded NSString of the format {scheme}pass, or nil if the scheme did not exists or an error occured
 */
- (NSString *) asCryptedPassUsingScheme: (NSString *) passwordScheme
{
  return [self asCryptedPassUsingScheme: passwordScheme
                               withSalt: [NSData data]
                            andEncoding: encDefault];
}

/**
 * Uses NSData -asCryptedPassUsingScheme to encrypt the string and converts the
 * binary data back to a readable string using userEncoding
 *
 * @param passwordScheme The scheme to use
 * @param theSalt The binary data of the salt
 * @param userEncoding The encoding (plain, hex, base64) to be used
 * @return If successful, the encrypted and encoded NSString of the format {scheme}pass, or nil if the scheme did not exists or an error occured
 */
- (NSString *) asCryptedPassUsingScheme: (NSString *) passwordScheme
                               withSalt: (NSData *) theSalt
                          andEncoding: (keyEncoding) userEncoding
{
  keyEncoding dataEncoding;
  NSData* cryptedData;
  // convert NSString to NSData and apply encryption scheme
  cryptedData = [self dataUsingEncoding: NSUTF8StringEncoding];
  cryptedData = [cryptedData asCryptedPassUsingScheme: passwordScheme  withSalt: theSalt];
  // abort on unsupported scheme or error
  if (cryptedData == nil)
    return nil;

  // use default encoding scheme, when set to default
  if (userEncoding == encDefault)
    dataEncoding = [NSString getDefaultEncodingForScheme: passwordScheme];
  else
    dataEncoding = userEncoding;

  if (dataEncoding == encHex)
    {
      // hex encoding
      return [NSData encodeDataAsHexString: cryptedData];
    }
  else if(dataEncoding == encBase64)
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
 * @param passwordScheme The scheme for which to get the encoding.
 * @see keyEncoding
 * @return returns the encoding, if unknown returns encPlain
 */
+ (keyEncoding) getDefaultEncodingForScheme: (NSString *) passwordScheme
{
  // in order to keep backwards-compatibility, hex encoding is used for sha1 here
  if ([passwordScheme caseInsensitiveCompare: @"md5"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"plain-md5"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"sha"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"cram-md5"] == NSOrderedSame)
    {
      return encHex;
    }
  else if ([passwordScheme caseInsensitiveCompare: @"smd5"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ldap-md5"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ssha"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"sha256"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ssha256"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"sha512"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ssha512"] == NSOrderedSame)
    {
      return encBase64;
    }
  return encPlain;
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
  return [NSData encodeDataAsHexString: [cryptData asSHA1] ];
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
  return [NSData encodeDataAsHexString: [cryptData asMD5] ];
}

@end
