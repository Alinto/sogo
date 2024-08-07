/* NSData+Crypto.m - this file is part of SOGo
 *
 * Copyright (C) 2012, 2020 Nicolas Höft
 * Copyright (C) 2012-2020 Inverse inc.
 * Copyright (C) 2012 Jeroen Dekkers
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

#define _XOPEN_SOURCE 600

#include <fcntl.h>
#include <unistd.h>
#if !defined(__OpenBSD__) && !defined(__FreeBSD__)
#include <crypt.h>
#endif

#if defined(HAVE_GNUTLS)
#include <gnutls/gnutls.h>
#include <gnutls/crypto.h>
#include "md4.h"
#define MD4_DIGEST_LENGTH 16
#define MD5_DIGEST_LENGTH 16
#define SHA_DIGEST_LENGTH 20
#define SHA256_DIGEST_LENGTH 32
#define SHA512_DIGEST_LENGTH 64
#elif defined(HAVE_OPENSSL)
#include <openssl/evp.h>
#include <openssl/md4.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
#else
#error this module requires either gnutls or openssl
#endif

#ifdef HAVE_SODIUM
#include <sodium.h>
#endif

#include "aes.h"
#include "crypt_blowfish.h"
#include "lmhash.h"
#include "pkcs5_pbkdf2.h"

#import <Foundation/NSArray.h>
#import <NGExtensions/NGBase64Coding.h>
#import "NSData+Crypto.h"

static unsigned charTo4Bits(char c);
#if defined(HAVE_GNUTLS)
static BOOL check_gnutls_init(void);
static void _nettle_md5_compress(uint32_t *digest, const uint8_t *input);
#endif

#define BLF_CRYPT_DEFAULT_COMPLEXITY (5)
#define BLF_CRYPT_SALT_LEN (16)
#define BLF_CRYPT_BUFFER_LEN (128)
#define BLF_CRYPT_PREFIX_LEN (7+22+1) /* $2.$nn$ + salt */
#define BLF_CRYPT_PREFIX "$2y"

static const char salt_chars[] =
	"./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";


@implementation NSData (SOGoCryptoExtension)

/**
 * Covert binary data to hex encoded data (lower-case).
 *
 * @param theData The NSData to be converted into a hex-encoded string.
 * @return Hex-Encoded data
 */
+ (NSString *) encodeDataAsHexString: (NSData *) theData
{
  unsigned int byteLength = [theData length], byteCounter = 0;
  unsigned int stringLength = (byteLength * 2) + 1, stringCounter = 0;
  unsigned char dstBuffer[stringLength];
  unsigned char srcBuffer[byteLength];
  unsigned char *srcPtr = srcBuffer;
  [theData getBytes: srcBuffer];
  const unsigned char t[16] = "0123456789abcdef";

  for (; byteCounter < byteLength; byteCounter++)
    {
      unsigned src = *srcPtr;
      dstBuffer[stringCounter++] = t[src >> 4];
      dstBuffer[stringCounter++] = t[src & 15];
      srcPtr++;
    }

  dstBuffer[stringCounter] = '\0';
  return [NSString stringWithUTF8String: (char*)dstBuffer];
}

/**
 * Covert hex-encoded data to binary data.
 *
 * @param theString The hex-encoded string to be converted into binary data (works both for upper and lowe case characters)
 * @return binary data or nil if unsuccessful
 */
+ (NSData *) decodeDataFromHexString: (NSString *) theString
{
  unsigned int stringLength = [theString length];
  unsigned int byteLength = stringLength/2;
  unsigned int byteCounter = 0;
  unsigned char srcBuffer[stringLength];
  [theString getCString:(char *)srcBuffer];
  unsigned char *srcPtr = srcBuffer;
  unsigned char dstBuffer[byteLength];
  unsigned char *dst = dstBuffer;
  while (byteCounter < byteLength)
    {
      unsigned char c = *srcPtr++;
      unsigned char d = *srcPtr++;
      unsigned hi = 0, lo = 0;
      hi = charTo4Bits(c);
      lo = charTo4Bits(d);
      if (hi == 255 || lo == 255)
        {
          //errorCase
          return nil;
        }
      dstBuffer[byteCounter++] = ((hi << 4) | lo);
    }
  return [NSData dataWithBytes: dst length: byteLength];
}

/**
 * Generate a binary key which can be used for salting hashes.
 *
 * @param theLength length of the binary data to be generated in bytes
 * @return Pseudo-random binary data with length theLength or nil, if an error occured
 */
+ (NSData *) generateSaltForLength: (unsigned int) theLength
{
  return [NSData generateSaltForLength: theLength withPrintable: NO];
}

/**
 * Generate a binary key which can be used for salting hashes. When using
 * with doBase64 == YES then the data will be longer than theLength
 *
 * @param theLength Length of the binary data to be generated in bytes
 * @param doPrintable Use only printable characters
 * @return Pseudo-random binary data with length theLength or nil, if an error occured
 */
+ (NSData *) generateSaltForLength: (unsigned int) theLength
                        withPrintable: (BOOL) doPrintable
{
  char *buf;
  int fd;
  NSData *data;
  unsigned int i;

  fd = open("/dev/urandom", O_RDONLY);

  if (fd > 0)
    {
      buf = (char *)malloc(theLength);
      read(fd, buf, theLength);
      close(fd);
      if (doPrintable == YES)
        {
          for (i = 0; i < theLength; i++)
            {
              buf[i] = salt_chars[buf[i] % (sizeof(salt_chars)-1)];
            }
        }
      data = [NSData dataWithBytesNoCopy: buf  length: theLength  freeWhenDone: YES];
      return data;
    }
  return nil;
}

