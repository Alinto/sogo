/*
  Copyright (C) 2005 Helge Hess

  This file is part of SOPE.

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

#import <string.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "NSString+NGCards.h"
#import "NGCardsSaxHandler.h"

#import "CardGroup.h"

#ifndef XMLNS_VCARD_XML_03
#  define XMLNS_VCARD_XML_03 \
     @"http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-03.txt"
#endif

@implementation NGCardsSaxHandler

- (id) init
{
  if ((self = [super init]))
    topGroupClass = nil;

  return self;
}

- (void) dealloc
{
  if (content)
    free (content);
  [cards release];
  [currentGroup release];
  [super dealloc];
}

/* results */

- (NSArray *) cards
{
  return [[cards copy] autorelease];;
}

/* state */

- (void) resetExceptResult
{
  if (content)
    {
      free (content);
      content = NULL;
    }

  vcs.isInVCardSet   = 0;
  vcs.collectContent = 0;
}

- (void) reset
{
  [self resetExceptResult];
  [cards removeAllObjects];
}

/* document events */

- (void) startDocument
{
  if (!cards)
    cards = [[NSMutableArray alloc] initWithCapacity:16];
  [self reset];
}

- (void) endDocument
{
  [self resetExceptResult];
}

/* common tags */

- (void) startValueTag: (NSString *) _tag
            attributes: (id<SaxAttributes>) _attrs
{
  /* a tag with types and attributes */
  unsigned i, count;
  
  [types removeAllObjects];
  [args  removeAllObjects];
  
  for (i = 0, count = [_attrs count]; i < count; i++) {
    NSString *n, *v;
    
    n = [_attrs nameAtIndex:i];
    v = [_attrs valueAtIndex:i];
    
    if ([n hasSuffix:@".type"] || [n isEqualToString:@"TYPE"]) {
      /*
        Note: types cannot be separated by comma! Its indeed always a space,eg
                "work pref voice"
              If you find commas, usually the vCard is broken.
      */
      NSEnumerator *e;
      NSString *k;
      
      e = [[v componentsSeparatedByString:@" "] objectEnumerator];
      while ((k = [e nextObject]) != nil) {
        k = [k uppercaseString];
        if ([types containsObject:k]) continue;
	[types addObject:k];
      }
    }
    else
      [args setObject:v forKey:n];
  }
}

- (void) endValueTag
{
  [types removeAllObjects];
  [args  removeAllObjects];
}

/* handle elements */

- (void) startGroup: (NSString *)_name
{
  vcs.isInGroup = 1;
  ASSIGNCOPY(currentGroup, _name);
}

- (void) endGroup
{
  vcs.isInGroup = 0;
  [currentGroup release];
  currentGroup = nil;
}

- (void) startVCardSet
{
  currentCardGroup = nil;
  currentGroup = nil;
  vcs.isInVCardSet = 1;
}

- (void) endVCardSet
{
  vcs.isInVCardSet = 0;
}

/* element events */

- (void) startElement:(NSString *)_localName
            namespace:(NSString *)_ns
              rawName:(NSString *)_rawName
           attributes:(id<SaxAttributes>)_attrs
{
  unsigned int count, max;
  Class elementClass;

//   NSLog (@"startElement localName: '%@'", _localName);

  if ([_localName isEqualToString: @"vCardSet"])
    [self startVCardSet];
  else if ([_localName isEqualToString: @"group"])
    [self startGroup: [_attrs valueAtIndex: 0]];
  else if ([_localName isEqualToString: @"container"])
    [self startGroupElement: [_attrs valueAtIndex: 0]];
  else
    {
      if (currentCardGroup)
        elementClass
          = [currentCardGroup classForTag: [_localName uppercaseString]];
      else
        elementClass = topGroupClass;
      
      if (!elementClass)
        elementClass = [CardElement class];

      currentElement = [elementClass elementWithTag: _localName];
      [currentElement setTag: _localName];
      if (currentGroup)
        [currentElement setGroup: currentGroup];

      max = [_attrs count];
      for (count = 0; count < max; count++)
        [currentElement addAttribute: [_attrs nameAtIndex: count]
                        value: [_attrs valueAtIndex: count]];

      [currentCardGroup addChild: currentElement];
      [self startCollectingContent];
    }
}

- (void) endElement: (NSString *)_localName
          namespace: (NSString *)_ns
            rawName: (NSString *)_rawName
{
//   NSLog (@"endElement localName: '%@'", _localName);
  if ([_localName isEqualToString: @"vCardSet"])
    [self endVCardSet];
  else if ([_localName isEqualToString: @"group"])
    [self endGroup];
  else if ([_localName isEqualToString: @"container"])
    [self endGroupElement];
  else
    [currentElement addValues: [self finishCollectingContent]];
}

/* content */

- (void) startCollectingContent
{
  if (content) {
    free (content);
    content = NULL;
  }
  vcs.collectContent = 1;
}

- (NSArray *) finishCollectingContent
{
  NSArray *contentValues;
  NSString *s;

  vcs.collectContent = 0;

  if (content && contentLength)
    {
      s = [NSString stringWithCharacters: content
                    length: contentLength];
      free (content);
      content = NULL;
//       NSLog (@"content: '%@'", s);
      contentValues = [s componentsWithSafeSeparator: ';'];
    }
  else
    contentValues = nil;

  return contentValues;
}

- (void) characters:(unichar *)_chars
             length:(int)_len
{
  if (_len && _chars)
    {
      if (!content)
        {
          /* first content */
          contentLength = _len;
          content = calloc (_len + 1, sizeof(unichar));
          memcpy (content, _chars, (_len * sizeof(unichar)));
        }
      else
        {
          /* increase content */
          content =
            realloc (content, (contentLength + _len+2) * sizeof(unichar));
          memcpy (&(content[contentLength]), _chars, 
                  (_len * sizeof(unichar)));
          contentLength += _len;
        }
      content[contentLength] = 0;
    }
}

- (void) startGroupElement: (NSString *) _localName
{
  CardGroup *newGroup;
  Class groupClass;

//   NSLog (@"startGroupElement localName: '%@'", _localName);

  if (currentCardGroup)
    {
      groupClass
        = [currentCardGroup classForTag: [_localName uppercaseString]];
      if (!groupClass)
        groupClass = [CardGroup class];

      newGroup = [groupClass groupWithTag: _localName];
      [currentCardGroup addChild: newGroup];
    }
  else
    {
      if (topGroupClass)
        groupClass = topGroupClass;
      else
        groupClass = [CardGroup class];

      newGroup = [groupClass groupWithTag: _localName];
      [cards addObject: newGroup];
    }

  currentCardGroup = newGroup;
}

- (void) endGroupElement
{
//   NSLog (@"endGroupElement localName: '%@'", _localName);

  if (currentCardGroup)
    currentCardGroup = [currentCardGroup parent];
}

- (void) setTopElementClass: (Class) aGroupClass
{
  topGroupClass = aGroupClass;
}

@end /* NGCardsSaxHandler */
