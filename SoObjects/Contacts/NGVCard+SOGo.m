/* NGVCard+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Cyril Robert <crobert@inverse.ca>
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import <NGCards/NSArray+NGCards.h>
#import <NGCards/NSString+NGCards.h>

#import "NSDictionary+LDIF.h"

#import "NGVCard+SOGo.h"

/*
objectclass ( 2.5.6.6 NAME 'person'
	DESC 'RFC2256: a person'
	SUP top STRUCTURAL
	MUST ( sn $ cn )
	MAY ( userPassword $ telephoneNumber $ seeAlso $ description ) )

objectclass ( 2.5.6.7 NAME 'organizationalPerson'
	DESC 'RFC2256: an organizational person'
	SUP person STRUCTURAL
	MAY ( title $ x121Address $ registeredAddress $ destinationIndicator $
		preferredDeliveryMethod $ telexNumber $ teletexTerminalIdentifier $
		telephoneNumber $ internationaliSDNNumber $ 
		facsimileTelephoneNumber $ street $ postOfficeBox $ postalCode $
		postalAddress $ physicalDeliveryOfficeName $ ou $ st $ l ) )

objectclass	( 2.16.840.1.113730.3.2.2
    NAME 'inetOrgPerson'
	DESC 'RFC2798: Internet Organizational Person'
    SUP organizationalPerson
    STRUCTURAL
	MAY (
		audio $ businessCategory $ carLicense $ departmentNumber $
		displayName $ employeeNumber $ employeeType $ givenName $
		homePhone $ homePostalAddress $ initials $ jpegPhoto $
		labeledURI $ mail $ manager $ mobile $ o $ pager $
		photo $ roomNumber $ secretary $ uid $ userCertificate $
		x500uniqueIdentifier $ preferredLanguage $
		userSMIMECertificate $ userPKCS12 )
	)

objectclass ( 1.3.6.1.4.1.13769.9.1 NAME 'mozillaAbPersonAlpha' 
         SUP top AUXILIARY 
         MUST ( cn )
         MAY( c $ 
              description $
              displayName $
              facsimileTelephoneNumber $
              givenName $
              homePhone $
              l $
              mail $
              mobile $
              mozillaCustom1 $
              mozillaCustom2 $
              mozillaCustom3 $
              mozillaCustom4 $
              mozillaHomeCountryName $
              mozillaHomeLocalityName $
              mozillaHomePostalCode $
              mozillaHomeState $
              mozillaHomeStreet $
              mozillaHomeStreet2 $
              mozillaHomeUrl $
              mozillaNickname $
              mozillaSecondEmail $
              mozillaUseHtmlMail $
              mozillaWorkStreet2 $
              mozillaWorkUrl $
              nsAIMid $
              o $
              ou $
              pager $
              postalCode $
              postOfficeBox $
              sn $
              st $
              street $
              telephoneNumber $
              title ) )

 additional vcard fields:
"vcardCategories"

test contact (export from tb):

dn:: Y249UHLDqW5vbSBOb20sbWFpbD1hZHIxQGVsZS5jb20=
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
objectclass: mozillaAbPersonAlpha
givenName:: UHLDqW5vbQ==
sn: Nom
cn:: UHLDqW5vbSBOb20=
mozillaNickname: Surnom
mail: adr1@ele.com
mozillaSecondEmail: adralt@ele.com
nsAIMid: pseudo aim
modifytimestamp: 1324509379
telephoneNumber: travail
homePhone: dom
facsimiletelephonenumber: fax
pager: pager
mobile: port
mozillaHomeStreet:: YWRyMSBwcml2w6ll
mozillaHomeStreet2:: YWRyMiBwcml2w6ll
mozillaHomeLocalityName: ville/locallite
mozillaHomeState:: w6l0YXQvcHJvdg==
mozillaHomePostalCode: codepos
mozillaHomeCountryName: pays
street: adr1 pro
mozillaWorkStreet2: adr2 pro
l: ville pro
st: etat pro
postalCode: codepro
c: payspro
title: fonction pro
ou: service pro
o: soc pro
mozillaWorkUrl: webpro
mozillaHomeUrl: web
birthyear: 1946
birthmonth: 12
birthday: 04
mozillaCustom1: d1
mozillaCustom2: d2
mozillaCustom3: d3
mozillaCustom4: d4
description: notes

convention:
- our "LDIF records" are inetOrgPerson + mozillaAbPersonAlpha + a few custom
  fields (categories)
- all keys are lowercase

 */

