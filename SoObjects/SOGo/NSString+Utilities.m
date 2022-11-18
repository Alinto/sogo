/* NSString+Utilities.m - this file is part of SOGo
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
static NSMutableCharacterSet *schemaStartChars = nil;
static NSMutableCharacterSet *emailStartChars = nil;

static NSMutableCharacterSet *jsonEscapingChars = NULL;
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
      locationR = [[self substringFromIndex: (hostR.location + hostR.length)] rangeOfString: @"/"];
      newURL = [self substringFromIndex: (hostR.location + hostR.length + locationR.location)];
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
               withPrefixChars: (NSCharacterSet *) startChars
{
  int start, length;
  NSRange workRange;

  start = refRange.location;
  if (start > 0)
    start--; // Start with the character before the refRange
  while (start > -1
         && [startChars characterIsMember:
                   [self characterAtIndex: start]])
    start--;
  start++;

  length = [self length];
  // In [UIxMailPartTextViewer flatContentAsString], we first escape HTML entities and then
  // add URLs. Therefore, the brackets (inequality signs <>) have been encoded at this point.
  if (length > (start + 4)
      && [[self substringWithRange: NSMakeRange (start, 4)] compare: @"&lt;"] == NSOrderedSame)
    start += 4;

  length -= start;
  workRange = [self rangeOfCharacterFromSet: urlAfterEndingChars
                                    options: NSLiteralSearch range: NSMakeRange (start, length)];
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
      urlPrefixChars: (NSCharacterSet *) startChars
              prefix: (NSString *) prefix
            inRanges: (NSMutableArray *) ranges
{
  NSEnumerator *enumRanges;
  NSMutableArray *newRanges;
  NSRange matchRange, currentUrlRange, rest;
  NSRange *rangePtr;
  NSString *urlText, *newUrlText;
  unsigned int length, matchLength, offset;

  newRanges = [NSMutableArray array];
  matchLength = [match length];

  matchRange = [selfCopy rangeOfString: match];
  while (matchRange.location != NSNotFound)
    {
      currentUrlRange = [selfCopy _rangeOfURLInRange: matchRange
                                     withPrefixChars: startChars];
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
      newUrlText = [NSString stringWithFormat: @"<a rel=\"noopener\" href=\"%@%@\">%@</a>",
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

  if (!urlNonEndingChars)
    {
      urlNonEndingChars = [NSMutableCharacterSet new];
      [urlNonEndingChars addCharactersInString: @"=,.:;&()>\t \r\n"];
    }
  if (!urlAfterEndingChars)
    {
      urlAfterEndingChars = [NSMutableCharacterSet new];
      [urlAfterEndingChars addCharactersInString: @"()[]\t \r\n"];
    }
  if (!schemaStartChars)
    {
      schemaStartChars = [NSMutableCharacterSet new];
      [schemaStartChars addCharactersInString: @"abcdefghijklmnopqrstuvwxyz"
                        @"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    }
  if (!emailStartChars)
    {
      emailStartChars = [NSMutableCharacterSet new];
      [emailStartChars addCharactersInString: @"abcdefghijklmnopqrstuvwxyz"
                       @"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                       @"01234567890"
                       @"!#$%&'*+-/=?^`{|}~."];
    }

  ranges = [NSMutableArray array];
  selfCopy = [NSMutableString stringWithString: self];
  [self _handleURLs: selfCopy
        textToMatch: @"://"
     urlPrefixChars: schemaStartChars
             prefix: @""
           inRanges: ranges];
  [self _handleURLs: selfCopy
        textToMatch: @"@"
     urlPrefixChars: emailStartChars
             prefix: @"mailto:"
           inRanges: ranges];
  [ranges freeNonNSObjects];

  return selfCopy;
}

- (NSString *) asSafeJSString
{
  NSRange esc;

  if (!jsonEscapingChars)
    {
      jsonEscapingChars = [[NSMutableCharacterSet characterSetWithRange: NSMakeRange(0,32)] retain];
      [jsonEscapingChars addCharactersInString: @"\"\\"];
    }

  esc = [self rangeOfCharacterFromSet: jsonEscapingChars];
  if (!esc.length)
    {
      // No special chars
      return self;
    }
  else
    {
      NSMutableString *representation;
      NSUInteger length, i;
      unichar uc;

      representation = [NSMutableString string];

      length = [self length];
      for (i = 0; i < length; i++)
        {
          uc = [self characterAtIndex:i];
          switch (uc)
            {
            case '"':   [representation appendString:@"\\\""];  break;
            case '\\':  [representation appendString:@"\\\\"];  break;
            case '\t':  [representation appendString:@"\\t"];   break;
            case '\n':  [representation appendString:@"\\n"];   break;
            case '\r':  [representation appendString:@"\\r"];   break;
            case '\b':  [representation appendString:@"\\b"];   break;
            case '\f':  [representation appendString:@"\\f"];   break;
            default:
              if (uc < 0x20)
                [representation appendFormat:@"\\u%04x", uc];
              else
                [representation appendFormat: @"%C", uc];
              break;
            }
        }
      return representation;
    }
}

- (NSString *) doubleQuotedString
{
  return [NSString stringWithFormat: @"\"%@\"", [self asSafeJSString]];
}

//
// See http://www.hackcraft.net/xmlUnicode/
//
// XML1.0 and XML1.1 allow different characters in different contexts,
// but for the most part I will only describe the XML1.0 usage, XML1.1
// usage is analogous.  The first definition that is relevant here is
// that of a Char: [2] Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] |
// [#xE000-#xFFFD] | [#x10000-#x10FFFF] /* any Unicode character,
// excluding the surrogate blocks, FFFE, and FFFF. */
//
// This defines which characters can be used in an XML1.0 document. It
// is clearly very liberal, banning only some of the control
// characters and the noncharacters U+FFFE and U+FFFF.  Indeed it is
// somewhat too liberal in my view since it allows other noncharacters
// (the code points from U+FDD0 to U+FDEF inclusive and the last 2
// code points in each plane, from U+1FFFE & U+1FFFF through to
// U+10FFFE & U+10FFFF, are noncharacters) but the production quoted
// above allows them.
//
- (NSString *) safeString
{
  NSData *data;
  NSString *s;

  const wchar_t *buf;
  wchar_t *start, c;
  int len, i, j;

  data = [self dataUsingEncoding: NSUTF32LittleEndianStringEncoding];
  len = [data length];
  buf = [data bytes];
  start = (wchar_t *)calloc(len, sizeof(wchar_t));

  for (i = 0, j = 0; i < len/4; i++)
    {
      c = buf[i];

      if (c == 0x0 ||
          c == 0x9 ||
          c == 0xA ||
          (c >= 0x20 && c < 0x300) || // Skip combining diacritical marks
          (c > 0x36F && c < 0xD7FF) ||
          (c >= 0xE000 && c < 0xFE00) || // Skip variation selectors
          (c > 0xFE0F && c <= 0xFFFD) ||
          (c >= (wchar_t)0x10000 && c <= (wchar_t)0x10FFFF))
        {
          start[j] = c;
          j++;
        }
    }

  s = [[NSString alloc] initWithBytesNoCopy: start  length: j*sizeof(wchar_t)  encoding: NSUTF32LittleEndianStringEncoding  freeWhenDone: YES];

  return AUTORELEASE(s);
}

