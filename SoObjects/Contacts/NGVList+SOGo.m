/* NGVCard+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2021 Inverse inc.
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
#import <Foundation/NSString.h>

#import <NGCards/NGVCardReference.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoContactFolder.h"
#import "NSDictionary+LDIF.h"

#import "NGVList+SOGo.h"

@implementation NGVList (SOGoExtensions)

/* LDIF -> VCARD */
- (CardElement *) elementWithTag: (NSString *) elementTag
                          ofType: (NSString *) type
{
  NSArray *elements;
  CardElement *element;

  elements = [self childrenWithTag: elementTag
                      andAttribute: @"type" havingValue: type];
  if ([elements count] > 0)
    element = [elements objectAtIndex: 0];
  else
    {
      element = [CardElement elementWithTag: elementTag];
      [element addType: type];
      [self addChild: element];
    }

  return element;
}

- (NSString *) ldifString
{
  NSMutableString *rc;
  NSArray *array;
  NSMutableArray *members;
  NGVCardReference *tmp;
  NSMutableDictionary *entry;
  int i, count;

  entry = [NSMutableDictionary dictionary];

  [entry setObject: [NSString stringWithFormat: @"cn=%@", [self fn]]
            forKey: @"dn"];
  [entry setObject: [NSArray arrayWithObjects: @"top", @"groupOfNames", nil]
            forKey: @"objectclass"];
  [entry setObject: [self fn] forKey: @"cn"];
  if ([self nickname])
    [entry setObject: [self nickname] forKey: @"mozillaNickname"];
  if ([self description])
    [entry setObject: [self description] forKey: @"description"];

  array = [self cardReferences];
  count = [array count];
  members = [NSMutableArray array];
  for (i = 0; i < count; i++)
    {
      tmp = [array objectAtIndex: i];
      [members addObject: [NSString stringWithFormat:
                           @"cn=%@,mail=%@", [tmp fn], [tmp email]]];
    }
  [entry setObject: members forKey: @"member"];

  rc = [NSMutableString stringWithString: [entry ldifRecordAsString]];
  [rc appendFormat: @"\n"];

  return rc;
}

- (NSMutableDictionary *) quickRecordFromContent: (NSString *) theContent
                                       container: (id) theContainer
                                 nameInContainer: (NSString *) nameInContainer

{
  NSMutableDictionary *fields;
  NSString *value;

  fields = [NSMutableDictionary dictionaryWithCapacity: 1];

  value = [self fn];
  if (value)
    [fields setObject: value forKey: @"c_cn"];
  [fields setObject: @"vlist" forKey: @"c_component"];

  return fields;
}

- (void) updateFromLDIFRecord: (NSDictionary *) ldifRecord
                  inContainer: (id) container
{
  NSString *fn;
  id o;

  fn = [ldifRecord objectForKey: @"displayname"];
  if (!fn)
    fn = [ldifRecord objectForKey: @"cn"];
  [self setFn: fn];

  o = [ldifRecord objectForKey: @"description"];
  if ([o isNotNull])
    [self setDescription: o];

  o = [ldifRecord objectForKey: @"member"];
  if ([o isKindOfClass: [NSArray class]])
    [self setCardReferences: o
                inContainer: container];
  else if ([o isNotNull])
    [self setCardReference: o
               inContainer: container];

  [self cleanupEmptyChildren];
}

- (void) setCardReference: (NSString *) newCardReference
              inContainer: (id) container
{
  NGVCardReference *cardReference;
  NSDictionary *record;
  NSEnumerator *attrsList;
  NSMutableDictionary *attrs;
  NSArray *pair, *records;
  NSString *value;

  attrs = [NSMutableDictionary dictionary];
  attrsList = [[newCardReference componentsSeparatedByString: @","] objectEnumerator];
  while ((value = [attrsList nextObject]))
    {
      pair = [value componentsSeparatedByString: @"="];
      if ([pair count] == 2 && [[pair objectAtIndex: 1] length])
        {
          [attrs setObject: [pair objectAtIndex: 1]
                    forKey: [[pair objectAtIndex: 0] lowercaseString]];
        }
      else
        {
          [self warnWithFormat: @"Unexpected LDAP member: %@", value];
        }
    }

  records = nil;
  if ((value = [attrs objectForKey: @"mail"]))
    {
      records = [container lookupContactsWithFilter: value
                                         onCriteria: [NSArray arrayWithObject: @"c_mail"]
                                             sortBy: nil
                                           ordering: NSOrderedAscending
                                           inDomain: nil];
    }
  else if ((value = [attrs objectForKey: @"cn"]))
    {
      records = [container lookupContactsWithFilter: value
                                         onCriteria: [NSArray arrayWithObject: @"c_cn"]
                                             sortBy: nil
                                           ordering: NSOrderedAscending
                                           inDomain: nil];
    }
  if (records && [records count] > 0)
    {
      record = [records objectAtIndex: 0];
      cardReference = [NGVCardReference elementWithTag: @"card"];
      [cardReference setReference: [record objectForKey: @"c_name"]];
      if ((value = [attrs objectForKey: @"mail"]) && [value length])
        [cardReference setEmail: value];
      if ((value = [attrs objectForKey: @"cn"]) && [value length])
        [cardReference setFn: value];
      [self addCardReference: cardReference];
    }
}

- (void) setCardReferences: (NSArray *) newCardReferences
               inContainer: (id) container
{
  NSEnumerator *referencesList;
  NSString *cardReference;

  referencesList = [newCardReferences objectEnumerator];
  while ((cardReference = [referencesList nextObject]))
    {
      [self setCardReference: cardReference
                 inContainer: container];
    }
}



@end /* NGVList */
