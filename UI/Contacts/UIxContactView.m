/*
  Copyright (C) 2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: UIxContactView.m 932 2005-08-01 13:17:55Z helge $

#import <Contacts/SOGoContactObject.h>

#import <NGCards/NGVCard.h>
#import <NGCards/CardElement.h>
#import <NGCards/NSArray+NGCards.h>
#import <NGExtensions/NSString+Ext.h>

#import "common.h"

#import "UIxContactView.h"

@implementation UIxContactView

/* accessors */

- (NSString *)tabSelection {
  NSString *selection;
    
  selection = [self queryParameterForKey:@"tab"];
  if (selection == nil)
    selection = @"attributes";
  return selection;
}

- (NSString *) _cardStringWithLabel: (NSString *) label
                              value: (NSString *) value
{
  NSMutableString *cardString;

  cardString = [NSMutableString new];
  [cardString autorelease];

  if (value && [value length] > 0)
    {
      if (label)
        [cardString appendFormat: @"%@%@<br />\n",
                    [self labelForKey: label], value];
      else
        [cardString appendFormat: @"%@<br />\n", value];
    }

  return cardString;
}

- (NSString *) contactCardTitle
{
  return [NSString stringWithFormat:
                     [self labelForKey: @"Card for %@"],
                   [card fn]];
}

- (NSString *) displayName
{
  return [self _cardStringWithLabel: @"Display Name: "
               value: [card fn]];
}

- (NSString *) nickName
{
  return [self _cardStringWithLabel: @"Nickname: "
               value: [card nickname]];
}

- (NSString *) preferredEmail
{
  NSString *email, *mailTo;

  email = [card preferredEMail];
  if (email && [email length] > 0)
    mailTo = [NSString stringWithFormat: @"<a href=\"mailto:%@\""
                       @" onclick=\"return onContactMailTo(this);\">"
                       @"%@</a>", email, email];
  else
    mailTo = nil;

  return [self _cardStringWithLabel: @"Email Address: "
               value: mailTo];
}

- (NSString *) preferredTel
{
  return [self _cardStringWithLabel: @"Phone Number: "
               value: [card preferredTel]];
}

- (NSString *) preferredAddress
{
  return @"";
}

- (BOOL) hasTelephones
{
  if (!phones)
    phones = [card childrenWithTag: @"tel"];

  return ([phones count] > 0);
}

- (NSString *) _phoneOfType: (NSString *) aType
                  withLabel: (NSString *) aLabel
{
  NSArray *elements;
  NSString *phone;

  elements = [phones cardElementsWithAttribute: @"type"
                     havingValue: aType];

  if ([elements count] > 0)
    phone = [[elements objectAtIndex: 0] value: 0];
  else
    phone = nil;

  return [self _cardStringWithLabel: aLabel value: phone];
}

- (NSString *) workPhone
{
  return [self _phoneOfType: @"work" withLabel: @"Work: "];
}

- (NSString *) homePhone
{
  return [self _phoneOfType: @"home" withLabel: @"Home: "];
}

- (NSString *) fax
{
  return [self _phoneOfType: @"fax" withLabel: @"Fax: "];
}

- (NSString *) mobile
{
  return [self _phoneOfType: @"cell" withLabel: @"Mobile: "];
}

- (NSString *) pager
{
  return [self _phoneOfType: @"pager" withLabel: @"Pager: "];
}

- (BOOL) hasHomeInfos
{
  BOOL result;
  NSArray *elements;

  elements = [card childrenWithTag: @"adr"
                   andAttribute: @"type"
                   havingValue: @"home"];
  if ([elements count] > 0)
    {
      result = YES;
      homeAdr = [elements objectAtIndex: 0];
    }
  else
    result = ([[card childrenWithTag: @"url"
                     andAttribute: @"type"
                     havingValue: @"home"] count] > 0);

  return result;
}

- (NSString *) homePobox
{
  return [self _cardStringWithLabel: nil value: [homeAdr value: 0]];
}

- (NSString *) homeExtendedAddress
{
  return [self _cardStringWithLabel: nil value: [homeAdr value: 1]];
}

- (NSString *) homeStreetAddress
{
  return [self _cardStringWithLabel: nil value: [homeAdr value: 2]];
}

- (NSString *) homeCityAndProv
{
  NSString *city, *prov;
  NSMutableString *data;

  city = [homeAdr value: 3];
  prov = [homeAdr value: 4];

  data = [NSMutableString new];
  [data autorelease];
  [data appendString: city];
  if ([city length] > 0 && [prov length] > 0)
    [data appendString: @", "];
  [data appendString: prov];

  return [self _cardStringWithLabel: nil value: data];
}

- (NSString *) homePostalCodeAndCountry
{
  NSString *postalCode, *country;
  NSMutableString *data;

  postalCode = [homeAdr value: 5];
  country = [homeAdr value: 6];

  data = [NSMutableString new];
  [data autorelease];
  [data appendString: postalCode];
  if ([postalCode length] > 0 && [country length] > 0)
    [data appendFormat: @", ", country];
  [data appendString: country];

  return [self _cardStringWithLabel: nil value: data];
}

- (NSString *) _urlOfType: (NSString *) aType
{
  NSArray *elements;
  NSString *data, *url;

  elements = [card childrenWithTag: @"url"
                   andAttribute: @"type"
                   havingValue: aType];
  if ([elements count] > 0)
    {
      url = [[elements objectAtIndex: 0] value: 0];
      data = [NSString stringWithFormat:
                         @"<a href=\"%@\" onclick=\"return openExternalLink(this);\">%@</a>",
                       url, url];
    }
  else
    data = nil;

  return [self _cardStringWithLabel: nil value: data];
}

