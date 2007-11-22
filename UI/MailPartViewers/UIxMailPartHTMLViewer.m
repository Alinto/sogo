/* UIxMailPartHTMLViewer.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSValue.h>

#import <SaxObjC/SaxAttributes.h>
#import <SaxObjC/SaxContentHandler.h>
#import <SaxObjC/SaxLexicalHandler.h>
#import <SaxObjC/SaxXMLReader.h>
#import <SaxObjC/SaxXMLReaderFactory.h>
#import <NGExtensions/NSString+misc.h>
#import <NGObjWeb/SoObjects.h>

#include <libxml/encoding.h>

#import "UIxMailPartHTMLViewer.h"

#if 0
#define showWhoWeAre() NSLog(@"invoked '%@'", NSStringFromSelector(_cmd))
#else
#define showWhoWeAre()
#endif

@interface _UIxHTMLMailContentHandler : NSObject <SaxContentHandler, SaxLexicalHandler>
{
  NSMutableString *result;
  NSMutableString *css;
  NSDictionary *attachmentIds;
  BOOL inBody;
  BOOL inStyle;
  BOOL inScript;
  BOOL inCSSDeclaration;
  BOOL hasEmbeddedCSS;
  NSMutableArray *crumb;
  xmlCharEncoding contentEncoding;
}

- (NSString *) result;

@end

@implementation _UIxHTMLMailContentHandler

- (id) init
{
  if ((self = [super init]))
    {
      crumb = nil;
      css = nil;
      result = nil;
      attachmentIds = nil;
      contentEncoding = XML_CHAR_ENCODING_UTF8;
    }

  return self;
}

- (void) dealloc
{
  [crumb release];
  [result release];
  [css release];
  [super dealloc];
}

- (void) setContentEncoding: (xmlCharEncoding) newContentEncoding
{
  contentEncoding = newContentEncoding;
}

- (xmlCharEncoding) contentEncoding
{
  return contentEncoding;
}

- (void) setAttachmentIds: (NSDictionary *) newAttachmentIds
{
  attachmentIds = newAttachmentIds;
}

- (NSString *) css
{
  return css;
}

- (NSString *) result
{
  return result;
}

/* SaxContentHandler */
- (void) startDocument
{
  showWhoWeAre();

  [crumb release];
  [css release];
  [result release];

  result = [NSMutableString new];
  css = [NSMutableString new];
  crumb = [NSMutableArray new];

  inBody = NO;
  inStyle = NO;
  inScript = NO;
  inCSSDeclaration = NO;
  hasEmbeddedCSS = NO;
}

- (void) endDocument
{
  unsigned int count, max;


  showWhoWeAre();
  max = [crumb count];
  if (max > 0)
    for (count = max - 1; count > -1; count--)
      {
        [result appendFormat: @"</%@>", [crumb objectAtIndex: count]];
        [crumb removeObjectAtIndex: count];
      }
}

- (void) startPrefixMapping: (NSString *)_prefix
                        uri: (NSString *)_uri
{
  showWhoWeAre();
}

- (void) endPrefixMapping: (NSString *)_prefix
{
  showWhoWeAre();
}

- (void) _appendStyle: (unichar *) _chars
               length: (int) _len
{
  unsigned int count;
  unichar *start, *currentChar;

  start = _chars;
  currentChar = start;
  for (count = 0; count < _len; count++)
    {
      currentChar = _chars + count;
      if (inCSSDeclaration)
        {
          if (*(char *) currentChar == '}')
            {
              inCSSDeclaration = NO;
              hasEmbeddedCSS = NO;
            }
        }
      else
        {
          if (*(char *) currentChar == '{')
            inCSSDeclaration = YES;
          if (*(char *) currentChar == ',')
            hasEmbeddedCSS = NO;
          else if (!hasEmbeddedCSS)
            {
              if (*(char *) currentChar == '@')
                hasEmbeddedCSS = YES;
              else
                if (*(char *) currentChar > 32)
                  {
                    [css appendString: [NSString stringWithCharacters: start
                                                 length: (currentChar - start)]];
                    [css appendString: @".SOGoHTMLMail-CSS-Delimiter "];
                    hasEmbeddedCSS = YES;
                    start = currentChar;
                  }
            }
        }
    }
  [css appendString: [NSString stringWithCharacters: start
                               length: (currentChar - start)]];
}