/**
 * Encrypt/Hash the data with a given scheme
 *
 * @param passwordScheme The scheme to use for hashing/encryption.
 * @param theSalt The salt to be used. If none is given but needed, it will be generated
 * @return Binary data from the encryption by the specified scheme. On error the function returns nil.
 */
- (NSData *) asCryptedPassUsingScheme: (NSString *) passwordScheme
                             withSalt: (NSData *) theSalt
                              keyPath: (NSString *) theKeyPath
{
  if ([passwordScheme caseInsensitiveCompare: @"none"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"plain"] == NSOrderedSame ||
      [passwordScheme caseInsensitiveCompare: @"cleartext"] == NSOrderedSame)
    {
      return self;
    }
  else if ([passwordScheme caseInsensitiveCompare: @"crypt"] == NSOrderedSame)
    {
      return [self asCryptUsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"md5-crypt"] == NSOrderedSame)
    {
      return [self asMD5CryptUsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"md4"] == NSOrderedSame)
    {
      return [self asMD4];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"md5"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"plain-md5"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"ldap-md5"] == NSOrderedSame)
    {
      return [self asMD5];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"cram-md5"] == NSOrderedSame)
    {
      return [self asCramMD5];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"smd5"] == NSOrderedSame)
    {
      return [self asSMD5UsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"sha"] == NSOrderedSame)
    {
      return [self asSHA1];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"ssha"] == NSOrderedSame)
    {
      return [self asSSHAUsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"sha256"] == NSOrderedSame)
    {
      return [self asSHA256];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"ssha256"] == NSOrderedSame)
    {
      return [self asSSHA256UsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"sha512"] == NSOrderedSame)
    {
      return [self asSHA512];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"ssha512"] == NSOrderedSame)
    {
      return [self asSSHA512UsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"sha256-crypt"] == NSOrderedSame)
    {
      return [self asSHA256CryptUsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"sha512-crypt"] == NSOrderedSame)
    {
      return [self asSHA512CryptUsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"blf-crypt"] == NSOrderedSame)
    {
      return [self asBlowfishCryptUsingSalt: theSalt];
    }
  else if ([passwordScheme caseInsensitiveCompare: @"pbkdf2"] == NSOrderedSame)
    {
      return [self asPBKDF2SHA1UsingSalt: theSalt];
    }
#ifdef HAVE_SODIUM
  else if ([passwordScheme caseInsensitiveCompare: @"argon2i"] == NSOrderedSame ||
           [passwordScheme caseInsensitiveCompare: @"argon2"] == NSOrderedSame)
    {
      return [self asArgon2iUsingSalt: theSalt];
    }
# ifdef crypto_pwhash_ALG_ARGON2ID13
  else if ([passwordScheme caseInsensitiveCompare: @"argon2id"] == NSOrderedSame)
    {
      return [self asArgon2idUsingSalt: theSalt];
    }
# endif /* crypto_pwhash_ALG_ARGON2ID13 */
#endif /* HAVE_SODIUM */
  else if ([[passwordScheme lowercaseString] hasPrefix: @"sym"])
    {
      // We first support one sym cipher, AES-128-CBC. If something else is provided
      // we return nil for now. Example of what theSalt might contain:
      // $AES-128-CBC$cinlbHKnyBApySphVCz6yA==$Z9hjCXfMhz4xbXkW+aMkAw==
      // If theSalt is empty, that means we are not validating a password
      // but rather changing it. In this case, we generate an IV.
      NSString *cipher, *iv;

      cipher = nil;
      iv = nil;

      if ([theSalt length])
        {
          NSString *s;
          NSArray *a;

          s = [[NSString alloc] initWithData: theSalt  encoding: NSUTF8StringEncoding];
          [s autorelease];
          a = [s componentsSeparatedByString: @"$"];
          cipher = [a objectAtIndex: 1];
          iv = [a objectAtIndex: 2];
        }
      else
        {
          if ([passwordScheme caseInsensitiveCompare: @"sym-aes-128-cbc"] == NSOrderedSame)
            cipher = @"AES-128-CBC";
        }

      if ([cipher caseInsensitiveCompare: @"AES-128-CBC"] == NSOrderedSame)
        return [self asSymAES128CBCUsingIV: iv
                                   keyPath: theKeyPath];
    }
  // in case the scheme was not detected, return nil
  return nil;
}

/**
 * Verify the given password data is equivalent with the
 * clear text password using the passed encryption scheme
 *
 * @param passwordScheme The password scheme to use for comparison
 * @param thePassword cleartext key
 */
- (BOOL) verifyUsingScheme: (NSString *) passwordScheme
                withPassword: (NSData *) thePassword
                     keyPath: (NSString *) theKeyPath
{
  NSData *passwordCrypted;
  NSData *salt;

  salt = [self extractSalt: passwordScheme];
  if (salt == nil)
      return NO;

#ifdef HAVE_SODIUM
  // use verification function provided by libsodium
  if ([passwordScheme caseInsensitiveCompare: @"argon2i"] == NSOrderedSame
#ifdef crypto_pwhash_ALG_ARGON2ID13
   || [passwordScheme caseInsensitiveCompare: @"argon2id"] == NSOrderedSame
#endif /* crypto_pwhash_ALG_ARGON2ID13 */
   )
     {
        NSString *cryptString;
        int result;

        if (sodium_init() < 0)
          return NO;
        // For the sodium comparison we need to pass a null-terminated string
        // as the first parameter
        cryptString = [[NSString alloc] initWithData: self encoding: NSUTF8StringEncoding];
        const char* pass = [thePassword bytes];
        result = crypto_pwhash_str_verify([cryptString UTF8String], pass, [thePassword length]);
        [cryptString release];
        return result == 0;
     }
#endif /* HAVE_SODIUM */

  // encrypt self with the salt an compare the results
  passwordCrypted = [thePassword asCryptedPassUsingScheme: passwordScheme
                                      withSalt: salt
                                       keyPath: theKeyPath];

  // return always false when there was a problem
  if (passwordCrypted == nil)
    return NO;

  return [self isEqual: passwordCrypted];
}

