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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import "NSArray+NGCards.h"
#import "NSString+NGCards.h"

#import "NGVCardPhoto.h"

#import "NGVCard.h"

@implementation NGVCard

+ (id) cardWithUid: (NSString *) _uid
{
  NGVCard *newCard;

  newCard = [[self alloc] initWithUid: _uid];
  [newCard autorelease];

  return newCard;
}

- (id) initWithUid: (NSString *) _uid
{
  if ((self = [self init]))
    {
      [self setTag: @"vcard"];
      [self setUid: _uid];
      [self setVersion: @"3.0"];
      [self setVClass: @"PUBLIC"];
      [self setProfile: @"VCARD"];
    }

  return self;
}

/* class mapping */
- (Class) classForTag: (NSString *) classTag
{
  Class tagClass;

  tagClass = Nil;
  if ([classTag isEqualToString: @"PRODID"]
      || [classTag isEqualToString: @"PRODID"]
      || [classTag isEqualToString: @"PROFILE"]
      || [classTag isEqualToString: @"UID"]
      || [classTag isEqualToString: @"CLASS"]
      || [classTag isEqualToString: @"N"]
      || [classTag isEqualToString: @"FN"]
      || [classTag isEqualToString: @"ORG"]
      || [classTag isEqualToString: @"ADR"]
      || [classTag isEqualToString: @"TEL"]
      || [classTag isEqualToString: @"TZ"]
      || [classTag isEqualToString: @"URL"]
      || [classTag isEqualToString: @"FBURL"]
      || [classTag isEqualToString: @"LABEL"]
      || [classTag isEqualToString: @"EMAIL"]
      || [classTag isEqualToString: @"NICKNAME"]
      || [classTag isEqualToString: @"NOTE"]
      || [classTag isEqualToString: @"BDAY"]
      || [classTag isEqualToString: @"TITLE"]
      || [classTag isEqualToString: @"VERSION"])
    tagClass = [CardElement class];
  else if ([classTag isEqualToString: @"PHOTO"])
    tagClass = [NGVCardPhoto class];
  else
    tagClass = [super classForTag: classTag];

  return tagClass;
}

- (void) setPreferred: (CardElement *) aChild
{
  NSEnumerator *elements;
  CardElement *element;

  if (![aChild hasAttribute: @"type" havingValue: @"pref"])
    {
      elements = [[children cardElementsWithTag: tag] objectEnumerator];
      element = [elements nextObject];
      while (element)
        {
          [element removeValue: @"pref" fromAttribute: @"type"];
          element = [elements nextObject];
        }
      [aChild addAttribute: @"type" value: @"pref"];
    }
}

/* helpers */
- (NSArray *) childrenWithType: (NSString *) aType
{
  return [self childrenWithAttribute: @"type" havingValue: aType];
}

/* accessors */

- (void) setVersion: (NSString *) _value
{
  [[self uniqueChildWithTag: @"version"] setSingleValue: _value forKey: @""];
}

- (NSString *) version
{
  return [[self uniqueChildWithTag: @"version"] flattenedValuesForKey: @""];
}

- (void) setUid: (NSString *) _value
{
  [[self uniqueChildWithTag: @"uid"] setSingleValue: _value forKey: @""];
}

- (NSString *) uid
{
  return [[self uniqueChildWithTag: @"uid"] flattenedValuesForKey: @""];
}

- (void) setVClass: (NSString *) _value
{
  [[self uniqueChildWithTag: @"class"] setSingleValue: _value forKey: @""];
}

- (NSString *) vClass
{
  return [[self uniqueChildWithTag: @"class"] flattenedValuesForKey: @""];
}

- (void) setProdID: (NSString *) _value
{
  [[self uniqueChildWithTag: @"prodid"] setSingleValue: _value forKey: @""];
}

- (NSString *) prodID
{
  return [[self uniqueChildWithTag: @"prodid"] flattenedValuesForKey: @""];
}

- (void) setProfile: (NSString *) _value
{
  [[self uniqueChildWithTag: @"profile"] setSingleValue: _value forKey: @""];
}

- (NSString *) profile
{
  return [[self uniqueChildWithTag: @"profile"] flattenedValuesForKey: @""];
}

