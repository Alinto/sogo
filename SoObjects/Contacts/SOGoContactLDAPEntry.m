/* SOGoContactLDAPEntry.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/NGVCard.h>
#import <NGCards/CardVersitRenderer.h>

#import <NGLdap/NGLdapEntry.h>
#import <NGLdap/NGLdapAttribute.h>

#import "NGLdapEntry+Contact.h"

#import "SOGoContactLDAPEntry.h"

@implementation SOGoContactLDAPEntry

+ (SOGoContactLDAPEntry *) contactEntryWithName: (NSString *) aName
                                  withLDAPEntry: (NGLdapEntry *) anEntry
                                    inContainer: (id) aContainer
{
  SOGoContactLDAPEntry *entry;

  entry = [[self alloc] initWithName: aName
                        withLDAPEntry: anEntry
                        inContainer: aContainer];
  [entry autorelease];

  return entry;
}

- (void) dumpEntry: (NGLdapEntry *) anEntry
{
  NSArray *keys;
  unsigned int count, max;

  keys = [anEntry attributeNames];
  max = [keys count];

  NSLog (@"dumping entry...");
  for (count = 0; count < max; count++)
    NSLog (@"%d: %@ = '%@'", count,
           [keys objectAtIndex: count],
           [anEntry singleAttributeWithName: [keys objectAtIndex: count]]);
  NSLog (@"dumping finished..");
}

- (id) initWithName: (NSString *) aName
      withLDAPEntry: (NGLdapEntry *) anEntry
        inContainer: (id) aContainer
{
  if ((self = [super initWithName: aName inContainer: aContainer]))
    {
      vcard = nil;
      [self setLDAPEntry: anEntry];
    }

  [self dumpEntry: anEntry];

  return self;
}

- (void) dealloc
{
  if (vcard)
    [vcard release];
  [super dealloc];
}

- (void) setLDAPEntry: (NGLdapEntry *) anEntry;
{
  ldapEntry = anEntry;
}

- (NSString *) contentAsString
{
  return [[self vCard] versitString];
}

- (void) _setPhonesOfVCard: (NGVCard *) vCard
{
  NSString *info;

  info = [ldapEntry singleAttributeWithName: @"telephoneNumber"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"work", @"voice", @"pref", nil]];
  info = [ldapEntry singleAttributeWithName: @"homePhone"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"home", @"voice", nil]];
  info = [ldapEntry singleAttributeWithName: @"fax"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"work", @"fax", nil]];
  info = [ldapEntry singleAttributeWithName: @"pager"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"pager", nil]];
  info = [ldapEntry singleAttributeWithName: @"mobile"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"cell", @"voice", nil]];

// telephoneNumber: work phone
// homePhone: home phone
// fax: fax phone
// pager: page phone
// mobile: mobile phone
  
}

- (NGVCard *) vCard
{
  NSString *info, *surname, *streetAddress, *location;
  CardElement *element;

  if (!vcard)
    {
      vcard = [[NGVCard alloc] initWithUid: [self nameInContainer]];
      [vcard setVClass: @"PUBLIC"];
      [vcard setProdID: @"-//OpenGroupware.org//SOGo"];
      [vcard setProfile: @"vCard"];
      info = [ldapEntry singleAttributeWithName: @"displayName"];
      if (!(info && [info length] > 0))
        info = [ldapEntry singleAttributeWithName: @"cn"];
      [vcard setFn: info];
      surname = [ldapEntry singleAttributeWithName: @"sn"];
      if (!surname)
        surname = [ldapEntry singleAttributeWithName: @"surname"];
      [vcard setNWithFamily: surname
             given: [ldapEntry singleAttributeWithName: @"givenName"]
             additional: nil
             prefixes: nil
             suffixes: nil];
      info = [ldapEntry singleAttributeWithName: @"title"];
      if (info)
        [vcard setTitle: info];
      info = [ldapEntry singleAttributeWithName: @"mozillaNickname"];
      if (info)
        [vcard setNickname: info];
      info = [ldapEntry singleAttributeWithName: @"xmozillaNickname"];
      if (info)
        [vcard setNickname: info];
      info = [ldapEntry singleAttributeWithName: @"notes"];
      if (info)
        [vcard setNote: info];
      info = [ldapEntry singleAttributeWithName: @"mail"];
      if (info)
        [vcard addEmail: info
               types: [NSArray arrayWithObjects: @"internet", @"pref", nil]];
      [self _setPhonesOfVCard: vcard];
      streetAddress = [ldapEntry singleAttributeWithName: @"streetAddress"];
      location = [ldapEntry singleAttributeWithName: @"l"];
      element = [CardElement elementWithTag: @"adr"
                             attributes: nil values: nil];
      [element setValue: 0 ofAttribute: @"type" to: @"work"];
      if (streetAddress)
        [element setValue: 2 to: streetAddress];
      if (location)
        [element setValue: 3 to: location];
      if (streetAddress || location)
        [vcard addChild: element];
      info = [ldapEntry singleAttributeWithName: @"calFBURL"];
      if (info)
        [vcard addChildWithTag: @"FBURL"
               types: nil
               singleValue: info];
    }

  return vcard;
}

- (NSString *) davEntityTag
{
  return [[ldapEntry attributeWithName: @"modifyTimeStamp"]
           stringValueAtIndex: 0];
}

- (NSString *) davContentType
{
  return @"text/x-vcard";
}

- (void) save
{
}

/* message type */

- (NSString *) outlookMessageClass
{
  return @"IPM.Contact";
}

@end
