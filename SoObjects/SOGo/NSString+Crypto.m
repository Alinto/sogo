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

#ifdef HAVE_OPENSSL
#import <openssl/evp.h>
#import <openssl/aes.h>
#endif

#import "aes.h"
#define AES_128_KEY_SIZE  16
#define AES_128_BLOCK_SIZE 16
#define AES_256_KEY_SIZE  32
#define AES_256_BLOCK_SIZE 16
#define GMC_IV_LEN 12
#define GMC_TAG_LEN 16

static const NSString *kAES128ECError = @"kAES128ECError";
static const NSString *kAES256GCMError = @"kAES256GCMError";

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
  NSData *data, *keyData, *outputData;
  NSString *value;
  int c_len, f_len;
  unsigned char *ciphertext;
  #ifdef HAVE_OPENSSL
    EVP_CIPHER_CTX *ctx;
  #endif

  value = nil;

  if (AES_128_KEY_SIZE != [passwordScheme length]) {
    *ex = [NSException exceptionWithName: kAES128ECError reason: [NSString stringWithFormat:@"Key must be %d bits", (AES_128_KEY_SIZE * 8)] userInfo: nil];
    return nil;
  }

  #ifdef HAVE_OPENSSL

    data = [self dataUsingEncoding: NSUTF8StringEncoding];
    keyData = [passwordScheme dataUsingEncoding: NSUTF8StringEncoding];

    // Initialize OpenSSL
    ctx = EVP_CIPHER_CTX_new();

    // Set up cipher parameters
    EVP_CIPHER_CTX_init(ctx);
    EVP_EncryptInit_ex(ctx, EVP_aes_128_ecb(), NULL, [keyData bytes], NULL);
    EVP_CIPHER_CTX_set_padding(ctx, 1);

    // Perform encryption
    c_len = [data length] + AES_128_BLOCK_SIZE;
    ciphertext = malloc(c_len);
    f_len = 0;

    EVP_EncryptInit_ex(ctx, NULL, NULL, NULL, NULL);
    EVP_EncryptUpdate(ctx, ciphertext, &c_len, [data bytes], [data length]);
    EVP_EncryptFinal_ex(ctx, ciphertext + c_len, &f_len);
    c_len += f_len;

    EVP_CIPHER_CTX_free(ctx);

    
    outputData = [NSData dataWithBytes: (char *)ciphertext length: c_len];
    free(ciphertext);
    if (outputData) {
      value = [outputData stringByEncodingBase64];
      if (encodedURL) {
        value = [value stringByReplacingOccurrencesOfString: @"+" withString: @"."];
        value = [value stringByReplacingOccurrencesOfString: @"/" withString: @"_"];
        value = [value stringByReplacingOccurrencesOfString: @"=" withString: @"-"];
      }
    } else {
      *ex = [NSException exceptionWithName: kAES128ECError reason:@"Empty data" userInfo: nil];
    }

    return value;

  #else
    *ex = [NSException exceptionWithName: kAES128ECError reason:@"Missing OpenSSL framework" userInfo: nil];
    return self;
  #endif
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

  NSData *keyData, *data, *outputData;
  NSString *inputString, *value;
  int p_len, f_len;
  unsigned char *plaintext;

  value = nil;

  #ifdef HAVE_OPENSSL

    if (AES_128_KEY_SIZE != [passwordScheme length]) {
      *ex = [NSException exceptionWithName: kAES128ECError reason: [NSString stringWithFormat:@"Key must be %d bits", (AES_128_KEY_SIZE * 8)] userInfo: nil];
      return nil;
    }
    keyData = [passwordScheme dataUsingEncoding: NSUTF8StringEncoding];

    inputString = [NSString stringWithString: self];
    if (encodedURL) {
      inputString = [inputString stringByReplacingOccurrencesOfString: @"." withString: @"+"];
      inputString = [inputString stringByReplacingOccurrencesOfString: @"_" withString: @"/"];
      inputString = [inputString stringByReplacingOccurrencesOfString: @"-" withString: @"="];
    }
    data = [inputString dataByDecodingBase64];

    // Initialize OpenSSL
    EVP_CIPHER_CTX *ctx;
    ctx = EVP_CIPHER_CTX_new();

    // Set up cipher parameters
    EVP_CIPHER_CTX_init(ctx);
    EVP_DecryptInit_ex(ctx, EVP_aes_128_ecb(), NULL, [keyData bytes], NULL);
    EVP_CIPHER_CTX_set_padding(ctx, 1);

    // Perform decryption
    p_len = [data length];
    plaintext = malloc(p_len);
    f_len = 0;

    EVP_DecryptInit_ex(ctx, NULL, NULL, NULL, NULL);
    EVP_DecryptUpdate(ctx, plaintext, &p_len, [data bytes], [data length]);
    EVP_DecryptFinal_ex(ctx, plaintext + p_len, &f_len);
    p_len += f_len;

    EVP_CIPHER_CTX_free(ctx);

    // Trim padding
    while (plaintext[p_len - 1] == '\0') {
        p_len--;
    }

    
    if (p_len > 0) {
      // Convert to NSString
      outputData = [NSData dataWithBytes: plaintext length: p_len];
      if (outputData && [outputData length] > 0) {
        char lastByte;
        [outputData getBytes:&lastByte range:NSMakeRange([outputData length]-1, 1)];
        if (lastByte == 0x0) {
          // string is null terminated
          value = [NSString stringWithUTF8String: [outputData bytes]];
        } else {
          // string is not null terminated
          value = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
          [value autorelease];
        }
      } else {
        *ex = [NSException exceptionWithName: kAES128ECError reason:@"Empty data" userInfo: nil];
      }
    } else {
      *ex = [NSException exceptionWithName: kAES128ECError reason:@"Could not decrypt" userInfo: nil];
    }

    // Clean up
    free(plaintext);
    return value;

  #else
    *ex = [NSException exceptionWithName:kAES128ECError reason:@"Missing OpenSSL framework" userInfo: nil];
    return self;
  #endif
}