- (void) setSource: (NSString *) _value
{
  [[self uniqueChildWithTag: @"source"] setSingleValue: _value forKey: @""];
}

- (NSString *) source
{
  return [[self uniqueChildWithTag: @"source"] flattenedValuesForKey: @""];
}

- (void) setFn: (NSString *) _value
{
  [[self uniqueChildWithTag: @"fn"] setSingleValue: _value forKey: @""];
}

- (NSString *) fn
{
  return [[self uniqueChildWithTag: @"fn"] flattenedValuesForKey: @""];
}

- (void) setRole: (NSString *) _value
{
  [[self uniqueChildWithTag: @"role"] setSingleValue: _value forKey: @""];
}

- (NSString *) role
{
  return [[self uniqueChildWithTag: @"role"] flattenedValuesForKey: @""];
}

- (void) setTitle: (NSString *) _value
{
  [[self uniqueChildWithTag: @"title"] setSingleValue: _value forKey: @""];
}

- (NSString *) title
{
  return [[self uniqueChildWithTag: @"title"] flattenedValuesForKey: @""];
}

- (void) setBday: (NSString *) _value
{
  [[self uniqueChildWithTag: @"bday"] setSingleValue: _value forKey: @""];
}

- (NSString *) bday
{
  return [[self uniqueChildWithTag: @"bday"] flattenedValuesForKey: @""];
}

- (void) setNote: (NSString *) _value
{
  [[self uniqueChildWithTag: @"note"] setSingleValue: _value forKey: @""];
}

- (NSString *) note
{
  return [[self uniqueChildWithTag: @"note"] flattenedValuesForKey: @""];
}

- (void) setTz: (NSString *) _value
{
  [[self uniqueChildWithTag: @"tz"] setSingleValue: _value forKey: @""];
}

- (NSString *) tz
{
  return [[self uniqueChildWithTag: @"tz"] flattenedValuesForKey: @""];
}

- (void) setNickname: (NSString *) _value
{
  [[self uniqueChildWithTag: @"nickname"] setSingleValue: _value forKey: @""];
}

- (NSString *) nickname
{
  return [[self uniqueChildWithTag: @"nickname"] flattenedValuesForKey: @""];
}

- (void) addTel: (NSString *) phoneNumber
          types: (NSArray *) types
{
  [self addChildWithTag: @"tel" types: types singleValue: phoneNumber];
}

- (void) addEmail: (NSString *) emailAddress
            types: (NSArray *) types
{
  [self addChildWithTag: @"email"
        types: types
        singleValue: emailAddress];
}

- (void) setNWithFamily: (NSString *) family
                  given: (NSString *) given
             additional: (NSString *) additional
               prefixes: (NSString *) prefixes
               suffixes: (NSString *) suffixes
{
  CardElement *n;

  n = [self uniqueChildWithTag: @"n"];
  if (family)
    [n setSingleValue: family atIndex: 0 forKey: @""];
  if (given)
    [n setSingleValue: given atIndex: 1 forKey: @""];
  if (additional)
    [n setSingleValue: additional atIndex: 2 forKey: @""];
  if (prefixes)
    [n setSingleValue: prefixes atIndex: 3 forKey: @""];
  if (suffixes)
    [n setSingleValue: suffixes atIndex: 4 forKey: @""];
}

- (CardElement *) n
{
  return [self uniqueChildWithTag: @"n"];
}

- (void) setOrg: (NSString *) anOrg
          units: (NSArray *) someUnits
{
  CardElement *org;
  unsigned int count, max;

  org = [self uniqueChildWithTag: @"org"];
  if (anOrg)
    [org setSingleValue: anOrg atIndex: 0 forKey: @""];
  if (someUnits)
    {
      max = [someUnits count];
      for (count = 0; count < max; count++)
        [org setSingleValue: [someUnits objectAtIndex: count]
                    atIndex: count + 1 forKey: @""];
    }
}

- (CardElement *) org
{
  return [self uniqueChildWithTag: @"org"];
}

- (void) setCategories: (NSArray *) newCategories
{
  CardElement *cats;
  NSMutableArray *copy;

  cats = [self uniqueChildWithTag: @"categories"];
  copy = [newCategories mutableCopy];
  [cats setValues: copy atIndex: 0 forKey: @""];
  [copy release];
}

