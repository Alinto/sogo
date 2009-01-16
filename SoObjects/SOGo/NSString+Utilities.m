/* NSString+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2008 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSEnumerator.h>

#import <EOControl/EOQualifier.h>

#import <NGExtensions/NGQuotedPrintableCoding.h>

#import "NSArray+Utilities.h"
#import "NSDictionary+URL.h"

#import "NSString+Utilities.h"

static NSMutableCharacterSet *urlNonEndingChars = nil;
static NSMutableCharacterSet *urlAfterEndingChars = nil;
static NSMutableCharacterSet *urlStartChars = nil;

@implementation NSString (SOGoURLExtension)

- (NSString *) composeURLWithAction: (NSString *) action
			 parameters: (NSDictionary *) urlParameters
			    andHash: (BOOL) useHash
{
  NSMutableString *completeURL;

  completeURL = [NSMutableString new];
  [completeURL autorelease];

  [completeURL appendString: [self urlWithoutParameters]];
  if (![completeURL hasSuffix: @"/"])
    [completeURL appendString: @"/"];
  [completeURL appendString: action];
  [completeURL appendString: [urlParameters asURLParameters]];
  if (useHash)
    [completeURL appendString: @"#"];

  return completeURL;
}

- (NSString *) hostlessURL
{
  NSString *newURL;
  NSRange hostR, locationR;

  if ([self hasPrefix: @"/"])
    {
      newURL = [self copy];
      [newURL autorelease];
    }
  else
    {
      hostR = [self rangeOfString: @"://"];
      locationR = [[self substringFromIndex: (hostR.location + hostR.length)]
                    rangeOfString: @"/"];
      newURL = [self substringFromIndex: (hostR.location + hostR.length
					  + locationR.location)];
    }

  return newURL;
}

- (NSString *) urlWithoutParameters;
{
  NSRange r;
  NSString *newUrl;
  
  r = [self rangeOfString:@"?" options: NSBackwardsSearch];
  if (r.length > 0)
    newUrl = [self substringToIndex: NSMaxRange(r) - 1];
  else
    newUrl = self;

  return newUrl;
}

- (NSString *) davMethodToObjC
{
  NSMutableString *newName;
  NSEnumerator *components;
  NSString *component;

  newName = [NSMutableString stringWithString: @"dav"];
  components = [[self componentsSeparatedByString: @"-"] objectEnumerator];
  while ((component = [components nextObject]))
    [newName appendString: [component capitalizedString]];

  return newName;
}

- (NSString *) davSetterName
{
  unichar firstLetter;
  NSString *firstString;

  firstLetter = [self characterAtIndex: 0];
  firstString = [[NSString stringWithCharacters: &firstLetter length: 1]
		  uppercaseString];
  return [NSString stringWithFormat: @"set%@%@:",
		   firstString, [self substringFromIndex: 1]];
}

- (NSDictionary *) asDavInvocation
{
  NSMutableDictionary *davInvocation;
  NSRange nsEnclosing, methodEnclosing;
  unsigned int length;

  davInvocation = nil;
  if ([self hasPrefix: @"{"])
    {
      nsEnclosing = [self rangeOfString: @"}"];
      length = [self length];
      if (nsEnclosing.length > 0
	  && nsEnclosing.location < (length - 1))
	{
	  methodEnclosing = NSMakeRange(nsEnclosing.location + 1,
					length - nsEnclosing.location - 1);
	  nsEnclosing.length = nsEnclosing.location - 1;
	  nsEnclosing.location = 1;
	  davInvocation = [NSMutableDictionary dictionaryWithCapacity: 2];
	  [davInvocation setObject: [self substringWithRange: nsEnclosing]
			 forKey: @"ns"];
	  [davInvocation setObject: [self substringWithRange: methodEnclosing]
			 forKey: @"method"];
	}
    }

  return davInvocation;
}

- (NSRange) _rangeOfURLInRange: (NSRange) refRange
{
  int start, length;
  NSRange workRange;

//       [urlNonEndingChars addCharactersInString: @">&=,.:;\t \r\n"];
//       [urlAfterEndingChars addCharactersInString: @"()[]{}&;<\t \r\n"];

  if (!urlNonEndingChars)
    {
      urlNonEndingChars = [NSMutableCharacterSet new];
      [urlNonEndingChars addCharactersInString: @"=,.:;&()\t \r\n"];
    }
  if (!urlAfterEndingChars)
    {
      urlAfterEndingChars = [NSMutableCharacterSet new];
      [urlAfterEndingChars addCharactersInString: @"()[]\t \r\n"];
    }

  start = refRange.location;
  while (start > -1
	 && ![urlAfterEndingChars characterIsMember:
				    [self characterAtIndex: start]])
    start--;
  start++;
  length = [self length] - start;
  workRange = NSMakeRange(start, length);
  workRange = [self rangeOfCharacterFromSet: urlAfterEndingChars
		    options: NSLiteralSearch range: workRange];
  if (workRange.location != NSNotFound)
    length = workRange.location - start;
  while
    (length > 0
     && [urlNonEndingChars characterIsMember:
			     [self characterAtIndex: (start + length - 1)]])
    length--;

  return NSMakeRange (start, length);
}

- (void) _handleURLs: (NSMutableString *) selfCopy
	 textToMatch: (NSString *) match
	      prefix: (NSString *) prefix
	    inRanges: (NSMutableArray *) ranges
{
  NSEnumerator *enumRanges;
  NSMutableArray *newRanges;
  NSRange matchRange, currentUrlRange, rest;
  NSString *urlText, *newUrlText, *range;
  unsigned int length, matchLength, offset;
  int startLocation;

  if (!urlStartChars)
    {
      urlStartChars = [NSMutableCharacterSet new];
      [urlStartChars addCharactersInString: @"abcdefghijklmnopqrstuvwxyz"
		     @"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		     @"0123456789:@"];
    }
  newRanges = [NSMutableArray new];
  matchLength = [match length];
  rest.location = -1;
 
  matchRange = [selfCopy rangeOfString: match];
  while (matchRange.location != NSNotFound)
    {
      startLocation = matchRange.location;
      while (startLocation > rest.location
	     && [urlStartChars characterIsMember:
				 [selfCopy characterAtIndex: startLocation]])
	startLocation--;
      matchRange.location = startLocation + 1;

      currentUrlRange = [selfCopy _rangeOfURLInRange: matchRange];
      if ([ranges hasRangeIntersection: currentUrlRange])
	rest.location = NSMaxRange(currentUrlRange);
      else
	{
	  if (currentUrlRange.length > matchLength)
	    [newRanges addRange: currentUrlRange];
	  rest.location = NSMaxRange(currentUrlRange);
	}

      length = [selfCopy length];
      rest.length = length - rest.location;
      matchRange = [selfCopy rangeOfString: match
			     options: 0 range: rest];
    }

  // Make the substitutions, keep track of the new offset
  offset = 0;
  enumRanges = [newRanges objectEnumerator];
  range = [enumRanges nextObject];
  while (range)
    {
      currentUrlRange = NSRangeFromString(range);
      currentUrlRange.location += offset;
      urlText = [selfCopy substringFromRange: currentUrlRange];
      if ([urlText hasPrefix: prefix]) prefix = @"";
      newUrlText = [NSString stringWithFormat: @"<a href=\"%@%@\">%@</a>",
			     prefix, urlText, urlText];
      [selfCopy replaceCharactersInRange: currentUrlRange
		withString: newUrlText];
      offset += ([newUrlText length] - [urlText length]);

      // Add range for further substitutions
      currentUrlRange = NSMakeRange (currentUrlRange.location, [newUrlText length]);
      [ranges addRange: currentUrlRange];

      range = [enumRanges nextObject];
    }
}

- (NSString *) stringByDetectingURLs
{
  NSMutableString *selfCopy;
  NSMutableArray *ranges;

  ranges = [NSMutableArray new];
  selfCopy = [NSMutableString stringWithString: self];
  [self _handleURLs: selfCopy
	textToMatch: @"://"
	prefix: @""
	inRanges: ranges];
  [self _handleURLs: selfCopy
	textToMatch: @"@"
	prefix: @"mailto:"
	inRanges: ranges];
  [ranges release];

  return selfCopy;
}

- (NSString *) doubleQuotedString
{
  NSMutableString *representation;

  representation = [NSMutableString stringWithString: self];
  [representation replaceString: @"\\" withString: @"\\\\"];
  [representation replaceString: @"\"" withString: @"\\\""];
  [representation replaceString: @"/" withString: @"\\/"];
  [representation replaceString: @"\b" withString: @"\\b"];
  [representation replaceString: @"\f" withString: @"\\f"];
  [representation replaceString: @"\n" withString: @"\\n"];
  [representation replaceString: @"\r" withString: @"\\r"];
  [representation replaceString: @"\t" withString: @"\\t"];

  return [NSString stringWithFormat: @"\"%@\"", representation];
}

- (NSString *) jsonRepresentation
{
  return [self doubleQuotedString];
}

- (NSString *) asCSSIdentifier
{
  NSMutableString *cssIdentifier;

  cssIdentifier = [NSMutableString stringWithString: self];
  [cssIdentifier replaceString: @"." withString: @"_D_"];
  [cssIdentifier replaceString: @"#" withString: @"_H_"];
  [cssIdentifier replaceString: @"@" withString: @"_A_"];
  [cssIdentifier replaceString: @"*" withString: @"_S_"];
  [cssIdentifier replaceString: @":" withString: @"_C_"];
  [cssIdentifier replaceString: @"," withString: @"_CO_"];
  [cssIdentifier replaceString: @" " withString: @"_SP_"];

  return cssIdentifier;
}

- (NSString *) pureEMailAddress
{
  NSString *pureAddress;
  NSRange delimiter;

  delimiter = [self rangeOfString: @"<"];
  if (delimiter.location == NSNotFound)
    pureAddress = self;
  else
    {
      pureAddress = [self substringFromIndex: NSMaxRange (delimiter)];
      delimiter = [pureAddress rangeOfString: @">"];
      if (delimiter.location != NSNotFound)
	pureAddress = [pureAddress substringToIndex: delimiter.location];
    }

  return pureAddress;
}

- (NSString *) asQPSubjectString: (NSString *) encoding
{
  NSString *qpString, *subjectString;
  NSData *subjectData, *destSubjectData;

  subjectData = [self dataUsingEncoding: NSUTF8StringEncoding];
  destSubjectData = [subjectData dataByEncodingQuotedPrintable];

  qpString = [[NSString alloc] initWithData: destSubjectData
			       encoding: NSASCIIStringEncoding];
  [qpString autorelease];
  if ([qpString length] > [self length])
    {
      qpString = [qpString stringByReplacingString: @" " withString: @"_"];
      subjectString = [NSString stringWithFormat: @"=?%@?Q?%@?=",
				encoding, qpString];
    }
  else
    subjectString = self;

  return subjectString;
}

- (BOOL) caseInsensitiveMatches: (NSString *) match
{
  EOQualifier *sq;
  NSString *format;

  format = [NSString stringWithFormat:
		       @"(description isCaseInsensitiveLike: '%@')",
		     match];
  sq = [EOQualifier qualifierWithQualifierFormat: format];

  return [sq evaluateWithObject: self];
}

#if LIB_FOUNDATION_LIBRARY
- (BOOL) boolValue
{
  return !([self isEqualToString: @"0"]
	   || [self isEqualToString: @"NO"]);
}
#endif

@end
