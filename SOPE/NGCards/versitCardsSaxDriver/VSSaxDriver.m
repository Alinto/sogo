/*
  Copyright (C) 2003-2004 Max Berger
  Copyright (C) 2004-2005 OpenGroupware.org
 
  This file is part of versitCardsSaxDriver, written for the OpenGroupware.org 
  project (OGo).
  
  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.
  
  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.
  
  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

/* FIXME: this class is badly designed. It is expected to feed
          NGVCardSaxHandler with correct values but it won't handle escaped
          commas. Also, it should handle CardGroups and CardElements
          correctly: treat the former as open/close tags and the latter as
          simple tags. Wrt that, the methods startGroupElement/endGroupElement
          are not expected in a sax handler... this is all wrong. */

#import "VSSaxDriver.h"
#import "VSStringFormatter.h"
#import <SaxObjC/SaxException.h>
#import <NGExtensions/NGQuotedPrintableCoding.h>
#import <NGCards/NSString+NGCards.h>
#import "common.h"

@interface VSSaxTag : NSObject
{
@private;
  char          type;
  NSString      *tagName;
  NSString      *group;
@public;
  SaxAttributes *attrs;
  unichar       *data;
  unsigned int  datalen;
  BOOL groupElement;
}

+ (id) beginTag: (NSString *) _tag
          group: (NSString *) _group
     attributes: (SaxAttributes *) _attrs;
- (id) initEndTag: (NSString *) _tag;

- (id) initWithContentString: (NSString *) _data;
- (void) setGroupElement: (BOOL) aBool;

- (NSString *) tagName;
- (NSString *) group;
- (BOOL) isStartTag;
- (BOOL) isEndTag;
- (BOOL) isTag;

@end

@implementation VSSaxTag

+ (id) beginTag: (NSString *) _tag
          group: (NSString *) _group
     attributes: (SaxAttributes *) _attrs
{
  VSSaxTag *tag;

  tag = [[self new] autorelease];
  tag->type = 'B';
  tag->tagName = [_tag copy];
  tag->group = [_group copy];
  tag->attrs = [_attrs retain];

  return tag;
}

- (id) init
{
  if ((self = [super init]))
    {
      groupElement = NO;
      data = NULL;
    }

  return self;
}

- (id) initEndTag: (NSString *) _tag
{
  type = 'E';
  tagName = [_tag copy];

  return self;
}

- (id) initWithContentString: (NSString *) _data
{
  if (!_data)
    {
      [self release];
      return nil;
    }

  datalen = [_data length];
  data = calloc(datalen + 1, sizeof(unichar));
  [_data getCharacters: data range: NSMakeRange(0, datalen)];
  return self;
}

- (void) setGroupElement: (BOOL) aBool
{
  groupElement = aBool;
}

- (void) dealloc {
  if (data) free (data);
  [group   release];
  [tagName release];
  [attrs   release];
  [super dealloc];
}

- (char) tagType
{
  return type;
}

/* accessors */

- (NSString *) tagName {
  return tagName;
}
- (NSString *) group {
  return group;
}

- (BOOL) isStartTag {
  return type == 'B' ? YES : NO;
}
- (BOOL) isEndTag {
  return type == 'E' ? YES : NO;
}
- (BOOL) isTag {
  return (type == 'B' || type == 'E') ? YES : NO;
}

@end /* VSSaxTag */

@implementation VSSaxDriver

static BOOL debugOn = NO;

static NSCharacterSet *dotCharSet = nil;
static NSCharacterSet *equalSignCharSet = nil;
static NSCharacterSet *commaCharSet = nil;
static NSCharacterSet *colonAndSemicolonCharSet = nil;
static NSCharacterSet *colonSemicolonAndDquoteCharSet = nil;
static NSCharacterSet *whitespaceCharSet = nil;

static VSStringFormatter *stringFormatter = nil;

