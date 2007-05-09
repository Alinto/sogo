/* SOGoContactLDIFEntry.m - this file is part of SOGo
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

#import "SOGoContactLDIFEntry.h"

@implementation SOGoContactLDIFEntry

+ (SOGoContactLDIFEntry *) contactEntryWithName: (NSString *) newName
                                  withLDIFEntry: (NSDictionary *) newEntry
                                    inContainer: (id) newContainer
{
  SOGoContactLDIFEntry *entry;

  entry = [[self alloc] initWithName: newName
                        withLDIFEntry: newEntry
                        inContainer: newContainer];
  [entry autorelease];

  return entry;
}

- (id) initWithName: (NSString *) newName
      withLDIFEntry: (NSDictionary *) newEntry
        inContainer: (id) newContainer
{
  self = [self init];
  ASSIGN (name, newName);
  ASSIGN (container, newContainer);
  ASSIGN (ldifEntry, newEntry);
  vcard = nil;

//   [self dumpEntry: anEntry];

  return self;
}

- (NSString *) nameInContainer
{
  return name;
}

- (void) dealloc
{
  [vcard release];
  [ldifEntry release];
  [super dealloc];
}

- (NSString *) contentAsString
{
  return [[self vCard] versitString];
}

- (void) _setPhonesOfVCard: (NGVCard *) vCard
{
  NSString *info;

  info = [ldifEntry valueForKey: @"telephoneNumber"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"work", @"voice", @"pref", nil]];
  info = [ldifEntry valueForKey: @"homePhone"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"home", @"voice", nil]];
  info = [ldifEntry valueForKey: @"fax"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"work", @"fax", nil]];
  info = [ldifEntry valueForKey: @"pager"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"pager", nil]];
  info = [ldifEntry valueForKey: @"mobile"];
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
      info = [ldifEntry valueForKey: @"displayName"];
      if (!(info && [info length] > 0))
        info = [ldifEntry valueForKey: @"cn"];
      [vcard setFn: info];
      surname = [ldifEntry valueForKey: @"sn"];
      if (!surname)
        surname = [ldifEntry valueForKey: @"surname"];
      [vcard setNWithFamily: surname
             given: [ldifEntry valueForKey: @"givenName"]
             additional: nil
             prefixes: nil
             suffixes: nil];
      info = [ldifEntry valueForKey: @"title"];
      if (info)
        [vcard setTitle: info];
      info = [ldifEntry valueForKey: @"mozillaNickname"];
      if (info)
        [vcard setNickname: info];
      info = [ldifEntry valueForKey: @"xmozillaNickname"];
      if (info)
        [vcard setNickname: info];
      info = [ldifEntry valueForKey: @"notes"];
      if (info)
        [vcard setNote: info];
      info = [ldifEntry valueForKey: @"mail"];
      if (info)
        [vcard addEmail: info
               types: [NSArray arrayWithObjects: @"internet", @"pref", nil]];
      [self _setPhonesOfVCard: vcard];
      streetAddress = [ldifEntry valueForKey: @"streetAddress"];
      location = [ldifEntry valueForKey: @"l"];
      element = [CardElement elementWithTag: @"adr"
                             attributes: nil values: nil];
      [element setValue: 0 ofAttribute: @"type" to: @"work"];
      if (streetAddress)
        [element setValue: 2 to: streetAddress];
      if (location)
        [element setValue: 3 to: location];
      if (streetAddress || location)
        [vcard addChild: element];
      info = [ldifEntry valueForKey: @"calFBURL"];
      if (info)
        [vcard addChildWithTag: @"FBURL"
               types: nil
               singleValue: info];
    }

  return vcard;
}

- (NSString *) davEntityTag
{
  return [ldifEntry valueForKey: @"modifyTimeStamp"];
}

- (NSString *) davContentType
{
  return @"text/x-vcard";
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
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
