/* SOGoHTMLSanitizer.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSString+misc.h>

#import "SOGoHTMLSanitizer.h"

/* Tags that are forbidden within the body of the html content */
static NSArray *BannedTags = nil;

/* Tags that can't have any contents (no end tag) */
static NSArray *VoidTags = nil;

@implementation SOGoHTMLSanitizer

+ (void) initialize
{
  if (!BannedTags)
    BannedTags = [[NSArray alloc] initWithObjects: @"script", @"frameset",
                                  @"frame", @"iframe", @"applet", @"link",
                                  @"base", @"meta", @"title", nil];
  [self voidTags];
}

+ (NSArray *) voidTags
{
  if (!VoidTags)
    {
      /* see http://www.w3.org/TR/html4/index/elements.html */
      VoidTags = [[NSArray alloc] initWithObjects: @"area", @"base",
                                  @"basefont", @"br", @"col", @"frame", @"hr",
                                  @"img", @"input", @"isindex", @"link",
                                @"meta", @"param", @"", nil];
    }

  return VoidTags;
}

- (id) init
{
  if ((self = [super init]))
    {
      css = nil;
      result = nil;
      ignoredTagStack = nil;
      attachmentIds = nil;
      contentEncoding = XML_CHAR_ENCODING_UTF8;
      rawContent = NO;
    }

  return self;
}

- (void) dealloc
{
  [result release];
  [css release];
  [ignoredTagStack release];
  [pendingAnchorTag release];
  [anchorWrapTag release];
  [lastAnchorOpenString release];
  [super dealloc];
}

- (void)activateRawContent
{
  rawContent = YES;
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

  [css release];
  [result release];

  result = [NSMutableString new];
  css = [NSMutableString new];

  [ignoredTagStack release];
  ignoredTagStack = nil;

  inBody = NO;
  inStyle = NO;
  inCSSDeclaration = NO;
  hasEmbeddedCSS = NO;
  embeddedCSSLevel = 0;

  [pendingAnchorTag release];
  [anchorWrapTag release];
  [lastAnchorOpenString release];
  pendingAnchorTag = nil;
  anchorWrapTag = nil;
  lastAnchorOpenString = nil;
  anchorWrapDepth = 0;
  lastAnchorOpenEnd = 0;
}

- (void) endDocument
{
}

- (void) startPrefixMapping: (NSString *)_prefix
                        uri: (NSString *)_uri
{
}

- (void) endPrefixMapping: (NSString *)_prefix
{
}

/**
 * About CSS At-Rules (https://css-tricks.com/the-at-rules-of-css/)
 *
 * At-Rules follow two possible synthaxes:
 *
 *   @[KEYWORD] (RULE);
 *     Examples:
 *       @charset "UTF-8";
 *       @import 'global.css';
 *       @namespace svg url(http://www.w3.org/2000/svg);
 *
 *   @[KEYWORD] { (Nested Statements) }
 *     Examples:
 *       @font-face {
 *         font-family: 'MyWebFont';
 *         src:  url('myfont.woff2') format('woff2'),
 *               url('myfont.woff') format('woff');
 *       }
 *       @media only screen
 *         and (min-device-width: 320px)
 *         and (max-device-width: 480px)
 *         and (-webkit-min-device-pixel-ratio: 2) {
 *           .module { width: 100%; }
 *       }
 */
