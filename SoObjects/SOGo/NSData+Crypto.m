/* NSData+Crypto.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Nicolas Höft
 * Copyright (C) 2012 Inverse inc.
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

#ifndef __OpenBSD__
#include <crypt.h>
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#define _XOPEN_SOURCE 1
#include <unistd.h>

#if defined(HAVE_GNUTLS)
#include <stdint.h>
#include <gnutls/gnutls.h>
#include <gnutls/crypto.h>
#define MD5_DIGEST_LENGTH 16
#define SHA_DIGEST_LENGTH 20
#define SHA256_DIGEST_LENGTH 32
#define SHA512_DIGEST_LENGTH 64
#elif defined(HAVE_OPENSSL)
#include <openssl/evp.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
#else
#error this module requires either gnutls or openssl
#endif

#import <Foundation/NSArray.h>
#import <NGExtensions/NGBase64Coding.h>
#import "NSData+Crypto.h"

static unsigned charTo4Bits(char c);
#if defined(HAVE_GNUTLS)
static BOOL check_gnutls_init();
static void _nettle_md5_compress(uint32_t *digest, const uint8_t *input);
#endif


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
  return [NSData generateSaltForLength: theLength withBase64: NO];
}

/**
 * Generate a binary key which can be used for salting hashes. When using
 * with doBase64 == YES then the data will be longer than theLength
 *
 * @param theLength Length of the binary data to be generated in bytes
 * @param doBase64 Convert the data into Base-64 before retuning it, be aware that this makes the binary data longer
 * @return Pseudo-random binary data with length theLength or nil, if an error occured
 */
+ (NSData *) generateSaltForLength: (unsigned int) theLength
                withBase64: (BOOL) doBase64
{
  char *buf;
  int fd;
  NSData *data;

  fd = open("/dev/urandom", O_RDONLY);

  if (fd > 0)
    {
      buf = (char *)malloc(theLength);
      read(fd, buf, theLength);
      close(fd);

      data = [NSData dataWithBytesNoCopy: buf  length: theLength  freeWhenDone: YES];
      if(doBase64 == YES)
        {
          return [data dataByEncodingBase64WithLineLength: 1024];
        }
      return data;
    }
  return nil;
}

/**
 * Encrypt/Hash the data with a given scheme
 *
 * @param passwordScheme The scheme to use for hashing/encryption.
 * @param theSalt The salt to be used. If none is given but needed, it will be generated
 * @return Binary data from the encryption by the specified scheme. On error the funciton returns nil.
 */
- (NSData *) asCryptedPassUsingScheme: (NSString *) passwordScheme
                               withSalt: (NSData *) theSalt
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
  // in case the scheme was not detected, return nil
  return nil;
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
  if ([theSalt length] == 0) theSalt = [NSData generateSaltForLength: 8];

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
  if ([theSalt length] == 0) theSalt = [NSData generateSaltForLength: 8];

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
  if ([theSalt length] == 0) theSalt = [NSData generateSaltForLength: 8];

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
  if ([theSalt length] == 0) theSalt = [NSData generateSaltForLength: 8];

  // put the pass and salt together as one data array
  smdData = [NSMutableData dataWithData: self];
  [smdData appendData: theSalt];
  // generate SHA1 from pass + salt
  smdData = [NSMutableData dataWithData: [smdData asMD5]];
  // append salt again
  [smdData appendData: theSalt];

  return smdData;
}


/**
 * Hash the data with CRYPT-MD5 as used in /etc/passwd nowadays. Uses crypt() function to generate it.
 *
 *
 * @param theSalt The salt to be used must not be nil, if empty, one will be generated. It must be printable characters only.
 * @return Binary data from CRYPT-MD5 hashing. On error the funciton returns nil.
 */
- (NSData *) asMD5CryptUsingSalt: (NSData *) theSalt
{
  char *buf;
  NSMutableData *saltData;
  NSString *cryptString;
  NSString *saltString;

  if ([theSalt length] == 0)
    {
      // make sure these characters are all printable by using base64
      theSalt = [NSData generateSaltForLength: 8  withBase64: YES];
    }
  cryptString = [[NSString alloc] initWithData: self  encoding: NSUTF8StringEncoding];

  NSString * magic = @"$1$";
  saltData = [NSMutableData dataWithData: [magic dataUsingEncoding: NSUTF8StringEncoding]];
  [saltData appendData: theSalt];
  // terminate with "$"
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

  if ([theSalt length] == 0) theSalt = [NSData generateSaltForLength: 8 withBase64: YES];

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
  if ([theScheme caseInsensitiveCompare: @"crypt"] == NSOrderedSame)
    {
      // for crypt schemes simply use the whole string
      // the crypt() function is able to extract it by itself
      r = NSMakeRange(0, len);
    }
  else if ([theScheme caseInsensitiveCompare: @"md5-crypt"] == NSOrderedSame)
    {
      // md5 crypt is generated the following "$1$<salt>$<encrypted pass>"
      NSString *cryptString;
      NSArray *cryptParts;
      cryptString = [NSString stringWithUTF8String: [self bytes] ];
      cryptParts = [cryptString componentsSeparatedByString: @"$"];
      // correct number of elements (first one is an empty string)
      if ([cryptParts count] != 4)
        {
          return [NSData data];
        }
      // second is the identifier of md5-crypt
      else if( [[cryptParts objectAtIndex: 1] caseInsensitiveCompare: @"1"] != NSOrderedSame )
        {
          return [NSData data];
        }
       // third is the salt; convert it to NSData
       return [[cryptParts objectAtIndex: 2] dataUsingEncoding: NSUTF8StringEncoding];
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

static BOOL check_gnutls_init() {
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