- (NSString *) safeStringByEscapingXMLString
{
  return [self safeStringByEscapingXMLString: NO];
}
//
// This is a copy from NSString+XMLEscaping.m from SOPE.
// The difference here is that we use wchar_t instead of unichar.
// This is needed to get the rigth numeric character reference.
// e.g. SMILING FACE WITH OPEN MOUTH
//      ok: wchar_t -> &#128515;   wrong:  unichar -> &#55357; &#56835;
//
// We avoid naming it like the one in SOPE since if the ActiveSync
// bundle is loaded, it'll overwrite the one provided by SOPE.
//
- (NSString *) safeStringByEscapingXMLString: (BOOL) encodeCR
{
  NSData *data;

  register unsigned i, len, j;
  register wchar_t *buf;
  const wchar_t *chars;
  unsigned escapeCount;

  if ([self length] == 0) return @"";

  data = [self dataUsingEncoding: NSUTF32LittleEndianStringEncoding];
  chars = [data bytes];
  len = [data length]/4;

  /* check for characters to escape ... */
  for (i = 0, escapeCount = 0; i < len; i++)
    {
      switch (chars[i]) {
      case '&': case '"': case '<': case '>': case '\r':
        escapeCount++;
        break;
      default:
        if (chars[i] < 0x20 || chars[i] > 127)
          escapeCount++;
        break;
      }
    }

  /* nothing to escape ... */
  if (escapeCount == 0 )
    return [[self copy] autorelease];

  buf = calloc((len + 5) + (escapeCount * 16), sizeof(wchar_t));
  for (i = 0, j = 0; i < len; i++)
    {
      switch (chars[i])
        {
          /* escape special chars */
        case '&':
          buf[j] = '&'; j++; buf[j] = 'a'; j++; buf[j] = 'm'; j++;
          buf[j] = 'p'; j++; buf[j] = ';'; j++;
          break;
        case '"':
          buf[j] = '&'; j++; buf[j] = 'q'; j++; buf[j] = 'u'; j++;
          buf[j] = 'o'; j++; buf[j] = 't'; j++; buf[j] = ';'; j++;
          break;
        case '<':
          buf[j] = '&'; j++; buf[j] = 'l'; j++; buf[j] = 't'; j++;
          buf[j] = ';'; j++;
          break;
        case '>':
          buf[j] = '&'; j++; buf[j] = 'g'; j++; buf[j] = 't'; j++;
          buf[j] = ';'; j++;
          break;
        case '\r':
          if (encodeCR) // falls back to default if we don't encode
            {
              buf[j] = '&'; j++; buf[j] = '#'; j++; buf[j] = '1'; j++;
              buf[j] = '3'; j++; buf[j] = ';'; j++;
              break;
            }
        default:
          /* escape big chars */
          if (chars[i] > 127)
            {
              unsigned char nbuf[32];
              unsigned int k;

              sprintf((char *)nbuf, "&#%i;", (int)chars[i]);
              for (k = 0; nbuf[k] != '\0'; k++)
                {
                  buf[j] = nbuf[k];
                  j++;
                }
            }
          else if (chars[i] == 0x9 || chars[i] == 0xA || chars[i] == 0xD || chars[i] >= 0x20)
            { // ignore any unsupported control character
              /* nothing to escape */
              buf[j] = chars[i];
              j++;
            }
          break;
        }
    }

  self = [[NSString alloc] initWithBytesNoCopy: buf
                                        length: (j*sizeof(wchar_t))
                                      encoding: NSUTF32LittleEndianStringEncoding
                                  freeWhenDone: YES];
  return [self autorelease];
}

