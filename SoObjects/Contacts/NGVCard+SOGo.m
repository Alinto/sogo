/* NGVCard+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2016 Inverse inc.
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


#import <Foundation/NSTimeZone.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>

#import <NGCards/NSArray+NGCards.h>
#import <NGCards/NSString+NGCards.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSCalendarDate+SOGo.h>

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

- (void) addElementWithTag: (NSString *) elementTag
                    ofType: (NSString *) type
                 withValue: (id) value
{
  NSArray *allValues;
  NSEnumerator *list;
  CardElement *element;

  // value is either an array or a string
  if ([value isKindOfClass: [NSString class]])
    allValues = [NSArray arrayWithObject: value];
  else
    allValues = value;

  // Add all values as separate elements
  list = [allValues objectEnumerator];
  while ((value = [list nextObject]))
    {
      if ([type length])
        element = [CardElement simpleElementWithTag: elementTag
                                         singleType: type
                                              value: value];
      else
        element = [CardElement simpleElementWithTag: elementTag
                                              value: value];
      [self addChild: element];
    }
}

- (void) _setPhoneValues: (NSDictionary *) ldifRecord
{
  [self addElementWithTag: @"tel"
                   ofType: @"work"
                withValue: [ldifRecord objectForKey: @"telephonenumber"]];
  [self addElementWithTag: @"tel"
                   ofType: @"home"
                withValue: [ldifRecord objectForKey: @"homephone"]];
  [self addElementWithTag: @"tel"
                   ofType: @"cell"
                withValue: [ldifRecord objectForKey: @"mobile"]];
  [self addElementWithTag: @"tel"
                   ofType: @"fax"
                withValue: [ldifRecord objectForKey: @"facsimiletelephonenumber"]];
  [self addElementWithTag: @"tel"
                   ofType: @"pager"
                withValue: [ldifRecord objectForKey: @"pager"]];
}

- (void) _setEmails: (NSDictionary *) ldifRecord
{
  CardElement *homeMail;
  NSString* mail;

  // Emails from the configured mail fields of the source have already been extracted in
  // [LDAPSource _fillEmailsOfEntry:intoLDIFRecord:]
  [self addElementWithTag: @"email"
                   ofType: @"work"
                withValue: [ldifRecord objectForKey: @"c_emails"]];
  // When importing an LDIF file, add the default mail attribute
  mail = [ldifRecord objectForKey: @"mail"];
  if ([mail length] && ![[self emails] containsObject: mail])
    [self addElementWithTag: @"email"
                     ofType: @"work"
                  withValue: [ldifRecord objectForKey: @"mail"]];
  homeMail = [self elementWithTag: @"email" ofType: @"home"];
  [homeMail setSingleValue: [ldifRecord objectForKey: @"mozillasecondemail"] forKey: @""];
  [[self uniqueChildWithTag: @"x-mozilla-html"]
    setSingleValue: [ldifRecord objectForKey: @"mozillausehtmlmail"]
            forKey: @""];
}

- (void) updateFromLDIFRecord: (NSDictionary *) ldifRecord
{
  NSInteger year, yearOfToday, month, day;
  CardElement *element;
  NSCalendarDate *now;
  NSMutableArray *units;
  NSString *fn;
  id o, ou;

  [self setNWithFamily: [ldifRecord objectForKey: @"sn"]
                 given: [ldifRecord objectForKey: @"givenname"]
            additional: nil prefixes: nil suffixes: nil];
  [self setNickname: [ldifRecord objectForKey: @"mozillanickname"]];
  [self setTitle: [ldifRecord objectForKey: @"title"]];

  fn = [ldifRecord objectForKey: @"displayname"];
  if (!fn)
    fn = [ldifRecord objectForKey: @"cn"];
  [self setFn: fn];

  element = [self elementWithTag: @"adr" ofType: @"home"];
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

  element = [self elementWithTag: @"adr" ofType: @"work"];
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
  if ([ou isKindOfClass: [NSArray class]])
    units = [NSMutableArray arrayWithArray: (NSArray *)ou];
  else if (ou)
    units = [NSMutableArray arrayWithObject: ou];
  else
    units = [NSMutableArray array];
  o = [ldifRecord objectForKey: @"o"];
  if ([o isKindOfClass: [NSArray class]])
    [units addObjectsFromArray: (NSArray *)o];
  else if (ou)
    [units addObject: o];
  [self setOrganizations: units];

  [self _setPhoneValues: ldifRecord];
  [self _setEmails: ldifRecord];
  [[self elementWithTag: @"url" ofType: @"home"]
    setSingleValue: [ldifRecord objectForKey: @"mozillahomeurl"] forKey: @""];
  [[self elementWithTag: @"url" ofType: @"work"]
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
                             (int)year, (int)month, (int)day]];
  else
    [self setBday: @""];

  /* hack to carry SOGoLDAPContactInfo to vcards */
  [[self uniqueChildWithTag: @"x-sogo-contactinfo"]
    setSingleValue: [ldifRecord objectForKey: @"c_info"]
            forKey: @""];

  o = [ldifRecord objectForKey: @"description"];
  if ([o isKindOfClass: [NSArray class]])
    [self setNotes: o];
  else
    [self setNote: o];

  o = [ldifRecord objectForKey: @"vcardcategories"];

  // We can either have an array (from SOGo's web gui) or a
  // string (from a LDIF import) as the value here.
  if ([o isKindOfClass: [NSArray class]])
    [self setCategories: o];
  else
    [self setCategories: [o componentsSeparatedByString: @","]];

  // Photo
  if ([ldifRecord objectForKey: @"photo"])
    [self setPhoto: [[ldifRecord objectForKey: @"photo"] stringByEncodingBase64]];

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

  elements = [self childrenWithTag: @"adr"
                   andAttribute: @"type" havingValue: @"work"];

  if (!elements || [elements count] == 0)
    elements = [self childrenWithTag: @"adr"];

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
      stringValue = [NSString stringWithFormat: @"%.4d", (int)[birthDay yearOfCommonEra]];
      [self _setValue: @"birthyear" to: stringValue inLDIFRecord: ldifRecord];
      stringValue = [NSString stringWithFormat: @"%.2d", (int)[birthDay monthOfYear]];
      [self _setValue: @"birthmonth" to: stringValue inLDIFRecord: ldifRecord];
      stringValue = [NSString stringWithFormat: @"%.2d", (int)[birthDay dayOfMonth]];
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

