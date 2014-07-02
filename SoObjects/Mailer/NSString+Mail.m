/* NSString+Mail.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2014 Inverse inc.
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
#import <Foundation/NSException.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSValue.h>

#import <SaxObjC/SaxAttributes.h>
#import <SaxObjC/SaxContentHandler.h>
#import <SaxObjC/SaxLexicalHandler.h>
#import <SaxObjC/SaxXMLReader.h>
#import <SaxObjC/SaxXMLReaderFactory.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>

#include <libxml/encoding.h>

#import "NSString+Mail.h"
#import "NSData+Mail.h"
#import "../SOGo/SOGoObject.h"

#if 0
#define showWhoWeAre() \
  [self logWithFormat: @"invoked '%@'", NSStringFromSelector (_cmd)]
#else
#define showWhoWeAre() {}
#endif

#define paddingBuffer 8192

@interface _SOGoHTMLContentHandler : NSObject <SaxContentHandler, SaxLexicalHandler>
{
  NSMutableArray *images;
  
  NSArray *ignoreContentTags;
  NSArray *specialTreatmentTags;
  NSArray *voidTags;
  
  BOOL ignoreContent;
  BOOL orderedList;
  BOOL unorderedList;
  unsigned int listCount;

  NSMutableString *result;
}

+ (id) htmlToTextContentHandler;
+ (id) sanitizerContentHandler;

- (NSString *) result;

- (void) setIgnoreContentTags: (NSArray *) theTags;
- (void) setSpecialTreatmentTags: (NSArray *) theTags;
- (void) setVoidTags: (NSArray *) theTags;
- (void) setImages: (NSMutableArray *) theImages;

@end

@implementation _SOGoHTMLContentHandler

- (id) init
{
  if ((self = [super init]))
    {
      images = nil;

      ignoreContentTags = nil;
      specialTreatmentTags = nil;
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

+ (id) htmlToTextContentHandler
{
  static id htmlToTextContentHandler;

  if (!htmlToTextContentHandler)
    htmlToTextContentHandler = [self new];

  [htmlToTextContentHandler setIgnoreContentTags: [NSArray arrayWithObjects: @"head", @"script",
                                                           @"style", nil]];
  [htmlToTextContentHandler setSpecialTreatmentTags: [NSArray arrayWithObjects: @"p", @"ul",
                                                              @"li", @"table", @"tr", @"td", @"th",
                                                              @"br", @"hr", @"dt", @"dd", nil]];

  return htmlToTextContentHandler;
}

+ (id) sanitizerContentHandler
{
  static id sanitizerContentHandler;

  if (!sanitizerContentHandler)
    sanitizerContentHandler = [self new];

  [sanitizerContentHandler setVoidTags: [NSArray arrayWithObjects: @"area", @"base",
                                                 @"basefont", @"br", @"col", @"frame", @"hr",
                                                 @"img", @"input", @"isindex", @"link",
                                                 @"meta", @"param", @"", nil]];

  return sanitizerContentHandler;
}

- (xmlCharEncoding) contentEncoding
{
  return XML_CHAR_ENCODING_UTF8;
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

- (void) setIgnoreContentTags: (NSArray *) theTags
{
  ASSIGN(ignoreContentTags, theTags);
}

- (void) setSpecialTreatmentTags: (NSArray *) theTags
{
  ASSIGN(specialTreatmentTags, theTags);
}

- (void) setVoidTags: (NSArray *) theTags
{
  ASSIGN(voidTags, theTags);
}

//
// We MUST NOT retain the array here
//
- (void) setImages: (NSMutableArray *) theImages
{
  images = theImages;
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

  tagName = [rawName lowercaseString];

  if (!ignoreContent && ignoreContentTags && specialTreatmentTags)
    {
      if ([ignoreContentTags containsObject: tagName])
        ignoreContent = YES;
      else if ([specialTreatmentTags containsObject: tagName])
        [self _startSpecialTreatment: tagName];
    }
  else
    {
      if ([tagName isEqualToString: @"img"])
        {
          NSString *value;

          value = [attributes valueForRawName: @"src"];

          //
          // Check for Data URI Scheme
          //
          // data:[<MIME-type>][;charset=<encoding>][;base64],<data>
          //
          if ([value length] > 5 && [[value substringToIndex: 5] caseInsensitiveCompare: @"data:"] == NSOrderedSame)
            {
              NSString *uniqueId, *mimeType, *encoding;
              NGMimeBodyPart *bodyPart;
              NGMutableHashMap *map;
              NSData *data;
              id body;

              int i, j, k;

              i = [value indexOf: ';'];
              j = [value indexOf: ';' fromIndex: i+1];
              k = [value indexOf: ','];
          
              // We try to get the MIME type
              mimeType = nil;

              if (i > 5 && i < k)
                {
                  mimeType = [value substringWithRange: NSMakeRange(5, i-5)];
                }
              else
                i = 5;

              // We might get a stupid value. We discard anything that doesn't have a / in it
              if ([mimeType indexOf: '/'] < 0)
                mimeType = @"image/jpeg";
          
              // We check and skip the charset
              if (j < i)
                j = i;

              // We check the encoding and we completely ignore it
              encoding = [value substringWithRange: NSMakeRange(j+1, k-j-1)];

              if (![encoding length])
                encoding = @"base64";

              data = [[value substringFromIndex: k+1] dataUsingEncoding: NSASCIIStringEncoding];

              uniqueId = [SOGoObject globallyUniqueObjectId];

              map = [[[NGMutableHashMap alloc] initWithCapacity:5] autorelease];
              [map setObject: encoding forKey: @"content-transfer-encoding"];
              [map setObject:[NSNumber numberWithInt:[data length]] forKey: @"content-length"];
              [map setObject: [NSString stringWithFormat: @"inline; filename=\"%@\"", uniqueId]  forKey: @"content-disposition"];
              [map setObject: [NSString stringWithFormat: @"%@; name=\"%@\"", mimeType, uniqueId]  forKey: @"content-type"];
              [map setObject: [NSString stringWithFormat: @"<%@>", uniqueId]  forKey: @"content-id"];
                    
                    
              body = [[NGMimeFileData alloc] initWithBytes: [data bytes]  length: [data length]];

              bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
              [bodyPart setBody: body];
              [body release];
          
              [images addObject: bodyPart];
          
              [result appendFormat: @"<img src=\"cid:%@\" type=\"%@\"/>", uniqueId, mimeType];
            }
        }
      else if (voidTags)
        {
          NSString *type;
          int i;

          [result appendString: @"<"];
          [result appendString: rawName];
          for (i = 0; i < [attributes count]; i++)
            {
              [result appendString: @" "];
              [result appendString: [attributes nameAtIndex: i]];
              [result appendString: @"='"];
              [result appendString: [attributes valueAtIndex: i]];
              [result appendString: @"'"];

              type = [attributes typeAtIndex: i];
              if (![type isEqualToString: @"CDATA"])
                {
                  [result appendString: @"["];
                  [result appendString: type];
                  [result appendString: @"]"];
                }
            }
          if ([voidTags containsObject: tagName])
            [result appendString: @"/"];
          [result appendString: @">"];
        }
    }
}

- (void) endElement: (NSString *) element
          namespace: (NSString *) namespace
            rawName: (NSString *) rawName
{
  NSString *tagName;

  showWhoWeAre();

  if (ignoreContentTags && specialTreatmentTags)
    {
      if (ignoreContent)
        {
          tagName = [rawName lowercaseString];
          if ([ignoreContentTags containsObject: tagName])
            ignoreContent = NO;
          else if ([specialTreatmentTags containsObject: tagName])
            [self _endSpecialTreatment: tagName];
        }
    }
  else if (voidTags)
    {
      tagName = [rawName lowercaseString];
      if (![voidTags containsObject: tagName])
        [result appendFormat: @"</%@>", rawName];
    }
}

- (void) characters: (unichar *) characters
             length: (NSUInteger) length
{
  if (!ignoreContent)
    {
      // Append a text node
      if (ignoreContentTags)
        // We are converting a HTML message to plain text (htmlToTextContentHandler):
        // include the HTML tags in the text
        [result appendString: [NSString stringWithCharacters: characters  length: length]];
      else
        // We are sanitizing an HTML message (sanitizerContentHandler):
        // escape the HTML entitites so they are visible
        [result appendString: [[NSString stringWithCharacters: characters  length: length] stringByEscapingHTMLString]];
    }
}

- (void) ignorableWhitespace: (unichar *) whitespaces
                      length: (NSUInteger) length
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

+ (NSString *) generateMessageID
{
  NSMutableString *messageID;
  NSString *pGUID;

  messageID = [NSMutableString string];
  [messageID appendFormat: @"<%@", [SOGoObject globallyUniqueObjectId]];
  pGUID = [[NSProcessInfo processInfo] globallyUniqueString];
  [messageID appendFormat: @"@%u>", [pGUID hash]];

  return [messageID lowercaseString];
}

- (NSString *) htmlToText
{
  _SOGoHTMLContentHandler *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *d;

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  handler = [_SOGoHTMLContentHandler htmlToTextContentHandler];
  [parser setContentHandler: handler];

  d = [self dataUsingEncoding: NSUTF8StringEncoding];
  [parser parseFromSource: d];

  return [handler result];
}

- (NSString *) htmlByExtractingImages: (NSMutableArray *) theImages
{
  _SOGoHTMLContentHandler *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *d;

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  handler = [_SOGoHTMLContentHandler sanitizerContentHandler];
  [handler setImages: theImages];

  [parser setContentHandler: handler];

  d = [self dataUsingEncoding: NSUTF8StringEncoding];
  [parser parseFromSource: d];

  return [handler result];
}

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
                       reallocated = NSZoneRealloc (NULL, newString,
                                                    maxLength + 1);
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
  const char *utf8String;
  char *newString;
  unsigned int newLength;

  utf8String = [self UTF8String];
  newString = convertChars (utf8String, strlen (utf8String), &newLength);
  convertedString = [[NSString alloc] initWithBytes: newString
                                             length: newLength
                                           encoding: NSUTF8StringEncoding];
  [convertedString autorelease];
  NSZoneFree (NULL, newString);

  return convertedString;
}


- (int) indexOf: (unichar) _c
      fromIndex: (int) start
{
  int i, len;
  
  len = [self length];
  
  if (start < 0 || start >= len)
    start = 0;
  
  for (i = start; i < len; i++)
    {
      if ([self characterAtIndex: i] == _c) return i;
    }

  return -1;
  
}

- (int) indexOf: (unichar) _c
{
  return [self indexOf: _c fromIndex: 0];
}

- (NSString *) decodedHeader
{
  NSString *decodedHeader;

  decodedHeader = [[self dataUsingEncoding: NSASCIIStringEncoding]
                     decodedHeader];
  if (!decodedHeader)
    decodedHeader = self;
  
  return decodedHeader;
}

@end