- (NSData *) asLM
{
  NSData *out;

  unsigned char buf[14];
  unsigned char *o;
  unsigned int len;

  memset(buf, 0, 14);
  len = ([self length] >= 14 ? 14 : [self length]);
  [self getBytes: buf  length: len];

  o = malloc(16*sizeof(unsigned char));

  auth_LMhash(o, buf, len);

  out = [NSData dataWithBytes: o  length: 16];
  free(o);

  return out;
}

/**
 * Hash the data with MD4. Uses openssl functions to generate it.
 *
 * @return Binary data from MD4 hashing. On error the funciton returns nil.
 */
- (NSData *) asMD4
{
  unsigned char md4[MD4_DIGEST_LENGTH];
  memset(md4, 0, MD4_DIGEST_LENGTH);

#if defined(HAVE_GNUTLS)
  if (!check_gnutls_init())
    return nil;

  md4_buffer([self bytes], [self length], md4);
#elif defined(HAVE_OPENSSL)
  MD4([self bytes], [self length], md4);
#endif

  return [NSData dataWithBytes: md4  length: MD4_DIGEST_LENGTH];
}

/**
 * Hash the data with MD5. Uses openssl functions to generate it
 *
 * @return Binary data from MD5 hashing. On error the funciton returns nil.
 */
- (NSData *) asMD5
{
  unsigned char md5[MD5_DIGEST_LENGTH];
  memset(md5, 0, MD5_DIGEST_LENGTH);

#if defined(HAVE_GNUTLS)
  if (!check_gnutls_init())
    return nil;
  gnutls_hash_fast (GNUTLS_DIG_MD5, [self bytes], [self length], md5);
#elif defined(HAVE_OPENSSL)
  MD5([self bytes], [self length], md5);
#endif

  return [NSData dataWithBytes: md5  length: MD5_DIGEST_LENGTH];
}

/**
 * Hash the data with CRAM-MD5. Uses openssl functions to generate it.
 *
 * Note that the actual CRAM-MD5 algorithm also needs a challenge
 * but this is not provided, this function actually calculalates
 * only the context data which can be used for the challange-response
 * algorithm then. This is just the underlying algorithm to store the passwords.
 *
 * The code is adopts the dovecot behaviour of storing the passwords
 *
 * @return Binary data from CRAM-MD5 'hashing'. On error the funciton returns nil.
 */
- (NSData *) asCramMD5
{
#if defined(HAVE_GNUTLS)
  const uint32_t init_digest[4] = {0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476};
  uint32_t digest[4];
#elif defined(HAVE_OPENSSL)
  MD5_CTX ctx;
#endif
  unsigned char inner[64];
  unsigned char outer[64];
  unsigned char result[32];
  unsigned char *r;
  int i;
  int len;
  NSData *key;

  if ([self length] > 64)
    {
      key = [self asMD5];
    }
  else
    {
      key = self;
    }

  len = [key length];
  // fill with both inner and outer with key
  memcpy(inner, [key bytes], len);
  // make sure the rest of the bytes is zero
  memset(inner + len, 0, 64 - len);
  memcpy(outer, inner, 64);

  for (i = 0; i < 64; i++)
    {
      inner[i] ^= 0x36;
      outer[i] ^= 0x5c;
    }
// this transformation is needed for the correct cast to binary data
#define CDPUT(p, c) {   \
    *p = (c) & 0xff; p++;       \
    *p = (c) >> 8 & 0xff; p++;  \
    *p = (c) >> 16 & 0xff; p++; \
    *p = (c) >> 24 & 0xff; p++; \
}

#if defined(HAVE_GNUTLS)
  // generate first set of context bytes from outer data
  memcpy(digest, init_digest, sizeof(digest));
  _nettle_md5_compress(digest, outer);

  r = result;
  // convert this to correct binary data according to RFC 1321
  CDPUT(r, digest[0]);
  CDPUT(r, digest[1]);
  CDPUT(r, digest[2]);
  CDPUT(r, digest[3]);

  // second set with inner data is appended to result string
  memcpy(digest, init_digest, sizeof(digest));
  _nettle_md5_compress(digest, inner);
  // convert this to correct binary data
  CDPUT(r, digest[0]);
  CDPUT(r, digest[1]);
  CDPUT(r, digest[2]);
  CDPUT(r, digest[3]);
#elif defined(HAVE_OPENSSL)
  // generate first set of context bytes from outer data
  MD5_Init(&ctx);
  MD5_Transform(&ctx, outer);
  r = result;
  // convert this to correct binary data according to RFC 1321
  CDPUT(r, ctx.A);
  CDPUT(r, ctx.B);
  CDPUT(r, ctx.C);
  CDPUT(r, ctx.D);

  // second set with inner data is appended to result string
  MD5_Init(&ctx);
  MD5_Transform(&ctx, inner);
  // convert this to correct binary data
  CDPUT(r, ctx.A);
  CDPUT(r, ctx.B);
  CDPUT(r, ctx.C);
  CDPUT(r, ctx.D);
#endif

  return [NSData dataWithBytes: result length: 32];
}

/**
 * Hash the data with SHA1. Uses openssl functions to generate it.
 *
 * @return Binary data from SHA1 hashing. On error the funciton returns nil.
 */