- (void) _appendStyle: (unichar *) _chars
               length: (NSUInteger) _len
{
  NSMutableString *sanitizedStyle, *declaration, *rule;
  NSUInteger count, length, max;
  unichar *sanitizedChars, *start, *currentChar;
  BOOL inComment;

  if (rawContent)
    return;

  /**
   * Sanitize style
   *   - remove control characters
   *   - remove HTML comment delimiters
   *   - remove CSS comments
   */
  sanitizedStyle = [NSMutableString string];
  inComment = NO;
  start = _chars;
  for (count = 0; count < _len; count++)
    {
      currentChar = _chars + count;
      if (*currentChar < 32)
        {
          // Ignore control characters
          if (!inComment && currentChar > start)
            [sanitizedStyle appendString: [NSString stringWithCharacters: start
                                                                  length: (currentChar - start)]];
          start = currentChar + 1;
        }
      else
        {
          if ((currentChar < _chars + _len - 3) &&
              *currentChar     == '<' &&
              *(currentChar+1) == '!' &&
              *(currentChar+2) == '-' &&
              *(currentChar+3) == '-')
            {
              // Ignore starting HTML comment
              if (!inComment && currentChar > start)
                [sanitizedStyle appendString: [NSString stringWithCharacters: start
                                                                      length: (currentChar - start)]];
              start = currentChar + 4;
            }
          else if ((currentChar < _chars + _len - 2) &&
                   *currentChar     == '-' &&
                   *(currentChar+1) == '-' &&
                   *(currentChar+2) == '>')
            {
              // Ignore ending HTML comment
              if (!inComment && currentChar > start)
                [sanitizedStyle appendString: [NSString stringWithCharacters: start
                                                                      length: (currentChar - start)]];
              start = currentChar + 3;
            }
          if (currentChar < _chars + _len - 1)
            {
              // Ignore CSS comments
              if (*currentChar == '/' && *(currentChar+1) == '*')
                {
                  inComment = YES;
                  if (currentChar > start)
                    [sanitizedStyle appendString: [NSString stringWithCharacters: start
                                                                          length: (currentChar - start)]];
                }
              else if (*currentChar == '*' && *(currentChar+1) == '/')
                {
                  inComment = NO;
                  start = currentChar + 2;
                }
            }
        }
    }
  if (!inComment && currentChar > start) {
    if (*currentChar == '}' && *currentChar++ == '\000') currentChar++; // Add offset
    [sanitizedStyle appendString: [NSString stringWithCharacters: start
                                               length: (currentChar - start)]];
  }
  /**
   * Parse sanitized style
   *   - remove at-rule definitions
   *   - add custom class to selectors
   *   - add !important suffix to all rules
   */
  rule = [NSMutableString string];
  max = [sanitizedStyle length];
  sanitizedChars = NSZoneMalloc (NULL, max * sizeof (unichar));
  [sanitizedStyle getCharacters: sanitizedChars];
  start = sanitizedChars;
  currentChar = start;
  for (count = 0; count < max; count++)
    {
      currentChar = sanitizedChars + count;
      if (inCSSDeclaration)
        {
          if (*currentChar == '}')
            {
              // Prefix CSS rule including ending curly bracket
              inCSSDeclaration = NO;
              length = (currentChar - start) + 1;
              [declaration appendString: [NSString stringWithCharacters: start length: length]];
              [css appendString: declaration];
              start = currentChar + 1;
            }
          else if (*currentChar == ';')
            {
              // Add !important
              if ((currentChar < sanitizedChars + 10) ||
                  !((*(currentChar-1) == 't' || *(currentChar-1) == 'T') &&
                    (*(currentChar-2) == 'n' || *(currentChar-2) == 'N') &&
                    (*(currentChar-3) == 'a' || *(currentChar-3) == 'A') &&
                    (*(currentChar-4) == 't' || *(currentChar-4) == 'T') &&
                    (*(currentChar-5) == 'r' || *(currentChar-5) == 'R') &&
                    (*(currentChar-6) == 'o' || *(currentChar-6) == 'O') &&
                    (*(currentChar-7) == 'p' || *(currentChar-7) == 'P') &&
                    (*(currentChar-8) == 'm' || *(currentChar-8) == 'M') &&
                    (*(currentChar-9) == 'i' || *(currentChar-9) == 'I') &&
                    *(currentChar-10) == '!'))
                {
                  length = (currentChar - start);
                  [declaration appendFormat: @"%@ !important;",
                               [NSString stringWithCharacters: start length: length]];
                  start = currentChar + 1;
                }
            }
        }
      else
        {
          if (*currentChar == '{')
            {
              if (hasEmbeddedCSS)
                {
                  embeddedCSSLevel++;
                }
              else
                {
                  // Start of rule declaration
                  inCSSDeclaration = YES;
                  length = (currentChar - start);
                  [rule appendFormat: @".SOGoHTMLMail-CSS-Delimiter %@ {",
                        [NSString stringWithCharacters: start length: length]];
                  [css appendString: rule];
                  rule = [NSMutableString string];
                  declaration = [NSMutableString string];
                }
              start = currentChar + 1;
            }
          if (*currentChar == '}')
            {
              if (hasEmbeddedCSS)
                {
                  embeddedCSSLevel--;
                  if (embeddedCSSLevel <= 0)
                    hasEmbeddedCSS = NO;
                }
              else
                {
                  // CSS syntax error: ending declaration character while not in a CSS declaration.
                  // Ignore eveything from last CSS declaration.
                  rule = [NSMutableString string];
                }
              start = currentChar + 1;
            }
          else if (*currentChar == ',')
            {
              if (!hasEmbeddedCSS)
                {
                  // Prefix CSS selector
                  length = (currentChar - start);
                  [rule appendFormat: @" .SOGoHTMLMail-CSS-Delimiter %@,",
                        [NSString stringWithCharacters: start length: length]];
                }
              start = currentChar + 1;
            }
          else if (*currentChar == '@')
            {
              // Start of at-rule definition
              hasEmbeddedCSS = YES;
              embeddedCSSLevel = 0;
            }
        }
    }
  if (currentChar > start)
    {
      [css appendString: [NSString stringWithCharacters: start
                                                 length: (currentChar - start)]];
    }

  NSZoneFree (NULL, sanitizedChars);
}

