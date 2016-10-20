/*
  Copyright (C) 2005-2015 Inverse inc.

  This file is part of SOGo.
 
  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.
 
  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.
 
  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>
#import <NGCards/NSArray+NGCards.h>
#import <NGExtensions/NSString+Ext.h>
#import <NGExtensions/NSString+misc.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import <Contacts/NGVCard+SOGo.h>
#import <Contacts/SOGoContactObject.h>

#import "UIxContactView.h"

@implementation UIxContactView

- (id) init
{
  if ((self = [super init]))
    {
      photosURL = nil;
      card = nil;
      phones = nil;
      homeAdr = nil;
      workAdr = nil;
    }

  return self;
}

- (void) dealloc
{
  [card release];
  [photosURL release];
  [super dealloc];
}

/* accessors */

// - (NSString *) _cardStringWithLabel: (NSString *) label
//                               value: (NSString *) value
//                byEscapingHTMLString: (BOOL) escapeHTML
//                        asLinkScheme: (NSString *) scheme
//                  withLinkAttributes: (NSString *) attrs
// {
//   NSMutableString *cardString;

//   cardString = [NSMutableString stringWithCapacity: 80];
//   value = [value stringByReplacingString: @"\r" withString: @""];
//   if ([value length] > 0)
//     {
//       if (escapeHTML)
//         value = [value stringByEscapingHTMLString];
//       if ([scheme length] > 0)
//         value = [NSString stringWithFormat: @"<a href=\"%@%@\" %@>%@</a>", scheme, value, attrs, value];

//       if (label)
//         [cardString appendFormat: @"<dt>%@</dt><dd>%@</dd>\n",
//                     [self labelForKey: label], value];
//       else
//         [cardString appendFormat: @"<dt></dt><dd>%@</dd>\n", value];
//     }

//   return cardString;
// }

// - (NSString *) _cardStringWithLabel: (NSString *) label
//                               value: (NSString *) value
// {
//   return [self _cardStringWithLabel: label
//                               value: value
//                byEscapingHTMLString: YES
//                        asLinkScheme: nil
//                  withLinkAttributes: nil];
// }

// - (NSString *) _cardStringWithLabel: (NSString *) label
//                               value: (NSString *) value
//                        asLinkScheme: (NSString *) scheme
// {
//   return [self _cardStringWithLabel: label
//                               value: value
//                byEscapingHTMLString: YES
//                        asLinkScheme: scheme
//                  withLinkAttributes: nil];
// }

// - (NSString *) displayName
// {
//   return [self _cardStringWithLabel: @"Display Name:"
//                value: [card fn]];
// }

// - (NSString *) nickName
// {
//   return [self _cardStringWithLabel: @"Nickname:"
//                value: [card nickname]];
// }

// - (NSString *) fullName
// {
//   return [card fullName];
// }

- (NSArray *) _languageContactsCategories
{
  NSArray *categoryLabels;

  categoryLabels = [[self labelForKey: @"contacts_category_labels"] componentsSeparatedByString: @","];
  if (!categoryLabels)
    categoryLabels = [NSArray array];
  
  return [categoryLabels trimmedComponents];
}

- (NSArray *) _fetchAndCombineCategoriesList
{
  NSString *ownerLogin;
  SOGoUserDefaults *ud;
  NSArray *cats, *newCats, *contactCategories;

  ownerLogin = [[self clientObject] ownerInContext: context];
  ud = [[SOGoUser userWithLogin: ownerLogin] userDefaults];
  cats = [ud contactsCategories];
  if (!cats)
    cats = [self _languageContactsCategories];

  contactCategories = [card categories];
  if (contactCategories)
    {
      newCats = [cats mergedArrayWithArray: [contactCategories trimmedComponents]];
      if ([newCats count] != [cats count])
        {
          cats = [newCats sortedArrayUsingSelector:
                            @selector (localizedCaseInsensitiveCompare:)];
          [ud setContactsCategories: cats];
          [ud synchronize];
        }
    }

  return cats;
}

