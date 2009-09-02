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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import "NSArray+NGCards.h"

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

- (void) setVersion: (NSString *) _version
{
  [[self uniqueChildWithTag: @"version"] setValue: 0 to: _version];
}

- (NSString *) version
{
  return [[self uniqueChildWithTag: @"version"] value: 0];
}

- (void) setUid: (NSString *) _uid
{
  [[self uniqueChildWithTag: @"uid"] setValue: 0 to: _uid];
}

- (NSString *) uid
{
  return [[self uniqueChildWithTag: @"uid"] value: 0];
}

- (void) setVClass: (NSString *) _class
{
  [[self uniqueChildWithTag: @"class"] setValue: 0 to: _class];
}

- (NSString *) vClass
{
  return [[self uniqueChildWithTag: @"class"] value: 0];
}

- (void) setVName: (NSString *) _vname
{
  [[self uniqueChildWithTag: @"vname"] setValue: 0 to: _vname];
}

- (NSString *) vName
{
  return [[self uniqueChildWithTag: @"vname"] value: 0];
}

- (void) setProdID: (NSString *) _value
{
  [[self uniqueChildWithTag: @"prodid"] setValue: 0 to: _value];
}

- (NSString *) prodID
{
  return [[self uniqueChildWithTag: @"prodid"] value: 0];
}

- (void) setProfile: (NSString *) _value
{
  [[self uniqueChildWithTag: @"profile"] setValue: 0 to: _value];
}

- (NSString *) profile
{
  return [[self uniqueChildWithTag: @"profile"] value: 0];
}

- (void) setSource: (NSString *) _value
{
  [[self uniqueChildWithTag: @"source"] setValue: 0 to: _value];
}

- (NSString *) source
{
  return [[self uniqueChildWithTag: @"source"] value: 0];
}

- (void) setFn: (NSString *) _value
{
  [[self uniqueChildWithTag: @"fn"] setValue: 0 to: _value];
}

- (NSString *) fn
{
  return [[self uniqueChildWithTag: @"fn"] value: 0];
}

- (void) setRole: (NSString *) _value
{
  [[self uniqueChildWithTag: @"role"] setValue: 0 to: _value];
}

- (NSString *) role
{
  return [[self uniqueChildWithTag: @"role"] value: 0];
}

- (void) setTitle: (NSString *) _title
{
  [[self uniqueChildWithTag: @"title"] setValue: 0 to: _title];
}

- (NSString *) title
{
  return [[self uniqueChildWithTag: @"title"] value: 0];
}

- (void) setBday: (NSString *) _value
{
  [[self uniqueChildWithTag: @"bday"] setValue: 0 to: _value];
}

- (NSString *) bday
{
  return [[self uniqueChildWithTag: @"bday"] value: 0];
}

- (void) setNote: (NSString *) _value
{
  [[self uniqueChildWithTag: @"note"] setValue: 0 to: _value];
}

- (NSString *) note
{
  return [[self uniqueChildWithTag: @"note"] value: 0];
}

- (void) setTz: (NSString *) _value
{
  [[self uniqueChildWithTag: @"tz"] setValue: 0 to: _value];
}

- (NSString *) tz
{
  return [[self uniqueChildWithTag: @"tz"] value: 0];
}

- (void) setNickname: (NSString *) _value
{
  [[self uniqueChildWithTag: @"nickname"] setValue: 0 to: _value];
}

- (NSString *) nickname
{
  return [[self uniqueChildWithTag: @"nickname"] value: 0];
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
    [n setValue: 0 to: family];
  if (given)
    [n setValue: 1 to: given];
  if (additional)
    [n setValue: 2 to: additional];
  if (prefixes)
    [n setValue: 3 to: prefixes];
  if (suffixes)
    [n setValue: 4 to: suffixes];
}

- (NSArray *) n
{
  return [[self uniqueChildWithTag: @"n"] values];
}

- (void) setOrg: (NSString *) anOrg
          units: (NSArray *) someUnits
{
  CardElement *org;
  unsigned int count, max;

  org = [self uniqueChildWithTag: @"org"];
  if (anOrg)
    [org setValue: 0 to: anOrg];
  if (someUnits)
    {
      max = [someUnits count];
      for (count = 0; count < max; count++)
        [org setValue: count + 1 to: [someUnits objectAtIndex: count]];
    }
}