- (void) startElement: (NSString *) _localName
            namespace: (NSString *) _ns
              rawName: (NSString *) _rawName
           attributes: (id <SaxAttributes>) _attributes
{
  unsigned int count, max;
  NSString *name, *value, *cid, *lowerName, *lowerValue;
  NSMutableString *resultPart;
  BOOL skipAttribute;


  lowerName = [_localName lowercaseString];
  if (inStyle)
    ;
  else if ([BannedTags containsObject: lowerName])
    {
      /* Banned subtrees are tracked on a stack so that mismatched
         events on malformed content cannot wedge the ignore state
         (#6167). Nested same-name banned starts are pushed as well, so
         that an inner closing tag pops its own frame. Banned-but-void
         elements (frame, link) are dropped without being pushed: no
         end event is guaranteed to come and pop them. */
      if (![VoidTags containsObject: lowerName])
        {
          if (!ignoredTagStack)
            ignoredTagStack = [NSMutableArray new];
          [ignoredTagStack addObject: lowerName];
        }
    }
  else if ([ignoredTagStack count])
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
          // If a libxml2-orphaned <a> is waiting, re-open it around the next
          // block element (HTML5 pattern <a><table>...</table></a>).
          // Skip if the next element is itself <a> (avoids invalid nesting).
          if (pendingAnchorTag != nil)
            {
              if ([lowerName isEqualToString: @"a"])
                {
                  [pendingAnchorTag release];
                  pendingAnchorTag = nil;
                }
              else
                {
                  [result appendString: pendingAnchorTag];
                  [anchorWrapTag release];
                  anchorWrapTag = [lowerName copy];
                  anchorWrapDepth = 1;
                  [pendingAnchorTag release];
                  pendingAnchorTag = nil;
                }
            }
          else if (anchorWrapTag != nil
                   && [lowerName isEqualToString: anchorWrapTag])
            {
              anchorWrapDepth++;
            }

          resultPart = [NSMutableString string];
          [resultPart appendFormat: @"<%@", _rawName];

          max = [_attributes count];
          for (count = 0; count < max; count++)
            {
              skipAttribute = NO;
              name = [[_attributes nameAtIndex: count] lowercaseString];
              if ([name isEqualToString: @"src"])
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
                      
                      //Check if the image is base64 ant not url
                      NSUInteger i, c;
                      BOOL isBase64 = NO;
                      for (i = 0, c = [_attributes count]; i < c; i++) {
                        NSString *type, *value;
                        type = [_attributes nameAtIndex:i];
                        if ([type isEqualToString:@"src"])
                        {
                          value = [_attributes valueAtIndex:i];
                          if([value length] > 4 && [[value substringToIndex: 4] isEqualToString:@"data"])
                          {
                            isBase64 = YES;
                            break;
                          }
                        }
                      }
                      if(!isBase64)
                        name = @"unsafe-src";
                    }
                  else
                    skipAttribute = YES;
                }
              else if ([name isEqualToString: @"background"] ||
                       (([name isEqualToString: @"data"]
                         || [name isEqualToString: @"classid"])
                        && [lowerName isEqualToString: @"object"]))
                {
                  value = [_attributes valueAtIndex: count];
                  name = [NSString stringWithFormat: @"unsafe-%@", name];
                }
              else if ([name isEqualToString: @"href"]
                       || [name isEqualToString: @"action"]
                       || [name isEqualToString: @"formaction"])
                {
                  value = [_attributes valueAtIndex: count];
                  lowerValue = [[value lowercaseString] stringByReplacingString: @"\""
                                                                     withString: @""];
                  skipAttribute =
                    ([lowerValue rangeOfString: @"://"].location == NSNotFound
                     && ![lowerValue hasPrefix: @"mailto:"]
                     && ![lowerValue hasPrefix: @"#"])
                    || [lowerValue rangeOfString: @"javascript:"].location != NSNotFound;
                  if (!skipAttribute)
                    [resultPart appendString: @" rel=\"noopener\""];
                }
              // Avoid: <div style="background:url('http://www.sogo.nu/fileadmin/sogo/logos/sogo.bts.png' ); width: 200px; height: 200px;" title="ssss">
              else if ([name isEqualToString: @"style"])
                {
                  value = [_attributes valueAtIndex: count];
                  lowerValue = [[value lowercaseString] stringByReplacingString: @"\""
                                                                     withString: @""];
                  if ([lowerValue rangeOfString: @"url"].location != NSNotFound)
                    name = [NSString stringWithFormat: @"unsafe-%@", name];
                }
	      else if ([name isEqualToString: @"rel"])
		{
		  skipAttribute = YES;
		}
	      else if ([name hasPrefix: @"on"])
		{
                  // on Events
		  skipAttribute = YES;
		}
              else
                value = [_attributes valueAtIndex: count];
              
              if (!skipAttribute)
                [resultPart appendFormat: @" %@=\"%@\"",
                            name, [value stringByReplacingString: @"\""
                                                  withString: @""]];
            }
          
          if ([VoidTags containsObject: lowerName])
            [resultPart appendString: @"/"];
          [resultPart appendString: @">"];
          [result appendString: resultPart];

          if ([lowerName isEqualToString: @"a"])
            {
              [lastAnchorOpenString release];
              lastAnchorOpenString = [resultPart copy];
              lastAnchorOpenEnd = [result length];
            }
    }
}