+ (void) initialize
{
  static BOOL didInit = NO;
  NSUserDefaults *ud;

  if (didInit)
    return;
  didInit = YES;

  ud = [NSUserDefaults standardUserDefaults];
  debugOn = [ud boolForKey: @"VSSaxDriverDebugEnabled"];

  dotCharSet =
    [[NSCharacterSet characterSetWithCharactersInString: @"."] retain];
  equalSignCharSet =
    [[NSCharacterSet characterSetWithCharactersInString: @"="] retain];
  commaCharSet =
    [[NSCharacterSet characterSetWithCharactersInString: @","] retain];
  colonAndSemicolonCharSet =
    [[NSCharacterSet characterSetWithCharactersInString: @":;"] retain];
  colonSemicolonAndDquoteCharSet =
    [[NSCharacterSet characterSetWithCharactersInString: @":;\""] retain];
  whitespaceCharSet =
    [[NSCharacterSet whitespaceCharacterSet] retain];

  stringFormatter = [VSStringFormatter sharedFormatter];
}

- (id) init {
  if ((self = [super init]))
    {
      prefixURI = @"";
      cardStack = [[NSMutableArray alloc]      initWithCapacity: 4];
      elementList = [[NSMutableArray alloc]      initWithCapacity: 8];
    }

  return self;
}

- (void) dealloc
{
  [contentHandler    release];
  [errorHandler      release];
  [prefixURI         release];
  [cardStack         release];
  [elementList       release];
  [super dealloc];
}

/* accessors */

- (void) setFeature: (NSString *) _name to: (BOOL) _value
{
}

- (BOOL) feature: (NSString *) _name
{
  return NO;
}

- (void) setProperty: (NSString *) _name to: (id) _value
{
}

- (id) property: (NSString *) _name
{
  return nil;
}

/* handlers */

- (void) setContentHandler: (id<NSObject,SaxContentHandler>) _handler
{
  ASSIGN(contentHandler, _handler);
}

- (void) setDTDHandler: (id<NSObject,SaxDTDHandler>) _handler
{
  // FIXME
}

- (void) setErrorHandler: (id<NSObject,SaxErrorHandler>) _handler
{
  ASSIGN(errorHandler, _handler);
}

- (void) setEntityResolver: (id<NSObject,SaxEntityResolver>) _handler
{
  // FIXME
}

- (id<NSObject,SaxContentHandler>) contentHandler
{
  return contentHandler;
}

- (id<NSObject,SaxDTDHandler>) dtdHandler
{
  // FIXME
  return nil;
}

- (id<NSObject,SaxErrorHandler>) errorHandler
{
  return errorHandler;
}

- (id<NSObject,SaxEntityResolver>) entityResolver
{
  // FIXME
  return nil;
}

- (void) setPrefixURI: (NSString *) _uri
{
  ASSIGNCOPY(prefixURI, _uri);
}

- (NSString *) prefixURI
{
  return prefixURI;
}

/* parsing */

- (NSString *) _groupFromTagName: (NSString *) _tagName
{
  NSRange  r;
  
  r = [_tagName rangeOfCharacterFromSet: dotCharSet];
  if (!r.length)
    return nil;
  
  return [_tagName substringToIndex: r.location];
}

- (NSString *) _mapTagName: (NSString *) _tagName
{
  NSString *ret;
  NSRange  r;

  //NSLog(@"Unknown Key: %@ in %@",_tagName,elementMapping);
  ret = _tagName;
  
  /*
    This is to allow parsing of vCards produced by Apple
    Addressbook.
    The dot-notation is described as 'grouping' in RFC 2425, section 5.8.2.
  */
  r = [_tagName rangeOfCharacterFromSet: dotCharSet];
  if (r.length > 0)
    ret = [self _mapTagName: [_tagName substringFromIndex: (r.location + 1)]];
  
  return ret;
}