- (void) startElement: (NSString *) _localName
            namespace: (NSString *) _ns
              rawName: (NSString *) _rawName
           attributes: (id <SaxAttributes>) _attributes
{
  unsigned int count, max;
  NSString *name, *value;
  NSMutableString *resultPart;
  BOOL skipAttribute;

  showWhoWeAre();
  if (inStyle || inScript)
    ;
  else if ([_localName caseInsensitiveCompare: @"body"] == NSOrderedSame)
    inBody = YES;
  else if ([_localName caseInsensitiveCompare: @"script"] == NSOrderedSame)
    inScript = YES;
  else if ([_localName caseInsensitiveCompare: @"style"] == NSOrderedSame)
    inStyle = YES;
  else if (inBody)
    {
      resultPart = [NSMutableString new];
      [resultPart appendFormat: @"<%@", _rawName];
      
      max = [_attributes count];
      for (count = 0; count < max; count++)
        {
          skipAttribute = NO;
          name = [_attributes nameAtIndex: count];
          if ([[name lowercaseString] hasPrefix: @"on"])
            skipAttribute = YES;
          else if ([name caseInsensitiveCompare: @"src"] == NSOrderedSame)
            {
              value = [_attributes valueAtIndex: count];
              if ([value hasPrefix: @"cid:"])
                {
                  value = [attachmentIds
                            objectForKey: [value substringFromIndex: 4]];
                  skipAttribute = (value == nil);
                }
              else
                skipAttribute = YES;
            }
          else
            value = [_attributes valueAtIndex: count];
          if (!skipAttribute)
            [resultPart appendFormat: @" %@=\"%@\"",
                        name, [value stringByReplacingString: @"\""
                                     withString: @"\\\""]];
        }

      [resultPart appendString: @">"];
      [result appendString: resultPart];
    }
}

- (void) _finishCSS
{
  [css replaceString: @".SOGoHTMLMail-CSS-Delimiter body"
       withString: @".SOGoHTMLMail-CSS-Delimiter"];
  [css replaceString: @";" withString: @" !important;"];
  [css replaceString: @"<!--" withString: @""];
  [css replaceString: @"-->" withString: @""];
}

- (void) endElement: (NSString *) _localName
          namespace: (NSString *) _ns
            rawName: (NSString *) _rawName
{
  showWhoWeAre();

  if (inStyle)
    {
     if ([_localName caseInsensitiveCompare: @"style"] == NSOrderedSame)
       {
         inStyle = NO;
         inCSSDeclaration = NO;
       }
    }
  else if (inScript)
    inScript = ([_localName caseInsensitiveCompare: @"script"] != NSOrderedSame);
  else if (inBody)
    {
      if ([_localName caseInsensitiveCompare: @"body"] == NSOrderedSame)
	{
	  inBody = NO;
	  if (css)
	    [self _finishCSS];
	}
      else
        [result appendFormat: @"</%@>", _localName];
    }
}

- (void) characters: (unichar *) _chars
             length: (int) _len
{
  NSString *tmpString;

  showWhoWeAre();
  if (!inScript)
    {
      if (inStyle)
        [self _appendStyle: _chars length: _len];
      else if (inBody)
        {
          tmpString = [NSString stringWithCharacters: _chars length: _len];
          [result appendString: [tmpString stringByEscapingHTMLString]];
        }
    }
}

- (void) ignorableWhitespace: (unichar *) _chars
                      length: (int) _len
{
  showWhoWeAre();
}

- (void) processingInstruction: (NSString *) _pi
                          data: (NSString *) _data
{
  showWhoWeAre();
}

- (void) setDocumentLocator: (id <NSObject, SaxLocator>) _locator
{
  showWhoWeAre();
}

- (void) skippedEntity: (NSString *) _entityName
{
  showWhoWeAre();
}

/* SaxLexicalHandler */
- (void) comment: (unichar *) _chars
          length: (int) _len
{
  showWhoWeAre();
  if (inStyle)
    [self _appendStyle: _chars length: _len];
}

- (void) startDTD: (NSString *) _name
         publicId: (NSString *) _pub
         systemId: (NSString *) _sys
{
  showWhoWeAre();
}

- (void) endDTD
{
  showWhoWeAre();
}

- (void) startEntity: (NSString *) _name
{
  showWhoWeAre();
}

- (void) endEntity: (NSString *) _name
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

@interface NSDictionary (SOGoDebug)

- (void) dump;

@end

@implementation NSDictionary (SOGoDebug)

- (void) dump
{
  NSEnumerator *keys;
  NSString *key;
  NSMutableString *dump;

  dump = [NSMutableString new];
  [dump appendFormat: @"\nNSDictionary dump (%@):\n", self];
  keys = [[self allKeys] objectEnumerator];
  key = [keys nextObject];
  while (key)
    {
      [dump appendFormat: @"%@: %@\n", key, [self objectForKey: key]];
      key = [keys nextObject];
    }
  [dump appendFormat: @"--- end ---\n"];

  NSLog (dump);
  [dump release];
}

@end

@implementation UIxMailPartHTMLViewer

- (id) init
{
  if ((self = [super init]))
    {
      handler = nil;
    }

  return self;
}

- (void) dealloc
{
  [handler release];
  [super dealloc];
}

- (void) _convertReferencesForPart: (NSDictionary *) part
                         withCount: (unsigned int) count
                        andBaseURL: (NSString *) url
                    intoDictionary: (NSMutableDictionary *) attachmentIds
{
  NSString *bodyId;

  bodyId = [part objectForKey: @"bodyId"];
  if ([bodyId length] > 0)
    {
      if ([bodyId hasPrefix: @"<"])
        bodyId = [bodyId substringFromIndex: 1];
      if ([bodyId hasSuffix: @">"])
        bodyId = [bodyId substringToIndex: [bodyId length] - 1];
      [attachmentIds setObject: [url stringByAppendingFormat: @"/%d", count]
                     forKey: bodyId];
    }
}

