/* NSString+Utilities.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSValue.h>

#import <EOControl/EOQualifier.h>

#import <NGExtensions/NSDictionary+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NGBase64Coding.h>

#import <NGMime/NGMimeHeaderFieldGenerator.h>
#import <SBJson/SBJsonParser.h>

#import "NSArray+Utilities.h"
#import "NSDictionary+URL.h"

#import "NSString+Utilities.h"

static NSMutableCharacterSet *urlNonEndingChars = nil;
static NSMutableCharacterSet *urlAfterEndingChars = nil;
static NSMutableCharacterSet *urlStartChars = nil;

static NSString **cssEscapingStrings = NULL;
static unichar *cssEscapingCharacters = NULL;
static int cssEscapingCount;

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
  if (urlParameters)
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
    newUrl = [self substringToIndex: NSMaxRange (r) - 1];
  else
    newUrl = self;

  return newUrl;
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

  // In [UIxMailPartTextViewer flatContentAsString], we first escape HTML entities and then
  // add URLs. Therefore, the brackets (inequality signs <>) have been encoded at this point.
  if ([[self substringWithRange: NSMakeRange (start, 4)] compare: @"&lt;"] == NSOrderedSame)
    start += 4;

  length = [self length] - start;
  workRange = NSMakeRange (start, length);
  workRange = [self rangeOfCharacterFromSet: urlAfterEndingChars
		    options: NSLiteralSearch range: workRange];
  if (workRange.location != NSNotFound)
    length = workRange.location - start;
  while
    (length > 0
     && [urlNonEndingChars characterIsMember:
			     [self characterAtIndex: (start + length - 1)]])
    length--;

  // Remove trailing ">"
  if (([self length] >= start + length + 1)
      && [[self substringWithRange: NSMakeRange (start, length + 1)] hasSuffix: @"&gt;"])
    length -= 3;

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
  NSRange *rangePtr;
  NSString *urlText, *newUrlText;
  unsigned int length, matchLength, offset;
  int startLocation;

  if (!urlStartChars)
    {
      urlStartChars = [NSMutableCharacterSet new];
      [urlStartChars addCharactersInString: @"abcdefghijklmnopqrstuvwxyz"
		     @"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		     @"0123456789:@"];
    }

  newRanges = [NSMutableArray array];
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
      if (![ranges hasRangeIntersection: currentUrlRange])
	if (currentUrlRange.length > matchLength)
	  [newRanges addNonNSObject: &currentUrlRange
			   withSize: sizeof (NSRange)
			       copy: YES];
      
      rest.location = NSMaxRange (currentUrlRange);
      length = [selfCopy length];
      rest.length = length - rest.location;
      matchRange = [selfCopy rangeOfString: match
			     options: 0 range: rest];
    }

  // Make the substitutions, keep track of the new offset
  offset = 0;
  enumRanges = [newRanges objectEnumerator];
  while ((rangePtr = [[enumRanges nextObject] pointerValue]))
    {
      rangePtr->location += offset;
      urlText = [selfCopy substringFromRange: *rangePtr];
      newUrlText = [NSString stringWithFormat: @"<a href=\"%@%@\">%@</a>",
                          ([urlText hasPrefix: prefix]? @"" : prefix),
                             urlText, urlText];
      [selfCopy replaceCharactersInRange: *rangePtr
                              withString: newUrlText];
      offset += ([newUrlText length] - [urlText length]);
      
      // Add range for further substitutions
      currentUrlRange = NSMakeRange (rangePtr->location, [newUrlText length]);
      [ranges addNonNSObject: &currentUrlRange
                    withSize: sizeof (NSRange)
                        copy: YES];
    }
  [newRanges freeNonNSObjects];
}

- (NSString *) stringByDetectingURLs
{
  NSMutableString *selfCopy;
  NSMutableArray *ranges;

  ranges = [NSMutableArray array];
  selfCopy = [NSMutableString stringWithString: self];
  [self _handleURLs: selfCopy
	textToMatch: @"://"
             prefix: @""
           inRanges: ranges];
  [self _handleURLs: selfCopy
	textToMatch: @"@"
             prefix: @"mailto:"
           inRanges: ranges];
  [ranges freeNonNSObjects];

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

- (void) _setupCSSEscaping
{
  NSArray *strings, *characters;
  int count;

  strings = [NSArray arrayWithObjects: @"_U_", @"_D_", @"_H_", @"_A_", @"_S_",
                     @"_C_", @"_CO_", @"_SP_", @"_SQ_", @"_AM_", @"_P_", nil];
  [strings retain];
  cssEscapingStrings = [strings asPointersOfObjects];

  characters = [NSArray arrayWithObjects: @"_", @".", @"#", @"@", @"*", @":",
                        @",", @" ", @"'", @"&", @"+", nil];
  cssEscapingCount = [strings count];
  cssEscapingCharacters = NSZoneMalloc (NULL,
                                        (cssEscapingCount + 1)
                                        * sizeof (unichar));
  for (count = 0; count < cssEscapingCount; count++)
    *(cssEscapingCharacters + count)
      = [[characters objectAtIndex: count] characterAtIndex: 0];
  *(cssEscapingCharacters + cssEscapingCount) = 0;
}

- (int) _cssCharacterIndex: (unichar) character
{
  int idx, count;

  idx = -1;
  for (count = 0; idx == -1 && count < cssEscapingCount; count++)
    if (*(cssEscapingCharacters + count) == character)
      idx = count;

  return idx;
}

- (NSString *) asCSSIdentifier
{
  NSMutableString *cssIdentifier;
  unichar currentChar;
  int count, max, idx;

  if (!cssEscapingStrings)
    [self _setupCSSEscaping];

  cssIdentifier = [NSMutableString string];
  max = [self length];
  for (count = 0; count < max; count++)
    {
      currentChar = [self characterAtIndex: count];
      idx = [self _cssCharacterIndex: currentChar];
      if (idx > -1)
        [cssIdentifier appendString: cssEscapingStrings[idx]];
      else
        [cssIdentifier appendFormat: @"%C", currentChar];
    }

  return cssIdentifier;
}

- (int) _cssStringIndex: (NSString *) string
{
  int idx, count;

  idx = -1;
  for (count = 0; idx == -1 && count < cssEscapingCount; count++)
    if ([string hasPrefix: *(cssEscapingStrings + count)])
      idx = count;

  return idx;
}

- (NSString *) fromCSSIdentifier
{
  NSMutableString *newString;
  NSString *currentString;
  int count, length, max, idx;
  unichar currentChar;

  if (!cssEscapingStrings)
    [self _setupCSSEscaping];

  newString = [NSMutableString string];
  max = [self length];
  for (count = 0; count < max - 2; count++)
    {
      currentChar = [self characterAtIndex: count];
      if (currentChar == '_')
        {
          /* The difficulty here is that most escaping strings are 3 chars
             long except one. Therefore we must juggle a little bit with the
             lengths in order to avoid an overflow exception. */
          length = 4;
          if (count + length > max)
            length = max - count;
          currentString = [self substringFromRange: NSMakeRange (count, length)];
          idx = [self _cssStringIndex: currentString];
          if (idx > -1)
            {
              [newString appendFormat: @"%C", cssEscapingCharacters[idx]];
              count += [cssEscapingStrings[idx] length] - 1;
            }
          else
            [newString appendFormat: @"%C", currentChar];
        }
      else
        [newString appendFormat: @"%C", currentChar];
    }
  currentString = [self substringFromRange: NSMakeRange (count, max - count)];
  [newString appendString: currentString];

  return newString;
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
  NSUInteger length, destLength;
  unsigned char *destString;