- (NSString *) jsonRepresentation
{
  NSString *cleanedString;

  // Escape double quotes and remove control characters
  cleanedString = [[self safeString] doubleQuotedString];
  return cleanedString;
}

- (void) _setupCSSEscaping
{
  NSArray *strings, *characters;
  int count;

  strings = [NSArray arrayWithObjects: @"_U_", @"_D_", @"_H_", @"_A_", @"_S_",
                     @"_C_", @"_SC_",
                     @"_CO_", @"_SP_", @"_SQ_", @"_DQ_",
                     @"_LP_", @"_RP_", @"_LS_", @"_RS_", @"_LC_", @"_RC_",
                     @"_AM_", @"_P_", @"_DS_", nil];
  [strings retain];
  cssEscapingStrings = [strings asPointersOfObjects];

  characters = [NSArray arrayWithObjects: @"_", @".", @"#", @"@", @"*",
                        @":", @";",
                        @",", @" ", @"'", @"\"",
                        @"(", @")", @"[", @"]", @"{", @"}",
                        @"&", @"+", @"$", nil];
  cssEscapingCount = [strings count];
  cssEscapingCharacters = NSZoneMalloc (NULL,
                                        (cssEscapingCount + 1)
                                        * sizeof (unichar));
  for (count = 0; count < cssEscapingCount; count++)
    *(cssEscapingCharacters + count) = [[characters objectAtIndex: count] characterAtIndex: 0];
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
  NSCharacterSet *numericSet;
  NSMutableString *cssIdentifier;
  unichar currentChar;
  int count, max, idx;

  if (!cssEscapingStrings)
    [self _setupCSSEscaping];

  cssIdentifier = [NSMutableString string];
  numericSet = [NSCharacterSet decimalDigitCharacterSet];
  max = [self length];

  if (max > 0)
    {
      if ([numericSet characterIsMember: [self characterAtIndex: 0]])
        // A CSS identifier can't start with a digit; we add an underscore
        [cssIdentifier appendString: @"_"];
      for (count = 0; count < max; count++)
        {
          currentChar = [self characterAtIndex: count];
          idx = [self _cssCharacterIndex: currentChar];
          if (idx > -1)
            [cssIdentifier appendString: cssEscapingStrings[idx]];
          else
            [cssIdentifier appendFormat: @"%C", currentChar];
        }
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
  NSCharacterSet *numericSet;
  NSMutableString *newString;
  NSString *currentString;
  int count, length, max, idx;
  unichar currentChar;

  if (!cssEscapingStrings)
    [self _setupCSSEscaping];

  numericSet = [NSCharacterSet decimalDigitCharacterSet];
  newString = [NSMutableString string];
  max = [self length];
  count = 0;

  if (max > 0
      && [self characterAtIndex: 0] == '_'
      && [numericSet characterIsMember: [self characterAtIndex: 1]])
    {
      /* If the identifier starts with an underscore followed by a digit,
         we remove the underscore */
      count = 1;
    }

  for (; count < max - 2; count++)
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
  return [NGMimeHeaderFieldGenerator encodeQuotedPrintableText: self];
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

//
// To decompose the DN extracted from a SSL certificate
// using the XN_FLAG_SEP_MULTILINE flag.
//
- (NSArray *) componentsFromMultilineDN
{
  NSArray *pair;
  NSEnumerator *componentsEnum, *rdnComponentsEnum;
  NSMutableArray *components;
  NSString *component, *pairString;

  components = [NSMutableArray array];
  componentsEnum = [[self componentsSeparatedByString: @"\n"] objectEnumerator];
  while (( component = [componentsEnum nextObject] ))
    {
      rdnComponentsEnum = [[component componentsSeparatedByString: @" + "] objectEnumerator];
      while (( pairString = [rdnComponentsEnum nextObject] ))
        {
          pair = [pairString componentsSeparatedByString: @"="];
          if ([pair count] == 2)
            [components addObject: [NSArray arrayWithObjects:
                                         [pair objectAtIndex: 0],
                                         [pair objectAtIndex: 1], nil]];
        }
    }

  return components;
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
  NSArray *object;
  NSError *error;
  NSString *unescaped, *json;

  object = nil;

  if ([self length] > 0)
    {
      parser = [SBJsonParser new];
      [parser autorelease];
      error = nil;

      /* Parse it this way so we can parse simple values, like "null" */
      json = [NSString stringWithFormat: @"[%@]", self];
      object = [parser objectWithString: json
                                  error: &error];
      if (error)
        {
          [self errorWithFormat: @"json parser: %@,"
                @" attempting once more after unescaping...", error];
          unescaped = [json stringByReplacingString: @"\\\\"
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

  return [object objectAtIndex: 0];
}

- (NSString *) asSafeSQLString
{
  return [[self stringByReplacingString: @"\\" withString: @"\\\\"]
           stringByReplacingString: @"'" withString: @"\\'"];
}

- (NSString *) asSafeSQLLikeString
{
  return [[self asSafeSQLString] stringByReplacingString: @"\%" withString: @"\\%"];
}

- (NSUInteger) countOccurrencesOfString: (NSString *) substring
{
  NSRange matchRange, substrRange;
  BOOL done = NO;
  NSUInteger selfLen, substrLen, count = 0;

  selfLen = [self length];
  substrLen = [substring length];

  matchRange = NSMakeRange (0, selfLen);
  while (!done && matchRange.length > 0)
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

/**
 * Get the safe string avoiding HTML injection
 * @param stripHTMLCode Remove all HTML code from content
 * @return A safe string
 */
- (NSString *) stringWithoutHTMLInjection: (BOOL)stripHTMLCode
{
  NSString *result, *text;
  NSScanner *theScanner;
  NSError *error;

  text = nil;
  error = nil;
  result = [NSString stringWithString: self];

  if (stripHTMLCode) {
    // Author : https://www.codercrunch.com/question/1251681838/how-remove-html-tags-string-ios
    theScanner = [NSScanner scannerWithString: result];
    while ([theScanner isAtEnd] == NO) {
      // find start of tag
      [theScanner scanUpToString: @"<" intoString: NULL];
      // find end of tag
      [theScanner scanUpToString: @">" intoString: &text];
      // replace the found tag with a space
      //(you can filter multi-spaces out later if you wish)
      result = [result stringByReplacingOccurrencesOfString:
              [NSString stringWithFormat: @"%@>", text]
              withString: @" "];
    } 
  } else {
    // Clean XSS
    // Examples of injection : https://cheatsheetseries.owasp.org/cheatsheets/XSS_Filter_Evasion_Cheat_Sheet.html#xss-locator-polygot

    // NSRegularExpression is not implemented in old GNUStep versions (ubuntu trusty)
    if (NSClassFromString(@"NSRegularExpression")) {
      NSRegularExpression *regex = nil;

      // Remove javascript:
      regex = [NSRegularExpression regularExpressionWithPattern:@"j[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*a[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*v[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*a[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*s[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*c[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*r[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*i[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*p[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*t[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*:"
                                  options: NSRegularExpressionCaseInsensitive error:&error];
      result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, [result length]) withTemplate:@""];

      // Remove vbscript:
      regex = [NSRegularExpression regularExpressionWithPattern:@"v[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*b[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*s[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*r[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*i[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*p[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*t[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*:"
                                  options: NSRegularExpressionCaseInsensitive error:&error];
      result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, [result length]) withTemplate:@""];

      // Remove livescript:
      regex = [NSRegularExpression regularExpressionWithPattern:@"l[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*i[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*v[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*e[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*s[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*c[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*r[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*i[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*p[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*t[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*:"
                                  options: NSRegularExpressionCaseInsensitive error:&error];
      result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, [result length]) withTemplate:@""];

      // Remove <script
      regex = [NSRegularExpression regularExpressionWithPattern:@"<[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*s[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*c[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*r[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*i[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*p[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*t" 
                                  options: NSRegularExpressionCaseInsensitive error:&error];
      result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, [result length]) withTemplate:@"<scr***"];

      // Remove </script
      regex = [NSRegularExpression regularExpressionWithPattern:@"<[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*/[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*s[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*c[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*r[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*i[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*p[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*t" 
                                  options: NSRegularExpressionCaseInsensitive error:&error];
      result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, [result length]) withTemplate:@"</scr***"];

      // Remove <iframe
      regex = [NSRegularExpression regularExpressionWithPattern:@"<[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*i[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*f[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*r[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*a[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*m[\\s\\u200B&#x09;&#x0A;&#x0D;\\\\0]*e" 
                                  options: NSRegularExpressionCaseInsensitive error:&error];
      result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, [result length]) withTemplate:@"<ifr***"];

      // Remove onload
      regex = [NSRegularExpression regularExpressionWithPattern:@"onload=" 
                                  options: NSRegularExpressionCaseInsensitive error:&error];
      result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, [result length]) withTemplate:@"onl***="];

      // Remove onmouseover
      regex = [NSRegularExpression regularExpressionWithPattern:@"onmouseover=" 
                                  options: NSRegularExpressionCaseInsensitive error:&error];
      result = [regex stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, [result length]) withTemplate:@"onmouseo***="];
    }
  }  
  
  return result;
}

@end