- (void) _finishCSS
{
  [css replaceString: @"<!--" withString: @""];
  [css replaceString: @"-->" withString: @""];
  [css replaceString: @".SOGoHTMLMail-CSS-Delimiter body"
       withString: @".SOGoHTMLMail-CSS-Delimiter"];
}

- (void) endElement: (NSString *) _localName
          namespace: (NSString *) _ns
            rawName: (NSString *) _rawName
{
  NSString *lowerName;


  lowerName = [_localName lowercaseString];

  if ([ignoredTagStack count])
    {
      NSUInteger idx;

      /* Pop everything up to the matching banned tag; closing tags of
         non-banned children are swallowed. */
      for (idx = [ignoredTagStack count]; idx > 0; idx--)
        if ([[ignoredTagStack objectAtIndex: idx - 1] isEqualToString: lowerName])
          {
            [ignoredTagStack removeObjectsInRange:
                         NSMakeRange (idx - 1, [ignoredTagStack count] - idx + 1)];
            break;
          }
    }
  else if ([BannedTags containsObject: lowerName])
    /* synthesized end events of banned-but-void elements must not leak
       into the output */
    ;
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
              // Assume <body> never ends to properly display incorrectly constructed messages.
              // See bug #4492
              // inBody = NO;
              if (css)
                [self _finishCSS];
            }
          else
            {
              // Empty <a> auto-closed by libxml2 right after opening:
              // strip it from result and remember it to wrap the next block.
              if ([lowerName isEqualToString: @"a"]
                  && lastAnchorOpenString != nil
                  && [result length] == lastAnchorOpenEnd)
                {
                  NSUInteger tagLen = [lastAnchorOpenString length];
                  [result deleteCharactersInRange:
                            NSMakeRange(lastAnchorOpenEnd - tagLen, tagLen)];
                  [pendingAnchorTag release];
                  pendingAnchorTag = lastAnchorOpenString;
                  lastAnchorOpenString = nil;
                  lastAnchorOpenEnd = 0;
                  return;
                }
              if ([lowerName isEqualToString: @"a"])
                {
                  [lastAnchorOpenString release];
                  lastAnchorOpenString = nil;
                  lastAnchorOpenEnd = 0;
                }

              //NSLog (@"%@", _localName);
              [result appendFormat: @"</%@>", _localName];

              if (anchorWrapTag != nil
                  && [lowerName isEqualToString: anchorWrapTag])
                {
                  anchorWrapDepth--;
                  if (anchorWrapDepth == 0)
                    {
                      [result appendString: @"</a>"];
                      [anchorWrapTag release];
                      anchorWrapTag = nil;
                    }
                }
            }
        }
    }
}