- (NSString *) workCompany
{
  CardElement *org;
  NSString *company;

  org = [self org];
  company = [org flattenedValueAtIndex: 0 forKey: @""];
  if ([company length] == 0)
    company = nil;

  return company;
}

- (void) setOrganizations: (NSArray *) newOrganizations
{
  CardElement *org;
  NSArray *elements;
  NSUInteger count, max;

  // First remove all current org properties
  elements = [self childrenWithTag: @"org"];
  [self removeChildren: elements];

  org = [self uniqueChildWithTag: @"org"];
  max = [newOrganizations count];
  for (count = 0; count < max; count++)
    {
      [org setSingleValue: [newOrganizations objectAtIndex: count]
                  atIndex: count forKey: @""];
    }
}

- (NSArray *) organizations
{
  CardElement *org;
  NSArray *organizations;
  NSEnumerator *orgs;
  NSMutableArray *flattenedOrganizations;
  NSString *value;
  NSUInteger count, max;

  // Get all org properties
  orgs = [[self childrenWithTag: @"org"] objectEnumerator];
  flattenedOrganizations = [NSMutableArray array];
  while ((org = [orgs nextObject]))
    {
      // Get all values of each org property
      organizations = [org valuesForKey: @""];
      max = [organizations count];
      for (count = 0; count < max; count++)
        {
          value = [[organizations objectAtIndex: count] lastObject];
          if ([value length])
            [flattenedOrganizations addObject: value];
        }
    }

  return flattenedOrganizations;
}

- (NSString *) fullName
{
  CardElement *n;
  NSString *fn, *firstName, *lastName, *org;

  fn = [self fn];
  if ([fn length] == 0)
    {
      n = [self n];
      lastName = [n flattenedValueAtIndex: 0 forKey: @""];
      firstName = [n flattenedValueAtIndex: 1 forKey: @""];
      if ([firstName length] > 0)
        {
          if ([lastName length] > 0)
            fn = [NSString stringWithFormat: @"%@ %@", firstName, lastName];
          else
            fn = firstName;
        }
      else if ([lastName length] > 0)
        fn = lastName;
      else
        {
          n = [self org];
          org = [n flattenedValueAtIndex: 0 forKey: @""];
          fn = org;
        }
    }

  return fn;
}

- (NSArray *) emails
{
  NSArray *elements;
  NSMutableArray *emails;
  NSString *email;
  int i;

  emails = [NSMutableArray array];
  elements = [self childrenWithTag: @"email"];

  for (i = [elements count]-1; i >= 0; i--)
    {
      email = [[elements objectAtIndex: i] flattenedValuesForKey: @""];
      if ([email caseInsensitiveCompare: [self preferredEMail]] == NSOrderedSame)
        // First element of array is the preferred email address
        [emails insertObject: email atIndex: 0];
      else
        [emails addObject: email];
    }

  return emails;
}

- (NSArray *) secondaryEmails
{
  NSMutableArray *emails;
  NSString *email;
  int i;

  emails = [NSMutableArray array];

  [emails addObjectsFromArray: [self childrenWithTag: @"email"]];
  [emails removeObjectsInArray: [self childrenWithTag: @"email"
                                         andAttribute: @"type"
                                          havingValue: @"pref"]];

  for (i = [emails count]-1; i >= 0; i--)
    {
      email = [[emails objectAtIndex: i] flattenedValuesForKey: @""];

      if ([email caseInsensitiveCompare: [self preferredEMail]] == NSOrderedSame)
        [emails removeObjectAtIndex: i];
    }

  return emails;
}

