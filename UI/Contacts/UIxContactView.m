/*
  Copyright (C) 2005-2019 Inverse inc.

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
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserManager.h>

#import <Contacts/NGVCard+SOGo.h>
#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactFolders.h>

#import "UIxContactView.h"

@implementation UIxContactView

- (id) init
{
  if ((self = [super init]))
    {
      card = nil;
    }

  return self;
}

- (void) dealloc
{
  [card release];
  [super dealloc];
}

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
          if (url)
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
  NSString *type, *postoffice, *street, *street2, *locality, *region, *postalcode, *country;
  NSMutableDictionary *address;
  NSMutableArray *addresses;
  NSArray *elements;
  CardElement *adr;

  NSUInteger count, max;

  elements = [card childrenWithTag: @"adr"];
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

          address = [NSMutableDictionary dictionaryWithObject: type  forKey: @"type"];
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

/* action */

- (id <WOActionResults>) defaultAction
{
  card = [[self clientObject] vCard];
  if (card)
    [card retain];
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
 * @apiSuccess (Success 200) {String} [title]              Title
 * @apiSuccess (Success 200) {String} [role]               Role
 * @apiSuccess (Success 200) {String} [c_screenname]       Screen Name (X-AIM for now)
 * @apiSuccess (Success 200) {String} [tz]                 Timezone
 * @apiSuccess (Success 200) {String} [org]                Main organization
 * @apiSuccess (Success 200) {String[]} [orgs]             Additional organizations
 * @apiSuccess (Success 200) {String[]} [notes]            Notes
 * @apiSuccess (Success 200) {String[]} allCategories      All available categories
 * @apiSuccess (Success 200) {Object[]} [categories]       Categories assigned to the card
 * @apiSuccess (Success 200) {String} categories.value     Category name
 * @apiSuccess (Success 200) {Number} hasCertificate       1 if contact has a mail certificate
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
 * @apiSuccess (Success 200) {Object[]} customFields       Custom fields from Thunderbird
 */
- (id <WOActionResults>) dataAction
{
  NSMutableDictionary *customFields, *data;
  SOGoObject <SOGoContactObject> *contact;
  id <WOActionResults> result;
  NSArray *values;
  id o;

  contact = [self clientObject];
  card = [contact vCard];
  if (card)
    [card retain];
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
  o = [card titles];
  if ([o count])
    [data setObject: [o componentsJoinedByString: @" / "] forKey: @"title"];
  o = [card role];
  if ([o length] > 0)
    [data setObject: o forKey: @"role"];
  values = [card organizations];
  if ([values count])
    {
      [data setObject: [values objectAtIndex: 0] forKey: @"org"];
      if ([values count] > 1)
        [data setObject: [values subarrayWithRange: NSMakeRange(1, [values count] - 1)] forKey: @"orgs"];
    }

  o = [card certificate];
  if ([o length])
    [data setObject: [NSNumber numberWithBool: YES] forKey: @"hasCertificate"];

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

  // Custom fields from Thunderbird
  customFields = [NSMutableDictionary dictionary];
  if ((o = [[card uniqueChildWithTag: @"custom1"] flattenedValuesForKey: @""]) && [o length])
    [customFields setObject: o  forKey: @"1"];

  if ((o = [[card uniqueChildWithTag: @"custom2"] flattenedValuesForKey: @""]) && [o length])
    [customFields setObject: o  forKey: @"2"];

  if ((o = [[card uniqueChildWithTag: @"custom3"] flattenedValuesForKey: @""]) && [o length])
    [customFields setObject: o  forKey: @"3"];

  if ((o = [[card uniqueChildWithTag: @"custom4"] flattenedValuesForKey: @""]) && [o length])
    [customFields setObject: o  forKey: @"4"];

  if ([customFields count])
    [data setObject: customFields  forKey: @"customFields"];

  result = [self responseWithStatus: 200
                          andString: [data jsonRepresentation]];

  return result;
}

- (id <WOActionResults>) membersAction
{
  NSArray *allUsers;
  NSDictionary *dict;
  NSEnumerator *emails;
  NSMutableArray *allUsersData, *allUserEmails;
  NSMutableDictionary *userData;
  NSString *email;
  SOGoObject <SOGoContactObject> *contact;
  SOGoObject <SOGoSource> *source;
  SOGoUser *user;
  id <WOActionResults> result;
  unsigned int i, max;

  result = nil;
  contact = [self clientObject];
  source = [[contact container] source];
  dict = [source lookupContactEntryWithUIDorEmail: [contact nameInContainer]
                                         inDomain: nil];

  if ([[dict objectForKey: @"isGroup"] boolValue])
    {
      if ([source conformsToProtocol:@protocol(SOGoMembershipSource)])
        {
          allUsers = [(id<SOGoMembershipSource>)(source) membersForGroupWithUID: [dict objectForKey: @"c_uid"]];
          max = [allUsers count];
          allUsersData = [NSMutableArray arrayWithCapacity: max];
          for (i = 0; i < max; i++)
            {
              user = [allUsers objectAtIndex: i];
              allUserEmails = [NSMutableArray array];
              emails = [[user allEmails] objectEnumerator];
              while ((email = [emails nextObject])) {
                [allUserEmails addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                                          email, @"value", @"work", @"type", nil]];
              }
              userData = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [user loginInDomain], @"c_uid",
                                       [user cn], @"c_cn",
                                       allUserEmails, @"emails", nil];
              [allUsersData addObject: userData];
            }
          dict = [NSDictionary dictionaryWithObject: allUsersData forKey: @"members"];
          result = [self responseWithStatus: 200
                                  andString: [dict jsonRepresentation]];
        }
      else
        {
          result = [self responseWithStatus: 403
                                  andString: @"Group is not expandable"];
        }
    }
  else
    {
      result = [self responseWithStatus: 405
                              andString: @"Contact is not a group"];
    }

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