@implementation NGVCard (SOGoExtensions)

/* LDIF -> VCARD */
- (CardElement *) _elementWithTag: (NSString *) elementTag
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

- (void) _setPhoneValues: (NSDictionary *) ldifRecord
{
  CardElement *phone;

  phone = [self _elementWithTag: @"tel" ofType: @"work"];
  [phone setSingleValue: [ldifRecord objectForKey: @"telephonenumber"] forKey: @""];
  phone = [self _elementWithTag: @"tel" ofType: @"home"];
  [phone setSingleValue: [ldifRecord objectForKey: @"homephone"] forKey: @""];
  phone = [self _elementWithTag: @"tel" ofType: @"cell"];
  [phone setSingleValue: [ldifRecord objectForKey: @"mobile"] forKey: @""];
  phone = [self _elementWithTag: @"tel" ofType: @"fax"];
  [phone setSingleValue: [ldifRecord objectForKey: @"facsimiletelephonenumber"]
                 forKey: @""];
  phone = [self _elementWithTag: @"tel" ofType: @"pager"];
  [phone setSingleValue: [ldifRecord objectForKey: @"pager"] forKey: @""];
}

- (void) _setEmails: (NSDictionary *) ldifRecord
{
  CardElement *mail, *homeMail;

  mail = [self _elementWithTag: @"email" ofType: @"work"];
  [mail setSingleValue: [ldifRecord objectForKey: @"mail"] forKey: @""];
  homeMail = [self _elementWithTag: @"email" ofType: @"home"];
  [homeMail setSingleValue: [ldifRecord objectForKey: @"mozillasecondemail"] forKey: @""];
  [[self uniqueChildWithTag: @"x-mozilla-html"]
    setSingleValue: [ldifRecord objectForKey: @"mozillausehtmlmail"]
            forKey: @""];
}

- (void) updateFromLDIFRecord: (NSDictionary *) ldifRecord
{
  CardElement *element;
  NSArray *units;
  NSInteger year, yearOfToday, month, day;
  NSCalendarDate *now;
  NSString *ou;

  [self setNWithFamily: [ldifRecord objectForKey: @"sn"]
                 given: [ldifRecord objectForKey: @"givenname"]
            additional: nil prefixes: nil suffixes: nil];
  [self setNickname: [ldifRecord objectForKey: @"mozillanickname"]];
  [self setFn: [ldifRecord objectForKey: @"displayname"]];
  [self setTitle: [ldifRecord objectForKey: @"title"]];

  element = [self _elementWithTag: @"adr" ofType: @"home"];
  [element setSingleValue: [ldifRecord objectForKey: @"mozillahomestreet2"]
                  atIndex: 1 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"mozillahomestreet"]
                  atIndex: 2 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"mozillahomelocalityname"]
                  atIndex: 3 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"mozillahomestate"]
                  atIndex: 4 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"mozillahomepostalcode"]
                  atIndex: 5 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"mozillahomecountryname"]
                  atIndex: 6 forKey: @""];

  element = [self _elementWithTag: @"adr" ofType: @"work"];
  [element setSingleValue: [ldifRecord objectForKey: @"mozillaworkstreet2"]
                  atIndex: 1 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"street"]
                  atIndex: 2 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"l"]
                  atIndex: 3 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"st"]
                  atIndex: 4 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"postalcode"]
                  atIndex: 5 forKey: @""];
  [element setSingleValue: [ldifRecord objectForKey: @"c"]
                  atIndex: 6 forKey: @""];

  ou = [ldifRecord objectForKey: @"ou"];
  if (ou)
    units = [NSArray arrayWithObject: ou];
  else
    units = nil;
  [self setOrg: [ldifRecord objectForKey: @"o"]
         units: units];

  [self _setPhoneValues: ldifRecord];
  [self _setEmails: ldifRecord];
  [[self _elementWithTag: @"url" ofType: @"home"]
    setSingleValue: [ldifRecord objectForKey: @"mozillahomeurl"] forKey: @""];
  [[self _elementWithTag: @"url" ofType: @"work"]
    setSingleValue: [ldifRecord objectForKey: @"mozillaworkurl"] forKey: @""];
  
  [[self uniqueChildWithTag: @"x-aim"]
    setSingleValue: [ldifRecord objectForKey: @"nsaimid"]
            forKey: @""];

  now = [NSCalendarDate date];
  year = [[ldifRecord objectForKey: @"birthyear"] intValue];
  if (year < 100)
    {
      yearOfToday = [now yearOfCommonEra];
      if (year == 0)
        year = yearOfToday;
      else if (yearOfToday < (year + 2000))
        year += 1900;
      else
        year += 2000;
    }
  month = [[ldifRecord objectForKey: @"birthmonth"] intValue];
  day = [[ldifRecord objectForKey: @"birthday"] intValue];

  if (year && month && day)
    [self setBday: [NSString stringWithFormat: @"%.4d-%.2d-%.2d",
                             year, month, day]];
  else
    [self setBday: @""];

  [self setNote: [ldifRecord objectForKey: @"description"]];
  [self setCategories: [ldifRecord objectForKey: @"vcardcategories"]];

  [self cleanupEmptyChildren];
}

