/* TestSOGoHTMLSanitizer.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
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
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* This file is encoded in utf-8. */

#import "SOGoTest.h"

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>

#import <SaxObjC/SaxXMLReaderFactory.h>

#import <SOGo/SOGoHTMLSanitizer.h>

@interface TestSOGoHTMLSanitizer : SOGoTest
@end

@implementation TestSOGoHTMLSanitizer

- (NSString *) sanitize: (NSString *) html
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSString *wrapped;
  NSData *data;

  wrapped = [NSString stringWithFormat: @"<html>%@</html>", html];
  data = [wrapped dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  [parser setContentHandler: handler];
  [parser parseFromSource: data];

  return [[[handler result] copy] autorelease];
}

/* Bug #6167: a void tag (or a banned tag closed by mismatched events,
   as produced by Outlook conditional comments) left the "ignored
   content" counter stuck, silently dropping the tags and images that
   followed, while the text kept rendering. */
- (void) test_contentAfterVoidTagsIsPreserved
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p>first</p>"
              @"<img src=\"https://example.com/a.png\"/>"
              @"<br/>"
              @"<p>second <b>bold</b></p>"
              @"<img src=\"https://example.com/b.png\"/>"
              @"</body>"];

  error = [NSString stringWithFormat: @"text dropped: %@", result];
  testWithMessage ([result rangeOfString: @"first"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"second"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"tag dropped: %@", result];
  testWithMessage ([result rangeOfString: @"<b>bold</b>"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"image dropped: %@", result];
  testWithMessage ([result rangeOfString: @"a.png"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"b.png"].location != NSNotFound, error);
}

- (void) test_conditionalCommentWrappedImagesArePreserved
{
  NSString *result, *error;

  /* Outlook "downlevel-revealed" conditional comment, as in the report */
  result = [self sanitize:
              @"<body>"
              @"<p>intro</p>"
              @"<a href=\"https://example.com/\">"
              @"<!--[if !mso]><!-->"
              @"<div><img src=\"https://example.com/big.png\"/></div>"
              @"<!--<![endif]-->"
              @"<!--[if mso]><v:roundrect></v:roundrect><![endif]-->"
              @"</a>"
              @"<p>outro</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"content after comment dropped: %@", result];
  testWithMessage ([result rangeOfString: @"intro"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"outro"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"big.png"].location != NSNotFound, error);
}

- (void) test_bannedTagsAreDropped
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p>before</p>"
              @"<script>var evil = 1;</script>"
              @"<p>after</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"script content kept: %@", result];
  testWithMessage ([result rangeOfString: @"evil"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"content after script dropped: %@", result];
  testWithMessage ([result rangeOfString: @"after"].location != NSNotFound, error);
}

/* A banned tag nested inside another banned tag used to wedge the
   ignore counter and drop the remainder of the document. */
- (void) test_nestedBannedTagsDoNotWedgeTheIgnoreState
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<frameset><frame src=\"x\"></frameset>"
              @"<p>kept</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"content after frameset dropped: %@", result];
  testWithMessage ([result rangeOfString: @"kept"].location != NSNotFound, error);
}

/* <link> and <frame> are banned AND void: they must not be pushed on
   the ignore stack, as no end event would ever pop them. */
/* nested same-name banned tags must each pop their own frame,
   otherwise an inner closing tag re-enables emission too early.
   iframe is parsed as CDATA by libxml2 - frameset is the element that
   genuinely nests. */
- (void) test_nestedSameNameBannedTagsAreFullyIgnored
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body><frameset><frameset></frameset>LEAK</frameset><p>kept</p></body>"];
  error = [NSString stringWithFormat: @"banned inner content leaked: %@", result];
  testWithMessage ([result rangeOfString: @"LEAK"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"content after banned block dropped: %@", result];
  testWithMessage ([result rangeOfString: @"kept"].location != NSNotFound, error);
}

/* an unclosed banned tag at EOF must not swallow what precedes it */
- (void) test_unclosedScriptAtEOF
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body><p>kept</p><script>var evil = 1;"];
  error = [NSString stringWithFormat: @"content before unclosed script dropped: %@", result];
  testWithMessage ([result rangeOfString: @"kept"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"script content kept: %@", result];
  testWithMessage ([result rangeOfString: @"evil"].location == NSNotFound, error);
}

/* style blocks are collected in the css accessor, prefixed for scoping */
- (void) test_styleBlocksAreCollected
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *data;
  NSString *css, *error;

  data = [@"<html><body><style>p { color: red; }</style><p>text</p></body></html>"
           dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  [parser setContentHandler: handler];
  [parser parseFromSource: data];

  css = [handler css];
  error = [NSString stringWithFormat: @"css rules not collected or not scoped: %@", css];
  testWithMessage (css != nil
                   && [css rangeOfString: @".SOGoHTMLMail-CSS-Delimiter"].location != NSNotFound,
                   error);
}

- (void) test_bannedVoidTagsDoNotWedgeTheIgnoreState
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p>before</p>"
              @"<link rel=\"stylesheet\" href=\"https://evil/x.css\">"
              @"<frame src=\"https://evil/x\">"
              @"<p>after</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"content after banned void tags dropped: %@", result];
  testWithMessage ([result rangeOfString: @"after"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"banned link kept: %@", result];
  testWithMessage ([result rangeOfString: @"evil/x.css"].location == NSNotFound, error);
}

- (void) test_remoteImageSourcesAreNeutralized
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<img src=\"https://example.com/remote.png\"/>"
              @"<img src=\"data:image/png;base64,iVBORw0KGgo=\"/>"
              @"</body>"];

  error = [NSString stringWithFormat: @"remote src not neutralized: %@", result];
  testWithMessage ([result rangeOfString: @"unsafe-src"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"base64 src neutralized: %@", result];
  testWithMessage ([result rangeOfString: @"data:image/png"].location != NSNotFound, error);
}

- (void) test_cidReferencesAreResolved
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *data;
  NSString *result, *error;

  data = [@"<html><body><img src=\"cid:photo@localhost\"/></body></html>"
           dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];
  [handler setAttachmentIds: [NSDictionary dictionaryWithObject: @"http://x/1"
                                                         forKey: @"<photo@localhost>"]];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  [parser setContentHandler: handler];
  [parser parseFromSource: data];

  result = [[[handler result] copy] autorelease];

  error = [NSString stringWithFormat: @"cid not resolved: %@", result];
  testWithMessage ([result rangeOfString: @"http://x/1"].location != NSNotFound, error);
}

@end
