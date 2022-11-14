/* NSString+Utilities.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2022 Inverse inc.
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

#ifndef NSSTRING_URL_H
#define NSSTRING_URL_H

#import <Foundation/NSString.h>

@class NSCharacterSet;
@class NSDictionary;
@class NSObject;

@interface NSString (SOGoURLExtension)

/* URL handling */
- (NSString *) composeURLWithAction: (NSString *) action
			 parameters: (NSDictionary *) urlParameters
			    andHash: (BOOL) useHash;
- (NSString *) hostlessURL;

- (NSString *) urlWithoutParameters;

- (NSString *) stringByDetectingURLs;

/* escaping */
- (NSString *) doubleQuotedString;

/* CSS and URL safety */
- (NSString *) asCSSIdentifier;
- (NSString *) fromCSSIdentifier;

/* JavaScript safety */
- (NSString *) asSafeJSString;

/* SQL safety */
- (NSString *) asSafeSQLString;
- (NSString *) asSafeSQLLikeString;

/* Unicode safety */
- (NSString *) safeString;
- (NSString *) safeStringByEscapingXMLString;
- (NSString *) safeStringByEscapingXMLString: (BOOL) encodeCR;

/* JSON */
- (NSString *) jsonRepresentation;
- (BOOL) isJSONString;
- (id) objectFromJSONString;

/* bare email addresses */
- (NSString *) pureEMailAddress;

- (NSString *) asQPSubjectString: (NSString *) encoding;

/* LDAP */
- (BOOL) caseInsensitiveMatches: (NSString *) match;

/* OpenSSL multiline DN */
- (NSArray *) componentsFromMultilineDN;

- (NSString *) stringWithoutHTMLInjection: (BOOL)stripHTMLCode;

#ifndef GNUSTEP_BASE_LIBRARY
- (BOOL) boolValue;
#endif

- (int) timeValue;

/* substrings */
- (NSUInteger) countOccurrencesOfString: (NSString *) substring;
- (NSString *) stringByReplacingPrefix: (NSString *) oldPrefix
                            withPrefix: (NSString *) newPrefix;

/* Those methods provide symmetric enc-/decryption via a XOR operation */
- (NSString *) encryptWithKey: (NSString *) theKey;
- (NSString *) decryptWithKey: (NSString *) theKey;

@end

#endif /* NSSTRING_URL_H */