// - (NSString *) primaryEmail
// {
//   NSString *email, *fn, *attrs;

//   email = [card preferredEMail];
//   if ([email length] > 0)
//     {
//       fn = [card fn];
//       if ([fn length] > 0)
//         attrs = [NSString stringWithFormat: @"%@ <%@>", fn, email];
//       else
//         attrs = email;
//       attrs = [attrs stringByReplacingString: @"'"  withString: @"\\'"];
//       attrs = [attrs stringByReplacingString: @"\""  withString: @"\\\""];
//       attrs = [NSString stringWithFormat: @"onclick=\"return openMailTo('%@');\"", attrs];
//     }
//   else
//     {
//       attrs = nil;
//     }

//   return [self _cardStringWithLabel: @"Email:"
//                               value: email
//                byEscapingHTMLString: YES
//                        asLinkScheme: @"mailto:"
//                  withLinkAttributes: attrs];
// }

// - (NSArray *) secondaryEmails
// {
//   NSMutableArray *secondaryEmails;
//   NSString *email, *fn, *attrs;
//   NSArray *emails;

//   emails = [card secondaryEmails];
//   secondaryEmails = [NSMutableArray array];
//   attrs = nil;

//   // We might not have a preferred item but rather something like this:
//   // EMAIL;TYPE=work:dd@ee.com
//   // EMAIL;TYPE=home:ff@gg.com
//   // 
//   // or:
//   //
//   // EMAIL;TYPE=INTERNET:a@a.com                                                  
//   // EMAIL;TYPE=INTERNET,HOME:b@b.com
//   // 
//   // In this case, we always return the entry NOT matching the primaryEmail
//   if ([emails count] > 0)
//     {
//       int i;

//       for (i = 0; i < [emails count]; i++)
// 	{
// 	  email = [[emails objectAtIndex: i] flattenedValuesForKey: @""];
//           if ([email length])
//             {
//               fn = [card fn];
//               if ([fn length])
//                 attrs = [NSString stringWithFormat: @"%@ <%@>", fn, email];
//               else
//                 attrs = email;
//               attrs = [attrs stringByReplacingString: @"'"  withString: @"\\'"];
//               attrs = [attrs stringByReplacingString: @"\""  withString: @"\\\""];
//               attrs = [NSString stringWithFormat: @"onclick=\"return openMailTo('%@');\"", attrs];

//               [secondaryEmails addObject: [self _cardStringWithLabel: nil
//                                                                value: email
//                                                 byEscapingHTMLString: YES
//                                                         asLinkScheme: @"mailto:"
//                                                   withLinkAttributes: attrs]];
//             }
//         }
//     }
//   else
//     {
//       [secondaryEmails addObject: [self _cardStringWithLabel: nil
//                                                        value: nil]];
//     }


//   return secondaryEmails;
// }

// - (NSString *) screenName
// {
//   NSString *screenName;

//   screenName = [[card uniqueChildWithTag: @"x-aim"] flattenedValuesForKey: @""];

//   return [self _cardStringWithLabel: @"Screen Name:"
//                               value: screenName
//                        asLinkScheme: @"aim:goim?screenname="];
// }

// - (NSString *) preferredTel
// {
//   return [self _cardStringWithLabel: @"Phone Number:"
//                               value: [card preferredTel] asLinkScheme: @"tel:"];
// }

// - (NSString *) preferredAddress
// {
//   return @"";
// }

// - (BOOL) hasTelephones
// {
//   if (!phones)
//     phones = [card childrenWithTag: @"tel"];

//   return ([phones count] > 0);
// }

// - (NSString *) workPhone
// {
//   // We do this (exclude FAX) in order to avoid setting the WORK number as the FAX
//   // one if we do see the FAX field BEFORE the WORK number.
//   return [self _cardStringWithLabel: @"Work:" value: [card workPhone] asLinkScheme: @"tel:"];
// }