- (NSData *) asSHA1
{
  unsigned char sha[SHA_DIGEST_LENGTH];
  memset(sha, 0, SHA_DIGEST_LENGTH);

#if defined(HAVE_GNUTLS)
  if (!check_gnutls_init())
    return nil;
  gnutls_hash_fast (GNUTLS_DIG_SHA1, [self bytes], [self length], sha);
#elif defined(HAVE_OPENSSL)
  SHA1([self bytes], [self length], sha);
#endif

  return [NSData dataWithBytes: sha  length: SHA_DIGEST_LENGTH];
}

/**
 * Hash the data with SHA256. Uses openssl functions to generate it.
 *
 * @return Binary data from SHA256 hashing. On error the funciton returns nil.
 */
- (NSData *) asSHA256
{
  unsigned char sha[SHA256_DIGEST_LENGTH];
  memset(sha, 0, SHA256_DIGEST_LENGTH);

#if defined(HAVE_GNUTLS)
  if (!check_gnutls_init())
    return nil;
  gnutls_hash_fast (GNUTLS_DIG_SHA256, [self bytes], [self length], sha);
#elif defined(HAVE_OPENSSL)
  SHA256([self bytes], [self length], sha);
#endif

  return [NSData dataWithBytes: sha  length: SHA256_DIGEST_LENGTH];
}

/**
 * Hash the data with SHA512. Uses openssl functions to generate it.
 *
 * @return Binary data from SHA512 hashing. On error the funciton returns nil.
 */
- (NSData *) asSHA512
{
  unsigned char sha[SHA512_DIGEST_LENGTH];
  memset(sha, 0, SHA512_DIGEST_LENGTH);

#if defined(HAVE_GNUTLS)
  if (!check_gnutls_init())
    return nil;
  gnutls_hash_fast (GNUTLS_DIG_SHA512, [self bytes], [self length], sha);
#elif defined(HAVE_OPENSSL)
  SHA512([self bytes], [self length], sha);
#endif

  return [NSData dataWithBytes: sha  length: SHA512_DIGEST_LENGTH];
}

- (NSData *) asSymAES128CBCUsingIV: (NSString *) theIV
                           keyPath: (NSString *) theKeyPath
{
  NSData *iv_d, *key_d, *cipherdata;
  NSMutableString *result;
  NSString *s;

  char ciphertext[256], *iv_s, *key_s, *pass;
  unsigned int len;

  len = ceil((double)[self length]/16) * 16;

  if (theIV)
    iv_d = [theIV dataByDecodingBase64];
  else
    {
      iv_d = [NSData generateSaltForLength: len];
      theIV = [iv_d stringByEncodingBase64];
    }

  iv_s = calloc([iv_d length]+1, sizeof(char));
  strncpy(iv_s, [iv_d bytes], [iv_d length]);

  key_d = [NSData dataWithContentsOfFile: theKeyPath];
  key_s = calloc([key_d length]+1, sizeof(char));
  strncpy(key_s, [key_d bytes], [key_d length]);

  pass = calloc(len, sizeof(char));
  strncpy(pass, [self bytes], [self length]);
  AES128_CBC_encrypt_buffer((uint8_t*)ciphertext, (uint8_t*)pass, (uint32_t)len, (const uint8_t*)key_s, (const uint8_t*)iv_s);

  cipherdata = [NSData dataWithBytes: ciphertext  length: 16];
  s = [[NSString alloc] initWithData: [cipherdata dataByEncodingBase64WithLineLength: 1024]
                            encoding: NSASCIIStringEncoding];

  result = [NSMutableString string];
  [result appendFormat: @"$AES-128-CBC$%@$%@", theIV, s];
  RELEASE(s);

  return [result dataUsingEncoding: NSUTF8StringEncoding];
}

/**
 * Hash the data with SSHA. Uses openssl functions to generate it.
 *
 * SSHA works following: SSHA(pass, salt) = SHA1(pass + salt) + saltData
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated
 * @return Binary data from SHA1 hashing. On error the funciton returns nil.
 */
- (NSData *) asSSHAUsingSalt: (NSData *) theSalt
{
  //
  NSMutableData *sshaData;

  // generate salt, if not available
  if ([theSalt length] == 0)
    theSalt = [NSData generateSaltForLength: 8];

  // put the pass and salt together as one data array
  sshaData = [NSMutableData dataWithData: self];
  [sshaData appendData: theSalt];
  // generate SHA1 from pass + salt
  sshaData = [NSMutableData dataWithData: [sshaData asSHA1]];
  // append salt again
  [sshaData appendData: theSalt];

  return sshaData;
}

/**
 * Hash the data with SSHA256. Uses openssl functions to generate it.
 *
 * SSHA256 works following: SSHA256(pass, salt) = SHA256(pass + salt) + saltData
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated
 * @return Binary data from SHA1 hashing. On error the funciton returns nil.
 */

- (NSData *) asSSHA256UsingSalt: (NSData *) theSalt
{
  NSMutableData *sshaData;

  // generate salt, if not available
  if ([theSalt length] == 0)
    theSalt = [NSData generateSaltForLength: 8];

  // put the pass and salt together as one data array
  sshaData = [NSMutableData dataWithData: self];
  [sshaData appendData: theSalt];
  // generate SHA1 from pass + salt
  sshaData = [NSMutableData dataWithData: [sshaData asSHA256]];
  // append salt again
  [sshaData appendData: theSalt];

  return sshaData;
}

/**
 * Hash the data with SSHA512. Uses openssl functions to generate it.
 *
 * SSHA works following: SSHA512(pass, salt) = SHA512(pass + salt) + saltData
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated
 * @return Binary data from SHA512 hashing. On error the funciton returns nil.
 */