- (NSArray *) org
{
  NSArray *elements, *org;

  elements = [self childrenWithTag: @"org"];
  if ([elements count] > 0)
    org = [[elements objectAtIndex: 0] values];
  else
    org = nil;

  return org;
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

// - (void) setCategories: (id) _v
// {
//   if (![_v isKindOfClass:[NGVCardStrArrayValue class]] && [_v isNotNull])
//     _v = [[[NGVCardStrArrayValue alloc] initWithPropertyList:_v] autorelease];
  
//   ASSIGNCOPY(self->categories, _v);
// }

// - (NGVCardStrArrayValue *) categories
// {
//   return self->categories;
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
  return [[self _preferredElementWithTag: @"email"] value: 0];
}

- (NSString *) preferredTel
{
  return [[self _preferredElementWithTag: @"tel"] value: 0];
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


- (NSString *) ldifString
{
  NSMutableString *rc;
  NSString *buffer;
  NSMutableArray *array;
  id tmp;

  rc = [NSMutableString string];

  [rc appendFormat: @"dn: cn=%@,mail=%@\n", [self fn], [self preferredEMail]];
  [rc appendFormat: @"objectclass: top\nobjectclass: person\nobjectclass: "
    @"organizationalPerson\nobjectclass: inetOrgPerson\nobjectclass: "
    @"mozillaAbPersonObsolete\n"];
  [rc appendFormat: @"givenName: %@\n", [[self n] objectAtIndex: 1]];
  [rc appendFormat: @"sn: %@\n", [[self n] objectAtIndex: 0]];
  [rc appendFormat: @"cn: %@\n", [self fn]];
  [rc appendFormat: @"mail: %@\n", [self preferredEMail]];
  [rc appendFormat: @"modifytimestamp: 0Z\n"];

  buffer = [self nickname];
  if (buffer && [buffer length] > 0)
    [rc appendFormat: @"mozillaNickname: %@\n", buffer];

  array = [NSMutableArray arrayWithArray: [self childrenWithTag: @"email"]];
  [array removeObjectsInArray: [self childrenWithTag: @"email"
                 andAttribute: @"type"
                  havingValue: @"pref"]];
  if ([array count])
    {
      buffer = [[array objectAtIndex: [array count]-1] value: 0];

      if ([buffer caseInsensitiveCompare: [self preferredEMail]] != NSOrderedSame)
        [rc appendFormat: @"mozillaSecondEmail: %@\n", buffer];
    }

  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    [rc appendFormat: @"homePhone: %@\n", [[array objectAtIndex: 0] value: 0]];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"fax"];
  if ([array count])
    [rc appendFormat: @"fax: %@\n", [[array objectAtIndex: 0] value: 0]];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"cell"];
  if ([array count])
    [rc appendFormat: @"mobile: %@\n", [[array objectAtIndex: 0] value: 0]];
  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"pager"];
  if ([array count])
    [rc appendFormat: @"pager: %@\n", [[array objectAtIndex: 0] value: 0]];

  array = [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    {
      tmp = [array objectAtIndex: 0];
      [rc appendFormat: @"homeStreet: %@\n", [tmp value: 0]];
      [rc appendFormat: @"mozillaHomeLocalityName: %@\n", [tmp value: 1]];
      [rc appendFormat: @"mozillaHomeState: %@\n", [tmp value: 2]];
      [rc appendFormat: @"mozillaHomePostalCode: %@\n", [tmp value: 3]];
      [rc appendFormat: @"mozillaHomeCountryName: %@\n", [tmp value: 4]];
    }

  array = [self org];
  if (array && [array count])
    [rc appendFormat: @"o: %@\n", [array objectAtIndex: 0]];

  array = [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    {
      tmp = [array objectAtIndex: 0];
      [rc appendFormat: @"street: %@\n", [tmp value: 0]];
      [rc appendFormat: @"l: %@\n", [tmp value: 1]];
      [rc appendFormat: @"st: %@\n", [tmp value: 2]];
      [rc appendFormat: @"postalCode: %@\n", [tmp value: 3]];
      [rc appendFormat: @"c: %@\n", [tmp value: 4]];
    }

  array = [self childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    [rc appendFormat: @"telephoneNumber: %@\n", [[array objectAtIndex: 0] value: 0]];

  array = [self childrenWithTag: @"url" andAttribute: @"type" havingValue: @"work"];
  if ([array count])
    [rc appendFormat: @"workurl: %@\n", [[array objectAtIndex: 0] value: 0]];

  array = [self childrenWithTag: @"url" andAttribute: @"type" havingValue: @"home"];
  if ([array count])
    [rc appendFormat: @"homeurl: %@\n", [[array objectAtIndex: 0] value: 0]];

  tmp = [self note];
  if (tmp && [tmp length])
    [rc appendFormat: @"description: %@\n", tmp];

  [rc appendFormat: @"\n"];

  return rc;
}

@end /* NGVCard */
