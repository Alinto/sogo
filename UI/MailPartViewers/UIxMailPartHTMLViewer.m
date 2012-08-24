/* UIxMailPartHTMLViewer.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2012 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSValue.h>

#import <SaxObjC/SaxAttributes.h>
#import <SaxObjC/SaxContentHandler.h>
#import <SaxObjC/SaxLexicalHandler.h>
#import <SaxObjC/SaxXMLReader.h>
#import <SaxObjC/SaxXMLReaderFactory.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGObjWeb/SoObjects.h>

#include <libxml/encoding.h>

#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/Mailer/SOGoMailBodyPart.h>

#import "UIxMailPartHTMLViewer.h"

#if 0
#define showWhoWeAre() NSLog(@"invoked '%@'", NSStringFromSelector(_cmd))
#else
#define showWhoWeAre()
#endif

/* Tags that are forbidden within the body of the html content */
static NSArray *BannedTags = nil;

/* Tags that can't have any contents (no end tag) */
static NSArray *VoidTags= nil;

static xmlCharEncoding
_xmlCharsetForCharset (NSString *charset)
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
    { @"iso-8859-13", XML_CHAR_ENCODING_ERROR},
    { @"iso-2022-jp", XML_CHAR_ENCODING_2022_JP},
//     { @"iso-2022-jp", XML_CHAR_ENCODING_SHIFT_JIS},
    { @"koi8-r", XML_CHAR_ENCODING_ERROR},       // unsupported, will trigger koi8-r -> utf8 conversion
    { @"windows-1250", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1250 -> utf8 conversion
    { @"windows-1251", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1251 -> utf8 conversion
    { @"windows-1257", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1257 -> utf8 conversion
    { @"gb2312", XML_CHAR_ENCODING_ERROR},       // unsupported, will trigger gb2312 -> utf8 conversion
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

//
// In order to avoid a libxml bug/limitation, we strip the charset= parameter
// to avoid libxml to consider the charset= parameter while it works in UTF-8
// internally, all the time.
//
// A fix was commited by Daniel Veillard following discussions Inverse had
// with him on the issue:
//
// commit a1bc2f2ba4b5317885205d4f71c7c4b1c99ec870
// Author: Daniel Veillard <veillard redhat com>
// Date:   Mon May 16 16:03:50 2011 +0800
//
//     Add options to ignore the internal encoding
//  
//     For both XML and HTML, the document can provide an encoding
//     either in XMLDecl in XML, or as a meta element in HTML head.
//     This adds options to ignore those encodings if the encoding
//     is known in advace for example if the content had been converted
//     before being passed to the parser.
//  
//     * parser.c include/libxml/parser.h: add XML_PARSE_IGNORE_ENC option
//       for XML parsing
//     * include/libxml/HTMLparser.h HTMLparser.c: adds the
//       HTML_PARSE_IGNORE_ENC for HTML parsing
//     * HTMLtree.c: fix the handling of saving when an unknown encoding is
//       defined in meta document header
//     * xmllint.c: add a --noenc option to activate the new parser options
//
// 
static NSData* _sanitizeContent(NSData *theData)
{
  NSMutableData *d;
  NSString *found_tag, *tag;
  NSEnumerator *tags;
  const char *bytes;
  char *buf;
  int i, j, len;
  BOOL found_delimiter;

  d = [NSMutableData dataWithData: theData];
  bytes = [d bytes];
  len = [d length];
  i = 0;

  while (i < len)
    {
      // We check if we see </head> in which case, we don't do any kind
      // of substitution there after.
      if (i < len-5)
	{
	  if ((*bytes == '<') &&
	      (*(bytes+1) == '/') &&
	      (*(bytes+1) == 'h' || *(bytes+1) == 'H') &&
	      (*(bytes+2) == 'e' || *(bytes+2) == 'E') &&
	      (*(bytes+3) == 'a' || *(bytes+3) == 'A') &&
	      (*(bytes+4) == 'd' || *(bytes+4) == 'D') &&
	      (*(bytes+7) == '>'))
          break;
	}
      
      // We search for something like :
      // 
      // <meta http-equiv="Content-Type" content="text/html; charset=Windows-1252">
      //
      if (i < len-9)
	{
	  if ((*bytes == 'c' || *bytes == 'C') &&
	      (*(bytes+1) == 'h' || *(bytes+1) == 'H') &&
	      (*(bytes+2) == 'a' || *(bytes+2) == 'A') &&
	      (*(bytes+3) == 'r' || *(bytes+3) == 'R') &&
	      (*(bytes+4) == 's' || *(bytes+4) == 'S') &&
	      (*(bytes+5) == 'e' || *(bytes+5) == 'E') &&
	      (*(bytes+6) == 't' || *(bytes+6) == 'T') &&
	      (*(bytes+7) == '='))
	    {
	      // We search until we find a '"' or a space
	      j = 8;
              found_delimiter = YES;

	      while (*(bytes+j) != ' ' && *(bytes+j) != '"')
		{
		  j++;
		  
		  // We haven't found anything, let's return the data untouched
		  if ((i+j) >= len)
                    {
                      found_delimiter = NO;
                      break;
                    }
		}

              if (found_delimiter)
                [d replaceBytesInRange: NSMakeRange(i, j)
                             withBytes: NULL
                                length: 0];
	      break;
	    }
	}

      bytes++;
      i++;
    }

  /*
   * Replace badly formatted void tags
   *
   * A void tag that begins with a slash is considered invalid.
   * We remove the slash from those tags.
   *
   * Ex: </br> is replaced by <br>
   */

  if (!VoidTags)
    {
      /* see http://www.w3.org/TR/html4/index/elements.html */
      VoidTags = [[NSArray alloc] initWithObjects: @"area", @"base",
                                  @"basefont", @"br", @"col", @"frame", @"hr",
                                  @"img", @"input", @"isindex", @"link",
                                  @"meta", @"param", @"", nil];
    }

  bytes = [d bytes];
  len = [d length];
  i = 0;
  while (i < len)
    {
      if (i < len-3)
	{
          // Search for ending tags
	  if ((*bytes == '<') && (*(bytes+1) == '/'))
            {
              i += 2;
              bytes += 2;
              j = 0;
              found_delimiter = YES;

              while (*(bytes+j) != '>')
                {
                  j++;
                  if ((i+j) >= len)
                    {
                      found_delimiter = NO;
                      break;
                    }
                }

              if (found_delimiter && j > 0)
                {
                  // Copy the ending tag to a NSString
                  buf = malloc((j+1) * sizeof(char));
                  memset (buf, 0, j+1);
                  memcpy (buf, bytes, j);
                  found_tag = [NSString stringWithCString: buf encoding: NSASCIIStringEncoding];
                  
                  tags = [VoidTags objectEnumerator];
                  tag = [tags nextObject];
                  while (tag)
                    {
                      if ([tag caseInsensitiveCompare: found_tag] == NSOrderedSame)
                        {
                          // Remove the leading slash
                          NSLog(@"Found void tag with invalid leading slash: </%@>", found_tag);
                          i--;
                          [d replaceBytesInRange: NSMakeRange(i, 1)
                                       withBytes: NULL
                                          length: 0];
                          bytes = [d bytes];
                          bytes += i;
                          len = [d length];
                          break;
                        }
                      tag = [tags nextObject];
                    }
                  free(buf);

                  // Continue the parsing after end tag
                  i += j;
                  bytes += j;
                }
            }
        }

      bytes++;
      i++;
    }
  
  return d;
}

@interface _UIxHTMLMailContentHandler : NSObject <SaxContentHandler, SaxLexicalHandler>
{
  NSMutableString *result;
  NSMutableString *css;
  NSDictionary *attachmentIds;
  int ignoredContent;
  NSString *ignoreTag;
  BOOL inBody;
  BOOL inStyle;
  BOOL inCSSDeclaration;
  BOOL hasEmbeddedCSS;
  xmlCharEncoding contentEncoding;
}

- (NSString *) result;

@end

@implementation _UIxHTMLMailContentHandler

+ (void) initialize
{
  if (!BannedTags)
    BannedTags = [[NSArray alloc] initWithObjects: @"script", @"frameset",
                                  @"frame", @"iframe", @"applet", @"link",
                                  @"base", @"meta", @"title", nil];
  if (!VoidTags)
    {
      /* see http://www.w3.org/TR/html4/index/elements.html */
      VoidTags = [[NSArray alloc] initWithObjects: @"area", @"base",
                                  @"basefont", @"br", @"col", @"frame", @"hr",
                                  @"img", @"input", @"isindex", @"link",
                                @"meta", @"param", @"", nil];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      css = nil;
      result = nil;
      ignoreTag = nil;
      attachmentIds = nil;
      contentEncoding = XML_CHAR_ENCODING_UTF8;
    }

  return self;
}

- (void) dealloc
{
  [result release];
  [css release];
  [ignoreTag release];
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

  [css release];
  [result release];

  result = [NSMutableString new];
  css = [NSMutableString new];

  ignoredContent = 0;
  [ignoreTag release];
  ignoreTag = nil;

  inBody = NO;
  inStyle = NO;
  inCSSDeclaration = NO;
  hasEmbeddedCSS = NO;
}

- (void) endDocument
{
  showWhoWeAre();
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
  unsigned int count, length;
  unichar *start, *currentChar;

  start = _chars;
  while (*start < 33)
    start++;

  currentChar = start;
  for (count = 0; count < _len; count++)
    {
      currentChar = _chars + count;
      if (inCSSDeclaration)
        {
          if (*currentChar == '}')
            {
              inCSSDeclaration = NO;
              hasEmbeddedCSS = NO;
            }
        }
      else
        {
          if (*currentChar < 32)
            {
              if (currentChar > start)
                [css appendString: [NSString stringWithCharacters: start
                                                           length: (currentChar - start)]];
              start = currentChar + 1;
            }
          else
            {
              if (*currentChar == '{')
                inCSSDeclaration = YES;
              else if (*currentChar == ',')
                hasEmbeddedCSS = NO;
              else if (!hasEmbeddedCSS)
                {
                  if (*currentChar == '@')
                    hasEmbeddedCSS = YES;
                  else
                    if (*currentChar > 32)
                      {
                        length = (currentChar - start);
                        [css appendFormat: @"%@\n.SOGoHTMLMail-CSS-Delimiter ",
                             [NSString stringWithCharacters: start length: length]];
                        hasEmbeddedCSS = YES;
                        start = currentChar;
                      }
                }
            }
        }
    }
  if (currentChar > start)
    [css appendString: [NSString stringWithCharacters: start
                                               length: (currentChar - start)]];
}

- (void) startElement: (NSString *) _localName
            namespace: (NSString *) _ns
              rawName: (NSString *) _rawName
           attributes: (id <SaxAttributes>) _attributes
{
  unsigned int count, max;
  NSString *name, *value, *cid, *lowerName;
  NSMutableString *resultPart;
  BOOL skipAttribute;

  showWhoWeAre();

  lowerName = [_localName lowercaseString];
  if (inStyle || ignoredContent)
    ;
  else if ([lowerName isEqualToString: @"base"])
    ;
  else if ([lowerName isEqualToString: @"meta"])
    ;
  else if ([lowerName isEqualToString: @"body"])
    inBody = YES;
  else if ([lowerName isEqualToString: @"style"])
    inStyle = YES;
  else if (inBody)
    {
      if ([BannedTags containsObject: lowerName])
        {
          if (!ignoredContent)
            ignoreTag = [lowerName copy];
          ignoredContent++;
        }
      else
        {
          resultPart = [NSMutableString string];
          [resultPart appendFormat: @"<%@", _rawName];

          if ([VoidTags containsObject: lowerName])
            {
              if (!ignoredContent)
                ignoreTag = [lowerName copy];
              ignoredContent++;
            }
          max = [_attributes count];
          for (count = 0; count < max; count++)
            {
              skipAttribute = NO;
              name = [[_attributes nameAtIndex: count] lowercaseString];
              if ([name hasPrefix: @"ON"])
                skipAttribute = YES;
              else if ([name isEqualToString: @"src"])
                {
                  value = [_attributes valueAtIndex: count];
                  if ([value hasPrefix: @"cid:"])
                    {
                      cid = [NSString stringWithFormat: @"<%@>",
                             [value substringFromIndex: 4]];
                      value = [attachmentIds objectForKey: cid];
                      skipAttribute = (value == nil);
                    }
                  else if ([lowerName isEqualToString: @"img"])
                    {
                      /* [resultPart appendString:
                         @"src=\"/SOGo.woa/WebServerResources/empty.gif\""]; */
                      name = @"unsafe-src";
                    }
                  else
                    skipAttribute = YES;
                }
              else if (([name isEqualToString: @"data"]
                        || [name isEqualToString: @"classid"])
                       && [lowerName isEqualToString: @"object"])
                {
                  value = [_attributes valueAtIndex: count];
                  name = [NSString stringWithFormat: @"unsafe-%@", name];
                }
              else if ([name isEqualToString: @"href"]
                       || [name isEqualToString: @"action"])
                {
                  value = [_attributes valueAtIndex: count];
                  skipAttribute = ([value rangeOfString: @"://"].location
                                   == NSNotFound
                                   && ![value hasPrefix: @"mailto:"]
                                   && ![value hasPrefix: @"#"]);
                }
              else
                value = [_attributes valueAtIndex: count];
              if (!skipAttribute)
                [resultPart appendFormat: @" %@=\"%@\"",
                            name, [value stringByReplacingString: @"\""
                                                      withString: @"\\\""]];
            }

          if ([VoidTags containsObject: lowerName])
            [resultPart appendString: @"/"];
          [resultPart appendString: @">"];
          [result appendString: resultPart];
        }
    }
}

- (void) _finishCSS
{
  NSRange excessiveDelimiter;

  [css replaceString: @"<!--" withString: @""];
  [css replaceString: @"-->" withString: @""];
  [css replaceString: @".SOGoHTMLMail-CSS-Delimiter body"
       withString: @".SOGoHTMLMail-CSS-Delimiter"];
  [css replaceString: @";" withString: @" !important;"];

  excessiveDelimiter = [css rangeOfString: @".SOGoHTMLMail-CSS-Delimiter "
                                  options: NSBackwardsSearch];
  if (excessiveDelimiter.location != NSNotFound)
    {
      if (NSMaxRange (excessiveDelimiter) == [css length])
        [css deleteCharactersInRange: excessiveDelimiter];
    }
}

- (void) endElement: (NSString *) _localName
          namespace: (NSString *) _ns
            rawName: (NSString *) _rawName
{
  NSString *lowerName;

  showWhoWeAre();

  lowerName = [_localName lowercaseString];

  if (ignoredContent)
    {
      if ([lowerName isEqualToString: ignoreTag])
        {
          ignoredContent--;
          if (!ignoredContent)
            {
              [ignoreTag release];
              ignoreTag = nil;
            }
        }
    }
  else
    {
      if (inStyle)
        {
          if ([lowerName isEqualToString: @"style"])
            {
              inStyle = NO;
              inCSSDeclaration = NO;
            }
        }
      else if (inBody)
        {
          if ([lowerName isEqualToString: @"body"])
            {
              inBody = NO;
              if (css)
                [self _finishCSS];
            }
          else
            {
              //NSLog (@"%@", _localName);
              [result appendFormat: @"</%@>", _localName];
            }
        }
    }
}

- (void) characters: (unichar *) _chars
             length: (int) _len
{
  showWhoWeAre();
  if (!ignoredContent)
    {
      if (inStyle)
        [self _appendStyle: _chars length: _len];
      else if (inBody)
        {
	  NSString *tmpString;
  
          tmpString = [NSString stringWithCharacters: _chars length: _len];

	  // HACK: This is to avoid appending the useless junk in the <html> tag
	  //       that Outlook adds. It seems to confuse the XML parser for
	  //       forwarded messages as we get this in the _body_ of the email
	  //       while we really aren't in it!
	  if (![tmpString hasPrefix: @" xmlns:v=\"urn:schemas-microsoft-com:vml\""])
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

  NSLog(dump);
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

- (xmlCharEncoding) _xmlCharEncoding
{
  NSString *charset;

  charset = [[bodyInfo objectForKey:@"parameterList"]
	      objectForKey: @"charset"];
  if (![charset length])
    charset = @"us-ascii";

  return _xmlCharsetForCharset([charset lowercaseString]);
}

- (void) _parseContent
{
  NSObject <SaxXMLReader> *parser;
  NSData *preparsedContent;
  SOGoMailObject *mail;
  xmlCharEncoding enc;

  mail = [self clientObject];

  preparsedContent = _sanitizeContent([super decodedFlatContent]);
  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];

  handler = [_UIxHTMLMailContentHandler new];
  [handler setAttachmentIds: [mail fetchAttachmentIds]];

  // We check if we got an unsupported charset. If so
  // we convert everything to UTF-16{LE,BE} so it passes
  // in libxml2 and also in characters: length: defined
  // in this file (that expects unichar:s)
  enc = [self _xmlCharEncoding];
  if (enc == XML_CHAR_ENCODING_ERROR)
    {
      NSString *s;

      s = [NSString stringWithData: preparsedContent
		    usingEncodingNamed: [[bodyInfo objectForKey:@"parameterList"]
					  objectForKey: @"charset"]];

#if BYTE_ORDER == BIG_ENDIAN
      preparsedContent = [s dataUsingEncoding: NSUTF16BigEndianStringEncoding];
      enc = XML_CHAR_ENCODING_UTF16BE;
#else
      preparsedContent = [s dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      enc = XML_CHAR_ENCODING_UTF16LE;
#endif
    }

  [handler setContentEncoding: enc];

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

@implementation UIxMailPartExternalHTMLViewer

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

- (xmlCharEncoding) _xmlCharEncoding
{
  NSString *charset;

  charset = [[bodyInfo objectForKey:@"parameterList"]
	      objectForKey: @"charset"];
  if (![charset length])
    charset = @"us-ascii";

  return _xmlCharsetForCharset([charset lowercaseString]);
}

- (void) _parseContent
{
  NSObject <SaxXMLReader> *parser;
  NSData *preparsedContent;
  SOGoMailObject *mail;
  SOGoMailBodyPart *part;
  NSString *encoding;
  xmlCharEncoding enc;

  part = [self clientObject];
  mail = [part mailObject];

  preparsedContent = _sanitizeContent([part fetchBLOB]);
  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  encoding = [[part partInfo] valueForKey: @"encoding"];
  if (![encoding length])
    encoding = @"us-ascii";

  handler = [_UIxHTMLMailContentHandler new];
  [handler setAttachmentIds: [mail fetchAttachmentIds]];

  // We check if we got an unsupported charset. If so
  // we convert everything to UTF-16{LE,BE} so it passes
  // in libxml2 and also in characters: length: defined
  // in this file (that expects unichar:s)
  enc = _xmlCharsetForCharset(encoding);
  if (enc == XML_CHAR_ENCODING_ERROR)
    {
      NSString *s;

      s = [NSString stringWithData: preparsedContent
		    usingEncodingNamed: [[bodyInfo objectForKey:@"parameterList"]
					  objectForKey: @"charset"]];
      
#if BYTE_ORDER == BIG_ENDIAN
      preparsedContent = [s dataUsingEncoding: NSUTF16BigEndianStringEncoding];
      enc = XML_CHAR_ENCODING_UTF16BE;
#else
      preparsedContent = [s dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      enc = XML_CHAR_ENCODING_UTF16LE;
#endif
    }

  [handler setContentEncoding: enc];
  [parser setContentHandler: handler];
  [parser parseFromSource: preparsedContent];
}

- (NSString *) filename
{
  return [[self clientObject] filename];
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