- (NSData *) asSSHA512UsingSalt: (NSData *) theSalt
{
  NSMutableData *sshaData;

  // generate salt, if not available
  if ([theSalt length] == 0)
    theSalt = [NSData generateSaltForLength: 8];

  // put the pass and salt together as one data array
  sshaData = [NSMutableData dataWithData: self];
  [sshaData appendData: theSalt];
  // generate SHA1 from pass + salt
  sshaData = [NSMutableData dataWithData: [sshaData asSHA512]];
  // append salt again
  [sshaData appendData: theSalt];

  return sshaData;
}

/**
 * Hash the data with SMD5. Uses openssl functions to generate it.
 *
 * SMD5 works following: SMD5(pass, salt) = MD5(pass + salt) + saltData
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated
 * @return Binary data from SMD5 hashing. On error the funciton returns nil.
 */
- (NSData *) asSMD5UsingSalt: (NSData *) theSalt
{
  // SMD5 works following: SMD5(pass, salt) = MD5(pass + salt) + salt
  NSMutableData *smdData;

  // generate salt, if not available
  if ([theSalt length] == 0)
    theSalt = [NSData generateSaltForLength: 8];

  // put the pass and salt together as one data array
  smdData = [NSMutableData dataWithData: self];
  [smdData appendData: theSalt];
  // generate SHA1 from pass + salt
  smdData = [NSMutableData dataWithData: [smdData asMD5]];
  // append salt again
  [smdData appendData: theSalt];

  return smdData;
}

//
// Internal hashing function using glibc's crypt() one.
// Glibc 2.6 supports magic == 5 and 6
//
- (NSData *) _asCryptedUsingSalt: (NSData *) theSalt
			   magic: (NSString *) magic
{
  NSString *cryptString, *saltString;
  NSMutableData *saltData;
  char *buf;

  if ([theSalt length] == 0)
    {
      // make sure these characters are all printable
      theSalt = [NSData generateSaltForLength: 8  withPrintable: YES];
    }

  cryptString = [[NSString alloc] initWithData: self  encoding: NSUTF8StringEncoding];

  saltData = [NSMutableData dataWithData: [[NSString stringWithFormat:@"$%@$", magic] dataUsingEncoding: NSUTF8StringEncoding]];
  [saltData appendData: theSalt];

  // Terminate with "$"
  [saltData appendData: [@"$" dataUsingEncoding: NSUTF8StringEncoding]];

  saltString = [[NSString alloc] initWithData: saltData  encoding: NSUTF8StringEncoding];

  buf = crypt([cryptString UTF8String], [saltString UTF8String]);
  [cryptString release];
  [saltString release];

  if (!buf)
    return nil;

  return [NSData dataWithBytes: buf length: strlen(buf)];
}

/**
 * Hash the data with CRYPT-MD5 as used in /etc/passwd nowadays. Uses crypt() function to generate it.
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated. It must be printable characters only.
 * @return Binary data from CRYPT-MD5 hashing. On error the funciton returns nil.
 */
- (NSData *) asMD5CryptUsingSalt: (NSData *) theSalt
{
  return [self _asCryptedUsingSalt: theSalt  magic: @"1"];
}

/**
 * Hash the data with CRYPT-SHA256 as used in /etc/passwd nowadays. Uses crypt() function to generate it.
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated. It must be printable characters only.
 * @return Binary data from CRYPT-SHA256 hashing. On error the funciton returns nil.
 */
- (NSData *) asSHA256CryptUsingSalt: (NSData *) theSalt
{
  return [self _asCryptedUsingSalt: theSalt  magic: @"5"];
}

/**
 * Hash the data with CRYPT-SHA512 as used in /etc/passwd nowadays. Uses crypt() function to generate it.
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated. It must be printable characters only.
 * @return Binary data from CRYPT-SHA512 hashing. On error the funciton returns nil.
 */
- (NSData *) asSHA512CryptUsingSalt: (NSData *) theSalt
{
  return [self _asCryptedUsingSalt: theSalt  magic: @"6"];
}

/**
 * Hash the data using crypt() function.
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated
 * @return Binary data from CRYPT-MD5 hashing. On error the funciton returns nil.
 */
- (NSData *) asCryptUsingSalt: (NSData *) theSalt
{
  char *buf;
  NSString *saltString;
  NSString *cryptString;

  // crypt() works with strings, so convert NSData to strings
  cryptString = [[NSString alloc] initWithData: self  encoding: NSUTF8StringEncoding];

  if ([theSalt length] == 0)
    theSalt = [NSData generateSaltForLength: 8 withPrintable: YES];

  saltString = [[NSString alloc] initWithData: theSalt  encoding: NSUTF8StringEncoding];

  // The salt is weak here, but who cares anyway, crypt should not
  // be used anymore
  buf = crypt([cryptString UTF8String], [saltString UTF8String]);
  [saltString release];
  [cryptString release];
  if (!buf)
    return nil;
  return [NSData dataWithBytes: buf length: strlen(buf)];
}

/**
 * Hash the data using blowfish-crypt
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated
 */