- (NSDictionary *)encryptAES256GCM:(NSString *)passwordScheme exception:(NSException **)ex
{

  NSData *data, *keyData, *ivData, *tagData, *outputData;
  NSString *value;
  NSError *error;
  NSMutableDictionary* gcmDisctionary;
  int c_len, f_len;
  unsigned char *ciphertext;
  unsigned char tag[16];

  #ifdef HAVE_OPENSSL
    EVP_CIPHER_CTX *ctx;
  #endif

  value = nil;
  gcmDisctionary = [NSMutableDictionary dictionaryWithObject: @"" forKey: @"cypher"];


  if (AES_256_KEY_SIZE != [passwordScheme length]) {
    *ex = [NSException exceptionWithName: kAES256GCMError reason: [NSString stringWithFormat:@"Key must be %d bits", (AES_256_KEY_SIZE * 8)] userInfo: nil];
    return nil;
  }

  #ifdef HAVE_OPENSSL

    //Generate random IV
    ivData = [[NSFileHandle fileHandleForReadingAtPath:@"/dev/random"] readDataOfLength:GMC_IV_LEN];
    if (GMC_IV_LEN != [ivData length]) {
      *ex = [NSException exceptionWithName: kAES256GCMError reason: [NSString stringWithFormat:@"IV must be %d bits", (GMC_IV_LEN * 8)] userInfo: nil];
      return nil;
    }

    data = [self dataUsingEncoding: NSUTF8StringEncoding];
    keyData = [passwordScheme dataUsingEncoding: NSUTF8StringEncoding];

    //Set cipher encryption
    ctx = EVP_CIPHER_CTX_new();
    EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
    EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, GMC_IV_LEN, NULL);
    EVP_EncryptInit_ex(ctx, NULL, NULL, [keyData bytes], [ivData bytes]);

    //Start Encryption
    c_len = [data length];
    ciphertext = malloc(c_len);
    int status = 0;
    EVP_EncryptUpdate(ctx, ciphertext, &c_len, [data bytes], (int)[data length]);
    status = EVP_EncryptFinal_ex(ctx, ciphertext + c_len, &f_len);
    c_len += f_len;

    outputData = nil;
    tagData = nil;
    if(status)
    {
      outputData = [NSData dataWithBytes: (char *)ciphertext length: c_len];
      EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, GMC_TAG_LEN, tag);
      tagData = [NSData dataWithBytes: (char *)tag length: GMC_TAG_LEN];
    }
    else {
      *ex = [NSException exceptionWithName: kAES256GCMError reason:@"Encryption not successful" userInfo: nil];
    }

    EVP_CIPHER_CTX_free(ctx);

    free(ciphertext);
    if(outputData && tagData)
    {
      [gcmDisctionary setObject: [outputData stringByEncodingBase64] forKey: @"cypher"];
      [gcmDisctionary setObject: [ivData stringByEncodingBase64] forKey: @"iv"];
      [gcmDisctionary setObject: [tagData stringByEncodingBase64] forKey: @"tag"];
    }
    else {
      *ex = [NSException exceptionWithName: kAES256GCMError reason:@"Empty data" userInfo: nil];
    }

    return gcmDisctionary;
      
  #else
    *ex = [NSException exceptionWithName:kAES256GCMError reason:@"Missing OpenSSL framework" userInfo: nil];
    return nil;
  #endif
}

