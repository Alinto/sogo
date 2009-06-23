/* NSString+Mail.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSException.h>
#import <SaxObjC/SaxAttributes.h>
#import <SaxObjC/SaxContentHandler.h>
#import <SaxObjC/SaxLexicalHandler.h>
#import <SaxObjC/SaxXMLReader.h>
#import <SaxObjC/SaxXMLReaderFactory.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSString+Mail.h"
#import "NSData+Mail.h"

#if 1
#define showWhoWeAre() \
  [self logWithFormat: @"invoked '%@'", NSStringFromSelector (_cmd)]
#else
#define showWhoWeAre() {}
#endif

@interface _SOGoHTMLToTextContentHandler : NSObject <SaxContentHandler, SaxLexicalHandler>
{
  NSArray *ignoreContentTags;
  NSArray *specialTreatmentTags;

  BOOL ignoreContent;
  BOOL orderedList;
  BOOL unorderedList;
  unsigned int listCount;

  NSMutableString *result;
}

+ (id) htmlToTextContentHandler;

- (NSString *) result;

@end

@implementation _SOGoHTMLToTextContentHandler

+ (id) htmlToTextContentHandler
{
  static id htmlToTextContentHandler;

  if (!htmlToTextContentHandler)
    htmlToTextContentHandler = [self new];

  return htmlToTextContentHandler;
}

- (id) init
{
  if ((self = [super init]))
    {
      ignoreContentTags = [NSArray arrayWithObjects: @"head", @"script",
				   @"style", nil];
      specialTreatmentTags = [NSArray arrayWithObjects: @"body", @"p", @"ul",
				      @"li", @"table", @"tr", @"td", @"th",
				      @"br", @"hr", @"dt", @"dd", nil];
      [ignoreContentTags retain];
      [specialTreatmentTags retain];

      ignoreContent = NO;
      result = nil;

      orderedList = NO;
      unorderedList = NO;
      listCount = 0;
    }

  return self;
}

- (void) dealloc
{
  [ignoreContentTags release];
  [specialTreatmentTags release];
  [result release];
  [super dealloc];
}

- (NSString *) result
{
  NSString *newResult;

  newResult = [NSString stringWithString: result];
  [result release];
  result = nil;

  return newResult;
}

/* SaxContentHandler */
- (void) startDocument
{
  showWhoWeAre();

  [result release];
  result = [NSMutableString new];
}

- (void) endDocument
{
  showWhoWeAre();

  ignoreContent = NO;
}

- (void) startPrefixMapping: (NSString *) prefix
                        uri: (NSString *) uri
{
  showWhoWeAre();
}

- (void) endPrefixMapping: (NSString *) prefix
{
  showWhoWeAre();
}

- (void) _startSpecialTreatment: (NSString *) tagName
{
  if ([tagName isEqualToString: @"br"]
      || [tagName isEqualToString: @"p"])
    [result appendString: @"\n"];
  else if ([tagName isEqualToString: @"hr"])
    [result appendString: @"______________________________________________________________________________\n"];
  else if ([tagName isEqualToString: @"ul"])
    {
      [result appendString: @"\n"];
      unorderedList = YES;
    }
  else if ([tagName isEqualToString: @"ol"])
    {
      [result appendString: @"\n"];
      orderedList = YES;
      listCount = 0;
    }
  else if ([tagName isEqualToString: @"li"])
    {
      if (orderedList)
	{
	  listCount++;
	  [result appendFormat: @" %d. ", listCount];
	}
      else
	[result appendString: @" * "];
    }
  else if ([tagName isEqualToString: @"dd"])
    [result appendString: @"  "];
}

- (void) _endSpecialTreatment: (NSString *) tagName
{
  if ([tagName isEqualToString: @"ul"])
    {
      [result appendString: @"\n"];
      unorderedList = NO;
    }
  else if ([tagName isEqualToString: @"ol"])
    {
      [result appendString: @"\n"];
      orderedList = NO;
    }
  else if ([tagName isEqualToString: @"dt"])
    {
      [result appendString: @":\n"];
    }
  else if ([tagName isEqualToString: @"li"]
	   || [tagName isEqualToString: @"dd"])
    [result appendString: @"\n"];
}

- (void) startElement: (NSString *) element
            namespace: (NSString *) namespace
              rawName: (NSString *) rawName
           attributes: (id <SaxAttributes>) attributes
{
  NSString *tagName;

  showWhoWeAre();

  if (!ignoreContent)
    {
      tagName = [rawName lowercaseString];
      if ([ignoreContentTags containsObject: tagName])
	ignoreContent = YES;
      else if ([specialTreatmentTags containsObject: tagName])
	[self _startSpecialTreatment: tagName];
    }
}

- (void) endElement: (NSString *) element
          namespace: (NSString *) namespace
            rawName: (NSString *) rawName
{
  NSString *tagName;

  showWhoWeAre();

  if (ignoreContent)
    {
      tagName = [rawName lowercaseString];
      if ([ignoreContentTags containsObject: tagName])
	ignoreContent = NO;
      else if ([specialTreatmentTags containsObject: tagName])
	[self _endSpecialTreatment: tagName];
    }
}