- (NSData *) asBlowfishCryptUsingSalt: (NSData *) theSalt
{
  NSString *cleartext;
  char hashed_password[BLF_CRYPT_BUFFER_LEN];
  char magic_salt[BLF_CRYPT_PREFIX_LEN]; // contains $2.$nn$ + salt

  if ([theSalt length] == 0)
    {
      // generate a salt with default complexity if none was provided
      NSData* salt = [NSData generateSaltForLength: BLF_CRYPT_SALT_LEN];
      if (_crypt_gensalt_blowfish_rn(BLF_CRYPT_PREFIX, BLF_CRYPT_DEFAULT_COMPLEXITY,
        [salt bytes], BLF_CRYPT_SALT_LEN,
        magic_salt, BLF_CRYPT_PREFIX_LEN) == NULL)
          return nil;
    }
  else
    {
      const char* salt = [theSalt bytes];
      if ([theSalt length] < BLF_CRYPT_PREFIX_LEN ||
          salt[0] != '$' || salt[1] != '2' ||
          salt[2] < 'a' || salt[2] > 'z' ||
          salt[3] != '$')
        {
          return nil;
        }
      memcpy(magic_salt, salt, BLF_CRYPT_PREFIX_LEN);
    }

  cleartext = [[NSString alloc] initWithData: self encoding: NSUTF8StringEncoding];
  const char* password = [cleartext UTF8String];

  char* bf_res = _crypt_blowfish_rn(password, magic_salt,
    hashed_password, BLF_CRYPT_BUFFER_LEN);
  [cleartext autorelease];

  if (bf_res == NULL)
    return nil;

  return [NSData dataWithBytes: hashed_password length: strlen(hashed_password)];
}

- (NSData *) asPBKDF2SHA1UsingSalt: (NSData *) theSalt
{
  NSString *saltString;
  unsigned char hashed_password[PBKDF2_KEY_SIZE_SHA1] = {0};
  int rounds = 0;

  if ([theSalt length] == 0)
    {
      // generate a salt with default complexity if none was provided
      NSData* saltData = [NSData generateSaltForLength: PBKDF2_SALT_LEN withPrintable: YES];
      saltString = [[NSString alloc] initWithData: saltData encoding: NSUTF8StringEncoding];
      [saltString autorelease];
    }
  else
    {
      NSString *saltAndRounds;
      NSArray *saltAndRoundsComponents;
      saltAndRounds = [[NSString alloc] initWithData: theSalt encoding: NSUTF8StringEncoding];
      // salt is expected to be of the form salt$rounds
      saltAndRoundsComponents = [saltAndRounds componentsSeparatedByString: @"$"];
      AUTORELEASE(saltAndRounds);

      if ([saltAndRoundsComponents count] != 2)
        {
          return nil;
        }
      saltString = [saltAndRoundsComponents objectAtIndex: 0];

      rounds = [[saltAndRoundsComponents objectAtIndex: 1] intValue];
    }

  if (rounds == 0)
      rounds = PBKDF2_DEFAULT_ROUNDS;

  const char* password = [self bytes];
  const unsigned char* salt = (const unsigned char*)[saltString UTF8String];
#if defined(HAVE_GNUTLS)
  if (!check_gnutls_init())
    return nil;
#endif
  if (pkcs5_pbkdf2(password, [self length], salt, PBKDF2_SALT_LEN,
                   hashed_password, PBKDF2_KEY_SIZE_SHA1,
                   rounds) != 0)
    {
      return nil;
    }

  NSData *passwordData =
    [NSData dataWithBytesNoCopy: hashed_password  length: PBKDF2_KEY_SIZE_SHA1  freeWhenDone: NO];
  NSString *hexHash = [NSData encodeDataAsHexString: passwordData];

  NSString* result = [NSString stringWithFormat: @"$1$%@$%u$%@", saltString, rounds, hexHash];
  return [result dataUsingEncoding:NSUTF8StringEncoding];
}


#ifdef HAVE_SODIUM
- (NSData *) asArgon2iUsingSalt: (NSData *) theSalt
{
  char hashed_password[crypto_pwhash_argon2i_STRBYTES];
  int rounds = crypto_pwhash_argon2i_OPSLIMIT_INTERACTIVE;
  size_t memlimit = crypto_pwhash_argon2i_MEMLIMIT_INTERACTIVE;

  if (sodium_init() < 0)
    return nil;

  const char* password = [self bytes];
  if (crypto_pwhash_argon2i_str(hashed_password, password, [self length], rounds, memlimit) != 0)
    return nil;

  return [NSData dataWithBytes: hashed_password length: strlen(hashed_password)];
}

# ifdef crypto_pwhash_ALG_ARGON2ID13
- (NSData *) asArgon2idUsingSalt: (NSData *) theSalt;
{
  char hashed_password[crypto_pwhash_argon2id_STRBYTES];
  int rounds = crypto_pwhash_argon2id_OPSLIMIT_INTERACTIVE;
  size_t memlimit = crypto_pwhash_argon2id_MEMLIMIT_INTERACTIVE;

  if (sodium_init() < 0)
    return nil;

  const char* password = [self bytes];
  if (crypto_pwhash_argon2id_str(hashed_password, password, [self length], rounds, memlimit) != 0)
    return nil;

  return [NSData dataWithBytes: hashed_password length: strlen(hashed_password)];
}
#endif /* crypto_pwhash_ALG_ARGON2ID13 */
#endif /* HAVE_SODIUM */

/**
 * Get the salt from a password encrypted with a specied scheme
 *
 * @param theScheme Needed to get the salt correctly out of the pass
 * @return The salt, if one was available in the password/scheme, else empty data
 */