- (NSString *)decryptAES256GCM:(NSString *)passwordScheme iv:(NSString *)ivString tag:(NSString *)tagString exception:(NSException **)ex
{

  NSData *keyData, *ivData, *tagData, *data, *outputData;
  NSString *inputString, *value;
  int p_len, f_len, rv;
  unsigned char *plaintext;

  value = nil;

  #ifdef HAVE_OPENSSL

    keyData = [passwordScheme dataUsingEncoding: NSUTF8StringEncoding];
    ivData = [ivString dataByDecodingBase64];
    tagData = [tagString dataByDecodingBase64];

    if (AES_256_KEY_SIZE != [keyData length]) {
      *ex = [NSException exceptionWithName: kAES256GCMError reason: [NSString stringWithFormat:@"Key must be %d bits", (AES_256_KEY_SIZE * 8)] userInfo: nil];
      return nil;
    }
    if (GMC_IV_LEN!= [ivData length]) {
      *ex = [NSException exceptionWithName: kAES256GCMError reason: [NSString stringWithFormat:@"Key must be %d bits", (GMC_IV_LEN * 8)] userInfo: nil];
      return nil;
    }
    if (GMC_TAG_LEN != [tagData length]) {
      *ex = [NSException exceptionWithName: kAES256GCMError reason: [NSString stringWithFormat:@"Tag must be %d bits", (GMC_TAG_LEN * 8)] userInfo: nil];
      return nil;
    }

    inputString = [NSString stringWithString: self];
    data = [inputString dataByDecodingBase64];

    // Initialize OpenSSL
    EVP_CIPHER_CTX *ctx;
    ctx = EVP_CIPHER_CTX_new();

    // Set up cipher parameters
    EVP_CIPHER_CTX_init(ctx);
    EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, GMC_IV_LEN, NULL);
    EVP_DecryptInit_ex(ctx, NULL, NULL, [keyData bytes], [ivData bytes]);

    // Perform decryption
    p_len = [data length];
    plaintext = malloc(p_len);
    f_len = 0;

    int status = 0;
    EVP_DecryptUpdate(ctx, plaintext, &p_len, [data bytes], [data length]);
    outputData = [NSData dataWithBytes: (char *)plaintext length: p_len];
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, GMC_TAG_LEN, (void *)[tagData bytes]);
    rv = EVP_DecryptFinal_ex(ctx, plaintext + p_len, &f_len);
    p_len += f_len;
    EVP_CIPHER_CTX_free(ctx);

    if (rv > 0) {
      if (outputData && [outputData length] > 0) {
        char lastByte;
        [outputData getBytes:&lastByte range:NSMakeRange([outputData length]-1, 1)];
        if (lastByte == 0x0) {
          // string is null terminated
          value = [NSString stringWithUTF8String: [outputData bytes]];
        } else {
          // string is not null terminated
          value = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
          [value autorelease];
        }
      } else {
        *ex = [NSException exceptionWithName: kAES256GCMError reason:@"Decryption ok but output empty" userInfo: nil];
      }
    } else {
      *ex = [NSException exceptionWithName: kAES256GCMError reason:@"Decryption not ok" userInfo: nil];
    }

    // Clean up
    free(plaintext);

    if(value)
      return value;
    else
    {
      *ex = [NSException exceptionWithName: kAES128ECError reason:@"Could decrypt but value is null" userInfo: nil];
      return nil;
    }


  #else
    *ex = [NSException exceptionWithName:kAES256GCMError reason:@"Missing OpenSSL framework" userInfo: nil];
    return self;
  #endif
}

@end
