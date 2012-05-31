/* NSString+Crypto.h - this file is part of SOGo
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

#ifndef NSSTRING_CRYPTO_H
#define NSSTRING_CRYPTO_H

#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

typedef enum {
  encDefault, //!< default encoding, let the algorithm decide
  encPlain,   //!< the data is plain text, simply convert to string
  encHex,     //!< the data is hex encoded
  encBase64,  //!< base64 encoding
} keyEncoding;

@class NSObject;

@interface NSString (SOGoCryptoExtension)


- (BOOL) isEqualToCrypted: (NSString *) cryptedPassword
         withDefaultScheme: (NSString *) theScheme;

- (NSString *) asCryptedPassUsingScheme: (NSString *) passwordScheme
                               withSalt: (NSData *) theSalt
                               andEncoding: (keyEncoding) encoding;

// this method uses the default encoding (base64, plain, hex)
// and generates a salt when necessary
- (NSString *) asCryptedPassUsingScheme: (NSString *) passwordScheme;

- (NSArray *) splitPasswordWithDefaultScheme: (NSString *) defaultScheme;

- (NSString *) asSHA1String;
- (NSString *) asMD5String;

+ (keyEncoding) getDefaultEncodingForScheme: (NSString *) passwordScheme;

@end

#endif /* NSSTRING_CRYPTO_H */