- (void) _parseAttr: (NSString *) _attr 
             forTag: (NSString *) _tagName
           intoAttr: (NSString **) attr_
          intoValue: (NSString **) value_
{
  NSRange  r;
  NSString *attrName, *attrValue;
  
  r = [_attr rangeOfCharacterFromSet: equalSignCharSet];
  if (r.length > 0)
    {
      unsigned left, right;

      attrName = [[_attr substringToIndex: r.location] uppercaseString];
      left = NSMaxRange(r);
      right = [_attr length] - 1;
      if (left < right)
        {
          if (([_attr characterAtIndex: left]  == '"') &&
              ([_attr characterAtIndex: right] == '"'))
            {
              left += 1;
              r = NSMakeRange(left, right - left);
              attrValue = [_attr substringWithRange: r];
            }
          else
            {
              attrValue = [_attr substringFromIndex: left];
            }
        }
      else if (left == right)
        {
          attrValue = [_attr substringFromIndex: left];
        }
      else
        {
          attrValue = @"";
        }
    }
  else
    {
      if ([[_attr uppercaseString] isEqualToString: @"QUOTED-PRINTABLE"])
        attrName = @"ENCODING";
      else
        attrName = @"TYPE";
      attrValue = _attr;
    }
  
#if 0
  // ZNeK: what's this for?
  r = [attrValue rangeOfCharacterFromSet: commaCharSet];
  while (r.length > 0)
    {
      [attrValue replaceCharactersInRange: r withString: @" "];
      r = [attrValue rangeOfCharacterFromSet: commaCharSet];
    }
#endif

  *attr_ = attrName;
  *value_ = [attrValue unescapedFromCard];
//   *value_ = [stringFormatter stringByUnescapingRFC2445Text: attrValue];
}

- (SaxAttributes *) _mapAttrs: (NSArray *) _attrs
                       forTag: (NSString *) _tagName
{
  SaxAttributes *retAttrs;
  NSEnumerator *attrEnum, *values;
  NSString *curAttr, *mappedAttr, *mappedValue, *curValue;

  /*
    TODO: values are not always mapped to CDATA! Eg in the dawson draft: 
    | TYPE for TEL   | tel.type   | NMTOKENS  | 'VOICE'         |
    | TYPE for EMAIL | email.type | NMTOKENS  | 'INTERNET'      |
    | TYPE for PHOTO,| img.type   | CDATA     | REQUIRED        |
    |  and LOGO      |            |           |                 |
    | TYPE for SOUND | aud.type   | CDATA     | REQUIRED        |
    | VALUE          | value      | NOTATION  | See elements    |
  */

  if (_attrs && [_attrs count] > 0)
    {
      retAttrs = [[SaxAttributes alloc] init];
      [retAttrs autorelease];

      attrEnum = [_attrs objectEnumerator];
      curAttr = [attrEnum nextObject];
      while (curAttr)
        {
          [self _parseAttr: curAttr
                forTag: _tagName
                intoAttr: &mappedAttr
                intoValue: &mappedValue];
          values = [[mappedValue asCardAttributeValues] objectEnumerator];
          curValue = [values nextObject];
          while (curValue)
            {
              [retAttrs addAttribute: mappedAttr
                        uri: prefixURI
                        rawName: mappedAttr
                        type: @"CDATA"
                        value: curValue];
              curValue = [values nextObject];
            }
          curAttr = [attrEnum nextObject];
        }
    }
  else
    retAttrs = nil;

  return retAttrs;
}

- (VSSaxTag *) _beginTag: (NSString *) _tagName
                   group: (NSString *) _group
               withAttrs: (SaxAttributes *) _attrs
{
  VSSaxTag *tag;
  
  tag = [VSSaxTag beginTag: [_tagName uppercaseString]
                  group: _group attributes: _attrs];
  [elementList addObject: tag];

  return tag;
}

- (void) _endTag: (NSString *) _tagName
{
  VSSaxTag *tag;
  
  tag = [[VSSaxTag alloc] initEndTag: _tagName];
  [elementList addObject: tag];
  [tag release]; tag = nil;
}

- (void) _endGroupElementTag: (NSString *) _tagName
{
  VSSaxTag *tag;
  
  tag = [[VSSaxTag alloc] initEndTag: _tagName];
  [elementList addObject: tag];
  [tag setGroupElement: YES];
  [tag release]; tag = nil;
}