- (NSString *) _phoneOfType: (NSString *) aType
		  excluding: (NSString *) aTypeToExclude
{
  NSArray *elements, *phones;
  NSString *phone;

  phones = [self childrenWithTag: @"tel"];
  elements = [phones cardElementsWithAttribute: @"type"
                     havingValue: aType];

  phone = nil;

  if ([elements count] > 0)
    {
      CardElement *ce;
      int i;

      for (i = 0; i < [elements count]; i++)
	{
	  ce = [elements objectAtIndex: i];
	  phone = [ce flattenedValuesForKey: @""];

	  if (!aTypeToExclude)
	    break;

	  if (![ce hasAttribute: @"type" havingValue: aTypeToExclude])
	    break;

	  phone = nil;
	}
    }

  return phone;
}

- (NSString *) workPhone
{
  // We do this (exclude FAX) in order to avoid setting the WORK number as the FAX
  // one if we do see the FAX field BEFORE the WORK number.
  return [self _phoneOfType: @"work" excluding: @"fax"];
}

- (NSString *) homePhone
{
  return [self _phoneOfType: @"home" excluding: @"fax"];
}

- (NSString *) fax
{
  return [self _phoneOfType: @"fax" excluding: nil];
}

- (NSString *) mobile
{
  return [self _phoneOfType: @"cell" excluding: nil];
}

- (NSString *) pager
{
  return [self _phoneOfType: @"pager" excluding: nil];
}

- (NSCalendarDate *) birthday
{
  NSString *bday, *value;
  NSCalendarDate *date;

  bday = [self bday];
  date = nil;
  if ([bday length] > 0)
    {
      // Expected format of BDAY is YYYY[-]MM[-]DD
      value = [bday stringByReplacingString: @"-" withString: @""];
      date = [NSCalendarDate dateFromShortDateString: value
                                  andShortTimeString: nil
                                          inTimeZone: [NSTimeZone timeZoneWithName: @"GMT"]];
    }

  return date;
}

- (void) setNotes: (NSArray *) newNotes
{
  NSArray *elements;
  NSUInteger count, max;

  elements = [self childrenWithTag: @"note"];
  [self removeChildren: elements];
  max = [newNotes count];
  for (count = 0; count < max; count++)
    {
      [self addChildWithTag: @"note"
                      types: nil
                singleValue: [newNotes objectAtIndex: count]];
    }
}


- (NSArray *) notes
{
  NSArray *notes;
  NSMutableArray *flattenedNotes;
  NSString *note;
  NSUInteger count, max;

  notes = [self childrenWithTag: @"note"];
  max = [notes count];
  flattenedNotes = [NSMutableArray arrayWithCapacity: max];

  for (count = 0; count < max; count++)
    {
      note = [[notes objectAtIndex: count] flattenedValuesForKey: @""];
      [flattenedNotes addObject: note];
    }

  return flattenedNotes;
}

- (NSMutableDictionary *) quickRecordFromContent: (NSString *) theContent
                                       container: (id) theContainer
				 nameInContainer: (NSString *) nameInContainer
{
  NSMutableDictionary *fields;
  CardElement *element;
  NSString *value;
  NSArray *v;

  fields = [NSMutableDictionary dictionaryWithCapacity: 16];

  value = [self fn];
  if (value)
    [fields setObject: value forKey: @"c_cn"];
  element = [self n];
  [fields setObject: [element flattenedValueAtIndex: 0 forKey: @""]
             forKey: @"c_sn"];
  [fields setObject: [element flattenedValueAtIndex: 1 forKey: @""]
             forKey: @"c_givenName"];
  value = [self preferredTel];
  if (value)
    [fields setObject: value forKey: @"c_telephonenumber"];
  v = [self emails];
  if ([v count] > 0)
    [fields setObject: [v componentsJoinedByString: @","]
               forKey: @"c_mail"];
  else
    [fields setObject: [NSNull null] forKey: @"c_mail"];
  element = [self org];
  [fields setObject: [element flattenedValueAtIndex: 0 forKey: @""]
             forKey: @"c_o"];
  [fields setObject: [element flattenedValueAtIndex: 1 forKey: @""]
             forKey: @"c_ou"];
  element = [self preferredAdr];
  if (element && ![element isVoid])
    [fields setObject: [element flattenedValueAtIndex: 3
                                               forKey: @""]
               forKey: @"c_l"];
  value = [[self uniqueChildWithTag: @"X-AIM"] flattenedValuesForKey: @""];
  [fields setObject: value forKey: @"c_screenname"];
  v = [[self categories] trimmedComponents];
  if ([v count] > 0)
    [fields setObject: [v componentsJoinedByString: @","]
               forKey: @"c_categories"];
  else
    [fields setObject: [NSNull null] forKey: @"c_categories"];
  [fields setObject: @"vcard" forKey: @"c_component"];

  return fields;
}

@end /* NGVCard */
