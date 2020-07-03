/* NSData+Crypto.h - this file is part of SOGo
 *
 * Copyright (C) 2012 Nicolas Höft
 * Copyright (C) 2012-2020 Inverse inc.
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

#ifndef NSDATA_CRYPTO_H
#define NSDATA_CRYPTO_H

#import <Foundation/NSData.h>

@class NSObject;

@interface NSData (SOGoCryptoExtension)

- (NSData *) asCryptedPassUsingScheme: (NSString *) passwordScheme
                             withSalt: (NSData *) theSalt
                              keyPath: (NSString *) theKeyPath;

- (BOOL) verifyUsingScheme: (NSString *) passwordScheme
                withPassword: (NSData *) thePassword
                     keyPath: (NSString *) theKeyPath;

- (NSData *) asLM;
- (NSData *) asMD4;
- (NSData *) asMD5;
- (NSData *) asSMD5UsingSalt: (NSData *) theSalt;
- (NSData *) asSHA1;
- (NSData *) asSSHAUsingSalt: (NSData *) theSalt;
- (NSData *) asSHA256;
- (NSData *) asSSHA256UsingSalt: (NSData *) theSalt;
- (NSData *) asSHA512;
- (NSData *) asSSHA512UsingSalt: (NSData *) theSalt;
- (NSData *) asSHA256CryptUsingSalt: (NSData *) theSalt;
- (NSData *) asSHA512CryptUsingSalt: (NSData *) theSalt;
- (NSData *) asSymAES128CBCUsingIV: (NSString *) theIV
                           keyPath: (NSString *) theKeyPath;
- (NSData *) asCramMD5;
- (NSData *) asPBKDF2SHA1UsingSalt: (NSData *) theSalt;
- (NSData *) asCryptUsingSalt: (NSData *) theSalt;
- (NSData *) asMD5CryptUsingSalt: (NSData *) theSalt;
- (NSData *) asBlowfishCryptUsingSalt: (NSData *) theSalt;
#ifdef HAVE_SODIUM
- (NSData *) asArgon2iUsingSalt: (NSData *) theSalt;
- (NSData *) asArgon2idUsingSalt: (NSData *) theSalt;
#endif /* HAVE_SODIUM */

- (NSData *) extractSalt: (NSString *) theScheme;

+ (NSData *) generateSaltForLength: (unsigned int) theLength
                        withPrintable: (BOOL) doPrintable;
+ (NSData *) generateSaltForLength: (unsigned int) theLength;

+ (NSString *) encodeDataAsHexString: (NSData *) theData;
+ (NSData *) decodeDataFromHexString: (NSString *) theString;

@end

#endif /* NSDATA_CRYPTO_H */