// - (NSString *) homePhone
// {
//   return [self _cardStringWithLabel: @"Home:" value: [card homePhone] asLinkScheme: @"tel:"];
// }

// - (NSString *) fax
// {
//   return [self _cardStringWithLabel: @"Fax:" value: [card fax] asLinkScheme: @"tel:"];
// }

// - (NSString *) mobile
// {
//   return [self _cardStringWithLabel: @"Mobile:" value: [card mobile] asLinkScheme: @"tel:"];
// }

// - (NSString *) pager
// {
//   return [self _cardStringWithLabel: @"Pager:" value: [card pager] asLinkScheme: @"tel:"];
// }

// - (BOOL) hasHomeInfos
// {
//   BOOL result;
//   NSArray *elements;

//   elements = [card childrenWithTag: @"adr"
//                    andAttribute: @"type"
//                    havingValue: @"home"];
//   if ([elements count] > 0)
//     {
//       result = YES;
//       homeAdr = [elements objectAtIndex: 0];
//     }
//   else
//     result = ([[card childrenWithTag: @"url"
//                      andAttribute: @"type"
//                      havingValue: @"home"] count] > 0);

//   return result;
// }

// - (NSString *) homePobox
// {
//   return [self _cardStringWithLabel: nil
//                               value: [homeAdr flattenedValueAtIndex: 0
//                                                              forKey: @""]];
// }

// - (NSString *) homeExtendedAddress
// {
//   return [self _cardStringWithLabel: nil
//                               value: [homeAdr flattenedValueAtIndex: 1
//                                                              forKey: @""]];
// }

// - (NSString *) homeStreetAddress
// {
//   return [self _cardStringWithLabel: nil
//                               value: [homeAdr flattenedValueAtIndex: 2
//                                                              forKey: @""]];
// }

// - (NSString *) homeCityAndProv
// {
//   NSString *city, *prov;
//   NSMutableString *data;

//   city = [homeAdr flattenedValueAtIndex: 3 forKey: @""];
//   prov = [homeAdr flattenedValueAtIndex: 4 forKey: @""];

//   data = [NSMutableString string];
//   [data appendString: city];
//   if ([city length] > 0 && [prov length] > 0)
//     [data appendString: @", "];
//   [data appendString: prov];

//   return [self _cardStringWithLabel: nil value: data];
// }

// - (NSString *) homePostalCodeAndCountry
// {
//   NSString *postalCode, *country;
//   NSMutableString *data;

//   postalCode = [homeAdr flattenedValueAtIndex: 5 forKey: @""];
//   country = [homeAdr flattenedValueAtIndex: 6 forKey: @""];

//   data = [NSMutableString string];
//   [data appendString: postalCode];
//   if ([postalCode length] > 0 && [country length] > 0)
//     [data appendFormat: @", "];
//   [data appendString: country];

//   return [self _cardStringWithLabel: nil value: data];
// }

// - (NSString *) _formattedURL: (NSString *) url
// {
//   NSRange schemaR;
//   NSString *schema, *data;

//   if ([url length] > 0)
//     {
//       schemaR = [url rangeOfString: @"://"];
//       if (schemaR.length > 0)
//         {
//           schema = [url substringToIndex: schemaR.location + schemaR.length];
//           data = [url substringFromIndex: schemaR.location + schemaR.length];
//         }
//       else
//         {
//           schema = @"http://";
//           data = url;
//         }
//     }
//   else
//     {
//       schema = nil;
//       data = nil;
//     }

//   return [self _cardStringWithLabel: nil
//                               value: data
//                byEscapingHTMLString: YES
//                        asLinkScheme: schema
//                  withLinkAttributes: @"target=\"_blank\""];
// }


// - (NSString *) _urlOfType: (NSString *) aType
// {
//   NSArray *elements;
//   NSString *url;