/* VCARD -> LDIF */
- (NSString *) _simpleValueForType: (NSString *) aType
                           inArray: (NSArray *) anArray
                         excluding: (NSString *) aTypeToExclude		  
{
  NSArray *elements;
  NSString *value;

  elements = [anArray cardElementsWithAttribute: @"type"
                                    havingValue: aType];
  value = nil;

  if ([elements count] > 0)
    {
      CardElement *ce;
      int i;

      for (i = 0; i < [elements count]; i++)
	{
	  ce = [elements objectAtIndex: i];
	  value = [ce flattenedValuesForKey: @""];

	  if (!aTypeToExclude)
	    break;
	  
	  if (![ce hasAttribute: @"type" havingValue: aTypeToExclude])
	    break;

	  value = nil;
	}
    }

  return value;
}

- (void) _setValue: (NSString *) key
                to: (NSString *) aValue
      inLDIFRecord: (NSMutableDictionary *) ldifRecord
{
  if (!aValue)
    aValue = @"";

  [ldifRecord setObject: aValue forKey: key];
}

- (void) _setupEmailFieldsInLDIFRecord: (NSMutableDictionary *) ldifRecord
{
  NSArray *elements;
  NSString *workMail, *homeMail, *mail, *secondEmail;
  NSUInteger max;

  elements = [self childrenWithTag: @"email"];

  max = [elements count];
  if (max > 0)
    {
      workMail = [self _simpleValueForType: @"work"
                                   inArray: elements excluding: nil];
      homeMail = [self _simpleValueForType: @"home"
                                   inArray: elements excluding: nil];

      mail = workMail;
      if (mail)
        secondEmail = homeMail;
      else
        {
          secondEmail = nil;
          mail = homeMail;
        }

      if (!mail)
        {
          mail = [[elements objectAtIndex: 0] flattenedValuesForKey: @""];
          if (max > 1) /* we know secondEmail is not set here either... */
            secondEmail = [[elements objectAtIndex: 1] flattenedValuesForKey: @""];
        }

      [self _setValue: @"mail" to: mail inLDIFRecord: ldifRecord];
      [self _setValue: @"mozillasecondemail" to: secondEmail inLDIFRecord: ldifRecord];
    }

  [self _setValue: @"mozillausehtmlmail"
               to: [[self uniqueChildWithTag: @"x-mozilla-html"]
                     flattenedValuesForKey: @""]
      inLDIFRecord: ldifRecord];
}

- (void) _setupOrgFieldsInLDIFRecord: (NSMutableDictionary *) ldifRecord
{
  NSMutableArray *orgServices;
  CardElement *org;
  NSString *service;
  NSUInteger count, max;

  org = [self org];
  [self _setValue: @"o"
               to: [org flattenedValueAtIndex: 0 forKey: @""]
      inLDIFRecord: ldifRecord];
  max = [[org valuesForKey: @""] count];
  if (max > 1)
    {
      orgServices = [NSMutableArray arrayWithCapacity: max];
      for (count = 1; count < max; count++)
        {
          service = [org flattenedValueAtIndex: count forKey: @""];
          if ([service length] > 0)
            [orgServices addObject: service];
        }

      [self _setValue: @"ou"
                   to: [orgServices componentsJoinedByString: @", "]
          inLDIFRecord: ldifRecord];
    }
}