- (void) _reportContentAsTag: (NSString *) _tagName
                       group: (NSString *) _group
                   withAttrs: (SaxAttributes *) _attrs 
                  andContent: (NSString *) _content 
{
  VSSaxTag *a;
  NSString *testContent;

  /* This is called for all non-BEGIN|END types. */
  testContent = [[_content unescapedFromCard] stringByReplacingString: @";"
					      withString: @""];

  if ([[testContent stringByTrimmingSpaces] length] > 0)
    {
      [self _beginTag: _tagName group: _group withAttrs: _attrs];
  
      a = [(VSSaxTag *)[VSSaxTag alloc]
                       initWithContentString: [_content unescapedFromCard]];
      if (a)
        {
          [elementList addObject: a];
          [a release];
        }

      [self _endTag: _tagName];
    }
}

/* report events for collected elements */

- (void) reportStartGroup: (NSString *) _group
{
  SaxAttributes *attrs;
  
  attrs = [[SaxAttributes alloc] init];
  [attrs addAttribute: @"name" uri: prefixURI rawName: @"name"
	 type: @"CDATA" value: _group];
  
  [contentHandler startElement: @"group"
                  namespace: prefixURI
                  rawName: @"group"
                  attributes: attrs];
  [attrs release];
}

- (void) reportEndGroup
{
  [contentHandler endElement: @"group"
                  namespace: prefixURI
                  rawName: @"group"];
}

- (void) reportStartContainer: (NSString *) _container
{
  SaxAttributes *attrs;
  
  attrs = [[SaxAttributes alloc] init];
  [attrs addAttribute: @"name"
         uri: prefixURI
         rawName: @"name"
	 type: @"CDATA"
         value: _container];
  [contentHandler startElement: @"container"
                  namespace: prefixURI
                  rawName: @"container"
                  attributes: attrs];
  [attrs release];
}

- (void) reportEndContainer
{
  [contentHandler endElement: @"container"
                  namespace: prefixURI
                  rawName: @"container"];
}

- (void) reportQueuedTags
{
  /*
    Why does the parser need the list instead of reporting the events
    straight away?
    
    Because some vCard tags like the 'version' are reported as attributes
    on the container tag. So we have a sequence like: 
    BEGIN: VCARD
    ...
    VERSION: 3.0
    which will get reported as: 
    <vcard version="3.0">
  */
  NSEnumerator *enu;
  VSSaxTag *tagToReport;
  NSString *lastGroup, *tg, *tagName;
  
  lastGroup = nil;

  enu = [elementList objectEnumerator];
  tagToReport = [enu nextObject];
  while (tagToReport)
    {
      tagName = [tagToReport tagName];

      if ([tagToReport isStartTag])
        {
         tg = [tagToReport group];
          if (![lastGroup isEqualToString: tg]
              && lastGroup != tg)
            {
              if (lastGroup) [self reportEndGroup];
              ASSIGNCOPY(lastGroup, tg);
              if (lastGroup) [self reportStartGroup: lastGroup];
            }
        }

      if ([tagToReport isStartTag])
        {
          if (tagToReport->groupElement)
            [self reportStartContainer: tagName];
          else
            [contentHandler startElement: tagName
                            namespace: prefixURI
                            rawName: tagName
                            attributes: tagToReport->attrs];
        }
      else if ([tagToReport isEndTag])
        {
          if (tagToReport->groupElement)
            [self reportEndContainer];
          else
            [contentHandler endElement: tagName
                            namespace: prefixURI
                            rawName: tagName];
        }
      else
        [contentHandler characters: tagToReport->data
                        length: tagToReport->datalen];

      tagToReport = [enu nextObject];
    }

  /* flush event group */
  [elementList removeAllObjects];

  /* close open groups */
  if (lastGroup)
    {
      [self reportEndGroup];
      [lastGroup release];
      lastGroup = nil;
    }
}

/* errors */

- (void) reportError: (NSString *) _text
{
  SaxParseException *e;

  e = (id)[SaxParseException exceptionWithName: @"SaxParseException"
			     reason: _text
			     userInfo: nil];
  [errorHandler error: e];
}

- (void) warn: (NSString *) _warn
{
  SaxParseException *e;

  e = (id)[SaxParseException exceptionWithName: @"SaxParseException"
			     reason: _warn
			     userInfo: nil];
  [errorHandler warning: e];
}