//   elements = [card childrenWithTag: @"url"
//                       andAttribute: @"type"
//                        havingValue: aType];
//   if ([elements count] > 0)
//     url = [[elements objectAtIndex: 0] flattenedValuesForKey: @""];
//   else
//     url = nil;

//   return [self _formattedURL: url];
// }

// - (NSString *) homeUrl
// {
//   NSString *s;

//   s = [self _urlOfType: @"home"];

//   if (!s || [s length] == 0)
//     {
//       NSArray *elements;
//       NSString *workURL;
//       int i;
      
//       elements = [card childrenWithTag: @"url"
// 		       andAttribute: @"type"
// 		       havingValue: @"work"];
//       workURL = nil;

//       if ([elements count] > 0)
// 	workURL = [[elements objectAtIndex: 0] flattenedValuesForKey: @""];

//       elements = [card childrenWithTag: @"url"];

//       if (workURL && [elements count] > 1)
// 	{
// 	  for (i = 0; i < [elements count]; i++)
// 	    {
// 	      if ([[[elements objectAtIndex: i] flattenedValuesForKey: @""]
//                     caseInsensitiveCompare: workURL] != NSOrderedSame)
// 		{
// 		  s = [[elements objectAtIndex: i] flattenedValuesForKey: @""];
// 		  break;
// 		}
// 	    }
	  
// 	}
//       else if (!workURL && [elements count] > 0)
// 	{
// 	  s = [[elements objectAtIndex: 0] flattenedValuesForKey: @""];
// 	}

//       if (s && [s length] > 0)
// 	s = [self _formattedURL: s];
//     }
  
//   return s;
// }

// - (BOOL) hasWorkInfos
// {
//   BOOL result;
//   NSArray *elements;

//   elements = [card childrenWithTag: @"adr"
//                    andAttribute: @"type"
//                    havingValue: @"work"];
//   if ([elements count] > 0)
//     {
//       result = YES;
//       workAdr = [elements objectAtIndex: 0];
//     }
//   else
//     result = (([[card childrenWithTag: @"url"
//                       andAttribute: @"type"
// 		      havingValue: @"work"] count] > 0)
//               || [[card childrenWithTag: @"org"] count] > 0);

//   return result;
// }

// - (NSString *) workTitle
// {
//   return [self _cardStringWithLabel: nil value: [card title]];
// }

- (NSArray *) orgUnits
{
  NSMutableArray *orgUnits;
  NSArray *values;
  CardElement *org;
  NSString *service;
  NSUInteger count, max;

  org = [card org];
  values = [org valuesForKey: @""];
  max = [values count];
  if (max > 1)
    {
      orgUnits = [NSMutableArray arrayWithCapacity: max];
      for (count = 1; count < max; count++)
        {
          service = [org flattenedValueAtIndex: count forKey: @""];
          if ([service length] > 0)
            [orgUnits addObject: [NSDictionary dictionaryWithObject: service forKey: @"value"]];
        }
    }
  else
    orgUnits = nil;

  return orgUnits;
}

- (NSArray *) categories
{
  NSMutableArray *categories;
  NSArray *values;
  NSString *category;
  NSUInteger count, max;

  values = [card categories];
  max = [values count];
  if (max > 0)
    {
      categories = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          category = [values objectAtIndex: count];
          if ([category length] > 0)
            [categories addObject: [NSDictionary dictionaryWithObject: category forKey: @"value"]];
        }
    }
  else
    categories = nil;

  return categories;
}