- (NSMutableDictionary *) asLDIFRecord
{
  NSArray *elements, *categories;
  CardElement *element;
  NSMutableDictionary *ldifRecord;
  NSCalendarDate *birthDay;
  NSString *dn, *stringValue, *stringValue2;

  ldifRecord = [NSMutableDictionary dictionaryWithCapacity: 32];
  [ldifRecord setObject: [NSArray arrayWithObjects: @"top", @"inetOrgPerson",
                                 @"mozillaAbPersonAlpha", nil]
                forKey: @"objectClass"];

  element = [self n];
  [self _setValue: @"sn"
               to: [element flattenedValueAtIndex: 0 forKey: @""]
      inLDIFRecord: ldifRecord];
  [self _setValue: @"givenname"
               to: [element flattenedValueAtIndex: 1 forKey: @""]
      inLDIFRecord: ldifRecord];
  [self _setValue: @"displayname" to: [self fn]
      inLDIFRecord: ldifRecord];
  [self _setValue: @"mozillanickname" to: [self nickname]
      inLDIFRecord: ldifRecord];

  elements = [self childrenWithTag: @"tel"];
  // We do this (exclude FAX) in order to avoid setting the WORK number as the FAX
  // one if we do see the FAX field BEFORE the WORK number.
  [self _setValue: @"telephonenumber"
               to: [self _simpleValueForType: @"work" inArray: elements
                                   excluding: @"fax"]
      inLDIFRecord: ldifRecord];
  [self _setValue: @"homephone"
               to: [self _simpleValueForType: @"home" inArray: elements
                                   excluding: @"fax"]
      inLDIFRecord: ldifRecord];
  [self _setValue: @"mobile"
               to: [self _simpleValueForType: @"cell" inArray: elements
                                   excluding: nil]
      inLDIFRecord: ldifRecord];
  [self _setValue: @"facsimiletelephonenumber"
               to: [self _simpleValueForType: @"fax" inArray: elements
                                   excluding: nil]
      inLDIFRecord: ldifRecord];
  [self _setValue: @"pager"
               to: [self _simpleValueForType: @"pager" inArray: elements
                                   excluding: nil]
      inLDIFRecord: ldifRecord];

  // If we don't have a "home" and "work" phone number but
  // we have a "voice" one defined, we set it to the "work" value
  // This can happen when we have :
  // VERSION:2.1
  // N:name;surname;;;;
  // TEL;VOICE;HOME:
  // TEL;VOICE;WORK:
  // TEL;PAGER:
  // TEL;FAX;WORK:
  // TEL;CELL:514 123 1234
  // TEL;VOICE:450 456 6789
  // ADR;HOME:;;;;;;
  // ADR;WORK:;;;;;;
  // ADR:;;;;;;
  if ([[ldifRecord objectForKey: @"telephonenumber"] length] == 0 &&
      [[ldifRecord objectForKey: @"homephone"] length] == 0 &&
      [elements count] > 0)
    [self _setValue: @"telephonenumber"
                 to: [self _simpleValueForType: @"voice" inArray: elements
                                     excluding: nil]
        inLDIFRecord: ldifRecord];

  [self _setupEmailFieldsInLDIFRecord: ldifRecord];

  [self _setValue: @"nsaimid"
               to: [[self uniqueChildWithTag: @"x-aim"]
                     flattenedValuesForKey: @""]
      inLDIFRecord: ldifRecord];

  elements = [self childrenWithTag: @"adr"
                   andAttribute: @"type" havingValue: @"work"];
  if (elements && [elements count] > 0)
    {
      element = [elements objectAtIndex: 0];
      [self _setValue: @"mozillaworkstreet2"
                   to: [element flattenedValueAtIndex: 1 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"street"
                   to: [element flattenedValueAtIndex: 2 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"l"
                   to: [element flattenedValueAtIndex: 3 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"st"
                   to: [element flattenedValueAtIndex: 4 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"postalcode"
                   to: [element flattenedValueAtIndex: 5 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"c"
                   to: [element flattenedValueAtIndex: 6 forKey: @""]
          inLDIFRecord: ldifRecord];
    }

  elements = [self childrenWithTag: @"adr"
                   andAttribute: @"type" havingValue: @"home"];
  if (elements && [elements count] > 0)
    {
      element = [elements objectAtIndex: 0];
      [self _setValue: @"mozillahomestreet2"
                   to: [element flattenedValueAtIndex: 1 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"mozillahomestreet"
                   to: [element flattenedValueAtIndex: 2 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"mozillahomelocalityname"
                   to: [element flattenedValueAtIndex: 3 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"mozillahomestate"
                   to: [element flattenedValueAtIndex: 4 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"mozillahomepostalcode"
                   to: [element flattenedValueAtIndex: 5 forKey: @""]
          inLDIFRecord: ldifRecord];
      [self _setValue: @"mozillahomecountryname"
                   to: [element flattenedValueAtIndex: 6 forKey: @""]
          inLDIFRecord: ldifRecord];
    }

  elements = [self childrenWithTag: @"url"];
  [self _setValue: @"mozillaworkurl"
               to: [self _simpleValueForType: @"work" inArray: elements
                                   excluding: nil]
      inLDIFRecord: ldifRecord];
  [self _setValue: @"mozillahomeurl"
               to: [self _simpleValueForType: @"home" inArray: elements
                                   excluding: nil]
      inLDIFRecord: ldifRecord];
  
  // If we don't have a "work" or "home" URL but we still have 
  // an URL field present, let's add it to the "home" value
  if ([[ldifRecord objectForKey: @"mozillaworkurl"] length] == 0 &&
      [[ldifRecord objectForKey: @"mozillahomeurl"] length] == 0 &&
      [elements count] > 0)
    [self _setValue: @"mozillahomeurl"
                 to: [[elements objectAtIndex: 0]
                       flattenedValuesForKey: @""]
        inLDIFRecord: ldifRecord];
  // If we do have a "work" URL but no "home" URL but two
  // values URLs present, let's add the second one as the home URL
  else if ([[ldifRecord objectForKey: @"mozillaworkurl"] length] > 0 &&
	   [[ldifRecord objectForKey: @"mozillahomeurl"] length] == 0 &&
	   [elements count] > 1)
    {
      int i;

      for (i = 0; i < [elements count]; i++)
	{
	  if ([[[elements objectAtIndex: i] flattenedValuesForKey: @""]
		caseInsensitiveCompare: [ldifRecord objectForKey: @"mozillaworkurl"]] != NSOrderedSame)
	    {
	      [self _setValue: @"mozillahomeurl"
                           to: [[elements objectAtIndex: i]
                                 flattenedValuesForKey: @""]
                  inLDIFRecord: ldifRecord];
	      break;
	    }
	}
    }
    
  [self _setValue: @"title" to: [self title] inLDIFRecord: ldifRecord];
  [self _setupOrgFieldsInLDIFRecord: ldifRecord];

  categories = [self categories];
  if ([categories count] > 0)
    [ldifRecord setValue: categories forKey: @"vcardcategories"];

  birthDay = [[self bday] asCalendarDate];
  if (birthDay)
    {
      stringValue = [NSString stringWithFormat: @"%.4d", [birthDay yearOfCommonEra]];
      [self _setValue: @"birthyear" to: stringValue inLDIFRecord: ldifRecord];
      stringValue = [NSString stringWithFormat: @"%.2d", [birthDay monthOfYear]];
      [self _setValue: @"birthmonth" to: stringValue inLDIFRecord: ldifRecord];
      stringValue = [NSString stringWithFormat: @"%.2d", [birthDay dayOfMonth]];
      [self _setValue: @"birthday" to: stringValue inLDIFRecord: ldifRecord];
    }
  [self _setValue: @"description" to: [self note] inLDIFRecord: ldifRecord];

  stringValue = [ldifRecord objectForKey: @"displayname"];
  stringValue2 = [ldifRecord objectForKey: @"mail"];
  if ([stringValue length] > 0)
    {
      if ([stringValue2 length] > 0)
        dn = [NSString stringWithFormat: @"cn=%@,mail=%@",
                       stringValue, stringValue2];
      else
        dn = [NSString stringWithFormat: @"cn=%@", stringValue];
    }
  else if ([stringValue2 length] > 0)
    dn = [NSString stringWithFormat: @"mail=%@", stringValue2];
  else
    dn = @"";
  [ldifRecord setObject: dn forKey: @"dn"];

  return ldifRecord;
}

@end /* NGVCard */