- (NSData *) extractSalt: (NSString *) theScheme
{
  NSRange r;
  int len;
  len = [self length];
  if (len == 0)
    return [NSData data];

  // for the ssha schemes the salt is appended at the endif
  // so the range with the salt are bytes after each digest length
  if ([theScheme caseInsensitiveCompare: @"crypt"] == NSOrderedSame ||
      [theScheme caseInsensitiveCompare: @"blf-crypt"] == NSOrderedSame)
    {
      // for (blf-)crypt schemes simply use the whole string
      // the crypt() function is able to extract it by itself
      r = NSMakeRange(0, len);
    }
  else if ([theScheme caseInsensitiveCompare: @"md5-crypt"] == NSOrderedSame ||
      [theScheme caseInsensitiveCompare: @"sha256-crypt"] == NSOrderedSame ||
      [theScheme caseInsensitiveCompare: @"sha512-crypt"] == NSOrderedSame ||
      [theScheme caseInsensitiveCompare: @"pbkdf2"] == NSOrderedSame)
    {
      // md5-crypt is generated the following "$1$<salt>$<encrypted pass>"
      // sha256-crypt is generated the following "$5$<salt>$<encrypted pass>"
      // sha512-crypt is generated the following "$6$<salt>$<encrypted pass>"
      // pbkdf2 is generated as "$1$<salt>$<rounds>$<encrypted pass>"
      NSString *cryptString;
      NSArray *cryptParts;

      cryptString = [[NSString alloc] initWithData: self  encoding: NSUTF8StringEncoding];
      AUTORELEASE(cryptString);

      cryptParts = [cryptString componentsSeparatedByString: @"$"];
      // correct number of elements (first one is an empty string)
      if ([cryptParts count] < 4)
        {
          return [NSData data];
        }
      // second is the identifier of md5-crypt/sha256-crypt or sha512-crypt
      else if ([[cryptParts objectAtIndex: 1] caseInsensitiveCompare: @"1"] == NSOrderedSame ||
          [[cryptParts objectAtIndex: 1] caseInsensitiveCompare: @"5"] == NSOrderedSame ||
          [[cryptParts objectAtIndex: 1] caseInsensitiveCompare: @"6"] == NSOrderedSame)
        {
          // third is the salt; convert it to NSData
          if ([cryptParts count] == 4)
            return [[cryptParts objectAtIndex: 2] dataUsingEncoding: NSUTF8StringEncoding];
          else
            {
              NSString *saltWithRounds;

              saltWithRounds = [NSString stringWithFormat: @"%@$%@", [cryptParts objectAtIndex: 2], [cryptParts objectAtIndex: 3]];

              return [saltWithRounds dataUsingEncoding: NSUTF8StringEncoding];
            }
        }
      // nothing good
      return [NSData data];
    }
  else if ([theScheme caseInsensitiveCompare: @"ssha"] == NSOrderedSame)
    {
      r = NSMakeRange(SHA_DIGEST_LENGTH, len - SHA_DIGEST_LENGTH);
    }
  else if ([theScheme caseInsensitiveCompare: @"ssha256"] == NSOrderedSame)
    {
      r = NSMakeRange(SHA256_DIGEST_LENGTH, len - SHA256_DIGEST_LENGTH);
    }
  else if ([theScheme caseInsensitiveCompare: @"ssha512"] == NSOrderedSame)
    {
      r = NSMakeRange(SHA512_DIGEST_LENGTH, len - SHA512_DIGEST_LENGTH);
    }
  else if ([theScheme caseInsensitiveCompare: @"smd5"] == NSOrderedSame)
    {
      r = NSMakeRange(MD5_DIGEST_LENGTH, len - MD5_DIGEST_LENGTH);
    }
  else if ([[theScheme lowercaseString] hasPrefix: @"sym"])
    {
      // For sym we return everything
      r = NSMakeRange(0, len);
    }
  else
    {
      // return empty string on unknown scheme
      return [NSData data];
    }

  return [self subdataWithRange: r];
}

@end

static unsigned charTo4Bits(char c)
{
  unsigned bits = 0;
  if (c > '/' && c < ':')
    {
      bits = c - '0';
    }
  else if (c > '@' && c < 'G')
    {
      bits = (c- 'A') + 10;
    }
  else if (c > '`' && c < 'g')
    {
      bits = (c- 'a') + 10;
    }
  else
    {
      bits = 255;
    }
  return bits;
}

#if defined(HAVE_GNUTLS)
static BOOL didGlobalInit = NO;

static BOOL check_gnutls_init(void) {
  if (!didGlobalInit) {
    /* Global system initialization*/
    if (gnutls_global_init()) {
      return NO;
    }

    didGlobalInit = YES;
  }

  return YES;
}

/* nettle, low-level cryptographics library
 *
 * Copyright (C) 2001, 2005 Niels Möller
 *
 * The nettle library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at your
 * option) any later version.
 *
 * The nettle library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with the nettle library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
 * MA 02111-1307, USA.
 */

/* Based on public domain code hacked by Colin Plumb, Andrew Kuchling, and
 * Niels Möller. */

#define LE_READ_UINT32(p)			\
(  (((uint32_t) (p)[3]) << 24)			\
 | (((uint32_t) (p)[2]) << 16)			\
 | (((uint32_t) (p)[1]) << 8)			\
 |  ((uint32_t) (p)[0]))

/* MD5 functions */
#define F1(x, y, z) ((z) ^ ((x) & ((y) ^ (z))))
#define F2(x, y, z) F1((z), (x), (y))
#define F3(x, y, z) ((x) ^ (y) ^ (z))
#define F4(x, y, z) ((y) ^ ((x) | ~(z)))

#define ROUND(f, w, x, y, z, data, s) \
( w += f(x, y, z) + data,  w = w<<s | w>>(32-s),  w += x )