- (NSString *) homeUrl
{
  return [self _urlOfType: @"home"];
}

- (BOOL) hasWorkInfos
{
  BOOL result;
  NSArray *elements;

  elements = [card childrenWithTag: @"adr"
                   andAttribute: @"type"
                   havingValue: @"work"];
  if ([elements count] > 0)
    {
      result = YES;
      workAdr = [elements objectAtIndex: 0];
    }
  else
    result = (([[card childrenWithTag: @"url"
                      andAttribute: @"type"
                     havingValue: @"work"] count] > 0)
              || [[card childrenWithTag: @"org"] count] > 0);

  return result;
}

- (NSString *) workTitle
{
  return [self _cardStringWithLabel: nil value: [card title]];
}

- (NSString *) workService
{
  NSArray *org, *orgServices;
  NSRange aRange;
  NSString *services;

  org = [card org];
  if (org && [org count] > 1)
    {
      aRange = NSMakeRange (1, [org count] - 1);
      orgServices = [org subarrayWithRange: aRange];
      services = [orgServices componentsJoinedByString: @", "];
    }
  else
    services = nil;

  return [self _cardStringWithLabel: nil value: services];
}

- (NSString *) workCompany
{
  NSArray *org;
  NSString *company;

  org = [card org];
  if (org && [org count] > 0)
    company = [org objectAtIndex: 0];
  else
    company = nil;

  return [self _cardStringWithLabel: nil value: company];
}

- (NSString *) workPobox
{
  return [self _cardStringWithLabel: nil value: [workAdr value: 0]];
}

- (NSString *) workExtendedAddress
{
  return [self _cardStringWithLabel: nil value: [workAdr value: 1]];
}

- (NSString *) workStreetAddress
{
  return [self _cardStringWithLabel: nil value: [workAdr value: 2]];
}

- (NSString *) workCityAndProv
{
  NSString *city, *prov;
  NSMutableString *data;

  city = [workAdr value: 3];
  prov = [workAdr value: 4];

  data = [NSMutableString new];
  [data autorelease];
  [data appendString: city];
  if ([city length] > 0 && [prov length] > 0)
    [data appendString: @", "];
  [data appendString: prov];

  return [self _cardStringWithLabel: nil value: data];
}

- (NSString *) workPostalCodeAndCountry
{
  NSString *postalCode, *country;
  NSMutableString *data;

  postalCode = [workAdr value: 5];
  country = [workAdr value: 6];

  data = [NSMutableString new];
  [data autorelease];
  [data appendString: postalCode];
  if ([postalCode length] > 0 && [country length] > 0)
    [data appendFormat: @", ", country];
  [data appendString: country];

  return [self _cardStringWithLabel: nil value: data];
}

- (NSString *) workUrl
{
  return [self _urlOfType: @"home"];
}

- (BOOL) hasOtherInfos
{
  return ([[card note] length] > 0
          || [[card bday] length] > 0
          || [[card tz] length] > 0);
}

- (NSString *) bday
{
  return [self _cardStringWithLabel: @"Birthday: " value: [card bday]];
}

- (NSString *) tz
{
  return [self _cardStringWithLabel: @"Timezone: " value: [card tz]];
}

- (NSString *) note
{
  NSString *note;

  note = [card note];
  if (note)
    {
      note = [note stringByReplacingString: @"\r\n"
                   withString: @"<br />"];
      note = [note stringByReplacingString: @"\n"
                   withString: @"<br />"];
    }

  return [self _cardStringWithLabel: @"Note: " value: note];
}

/* hrefs */

- (NSString *) completeHrefForMethod: (NSString *) _method
                       withParameter: (NSString *) _param
                              forKey: (NSString *) _key
{
  NSString *href;

  [self setQueryParameter:_param forKey:_key];
  href = [self completeHrefForMethod:[self ownMethodName]];
  [self setQueryParameter:nil forKey:_key];

  return href;
}

- (NSString *)attributesTabLink {
  return [self completeHrefForMethod:[self ownMethodName]
	       withParameter:@"attributes"
	       forKey:@"tab"];
}
- (NSString *)debugTabLink {
  return [self completeHrefForMethod:[self ownMethodName]
	       withParameter:@"debug"
	       forKey:@"tab"];
}

/* action */

- (id <WOActionResults>) vcardAction
{
  WOResponse *response;

  card = [[self clientObject] vCard];
  if (card)
    {
      response = [WOResponse new];
      [response autorelease];
      [response setHeader: @"text/vcard" forKey: @"Content-type"];
      [response appendContentString: [card versitString]];
    }
  else
    return [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                        reason:@"could not locate contact"];

  return response;
}

- (id <WOActionResults>) defaultAction
{
  card = [[self clientObject] vCard];
  if (card)
    {
      phones = nil;
      homeAdr = nil;
      workAdr = nil;
    }
  else
    return [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                        reason: @"could not locate contact"];

  return self;
}

- (BOOL) isDeletableClientObject
{
  return [[self clientObject] respondsToSelector: @selector(delete)];
}

- (id) deleteAction
{
  NSException *ex;
  id url;

  if (![self isDeletableClientObject])
    /* return 400 == Bad Request */
    return [NSException exceptionWithHTTPStatus:400
                        reason:@"method cannot be invoked on "
                        @"the specified object"];

  ex = [[self clientObject] delete];
  if (ex)
    {
    // TODO: improve error handling
      [self debugWithFormat:@"failed to delete: %@", ex];

      return ex;
    }

  url = [[[self clientObject] container] baseURLInContext:[self context]];

  return [self redirectToLocation:url];
}

@end /* UIxContactView */
