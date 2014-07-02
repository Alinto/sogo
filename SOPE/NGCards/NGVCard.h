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

#ifndef __NGiCal_NGVCard_H__
#define __NGiCal_NGVCard_H__

#import "CardGroup.h"

/*
  NGVCard
  
  Represents a vCard object.

  XML DTD in Dawson-03 Draft:
    <!ELEMENT vCard      (%prop.man;, (%prop.opt;)*)>
    
    <!ATTLIST vCard
            %attr.lang;
            xmlns     CDATA #FIXED 
        'http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-02.txt'
            xmlns:vcf CDATA #FIXED 
        'http://www.ietf.org/internet-drafts/draft-dawson-vcard-xml-dtd-02.txt'
            version   CDATA #REQUIRED
            rev       CDATA #IMPLIED
            uid       CDATA #IMPLIED
            prodid    CDATA #IMPLIED
            class (PUBLIC | PRIVATE | CONFIDENTIAL) "PUBLIC"
            value NOTATION (VCARD) #IMPLIED>
    <!-- version - Must be "3.0" if document conforms to this spec -->
    <!-- rev - ISO 8601 formatted date or date/time string -->
    <!-- uid - UID associated with the object described by the vCard -->
    <!-- prodid - ISO 9070 FPI for product that generated vCard -->
    <!-- class - Security classification for vCard information -->
  
  Mandatory elements:
    n
    fn
*/

@class NSArray;
@class NSDictionary;
@class NSString;

/* this should be merged in a common definition headers with iCalAccessClass */
typedef enum
{
  NGCardsAccessPublic = 0,
  NGCardsAccessPrivate = 1,
  NGCardsAccessConfidential = 2,
} NGCardsAccessClass;

@interface NGVCard : CardGroup

+ (id) cardWithUid: (NSString *) _uid;
- (id) initWithUid: (NSString *) _uid;

/* accessors */

- (void) setVersion: (NSString *) _version;
- (NSString *) version;

- (void) setUid: (NSString *) _uid;
- (NSString *) uid;

- (void) setPreferred: (CardElement *) aChild;

- (void) setVClass: (NSString *) _s;
- (NSString *) vClass;
- (void) setProdID: (NSString *) _s;
- (NSString *) prodID;
- (void) setProfile: (NSString *) _s;
- (NSString *) profile;
- (void) setSource: (NSString *) _s;
- (NSString *) source;

- (void) setFn: (NSString *) _fn;
- (NSString *) fn;
- (void) setNickname: (NSString *) aValue;
- (NSString *) nickname;

- (void) setRole: (NSString *) _s;
- (NSString *) role;
- (void) setTitle: (NSString *) _title;
- (NSString *) title;
- (void) setBday: (NSString *) _bday;
- (NSString *) bday;
- (void) setNote: (NSString *) _note;
- (NSString *) note;
- (void) setTz: (NSString *) _tz;
- (NSString *) tz;

- (void) addTel: (NSString *) phoneNumber
          types: (NSArray *) types;
- (void) addEmail: (NSString *) emailAddress
            types: (NSArray *) types;

- (void) setNWithFamily: (NSString *) family
                  given: (NSString *) given
             additional: (NSString *) additional
               prefixes: (NSString *) prefixes
               suffixes: (NSString *) suffixes;
/* returns an array of single values */
- (CardElement *) n;

- (void) setOrg: (NSString *) anOrg
          units: (NSArray *) someUnits;
- (CardElement *) org;

- (void) setCategories: (NSArray *) newCategories;
- (NSArray *) categories;
- (NSString *) photo;
- (void) setPhoto: (NSString *) _value;


// - (void) setN: (NGVCardName *) _v;
// - (NGVCardName *) n;
// - (void) setOrg: (NGVCardOrg *) _v;
// - (NGVCardOrg *) org;

// - (void) setTel: (NSArray *) _tel;
// - (NSArray *) tel;
// - (void) setAdr: (NSArray *) _adr;
// - (NSArray *) adr;
// - (void) setEmail: (NSArray *) _array;
// - (NSArray *) email;
// - (void) setLabel: (NSArray *) _array;
// - (NSArray *) label;
// - (void) setUrl: (NSArray *) _url;
// - (NSArray *) url;

// - (void) setFreeBusyURL: (NSArray *) _v;
// - (NSArray *) freeBusyURL;
// - (void) setCalURI: (NSArray *) _calURI;
// - (NSArray *) calURI;

// - (void) setX: (NSDictionary *) _dict;
// - (NSDictionary *) x;

/* convenience */

- (NSString *) preferredEMail;
- (NSString *) preferredTel;
- (CardElement *) preferredAdr;

@end

#endif /* __NGiCal_NGVCard_H__ */
