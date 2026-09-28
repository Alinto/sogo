/* UIxMailPartHTMLViewer.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2019 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSData.h>

#import <SaxObjC/SaxLexicalHandler.h>
#import <SaxObjC/SaxXMLReaderFactory.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSString+Encoding.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeType.h>

#include <libxml/encoding.h>

#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/Mailer/NSData+Mail.h>
#import <SoObjects/Mailer/SOGoMailAccounts.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/Mailer/SOGoMailBodyPart.h>

#import <SOGo/SOGoHTMLSanitizer.h>

#import "UIxMailPartHTMLViewer.h"

#if 0
#define showWhoWeAre() NSLog(@"invoked '%@'", NSStringFromSelector(_cmd))
#else
#define showWhoWeAre()
#endif

static xmlCharEncoding
_xmlCharsetForCharset (NSString *charset)
{
  struct { NSString *name; xmlCharEncoding encoding; } xmlEncodings[] = {
    { @"us-ascii", XML_CHAR_ENCODING_ASCII},
    { @"utf-8", XML_CHAR_ENCODING_UTF8},
    { @"utf8", XML_CHAR_ENCODING_UTF8},		// broken mailers
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
    { @"koi8-u", XML_CHAR_ENCODING_ERROR},       // unsupported, will trigger koi8-u -> utf8 conversion
    { @"windows-1250", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1250 -> utf8 conversion
    { @"windows-1251", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1251 -> utf8 conversion
    { @"windows-1255", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1255 -> utf8 conversion
    { @"windows-1256", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1255 -> utf8 conversion
    { @"windows-1257", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1257 -> utf8 conversion
    { @"windows-874", XML_CHAR_ENCODING_ERROR},  // unsupported, will trigger windows-874 -> utf8 conversion
    { @"gb2312", XML_CHAR_ENCODING_ERROR},       // unsupported, will trigger gb2312 -> utf8 conversion
    { @"gbk", XML_CHAR_ENCODING_ERROR},          // unsupported, will trigger gb2312 -> utf8 conversion
    { @"gb18030", XML_CHAR_ENCODING_ERROR},      // unsupported, will trigger gb2312 -> utf8 conversion
    { @"big5", XML_CHAR_ENCODING_ERROR},         // unsupported, will trigger gb2312 -> utf8 conversion
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

static NSString *_sanitizeHtmlForDisplay(NSString *content)
{
  // Sometimes, the mail contains SOGo mail template in the content, and broke mail display
  // replace the responsible css
  return [content stringByReplacingOccurrencesOfString: @"sg-face layout-fill layout-column" withString:@""];;
}


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

  NSLog(@"%@", dump);
  [dump release];
}

@end

@implementation UIxMailPartHTMLViewer

- (id) init
{
  if ((self = [super init]))
    {
      handler = nil;
      ex = nil;
      rawContent = NO;
    }

  return self;
}

- (void)activateRawContent
{
  rawContent = YES;
}

- (void) dealloc
{
  [handler release];
  if (ex) {
    [ex release];
  }
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
  NSMutableData *htmlContent;
  NSString *s;

  xmlCharEncoding enc;

  [self cleanException];

  if ([[self decodedFlatContent] isKindOfClass: [NGMimeBodyPart class]])
    preparsedContent = [[[self decodedFlatContent] body] sanitizedContentUsingVoidTags: [SOGoHTMLSanitizer voidTags]];
  else
    preparsedContent = [[self decodedFlatContent] sanitizedContentUsingVoidTags: [SOGoHTMLSanitizer voidTags]];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];

  handler = [SOGoHTMLSanitizer new];
  if (rawContent)
    [handler activateRawContent];
  [handler setAttachmentIds: attachmentIds];

  // Some broken email messages have some additionnal content outside the main HTML tags which are
  // ignored by libxml.
  // We surround the whole part with additional HTML tags to render all content.
  htmlContent = [NSMutableData dataWithBytes: "<html>" length: 6];
  [htmlContent appendData: preparsedContent];
  [htmlContent appendBytes: "</html>" length: 7];
  preparsedContent = (NSData *)htmlContent;

  // We check if we got an unsupported charset. If so
  // we convert everything to UTF-16{LE,BE} so it passes
  // in libxml2 and also in characters: length: defined
  // in this file (that expects unichar:s)
  enc = [self _xmlCharEncoding];
  if (enc == XML_CHAR_ENCODING_ERROR)
    {
      s = [NSString stringWithData: preparsedContent
		    usingEncodingNamed: [[bodyInfo objectForKey:@"parameterList"]
					  objectForKey: @"charset"]];

      // In some rare cases (like #3276), we can get utterly broken email messages where
      // HTML parts are wrongly encoded. We try to fall back to UTF-8 if that happens and
      // if it still happens, we fall back to ISO-Latin-1.
      if (!s)
        {
          s = [[NSString alloc] initWithData: preparsedContent  encoding: NSUTF8StringEncoding];

          if (!s)
            s = [[NSString alloc] initWithData: preparsedContent  encoding: NSISOLatin1StringEncoding];

          AUTORELEASE(s);
        }

#if BYTE_ORDER == BIG_ENDIAN
      preparsedContent = [s dataUsingEncoding: NSUTF16BigEndianStringEncoding];
      enc = XML_CHAR_ENCODING_UTF16BE;
#else
      preparsedContent = [s dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
      enc = XML_CHAR_ENCODING_UTF16LE;
#endif
    }

  // Let's sanitize the string to make sure libxml doesn't go havoc
  if (enc == XML_CHAR_ENCODING_UTF8)
    {
      s = [[NSString alloc] initWithData: preparsedContent  encoding: NSUTF8StringEncoding];

      // Again, In some rare cases (like #4513), we can get utterly broken email messages where
      // HTML parts are wrongly encoded. We try to fall back to UTF-8 if that happens and
      // if it still happens, we fall back to ISO-Latin-1.
      if (!s)
        s = [[NSString alloc] initWithData: preparsedContent  encoding: NSISOLatin1StringEncoding];

      preparsedContent = [[[s cleanInvalidHTMLTags] safeString] dataUsingEncoding: NSUTF8StringEncoding];
      RELEASE(s);
    }

  [handler setContentEncoding: enc];

  [parser setContentHandler: handler];
  [parser setErrorHandler: self];
  [parser parseFromSource: preparsedContent];
}

- (void)cleanException
{
  ex = nil;
}

- (void)warning:(SaxParseException *)_exception
{

}

- (void)error:(SaxParseException *)_exception
{

}

- (void)fatalError:(SaxParseException *)_exception
{
  ex = [NSException exceptionWithName:[_exception name] reason: [_exception reason] userInfo: [_exception userInfo]];
  [ex retain];
}

- (NSException *)getException
{
  return ex;
}


- (NSString *) cssContent
{
  NSString *cssContent, *css, *newResult;
  NSRegularExpression *regex;
  NSError *error;

  error = nil;

  if (!handler)
    [self _parseContent];

  css = [handler css];
  if ([css length])
    cssContent
      = [NSString stringWithFormat: @"<style type=\"text/css\">%@</style>",
		  [handler css]];
  else
    cssContent = @"";
  
  if([cssContent length])
  {
    regex = [NSRegularExpression regularExpressionWithPattern:@"margin-left\\s*:\\s*-[^;]+(\\s*!important)?"
                                    options: NSRegularExpressionCaseInsensitive error:&error];
    newResult = [regex stringByReplacingMatchesInString:cssContent options:0 range:NSMakeRange(0, [cssContent length]) withTemplate:@"margin-left: 0 !important"];
    cssContent = [NSString stringWithString: newResult];

    regex = [NSRegularExpression regularExpressionWithPattern:@"margin-right\\s*:\\s*-[^;]+(\\s*!important)?"
                                    options: NSRegularExpressionCaseInsensitive error:&error];
    newResult = [regex stringByReplacingMatchesInString:cssContent options:0 range:NSMakeRange(0, [cssContent length]) withTemplate:@"margin-right: 0 !important"];
    cssContent = [NSString stringWithString: newResult];
  }

  return cssContent;
}

- (NSString *) flatContentAsString
{
  if (!handler)
    [self _parseContent];
  
  if (rawContent)
    return [handler result];
  
  return _sanitizeHtmlForDisplay([handler result]);
}

@end

@implementation UIxMailPartExternalHTMLViewer

- (id) init
{
  if ((self = [super init]))
    {
      handler = nil;
      ex = nil;
    }

  return self;
}

- (void) dealloc
{
  [handler release];
  if (ex) {
    [ex release];
  }
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
  SOGoMailBodyPart *part;
  NSString *encoding;
  xmlCharEncoding enc;

  [self cleanException];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];

  if ([[self decodedFlatContent] isKindOfClass: [NGMimeBodyPart class]])
    {
      preparsedContent = [[[self decodedFlatContent] body] sanitizedContentUsingVoidTags: [SOGoHTMLSanitizer voidTags]];
      encoding = [[[self decodedFlatContent] contentType] valueOfParameter: @"charset"];
    }
  else
    {
      part = [self clientObject];
      preparsedContent = [[part fetchBLOB] sanitizedContentUsingVoidTags: [SOGoHTMLSanitizer voidTags]];
      encoding = [[part partInfo] valueForKey: @"encoding"];
    }

  if (![encoding length])
    encoding = @"us-ascii";

  handler = [SOGoHTMLSanitizer new];
  [handler setAttachmentIds: attachmentIds];

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
  [parser setErrorHandler: self];
  [parser parseFromSource: preparsedContent];
}

- (void)cleanException
{
  ex = nil;
}

- (void)warning:(SaxParseException *)_exception
{

}

- (void)error:(SaxParseException *)_exception
{

}

- (void)fatalError:(SaxParseException *)_exception
{
  ex = [NSException exceptionWithName:[_exception name] reason: [_exception reason] userInfo: [_exception userInfo]];
  [ex retain];
}

- (NSException *)getException
{
  return ex;
}

- (NSString *) filename
{
  return [[self clientObject] filename];
}

- (NSString *) cssContent
{
  NSString *cssContent, *css, *newResult;
  NSRegularExpression *regex;
  NSError *error;

  error = nil;

  if (!handler)
    [self _parseContent];

  css = [handler css];
  if ([css length])
    cssContent
      = [NSString stringWithFormat: @"<style type=\"text/css\">%@</style>",
		  [handler css]];
  else
    cssContent = @"";
  
  if([cssContent length])
  {
    regex = [NSRegularExpression regularExpressionWithPattern:@"margin-left\\s*:\\s*-[^;]+(\\s*!important)?"
                                    options: NSRegularExpressionCaseInsensitive error:&error];
    newResult = [regex stringByReplacingMatchesInString:cssContent options:0 range:NSMakeRange(0, [cssContent length]) withTemplate:@"margin-left: 0 !important"];
    cssContent = [NSString stringWithString: newResult];

    regex = [NSRegularExpression regularExpressionWithPattern:@"margin-right\\s*:\\s*-[^;]+(\\s*!important)?"
                                    options: NSRegularExpressionCaseInsensitive error:&error];
    newResult = [regex stringByReplacingMatchesInString:cssContent options:0 range:NSMakeRange(0, [cssContent length]) withTemplate:@"margin-right: 0 !important"];
    cssContent = [NSString stringWithString: newResult];
  }

  return cssContent;
}

- (NSString *) flatContentAsString
{
  if (!handler)
    [self _parseContent];

  return _sanitizeHtmlForDisplay([handler result]);
}

@end