/* parsing raw string */

- (void) _beginComponentWithValue: (NSString *) tagValue
{
  VSSaxTag *tag;

  tag = [self _beginTag: [self _mapTagName: tagValue]
	      group: nil
	      withAttrs: [[[SaxAttributes alloc] init] autorelease]];
  [tag setGroupElement: YES];
  [cardStack addObject: tag];
}

- (void) _endComponent: (NSString *) tagName
                 value: (NSString *) tagValue
{
  NSString *mtName;
  
  mtName = [[self _mapTagName: tagValue] uppercaseString];
  if ([cardStack count] > 0)
    {
      NSString *expectedName;
      
      expectedName = [(VSSaxTag *)[cardStack lastObject] tagName];
      if (![expectedName isEqualToString: mtName])
        {
          NSString *s;
	
          // TODO: rather report an error?
          // TODO: setup userinfo dict with details
          s = [NSString stringWithFormat: 
                          @"Found end tag '%@' which does not match expected "
		        @"name '%@'!"
		        @" Tag '%@' has not been closed properly. Given "
		        @"document contains errors!",
		        mtName, expectedName, expectedName];
          [self reportError: s];
	
          /* probably futile attempt to parse anyways */
          if (debugOn)
            {
              NSLog(@"%s trying to fix previous error by inserting bogus end "
                    @"tag.",
                    __PRETTY_FUNCTION__);
            }
          [self _endGroupElementTag: expectedName];
          [cardStack removeLastObject];
        }
    }
  else
    {
      // TOOD: generate error?
      [self reportError: [@"found end tag without any open tags left: "
                           stringByAppendingString: mtName]];
    }
  [self _endGroupElementTag: mtName];
  [cardStack removeLastObject];
    
  /* report parsed elements */
    
  if ([cardStack count] == 0)
    [self reportQueuedTags];
}

