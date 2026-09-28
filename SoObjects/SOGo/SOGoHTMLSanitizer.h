/* SOGoHTMLSanitizer.h - this file is part of SOGo
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

#ifndef SOGO_HTML_SANITIZER_H
#define SOGO_HTML_SANITIZER_H

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import <SaxObjC/SaxContentHandler.h>
#import <SaxObjC/SaxLexicalHandler.h>
#include <libxml/encoding.h>

/*
 * SAX content handler that rewrites an HTML mail body for safe
 * display: banned tags are dropped, remote references are neutralized,
 * inline styles are collected and CID references resolved against the
 * attachments of the message.
 */
@interface SOGoHTMLSanitizer : NSObject <SaxContentHandler, SaxLexicalHandler>
{
  NSMutableString *result;
  NSMutableString *css;
  NSDictionary *attachmentIds;
  int embeddedCSSLevel;
  NSMutableArray *ignoredTagStack;
  BOOL inBody;
  BOOL inStyle;
  BOOL inCSSDeclaration;
  BOOL hasEmbeddedCSS;
  xmlCharEncoding contentEncoding;
  BOOL rawContent;
  NSString *pendingAnchorTag;
  NSString *anchorWrapTag;
  NSUInteger anchorWrapDepth;
  NSString *lastAnchorOpenString;
  NSUInteger lastAnchorOpenEnd;
}

- (NSString *) result;
- (NSString *) css;
- (void) activateRawContent;
- (void) setContentEncoding: (xmlCharEncoding) newContentEncoding;
- (void) setAttachmentIds: (NSDictionary *) newAttachmentIds;

+ (NSArray *) voidTags;

@end

#endif /* SOGO_HTML_SANITIZER_H */