- (NSArray *) urls
{
  NSMutableArray *urls;
  NSMutableDictionary *attrs;
  NSArray *values;
  NSString *type, *value;
  NSURL *url;
  CardElement *element;
  NSUInteger count, max;

  values = [card childrenWithTag: @"url"];
  max = [values count];
  if (max > 0)
    {
      urls = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          attrs = [NSMutableDictionary dictionary];
          element = [values objectAtIndex: count];
          type = [element value: 0 ofAttribute: @"type"];
          if ([type length])
            [attrs setObject: type forKey: @"type"];
          value = [element flattenedValuesForKey: @""];
          url = [NSURL URLWithString: value];
          if (![url scheme] && [value length] > 0)
            url = [NSURL URLWithString: [NSString stringWithFormat: @"http://%@", value]];
          [attrs setObject: [url absoluteString] forKey: @"value"];

          [urls addObject: attrs];
        }
    }
  else
    urls = nil;

  return urls;
}

- (NSArray *) deliveryAddresses
{
  NSMutableArray *addresses;
  NSMutableDictionary *address;
  NSArray *elements;
  NSString *type, *postoffice, *street, *street2, *locality, *region, *postalcode, *country;
  CardElement *adr;
  NSUInteger count, max;

  elements = [card childrenWithTag: @"adr"];
  //values = [org valuesForKey: @""];
  max = [elements count];
  if (max > 0)
    {
      addresses = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          adr = [elements objectAtIndex: count];
          type = [adr value: 0 ofAttribute: @"type"];
          postoffice = [adr flattenedValueAtIndex: 0 forKey: @""];
          street2    = [adr flattenedValueAtIndex: 1 forKey: @""];
          street     = [adr flattenedValueAtIndex: 2 forKey: @""];
          locality   = [adr flattenedValueAtIndex: 3 forKey: @""];
          region     = [adr flattenedValueAtIndex: 4 forKey: @""];
          postalcode = [adr flattenedValueAtIndex: 5 forKey: @""];
          country    = [adr flattenedValueAtIndex: 6 forKey: @""];
          address = [NSMutableDictionary dictionaryWithObject: type forKey: @"type"];
          if (postoffice) [address setObject: postoffice forKey: @"postoffice"];
          if (street2)    [address setObject: street2 forKey: @"street2"];
          if (street)     [address setObject: street forKey: @"street"];
          if (locality)   [address setObject: locality forKey: @"locality"];
          if (region)     [address setObject: region forKey: @"region"];
          if (postalcode) [address setObject: postalcode forKey: @"postalcode"];
          if (country)    [address setObject: country forKey: @"country"];
          if ([[address allKeys] count] > 1) [addresses addObject: address];
        }
    }
  else
    addresses = nil;

  return addresses;
}

// - (NSString *) workService
// {
//   NSMutableArray *orgServices;
//   NSArray *values;
//   CardElement *org;
//   NSString *service, *services;
//   NSUInteger count, max;

//   org = [card org];
//   values = [org valuesForKey: @""];
//   max = [values count];
//   if (max > 1)
//     {
//       orgServices = [NSMutableArray arrayWithCapacity: max];
//       for (count = 1; count < max; count++)
//         {
//           service = [org flattenedValueAtIndex: count forKey: @""];
//           if ([service length] > 0)
//             [orgServices addObject: service];
//         }

//       services = [orgServices componentsJoinedByString: @", "];
//     }
//   else
//     services = nil;

//   return [self _cardStringWithLabel: nil value: services];
// }

// - (NSString *) workUrl
// {
//   return [self _urlOfType: @"work"];
// }

// - (BOOL) hasOtherInfos
// {
//   return ([[card note] length] > 0
//           || [[card bday] length] > 0
//           || [[card tz] length] > 0);
// }

// - (NSString *) bday
// {
//   SOGoDateFormatter *dateFormatter;
//   NSCalendarDate *date;
//   NSString *bday;
  
//   date = [card birthday];
//   bday = nil;

//   if (date)
//     {
//       dateFormatter = [[[self context] activeUser] dateFormatterInContext: context];
//       bday = [dateFormatter formattedDate: date];
//     }

//   return bday;
//   //return [self _cardStringWithLabel: @"Birthday:" value: bday];
// }

// - (NSString *) tz
// {
//   return [self _cardStringWithLabel: @"Timezone:" value: [card tz]];
// }