- (NSArray *) categories
{
  CardElement *cats;

  cats = [self uniqueChildWithTag: @"categories"];

  return [cats valuesAtIndex: 0 forKey: @""];
}

// - (void) setOrg: (NGVCardOrg *) _v
// {
//   ASSIGNCOPY(self->org, _v);
// }

// - (NGVCardOrg *)org {
//   return self->org;
// }

// - (void)setNickname: (id) _v
// {
//   if (![_v isKindOfClass:[NGVCardStrArrayValue class]] && [_v isNotNull])
//     _v = [[[NGVCardStrArrayValue alloc] initWithPropertyList:_v] autorelease];
  
//   ASSIGNCOPY(self->nickname, _v);
// }

// - (NGVCardStrArrayValue *) nickname
// {
//   return self->nickname;
// }

// - (void) setTel: (NSArray *) _tel
// {
//   ASSIGNCOPY(self->tel, _tel);
// }

// - (NSArray *) tel
// {
//   return [self childrenWithTag: @"tel"];
// }

// - (void) setAdr: (NSArray *) _adr
// {
//   ASSIGNCOPY(self->adr, _adr);
// }

// - (NSArray *) adr
// {
//   return self->adr;
// }

// - (void) setEmail: (NSArray *) _email
// {
//   ASSIGNCOPY(self->email, _email);
// }

// - (NSArray *) email
// {
//   return [self childrenWithTag: @"email"];
// }

// - (void) setLabel: (NSArray *) _label
// {
//   ASSIGNCOPY(self->label, _label);
// }

// - (NSArray *) label
// {
//   return [self childrenWithTag: @"email"];
// }

// - (void) setUrl: (NSArray *) _url
// {
//   ASSIGNCOPY(self->url, _url);
// }

// - (NSArray *) url
// {
//   return self->url;
// }

// - (void) setFreeBusyURL: (NSArray *) _v
// {
//   ASSIGNCOPY(self->fburl, _v);
// }

// - (NSArray *) freeBusyURL
// {
//   return self->fburl;
// }

// - (void) setCalURI: (NSArray *) _v
// {
//   ASSIGNCOPY(self->caluri, _v);
// }

// - (NSArray *) calURI
// {
//   return self->caluri;
// }

// - (void) setX: (NSDictionary *) _dict
// {
//   ASSIGNCOPY(self->x, _dict);
// }

// - (NSDictionary *) x
// {
//   return self->x;
// }

/* convenience */

- (CardElement *) _preferredElementWithTag: (NSString *) aTag
{
  NSArray *elements, *prefElements;
  CardElement *element;

  elements = [self childrenWithTag: aTag];
  if (elements && [elements count] > 0)
    {
      prefElements = [elements cardElementsWithAttribute: @"type"
                               havingValue: @"pref"];
      if (prefElements && [prefElements count] > 0)
        element = [prefElements objectAtIndex: 0];
      else
        element = [elements objectAtIndex: 0];
    }
  else
    element = nil;

  return element;
}

- (NSString *) preferredEMail
{
  return [[self _preferredElementWithTag: @"email"] flattenedValuesForKey: @""];
}

- (NSString *) preferredTel
{
  return [[self _preferredElementWithTag: @"tel"] flattenedValuesForKey: @""];
}

- (CardElement *) preferredAdr
{
  return [self _preferredElementWithTag: @"adr"];
}

- (NSString *) versitString
{
  [self setVersion: @"3.0"];

  return [super versitString];
}

/* description */

- (void) appendAttributesToDescription: (NSMutableString *) _ms
{
  if ([self uid]) [_ms appendFormat:@" uid='%@'", [self uid]];
  
//   if ([[self tel] count] > 0) [_ms appendFormat:@" tel=%@", [self tel];
//   if ([[self adr] count])
//     [_ms appendFormat:@" adr=%@", [self adr]];
//   if ([[self email] count])
//     [_ms appendFormat:@" email=%@", [self email]];
//   if ([[self label] count])
//     [_ms appendFormat:@" label=%@", [self label]];
//   if ([[self x] count])
//     [_ms appendFormat:@" x=%@", [self x]];
}

- (NSString *) description
{
  NSMutableString *str = nil;
  
  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:str];
  [str appendString:@">"];
  return str;
}

@end /* NGVCard */