- (NSDictionary *) _attachmentIds
{
  NSMutableDictionary *attachmentIds;
  UIxMailPartViewer *parent;
  unsigned int count, max;
  NSMutableString *url;
  NSString *baseURL;
  NSArray *parts;

  attachmentIds = [NSMutableDictionary new];
  [attachmentIds autorelease];
  
  parent = [self parent];
  if ([NSStringFromClass ([parent class])
                         isEqualToString: @"UIxMailPartAlternativeViewer"])
    {
      baseURL = [[self clientObject] baseURLInContext: context];
      url = [NSMutableString new];
      [url appendString: baseURL];
      [url appendFormat: @"/%@", [partPath componentsJoinedByString: @"/"]];
      [url deleteCharactersInRange: NSMakeRange([url length] - 2, 2)];
      parts = [[parent bodyInfo] objectForKey: @"parts"];
      max = [parts count];
      for (count = 0; count < max; count++)
        [self _convertReferencesForPart: [parts objectAtIndex: count]
              withCount: count + 1
              andBaseURL: url
              intoDictionary: attachmentIds];
      [url release];
    }

  return attachmentIds;
}

- (xmlCharEncoding) _xmlCharsetForCharset: (NSString *) charset
{
  struct { NSString *name; xmlCharEncoding encoding; } xmlEncodings[] = {
    { @"us-ascii", XML_CHAR_ENCODING_ASCII},
    { @"utf-8", XML_CHAR_ENCODING_UTF8},
    { @"utf-16le", XML_CHAR_ENCODING_UTF16LE},
    { @"utf-16be",  XML_CHAR_ENCODING_UTF16BE},
    { @"ucs-4le", XML_CHAR_ENCODING_UCS4LE},
    { @"ucs-4be", XML_CHAR_ENCODING_UCS4BE},
    { @"ebcdic", XML_CHAR_ENCODING_EBCDIC},
//     { @"iso-10646" , XML_CHAR_ENCODING_UCS4_2143},
//     {  , XML_CHAR_ENCODING_UCS4_3412},
//     { @"ucs-2", XML_CHAR_ENCODING_UCS2},
    { @"iso8859_1", XML_CHAR_ENCODING_8859_1},
    { @"iso-8859-1", XML_CHAR_ENCODING_8859_1},
    { @"iso-8859-2",  XML_CHAR_ENCODING_8859_2},
    { @"iso-8859-3", XML_CHAR_ENCODING_8859_3},
    { @"iso-8859-4", XML_CHAR_ENCODING_8859_4},
    { @"iso-8859-5", XML_CHAR_ENCODING_8859_5},
    { @"iso-8859-6", XML_CHAR_ENCODING_8859_6},
    { @"iso-8859-7", XML_CHAR_ENCODING_8859_7},
    { @"iso-8859-8", XML_CHAR_ENCODING_8859_8},
    { @"iso-8859-9", XML_CHAR_ENCODING_8859_9},
    { @"iso-2022-jp", XML_CHAR_ENCODING_2022_JP},
//     { @"iso-2022-jp", XML_CHAR_ENCODING_SHIFT_JIS},
    { @"euc-jp", XML_CHAR_ENCODING_EUC_JP}};
  unsigned count;
  xmlCharEncoding encoding;

  encoding = XML_CHAR_ENCODING_NONE;
  count = 0;

  while (encoding == XML_CHAR_ENCODING_NONE
	 && count < (sizeof (xmlEncodings) / sizeof (xmlEncodings[0])))
    if ([charset isEqualToString: xmlEncodings[count].name])
      encoding = xmlEncodings[count].encoding;
    else
      count++;

  if (encoding == XML_CHAR_ENCODING_NONE)
    encoding = XML_CHAR_ENCODING_8859_1;

  return encoding;
}

- (xmlCharEncoding) _xmlCharEncoding
{

  NSString *charset;

  charset = [[bodyInfo objectForKey:@"parameterList"]
	      objectForKey: @"charset"];
  if (![charset length])
    charset = @"us-ascii";
  
  return [self _xmlCharsetForCharset: [charset lowercaseString]];
}

- (void) _parseContent
{
  NSObject <SaxXMLReader> *parser;
  NSData *preparsedContent;

  preparsedContent = [super decodedFlatContent];
  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];

  handler = [_UIxHTMLMailContentHandler new];
  [handler setAttachmentIds: [self _attachmentIds]];
  [handler setContentEncoding: [self _xmlCharEncoding]];
  [parser setContentHandler: handler];
  [parser parseFromSource: preparsedContent];
}

- (NSString *) cssContent
{
  NSString *cssContent, *css;

  if (!handler)
    [self _parseContent];

  css = [handler css];
  if ([css length])
    cssContent
      = [NSString stringWithFormat: @"<style type=\"text/css\">%@</style>",
		  [handler css]];
  else
    cssContent = @"";

  return cssContent;
}

- (NSString *) flatContentAsString
{
  if (!handler)
    [self _parseContent];

  return [handler result];
}

@end