- (void) _parseLine: (NSString *) _line
{
  NSString       *tagName, *tagValue;
  NSMutableArray *tagAttributes;
  NSRange        r, todoRange;
  unsigned       length;
  
#if 0
  if (debugOn)
    NSLog(@"%s: parse line: '%@'", __PRETTY_FUNCTION__, _line);
#endif

  length = [_line length];
  todoRange = NSMakeRange(0, length);
  r = [_line rangeOfCharacterFromSet: colonAndSemicolonCharSet
             options: 0
             range: todoRange];
  /* is line well-formed? */
  if (!r.length || !r.location)
    {
#if 0
      NSLog(@"todo-range: %i-%i, range: %i-%i, length %i, str-class %@",
            todoRange.location, todoRange.length,
            r.location, r.length,
            length, NSStringFromClass([_line class]));
#endif

      [self reportError: 
              [@"got an improper content line! (did not find colon) ->\n" 
                stringByAppendingString: _line]];
      return;
    }
  
  /* tagname is everything up to a ': ' or  ';' (value or parameter) */
  tagName = [[_line substringToIndex: r.location] uppercaseString];
  tagAttributes = [[NSMutableArray alloc] initWithCapacity: 16];
  
  if (debugOn && ([tagName length] == 0))
    {
      [self reportError: [@"got an improper content line! ->\n" 
                           stringByAppendingString: _line]];
      return;
    }
  
  /* 
     possible shortcut: if we spotted a ': ', we don't have to do "expensive"
     argument scanning/processing.
  */
  if ([_line characterAtIndex: r.location] != ':')
    {
      BOOL isAtEnd = NO;
      BOOL isInDquote = NO;
      unsigned start;
    
      start = NSMaxRange(r);
      todoRange = NSMakeRange(start, length - start);
      while(!isAtEnd)
        {
          BOOL skip = YES;

          /* scan for parameters */
          r = [_line rangeOfCharacterFromSet: colonSemicolonAndDquoteCharSet
                     options: 0
                     range: todoRange];
      
          /* is line well-formed? */
          if (!r.length || !r.location)
            {
              [self reportError: [@"got an improper content line! ->\n" 
                                   stringByAppendingString: _line]];
              [tagAttributes release]; tagAttributes = nil;
              return;
            }
      
          /* first check if delimiter candidate is escaped */
          if ([_line characterAtIndex: (r.location - 1)] != '\\')
            {
              unichar delimiter;
              NSRange copyRange;

              delimiter = [_line characterAtIndex: r.location];
              if (delimiter == '\"')
                {
                  /* not a real delimiter - toggle isInDquote for proper escaping */
                  isInDquote = !isInDquote;
                }
              else
                {
                  if (!isInDquote)
                    {
                      /* is a delimiter, which one? */
                      skip = NO;
                      if (delimiter == ':')
                        {
                          isAtEnd = YES;
                        }
                      copyRange = NSMakeRange(start, r.location - start);
                      [tagAttributes addObject: [_line substringWithRange: copyRange]];
                      if (!isAtEnd)
                        {
                          /* adjust start, todoRange */
                          start = NSMaxRange(r);
                          todoRange = NSMakeRange(start, length - start);
                        }
                    }
                }
            }
          if (skip)
            {
              /* adjust todoRange */
              unsigned offset = NSMaxRange(r);
              todoRange = NSMakeRange(offset, length - offset);
            }
        }
    }
  tagValue = [_line substringFromIndex: NSMaxRange(r)];
  
  if (debugOn && ([tagName length] == 0))
    {
      NSLog(@"%s: missing tagname in line: '%@'", 
            __PRETTY_FUNCTION__, _line);
    }
  
  /*
    At this point we have: 
    name:       'BEGIN', 'TEL', 'EMAIL', 'ITEM1.ADR' etc
    value:      ';;;Magdeburg;;;Germany'
    attributes: ("type=INTERNET", "type=HOME", "type=pref")
  */

#if 0
#  warning DEBUG LOG ENABLED
  NSLog(@"TAG: %@, value %@ attrs %@",
        tagName, tagValue, tagAttributes);
#endif
  
  /* process tag */
  
  if ([tagName isEqualToString: @"BEGIN"])
    {
      if ([tagAttributes count] > 0)
        [self warn: @"Losing unexpected parameters of BEGIN line."];
      [self _beginComponentWithValue: tagValue];
    }
  else if ([tagName isEqualToString: @"END"])
    {
      if ([tagAttributes count] > 0)
        [self warn: @"Losing unexpected parameters of END line."];
      [self _endComponent: tagName value: tagValue];
    }
  else
    {
      /* a regular content tag */
    
      /* 
         check whether the tga value is encoded in quoted printable,
         this one is used with Outlook vCards (see data/ for examples)
      */
      // TODO: make the encoding check more generic
      if ([tagAttributes containsObject: @"ENCODING=QUOTED-PRINTABLE"])
        {
          // TODO: QP is charset specific! The one below decodes in Unicode!
          tagValue = [tagValue stringByDecodingQuotedPrintable];
          [tagAttributes removeObject: @"ENCODING=QUOTED-PRINTABLE"];
        }
    
      [self _reportContentAsTag: [self _mapTagName: tagName]
            group: [self _groupFromTagName: tagName]
            withAttrs: [self _mapAttrs: tagAttributes forTag: tagName]
            andContent: tagValue];
    }
  
  [tagAttributes release];
}


/* top level parsing method */

- (void) reportDocStart
{
  [contentHandler startDocument];
  [contentHandler startPrefixMapping: @"" uri: prefixURI];
}

- (void) reportDocEnd
{
  [contentHandler endPrefixMapping: @""];
  [contentHandler endDocument];
}