static void
_nettle_md5_compress(uint32_t *digest, const uint8_t *input)
{
  uint32_t data[MD5_DIGEST_LENGTH];
  uint32_t a, b, c, d;
  unsigned i;

  for (i = 0; i < MD5_DIGEST_LENGTH; i++, input += 4)
    data[i] = LE_READ_UINT32(input);

  a = digest[0];
  b = digest[1];
  c = digest[2];
  d = digest[3];

  ROUND(F1, a, b, c, d, data[ 0] + 0xd76aa478, 7);
  ROUND(F1, d, a, b, c, data[ 1] + 0xe8c7b756, 12);
  ROUND(F1, c, d, a, b, data[ 2] + 0x242070db, 17);
  ROUND(F1, b, c, d, a, data[ 3] + 0xc1bdceee, 22);
  ROUND(F1, a, b, c, d, data[ 4] + 0xf57c0faf, 7);
  ROUND(F1, d, a, b, c, data[ 5] + 0x4787c62a, 12);
  ROUND(F1, c, d, a, b, data[ 6] + 0xa8304613, 17);
  ROUND(F1, b, c, d, a, data[ 7] + 0xfd469501, 22);
  ROUND(F1, a, b, c, d, data[ 8] + 0x698098d8, 7);
  ROUND(F1, d, a, b, c, data[ 9] + 0x8b44f7af, 12);
  ROUND(F1, c, d, a, b, data[10] + 0xffff5bb1, 17);
  ROUND(F1, b, c, d, a, data[11] + 0x895cd7be, 22);
  ROUND(F1, a, b, c, d, data[12] + 0x6b901122, 7);
  ROUND(F1, d, a, b, c, data[13] + 0xfd987193, 12);
  ROUND(F1, c, d, a, b, data[14] + 0xa679438e, 17);
  ROUND(F1, b, c, d, a, data[15] + 0x49b40821, 22);

  ROUND(F2, a, b, c, d, data[ 1] + 0xf61e2562, 5);
  ROUND(F2, d, a, b, c, data[ 6] + 0xc040b340, 9);
  ROUND(F2, c, d, a, b, data[11] + 0x265e5a51, 14);
  ROUND(F2, b, c, d, a, data[ 0] + 0xe9b6c7aa, 20);
  ROUND(F2, a, b, c, d, data[ 5] + 0xd62f105d, 5);
  ROUND(F2, d, a, b, c, data[10] + 0x02441453, 9);
  ROUND(F2, c, d, a, b, data[15] + 0xd8a1e681, 14);
  ROUND(F2, b, c, d, a, data[ 4] + 0xe7d3fbc8, 20);
  ROUND(F2, a, b, c, d, data[ 9] + 0x21e1cde6, 5);
  ROUND(F2, d, a, b, c, data[14] + 0xc33707d6, 9);
  ROUND(F2, c, d, a, b, data[ 3] + 0xf4d50d87, 14);
  ROUND(F2, b, c, d, a, data[ 8] + 0x455a14ed, 20);
  ROUND(F2, a, b, c, d, data[13] + 0xa9e3e905, 5);
  ROUND(F2, d, a, b, c, data[ 2] + 0xfcefa3f8, 9);
  ROUND(F2, c, d, a, b, data[ 7] + 0x676f02d9, 14);
  ROUND(F2, b, c, d, a, data[12] + 0x8d2a4c8a, 20);

  ROUND(F3, a, b, c, d, data[ 5] + 0xfffa3942, 4);
  ROUND(F3, d, a, b, c, data[ 8] + 0x8771f681, 11);
  ROUND(F3, c, d, a, b, data[11] + 0x6d9d6122, 16);
  ROUND(F3, b, c, d, a, data[14] + 0xfde5380c, 23);
  ROUND(F3, a, b, c, d, data[ 1] + 0xa4beea44, 4);
  ROUND(F3, d, a, b, c, data[ 4] + 0x4bdecfa9, 11);
  ROUND(F3, c, d, a, b, data[ 7] + 0xf6bb4b60, 16);
  ROUND(F3, b, c, d, a, data[10] + 0xbebfbc70, 23);
  ROUND(F3, a, b, c, d, data[13] + 0x289b7ec6, 4);
  ROUND(F3, d, a, b, c, data[ 0] + 0xeaa127fa, 11);
  ROUND(F3, c, d, a, b, data[ 3] + 0xd4ef3085, 16);
  ROUND(F3, b, c, d, a, data[ 6] + 0x04881d05, 23);
  ROUND(F3, a, b, c, d, data[ 9] + 0xd9d4d039, 4);
  ROUND(F3, d, a, b, c, data[12] + 0xe6db99e5, 11);
  ROUND(F3, c, d, a, b, data[15] + 0x1fa27cf8, 16);
  ROUND(F3, b, c, d, a, data[ 2] + 0xc4ac5665, 23);

  ROUND(F4, a, b, c, d, data[ 0] + 0xf4292244, 6);
  ROUND(F4, d, a, b, c, data[ 7] + 0x432aff97, 10);
  ROUND(F4, c, d, a, b, data[14] + 0xab9423a7, 15);
  ROUND(F4, b, c, d, a, data[ 5] + 0xfc93a039, 21);
  ROUND(F4, a, b, c, d, data[12] + 0x655b59c3, 6);
  ROUND(F4, d, a, b, c, data[ 3] + 0x8f0ccc92, 10);
  ROUND(F4, c, d, a, b, data[10] + 0xffeff47d, 15);
  ROUND(F4, b, c, d, a, data[ 1] + 0x85845dd1, 21);
  ROUND(F4, a, b, c, d, data[ 8] + 0x6fa87e4f, 6);
  ROUND(F4, d, a, b, c, data[15] + 0xfe2ce6e0, 10);
  ROUND(F4, c, d, a, b, data[ 6] + 0xa3014314, 15);
  ROUND(F4, b, c, d, a, data[13] + 0x4e0811a1, 21);
  ROUND(F4, a, b, c, d, data[ 4] + 0xf7537e82, 6);
  ROUND(F4, d, a, b, c, data[11] + 0xbd3af235, 10);
  ROUND(F4, c, d, a, b, data[ 2] + 0x2ad7d2bb, 15);
  ROUND(F4, b, c, d, a, data[ 9] + 0xeb86d391, 21);

  digest[0] += a;
  digest[1] += b;
  digest[2] += c;
  digest[3] += d;
}
#endif