#warning "encoding" parameter is not useful
  subjectData = [self dataUsingEncoding: NSUTF8StringEncoding];
  length = [subjectData length];
  destLength = length * 3;
  destString = calloc (destLength, sizeof (char));

  NGEncodeQuotedPrintableMime ([subjectData bytes], length,
                               destString, destLength);

  destSubjectData = [NSData dataWithBytesNoCopy: destString
                                         length: strlen ((char *) destString)
                                   freeWhenDone: YES];
  qpString = [[NSString alloc] initWithData: destSubjectData
			       encoding: NSASCIIStringEncoding];
  [qpString autorelease];
  if ([qpString length] > [self length])
    {
      qpString = [qpString stringByReplacingString: @" " withString: @"_"];
      subjectString = [NSString stringWithFormat: @"=?%@?q?%@?=",
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

  return [(id<EOQualifierEvaluation>)sq evaluateWithObject: self];
}

#if LIB_FOUNDATION_LIBRARY
- (BOOL) boolValue
{
  return !([self isEqualToString: @"0"]
	   || [self isEqualToString: @"NO"]);
}
#endif

- (int) timeValue
{
  int 		time;
  NSInteger 	i;

  if ([self length] > 0)
    {
      i = [self rangeOfString: @":"].location;
      if (i == NSNotFound)
	time = [self intValue];
      else
	time = [[self substringToIndex: i] intValue];
    }
  else
    time = -1;
  
  return time;
}

- (BOOL) isJSONString
{
  NSDictionary *jsonData;

#warning this method is a quick and dirty way of detecting the file-format
  jsonData = [self objectFromJSONString];

  return (jsonData != nil);
}

- (id) objectFromJSONString
{
  SBJsonParser *parser;
  NSObject *object;
  NSError *error;
  NSString *unescaped;

  object = nil;

  if ([self length] > 0)
    {
      parser = [SBJsonParser new];
      [parser autorelease];
      error = nil;
      object = [parser objectWithString: self
                                  error: &error];
      if (error)
        {
          [self errorWithFormat: @"json parser: %@,"
                @" attempting once more after unescaping...", error];
          unescaped = [self stringByReplacingString: @"\\\\"
                                         withString: @"\\"];
          object = [parser objectWithString: unescaped
                                      error: &error];
          if (error)
            {
              [self errorWithFormat: @"total failure. Original string is: %@", self];
              object = nil;
            }
          else
            [self logWithFormat: @"initial object deserialized successfully!"];
        }
    }

  return object;
}

- (NSString *) asSafeSQLString
{
  return [[self stringByReplacingString: @"\\" withString: @"\\\\"]
           stringByReplacingString: @"'" withString: @"\\'"];
}

- (NSUInteger) countOccurrencesOfString: (NSString *) substring
{
  NSRange matchRange, substrRange;
  BOOL done = NO;
  NSUInteger selfLen, substrLen, count = 0;

  selfLen = [self length];
  substrLen = [substring length];

  matchRange = NSMakeRange (0, selfLen);
  while (!done)
    {
      substrRange = [self rangeOfString: substring options: 0 range: matchRange];
      if (substrRange.location == NSNotFound)
        done = YES;
      else
        {
          count++;
          matchRange.location = substrRange.location + 1;
          if (matchRange.location + substrLen > selfLen)
            done = YES;
          else
            matchRange.length = selfLen - matchRange.location;
        }
    }

  return count;
}

- (NSString *) stringByReplacingPrefix: (NSString *) oldPrefix
                            withPrefix: (NSString *) newPrefix
{
  NSUInteger oldPrefixLength;
  NSString *newString;

  if (![self hasPrefix: oldPrefix])
    [NSException raise: NSInvalidArgumentException
                 format: @"string does not have the specified prefix"];

  oldPrefixLength = [oldPrefix length];
  newString = [NSString stringWithFormat: @"%@%@",
                        newPrefix,
                        [self substringFromIndex: oldPrefixLength]];
  
  return newString;
}

- (NSString *) encryptWithKey: (NSString *) theKey
{
  NSMutableData *encryptedPassword;
  NSMutableString *key;
  NSString *result;
  NSUInteger i, passLength, theKeyLength, keyLength;
  unichar p, k, e;
 
  if ([theKey length] > 0)
    {
      // The length of the key must be greater (or equal) than
      // the length of the password
      key = [NSMutableString string];
      keyLength = 0;

      passLength = [self length];
      theKeyLength = [theKey length];
      while (keyLength < passLength)
        {
          [key appendString: theKey];
          keyLength += theKeyLength;
        }
 
      encryptedPassword = [NSMutableData data];
      for (i = 0; i < passLength; i++)
        {
          p = [self characterAtIndex: i];
          k = [key characterAtIndex: i];
          e = p ^ k;
          [encryptedPassword appendBytes: (void *)&e length: 2];
        }
 
      result = [encryptedPassword stringByEncodingBase64];
    }
  else
    result = nil;
 
  return result;
}
 
- (NSString *) decryptWithKey: (NSString *) theKey
{
  NSMutableString *result;
  NSMutableString *key;
  NSData *decoded;
  unichar *decryptedPassword;
  NSUInteger i, theKeyLength, keyLength, decodedLength;
  unichar p, k;
 
  if ([theKey length] > 0)
    {
      decoded = [self dataByDecodingBase64];
      decryptedPassword = (unichar *)[decoded bytes];

      // The length of the key must be greater (or equal) than
      // the length of the password
      key = [NSMutableString string];
      keyLength = 0;
      decodedLength = ([decoded length] / 2); /* 1 unichar = 2 bytes/char */
      theKeyLength = [theKey length];
 
      while (keyLength < decodedLength)
        {
          [key appendString: theKey];
          keyLength += theKeyLength;
        }
 
      result = [NSMutableString string];
      for (i = 0; i < decodedLength; i++)
        {
          k = [key characterAtIndex: i];
          p = decryptedPassword[i] ^ k;
          [result appendFormat: @"%C", p];
        }
    }
  else
    result = nil;

  return result;
}

@end