// - (NSArray *) notes
// {
//   NSMutableArray *notes;
//   NSString *note;
//   NSUInteger count, max;

//   notes = [NSMutableArray arrayWithArray: [card notes]];
//   max = [notes count];
//   for (count = 0; count < max; count++)
//     {
//       note = [notes objectAtIndex: count];
//       note = [note stringByEscapingHTMLString];
//       note = [note stringByReplacingString: @"\r\n"
//                    withString: @"<br />"];
//       note = [note stringByReplacingString: @"\n"
//                    withString: @"<br />"];

//       [notes replaceObjectAtIndex: count withObject: note];
//     }

//   return notes;
// }

/* hrefs */

// - (NSString *) completeHrefForMethod: (NSString *) _method
//                        withParameter: (NSString *) _param
//                               forKey: (NSString *) _key
// {
//   NSString *href;

//   [self setQueryParameter:_param forKey:_key];
//   href = [self completeHrefForMethod:[self ownMethodName]];
//   [self setQueryParameter:nil forKey:_key];

//   return href;
// }

// - (NSString *)attributesTabLink {
//   return [self completeHrefForMethod:[self ownMethodName]
// 	       withParameter:@"attributes"
// 	       forKey:@"tab"];
// }
// - (NSString *)debugTabLink {
//   return [self completeHrefForMethod:[self ownMethodName]
// 	       withParameter:@"debug"
// 	       forKey:@"tab"];
// }

/* action */

- (id <WOActionResults>) defaultAction
{
  card = [[self clientObject] vCard];
  if (card)
    {
      [card retain];
      phones = nil;
      homeAdr = nil;
      workAdr = nil;
    }
  else
    return [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                        reason: @"could not locate contact"];

  return self;
}

/**
 * @api {get} /so/:username/Contacts/:addressbookId/:cardId/view Get card
 * @apiVersion 1.0.0
 * @apiName GetData
 * @apiGroup Contacts
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Contacts/personal/1BC8-52F53F80-1-38C52040.vcf/view
 *
 * @apiSuccess (Success 200) {String} id                   Card ID
 * @apiSuccess (Success 200) {String} pid                  Address book ID (card's container)
 * @apiSuccess (Success 200) {String} c_component          Either vcard or vlist
 * @apiSuccess (Success 200) {String} [c_givenname]        Firstname
 * @apiSuccess (Success 200) {String} [nickname]           Nickname
 * @apiSuccess (Success 200) {String} [c_sn]               Lastname
 * @apiSuccess (Success 200) {String} [c_fn]               Fullname
 * @apiSuccess (Success 200) {String} [c_screenname]       Screen Name (X-AIM for now)
 * @apiSuccess (Success 200) {String} [tz]                 Timezone
 * @apiSuccess (Success 200) {String} [notes]              Notes
 * @apiSuccess (Success 200) {String[]} allCategories      All available categories
 * @apiSuccess (Success 200) {Object[]} [categories]       Categories assigned to the card
 * @apiSuccess (Success 200) {String} categories.value     Category name
 * @apiSuccess (Success 200) {Object[]} [addresses]        Postal addresses
 * @apiSuccess (Success 200) {String} addresses.type       Type (e.g., home or work)
 * @apiSuccess (Success 200) {String} addresses.postoffice Post office box
 * @apiSuccess (Success 200) {String} addresses.street     Street address
 * @apiSuccess (Success 200) {String} addresses.street2    Extended address (e.g., apartment or suite number)
 * @apiSuccess (Success 200) {String} addresses.locality   Locality (e.g., city)
 * @apiSuccess (Success 200) {String} addresses.region     Region (e.g., state or province)
 * @apiSuccess (Success 200) {String} addresses.postalcode Postal code
 * @apiSuccess (Success 200) {String} addresses.country    Country name
 * @apiSuccess (Success 200) {Object[]} [emails]           Email addresses
 * @apiSuccess (Success 200) {String} emails.type          Type (e.g., home or work)
 * @apiSuccess (Success 200) {String} emails.value         Email address
 * @apiSuccess (Success 200) {Object[]} [phones]           Phone numbers
 * @apiSuccess (Success 200) {String} phones.type          Type (e.g., mobile or work)
 * @apiSuccess (Success 200) {String} phones.value         Phone number
 * @apiSuccess (Success 200) {Object[]} [urls]             URLs
 * @apiSuccess (Success 200) {String} urls.type            Type (e.g., personal or work)
 * @apiSuccess (Success 200) {String} urls.value           URL
 */