- (void) _parseString: (NSString *) _rawString
{
  /*
    This method split the string into content lines for actual vCard
    parsing.

    RFC2445: 
    contentline = name *(";" param ) ": " value CRLF
    ; When parsing a content line, folded lines MUST first
    ; be unfolded
  */
  NSMutableString *line;
  unsigned pos, length;
  NSRange  r;

  [self reportDocStart];
  
  /* start parsing */
  
  length = [_rawString length];
  r = NSMakeRange(0, 0);
  line = [[NSMutableString alloc] initWithCapacity: 75 + 2];
  
  for (pos = 0; pos < length; pos++)
    {
      unichar c;
    
      c = [_rawString characterAtIndex: pos];
    
      if (c == '\r')
        {
          if (((length - 1) - pos) >= 1)
            {
              if ([_rawString characterAtIndex: pos + 1] == '\n')
                {
                  BOOL isAtEndOfLine = YES;
	  
                  /* test for folding first */
                  if (((length - 1) - pos) >= 2)
                    {
                      unichar ws;
	    
                      ws = [_rawString characterAtIndex: pos + 2];
                      isAtEndOfLine = [whitespaceCharSet characterIsMember: ws] ? NO : YES;
                      if (!isAtEndOfLine)
                        {
                          /* assemble part of line up to pos */
                          if (r.length > 0)
                            {
                              [line appendString: [_rawString substringWithRange: r]];
                            }
                          /* unfold */
                          pos += 2;
                          r = NSMakeRange(pos + 1, 0); /* begin new range */
                        }
                    }
                  if (isAtEndOfLine)
                    {
                      /* assemble part of line up to pos */
                      if (r.length > 0)
                        {
                          [line appendString: [_rawString substringWithRange: r]];
                        }
                      [self _parseLine: line];
                      /* reset line */
                      [line deleteCharactersInRange: NSMakeRange(0, [line length])];
                      pos += 1;
                      r = NSMakeRange(pos + 1, 0); /* begin new range */
                    }
                }
            }
          else
            {
              /* garbled last line! */
              [self warn: @"last line is truncated, trying to parse anyways!"];
            }
        }
      else if (c == '\n')
        { /* broken, non-standard */
          BOOL isAtEndOfLine = YES;
      
          /* test for folding first */
          if (((length - 1) - pos) >= 1)
            {
              unichar ws;
	
              ws = [_rawString characterAtIndex: (pos + 1)];
	
              isAtEndOfLine = [whitespaceCharSet characterIsMember: ws] ? NO : YES;
              if (!isAtEndOfLine)
                {
                  /* assemble part of line up to pos */
                  if (r.length > 0)
                    {
                      [line appendString: [_rawString substringWithRange: r]];
                    }
                  /* unfold */
                  pos += 1;
                  r = NSMakeRange(pos + 1, 0); /* begin new range */
                }
            }
          if (isAtEndOfLine)
            {
              /* assemble part of line up to pos */
              if (r.length > 0)
                {
                  [line appendString: [_rawString substringWithRange: r]];
                }
              [self _parseLine: line];
              /* reset line */
              [line deleteCharactersInRange: NSMakeRange(0, [line length])];
              r = NSMakeRange(pos + 1, 0); /* begin new range */
            }
        }
      else
        {
          r.length += 1;
        }
    }
  if (r.length > 0)
    {
      [self warn: @"Last line of parse string is not properly terminated!"];
      [line appendString: [_rawString substringWithRange: r]];
      [self _parseLine: line];
    }
  
  if ([cardStack count] != 0)
    {
      [self warn: @"found elements on cardStack. This indicates an improper "
            @"nesting structure! Not all required events will have been "
            @"generated, leading to unpredictable results!"];
      [cardStack removeAllObjects]; // clean up
    }
  
  [line release]; line = nil;
  
  [self reportDocEnd];
}

/* main entry functions */

- (id) sourceForData: (NSData *) _data
            systemId: (NSString *) _sysId
{
  SaxParseException *e = nil;
  NSStringEncoding encoding;
  unsigned len;
  const unsigned char *bytes;
  id source;
  
  if (debugOn)
    {
      NSLog(@"%s: trying to decode data (0x%p,len=%d) ...",
	    __PRETTY_FUNCTION__, _data, [_data length]);
    }
  
  if ((len = [_data length]) == 0)
    {
      e = (id)[SaxParseException exceptionWithName: @"SaxIOException"
                                 reason: @"Got no parsing data!"
                                 userInfo: nil];
      [errorHandler fatalError: e];
      return nil;
    }
  if (len < 10)
    {
      e = (id)[SaxParseException exceptionWithName: @"SaxIOException"
                                 reason: @"Input data to short for vCard!"
                                 userInfo: nil];
      [errorHandler fatalError: e];
      return nil;
    }
  
  bytes = [_data bytes];
  if ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
      (bytes[0] == 0xFE && bytes[1] == 0xFF))
    encoding = NSUnicodeStringEncoding;
  else
    encoding = NSUTF8StringEncoding;

  // FIXME: Data is not always utf-8.....
  source = [[[NSString alloc] initWithData: _data encoding: encoding]
	     autorelease];
  if (!source)
    {
      e = (id)[SaxParseException exceptionWithName: @"SaxIOException"
                                 reason: @"Could not convert input to string!"
                                 userInfo: nil];
      [errorHandler fatalError: e];
    }
  return source;
}

