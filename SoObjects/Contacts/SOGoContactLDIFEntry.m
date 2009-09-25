/* SOGoContactLDIFEntry.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2009 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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
#import <Foundation/NSUserDefaults.h>

#import <NGCards/NGVCard.h>
#import <NGCards/CardVersitRenderer.h>

#import "SOGoContactGCSEntry.h"
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

  info = [ldifEntry objectForKey: @"telephonenumber"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"work", @"voice", @"pref", nil]];
  info = [ldifEntry objectForKey: @"homephone"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"home", @"voice", nil]];
  info = [ldifEntry objectForKey: @"fax"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"work", @"fax", nil]];
  info = [ldifEntry objectForKey: @"pager"];
  if (info)
    [vCard addTel: info
           types: [NSArray arrayWithObjects: @"pager", nil]];
  info = [ldifEntry objectForKey: @"mobile"];
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
  NSString *info, *surname, *streetAddress, *location, *key, *region, *postalCode, *country, *org, *orgunit;
  CardElement *element;
  unsigned int count;

  if (!vcard)
    {
      vcard = [[NGVCard alloc] initWithUid: [self nameInContainer]];
      [vcard setVClass: @"PUBLIC"];
      [vcard setProdID: @"-//Inverse inc./SOGo 1.0//EN"];
      [vcard setProfile: @"vCard"];
      info = [ldifEntry objectForKey: @"displayname"];
      if (!(info && [info length] > 0))
        info = [ldifEntry objectForKey: @"cn"];
      [vcard setFn: info];
      surname = [ldifEntry objectForKey: @"sn"];
      if (!surname)
        surname = [ldifEntry objectForKey: @"surname"];
      [vcard setNWithFamily: surname
             given: [ldifEntry objectForKey: @"givenname"]
             additional: nil
             prefixes: nil
             suffixes: nil];
      info = [ldifEntry objectForKey: @"title"];
      if (info)
        [vcard setTitle: info];
      info = [ldifEntry objectForKey: @"mozillanickname"];
      if (info)
        [vcard setNickname: info];
      
      // If SOGoLDAPContactInfoAttribute is defined, we set it
      // as the NOTE value in order for Thunderbird (or any other
      // CardDAV client) to display it.
      key = [[NSUserDefaults standardUserDefaults]
	      stringForKey: @"SOGoLDAPContactInfoAttribute"];

      if (!key)
	key = @"description";

      info = [ldifEntry objectForKey: key];
      if (info)
        [vcard setNote: info];

      info = [ldifEntry objectForKey: @"mail"];
      if (info)
        [vcard addEmail: info
               types: [NSArray arrayWithObjects: @"internet", @"pref", nil]];
      [self _setPhonesOfVCard: vcard];

      streetAddress = [ldifEntry objectForKey: @"street"];
      if (!streetAddress) streetAddress = [ldifEntry objectForKey: @"streetaddress"];

      location = [ldifEntry objectForKey: @"l"];
      if (!location) location = [ldifEntry objectForKey: @"locality"];

      region = [ldifEntry objectForKey: @"st"];
      if (!region) region = [ldifEntry objectForKey: @"region"];

      postalCode = [ldifEntry objectForKey: @"postalcode"];
      if (!postalCode) postalCode = [ldifEntry objectForKey: @"zip"];

      country = [ldifEntry objectForKey: @"c"];
      if (!country) country = [ldifEntry objectForKey: @"countryname"];

      element = [CardElement elementWithTag: @"adr"
                             attributes: nil values: nil];
      [element setValue: 0 ofAttribute: @"type" to: @"work"];

      if (streetAddress)
        [element setValue: 2 to: streetAddress];
      if (location)
        [element setValue: 3 to: location];
      if (region)
	[element setValue: 4 to: region];
      if (postalCode)
	[element setValue: 5 to: postalCode];
      if (country)
	[element setValue: 6 to: country];
      
      if (streetAddress || location || region || postalCode || country)
        [vcard addChild: element];

      // We handle the org/orgunit stuff
      element = [CardElement elementWithTag: @"org"
                             attributes: nil values: nil];
      org = [ldifEntry objectForKey: @"o"];
      orgunit = [ldifEntry objectForKey: @"ou"];
      if (!orgunit) orgunit = [ldifEntry objectForKey: @"orgunit"];
      
      if (org)
	[element setValue: 0 to: org];
      if (orgunit)
	[element setValue: 1 to: orgunit];

      if (org || orgunit)
	[vcard addChild: element];

      info = [ldifEntry objectForKey: @"calFBURL"];
      if (info)
        [vcard addChildWithTag: @"FBURL"
               types: nil
               singleValue: info];
      for (count = 1; count < 5; count++)
	{
	  info = [ldifEntry objectForKey:
			      [NSString stringWithFormat: @"mozillacustom%d",
					count]];
	  if (info)
	    [vcard addChildWithTag: [NSString stringWithFormat: @"CUSTOM%d",
					      count]
		   types: nil
		   singleValue: info];
	}
    }

  return vcard;
}

- (BOOL) isFolderish
{
  return NO;
}

- (NSString *) davEntityTag
{
  unsigned int hash;
//   return [ldifEntry objectForKey: @"modifyTimeStamp"];

  hash = [[self contentAsString] hash];

  return [NSString stringWithFormat: @"hash%u", hash];
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

/* DAV */
- (NSException *) copyToFolder: (SOGoGCSFolder *) newFolder
{
  NGVCard *newCard;
  NSString *newUID;
  SOGoContactGCSEntry *newContact;

  // Change the contact UID
  newUID = [self globallyUniqueObjectId];
  newCard = [self vCard];

  [newCard setUid: newUID];

  newContact = [SOGoContactGCSEntry objectWithName:
				      [NSString stringWithFormat: @"%@.vcf", newUID]
				    inContainer: newFolder];

  return [newContact saveContentString: [newCard versitString]];
}

/* message type */

- (NSString *) outlookMessageClass
{
  return @"IPM.Contact";
}

@end