- (id <WOActionResults>) dataAction
{
  id <WOActionResults> result;
  id o;
  SOGoObject <SOGoContactObject> *contact;
  NSMutableDictionary *data;

  contact = [self clientObject];
  card = [contact vCard];
  if (card)
    {
      [card retain];
      phones = nil;
      homeAdr = nil;
      workAdr = nil;
    }
  else
    return [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                                         reason: @"could not locate contact"];

  data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                [[contact container] nameInContainer], @"pid",
                              [contact nameInContainer], @"id",
                              [[card tag] lowercaseString], @"c_component",
                              nil];
  o = [card fn];
  if (o) [data setObject: o forKey: @"c_cn"];
  o = [card n];
  if (o)
    {
      NSString *lastName = [o flattenedValueAtIndex: 0 forKey: @""];
      NSString *firstName = [o flattenedValueAtIndex: 1 forKey: @""];
      if ([lastName length] > 0)
        [data setObject: lastName forKey: @"c_sn"];
      if ([firstName length] > 0)
        [data setObject: firstName forKey: @"c_givenname"];
    }

  o = [[card uniqueChildWithTag: @"x-aim"] flattenedValuesForKey: @""];
  if ([o length]) [data setObject: o forKey: @"c_screenname"];

  o = [card nickname];
  if (o) [data setObject: o forKey: @"nickname"];
  o = [card title];
  if ([o length] > 0)
    [data setObject: o forKey: @"title"];
  o = [card role];
  if ([o length] > 0)
    [data setObject: o forKey: @"role"];
  o = [self orgUnits];
  if ([o count] > 0)
    [data setObject: o forKey: @"orgUnits"];
  o = [card workCompany];
  if ([o length] > 0)
    [data setObject: o forKey: @"c_org"];

  o = [card birthday];
  if (o)
    [data setObject: [o descriptionWithCalendarFormat: @"%Y-%m-%d"]
               forKey: @"birthday"];

  o = [card tz];
  if (o) [data setObject: o forKey: @"tz"];

  o = [card childrenWithTag: @"email"];
  if ([o count]) [data setObject: o forKey: @"emails"];
  o = [card childrenWithTag: @"tel"];
  if ([o count]) [data setObject: o forKey: @"phones"];
  o = [self categories];
  if ([o count]) [data setObject: o forKey: @"categories"];
  o = [self deliveryAddresses];
  if ([o count] > 0) [data setObject: o forKey: @"addresses"];
  o = [self urls];
  if ([o count]) [data setObject: o forKey: @"urls"];

  o = [card notes];
  if (o) [data setObject: o forKey: @"notes"];
  o = [self _fetchAndCombineCategoriesList];
  if (o) [data setObject: o forKey: @"allCategories"];
  if ([contact hasPhoto])
    [data setObject: [self photoURL] forKey: @"photoURL"];

  result = [self responseWithStatus: 200
                          andString: [data jsonRepresentation]];
  
  return result;
}

- (BOOL) hasPhoto
{
  return [[self clientObject] hasPhoto];
}

- (NSString *) photoURL
{
  NSURL *soURL;

  soURL = [[self clientObject] soURL];

  return [NSString stringWithFormat: @"%@/photo", [soURL absoluteString]];
}

@end /* UIxContactView */
