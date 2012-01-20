/* NSString+Utilities.h - this file is part of SOGo
 *
 * Copyright (C) 2006-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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

@class NSDictionary;
@class NSObject;

@interface NSString (SOGoURLExtension)

- (NSString *) composeURLWithAction: (NSString *) action
			 parameters: (NSDictionary *) urlParameters
			    andHash: (BOOL) useHash;
- (NSString *) hostlessURL;

- (NSString *) urlWithoutParameters;

- (NSString *) stringByDetectingURLs;

- (NSString *) doubleQuotedString;

- (NSString *) jsonRepresentation;

- (NSString *) asCSSIdentifier;
- (NSString *) fromCSSIdentifier;

/* bare email addresses */
- (NSString *) pureEMailAddress;

- (NSString *) asQPSubjectString: (NSString *) encoding;

- (NSRange) _rangeOfURLInRange: (NSRange) refRange;

- (BOOL) caseInsensitiveMatches: (NSString *) match;

#ifndef GNUSTEP_BASE_LIBRARY
- (BOOL) boolValue;
#endif

- (int) timeValue;

- (BOOL) isJSONString;

- (id) objectFromJSONString;

- (NSString *) asCryptStringUsingSalt: (NSString *) theSalt;
- (NSString *) asMD5String;
- (NSString *) asSHA1String;

- (NSString *) asSafeSQLString;

- (NSUInteger) countOccurrencesOfString: (NSString *) substring;

@end

#endif /* NSSTRING_URL_H */