- (void) characters: (unichar *) characters
             length: (int) length
{
  if (!ignoreContent)
    [result appendString: [NSString stringWithCharacters: characters
				    length: length]];
}

- (void) ignorableWhitespace: (unichar *) whitespaces
                      length: (int) length
{
  showWhoWeAre();
}

- (void) processingInstruction: (NSString *) pi
                          data: (NSString *) data
{
  showWhoWeAre();
}

- (void) setDocumentLocator: (id <NSObject, SaxLocator>) locator
{
  showWhoWeAre();
}

- (void) skippedEntity: (NSString *) entity
{
  showWhoWeAre();
}

/* SaxLexicalHandler */
- (void) comment: (unichar *) chars
          length: (int) len
{
  showWhoWeAre();
}

- (void) startDTD: (NSString *) name
         publicId: (NSString *) pub
         systemId: (NSString *) sys
{
  showWhoWeAre();
}

- (void) endDTD
{
  showWhoWeAre();
}

- (void) startEntity: (NSString *) entity
{
  showWhoWeAre();
}

- (void) endEntity: (NSString *) entity
{
  showWhoWeAre();
}

- (void) startCDATA
{
  showWhoWeAre();
}

- (void) endCDATA
{
  showWhoWeAre();
}

@end

// @interface NSDictionary (SOGoDebug)

// - (void) dump;

// @end

// @implementation NSDictionary (SOGoDebug)

// - (void) dump
// {
//   NSEnumerator *keys;
//   NSString *key;
//   NSMutableString *dump;

//   dump = [NSMutableString new];
//   [dump appendFormat: @"\nNSDictionary dump (%@):\n", self];
//   keys = [[self allKeys] objectEnumerator];
//   key = [keys nextObject];
//   while (key)
//     {
//       [dump appendFormat: @"%@: %@\n", key, [self objectForKey: key]];
//       key = [keys nextObject];
//     }
//   [dump appendFormat: @"--- end ---\n"];

//   NSLog (dump);
//   [dump release];
// }

// @end

@implementation NSString (SOGoExtension)

- (NSString *) htmlToText
{
  id <NSObject, SaxXMLReader> parser;
  _SOGoHTMLToTextContentHandler *handler;

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  handler = [_SOGoHTMLToTextContentHandler htmlToTextContentHandler];
  [parser setContentHandler: handler];
  [parser parseFromSource: self];

  return [handler result];
}

#define paddingBuffer 8192

static inline char *
convertChars (const char *oldString, unsigned int oldLength,
              unsigned int *newLength)
{
  const char *currentChar, *upperLimit;
  char *newString, *destChar, *reallocated;
  unsigned int length, maxLength;

  maxLength = oldLength + paddingBuffer;
  newString = NSZoneMalloc (NULL, maxLength + 1);
  destChar = newString;
  currentChar = oldString;

  length = 0;

  upperLimit = oldString + oldLength;
  while (currentChar < upperLimit)
    {
      switch (*currentChar)
        {
        case '\r': break;
        case '\n':
                   length = destChar - newString;
                   if (length + paddingBuffer > maxLength - 6)
                     {
                       maxLength += paddingBuffer;
                       reallocated = NSZoneRealloc (NULL, newString, maxLength + 1);
                       if (reallocated)
                         {
                           newString = reallocated;
                           destChar = newString + length;
                         }
                       else
                         [NSException raise: NSMallocException
                                     format: @"reallocation failed in %s",
                           __PRETTY_FUNCTION__];
                     }
                   strcpy (destChar, "<br />");
                   destChar += 6;
                   break;
        default:
                   *destChar = *currentChar;
                   destChar++;
        }
      currentChar++;
    }
  *destChar = 0;
  *newLength = destChar - newString;

  return newString;
}

- (NSString *) stringByConvertingCRLNToHTML
{
  NSString *convertedString;
  char *newString;
  unsigned int newLength;

  newString
    = convertChars ([self cStringUsingEncoding: NSUTF8StringEncoding],
                    [self lengthOfBytesUsingEncoding: NSUTF8StringEncoding],
                    &newLength);
  convertedString = [[NSString alloc] initWithBytes: newString
                                             length: newLength
                                           encoding: NSUTF8StringEncoding];
  [convertedString autorelease];
  NSZoneFree (NULL, newString);

  return convertedString;
}

- (int) indexOf: (unichar) _c
{
  int i, len;

  len = [self length];

  for (i = 0; i < len; i++)
    {
      if ([self characterAtIndex: i] == _c) return i;
    }

  return -1;
}

- (NSString *) decodedSubject
{
  NSString *decodedSubject;

  if ([self hasPrefix: @"=?"] && [self hasSuffix: @"?="])
    {
      decodedSubject = [[self dataUsingEncoding: NSASCIIStringEncoding]
			 decodedSubject];
      if (!decodedSubject)
	decodedSubject = self;
    }
  else
    decodedSubject = self;

  return decodedSubject;
}

@end