- (void) parseFromSource: (id) _source
                systemId: (NSString *) _sysId
{
  if (debugOn)
    NSLog(@"%s: parse: %@ (sysid=%@)", __PRETTY_FUNCTION__, _source, _sysId);
  
  if ([_source isKindOfClass: [NSURL class]])
    {
      NSURL *url;

      url = _source;
      if (!_sysId) _sysId = [url absoluteString];

      if (debugOn)
        {
          NSLog(@"%s: trying to load URL: %@ (sysid=%@)",__PRETTY_FUNCTION__, 
                url, _sysId);
        }
    
      // TODO: remember encoding of source
      _source = [url resourceDataUsingCache: NO];
      if (!_source || ![_source length])
        {
          SaxParseException *e;
          NSString          *s;
    
          if (debugOn) 
            NSLog(@"%s: got no data from url: %@", __PRETTY_FUNCTION__, url);
    
          s = [NSString stringWithFormat: @"got no data from url: %@", url]; 
          e = (id)[SaxParseException exceptionWithName: @"SaxIOException"
                                     reason: s
                                     userInfo: nil];
          [errorHandler fatalError: e];
          return;
        }
    }
  
  if ([_source isKindOfClass: [NSData class]])
    {
      if (!_sysId) _sysId = @"<data>";
      if ((_source = [self sourceForData: _source systemId: _sysId]) == nil)
        return;
    }

  if (![_source isKindOfClass: [NSString class]])
    {
      SaxParseException *e;
      NSString *s;
    
      if (debugOn) 
        NSLog(@"%s: unrecognizable source: %@", __PRETTY_FUNCTION__,_source);
    
      s = [@"cannot handle data-source: " stringByAppendingString: 
              [_source description]];
      e = (id)[SaxParseException exceptionWithName: @"SaxIOException"
                                 reason: s
                                 userInfo: nil];
    
      [errorHandler fatalError: e];
      return;
    }

  /* ensure consistent state */

  [cardStack   removeAllObjects];
  [elementList removeAllObjects];
  
  /* start parsing */
  
  if (debugOn)
    {
      NSLog(@"%s: trying to parse string (0x%p,len=%d) ...",
            __PRETTY_FUNCTION__, _source, [_source length]);
    }
  if (!_sysId) _sysId = @"<string>";
  [self _parseString: _source];
  
  /* tear down */
  
  [cardStack   removeAllObjects];
  [elementList removeAllObjects];
}

- (void) parseFromSource: (id) _source
{
  [self parseFromSource: _source systemId: nil];
}

- (void) parseFromSystemId: (NSString *) _sysId
{
  NSURL *url;
  
  if (![_sysId rangeOfString: @"://"].length)
    {
      /* seems to be a path, path to be a proper URL */
      url = [NSURL fileURLWithPath: _sysId];
    }
  else
    {
      /* Note: Cocoa NSURL doesn't complain on "/abc/def" like input! */
      url = [NSURL URLWithString: _sysId];
    }
  
  if (!url)
    {
      SaxParseException *e;
    
      e = (id)[SaxParseException exceptionWithName: @"SaxIOException"
                                 reason: @"cannot handle system-id"
                                 userInfo: nil];
      [errorHandler fatalError: e];
      return;
    }
  
  [self parseFromSource: url systemId: _sysId];
}

/* debugging */

- (BOOL) isDebuggingEnabled 
{
  return debugOn;
}

@end /* VersitCardsSaxDriver */