- (void) characters: (unichar *) _chars
             length: (NSUInteger) _len
{
  if (![ignoredTagStack count])
    {
      if (inStyle)
        [self _appendStyle: _chars length: _len];
      else if (inBody)
        {
	  NSString *s;

          s = [NSString stringWithCharacters: _chars length: _len];

          if (pendingAnchorTag != nil
              && [[s stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0)
            {
              [pendingAnchorTag release];
              pendingAnchorTag = nil;
            }

	  // HACK: This is to avoid appending the useless junk in the <html> tag
	  //       that Outlook adds. It seems to confuse the XML parser for
	  //       forwarded messages as we get this in the _body_ of the email
	  //       while we really aren't in it!
	  if (![s hasPrefix: @" xmlns:v=\"urn:schemas-microsoft-com:vml\""])
	    [result appendString: [s stringByEscapingHTMLString]];
        }
    }
}

- (void) ignorableWhitespace: (unichar *) _chars
                      length: (NSUInteger) _len
{
}

- (void) processingInstruction: (NSString *) _pi
                          data: (NSString *) _data
{
}

- (void) setDocumentLocator: (id <NSObject, SaxLocator>) _locator
{
}

- (void) skippedEntity: (NSString *) _entityName
{
}

/* SaxLexicalHandler */
- (void) comment: (unichar *) _chars
          length: (int) _len
{
  if (inStyle)
    [self _appendStyle: _chars length: _len];
}

- (void) startDTD: (NSString *) _name
         publicId: (NSString *) _pub
         systemId: (NSString *) _sys
{
}

- (void) endDTD
{
}

- (void) startEntity: (NSString *) _name
{
}

- (void) endEntity: (NSString *) _name
{
}

- (void) startCDATA
{
}

- (void) endCDATA
{
}

@end
