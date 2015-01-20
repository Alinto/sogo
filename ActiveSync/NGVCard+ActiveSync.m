/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#import "NGVCard+ActiveSync.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import <NGExtensions/NSString+misc.h>

#import <NGCards/CardElement.h>

#import <Contacts/NGVCard+SOGo.h>

#import <SOGo/NSString+Utilities.h>

#include "NSDate+ActiveSync.h"
#include "NSString+ActiveSync.h"

@implementation NGVCard (ActiveSync)

- (NSString *) activeSyncRepresentationInContext: (WOContext *) context
{
  NSArray *emails, *addresses, *categories, *elements;
  CardElement *n, *homeAdr, *workAdr;
  NSMutableString *s;
  NSString *url;
  id o;

  int i;

  s = [NSMutableString string];
  n = [self n];
  
  if ((o = [n flattenedValueAtIndex: 0 forKey: @""]))
    [s appendFormat: @"<LastName xmlns=\"Contacts:\">%@</LastName>", [o activeSyncRepresentationInContext: context]];
  
  if ((o = [n flattenedValueAtIndex: 1 forKey: @""]))
    [s appendFormat: @"<FirstName xmlns=\"Contacts:\">%@</FirstName>", [o activeSyncRepresentationInContext: context]];
  
  if ((o = [self workCompany]))
    [s appendFormat: @"<CompanyName xmlns=\"Contacts:\">%@</CompanyName>", [o activeSyncRepresentationInContext: context]];

  if ((o = [[self org] flattenedValueAtIndex: 1 forKey: @""]))
    [s appendFormat: @"<Department xmlns=\"Contacts:\">%@</Department>", [o activeSyncRepresentationInContext: context]];

  categories = [self categories];

  if ([categories count])
    {
      [s appendFormat: @"<Categories xmlns=\"Contacts:\">"];
      for (i = 0; i < [categories count]; i++)
        {
          [s appendFormat: @"<Category xmlns=\"Contacts:\">%@</Category>", [[categories objectAtIndex: i] activeSyncRepresentationInContext: context]];
        }
      [s appendFormat: @"</Categories>"];
    }
  
  elements = [self childrenWithTag: @"url"
                      andAttribute: @"type"
                       havingValue: @"work"];
  if ([elements count] > 0)
    {
      url = [[elements objectAtIndex: 0] flattenedValuesForKey: @""];
      [s appendFormat: @"<WebPage xmlns=\"Contacts:\">%@</WebPage>", [url activeSyncRepresentationInContext: context]];
    }
  
  
  if ((o = [[self uniqueChildWithTag: @"x-aim"] flattenedValuesForKey: @""]))
    [s appendFormat: @"<IMAddress xmlns=\"Contacts:\">%@</IMAddress>", [o activeSyncRepresentationInContext: context]];
  
  if ((o = [self nickname]))
    [s appendFormat: @"<NickName xmlns=\"Contacts:\">%@</NickName>", [o activeSyncRepresentationInContext: context]];
  
  
  if ((o = [self title]))
    [s appendFormat: @"<JobTitle xmlns=\"Contacts:\">%@</JobTitle>", [o activeSyncRepresentationInContext: context]];
  
  if ((o = [self preferredEMail])) 
    [s appendFormat: @"<Email1Address xmlns=\"Contacts:\">%@</Email1Address>", o];
  
  
  // Secondary email addresses (2 and 3)
  emails = [self secondaryEmails];

  for (i = 0; i < [emails count]; i++)
    {
      o = [[emails objectAtIndex: i] flattenedValuesForKey: @""];
      
      [s appendFormat: @"<Email%dAddress xmlns=\"Contacts:\">%@</Email%dAddress>", i+2, o, i+2];

      if (i == 1)
        break;
    }

  // Telephone numbers
  if ((o = [self workPhone]) && [o length])
    [s appendFormat: @"<BusinessPhoneNumber xmlns=\"Contacts:\">%@</BusinessPhoneNumber>", [o activeSyncRepresentationInContext: context]];
  
  if ((o = [self homePhone]) && [o length])
    [s appendFormat: @"<HomePhoneNumber xmlns=\"Contacts:\">%@</HomePhoneNumber>", [o activeSyncRepresentationInContext: context]];
  
  if ((o = [self fax]) && [o length])
    [s appendFormat: @"<BusinessFaxNumber xmlns=\"Contacts:\">%@</BusinessFaxNumber>", [o activeSyncRepresentationInContext: context]];
  
  if ((o = [self mobile]) && [o length])
    [s appendFormat: @"<MobilePhoneNumber xmlns=\"Contacts:\">%@</MobilePhoneNumber>", [o activeSyncRepresentationInContext: context]];
  
  if ((o = [self pager]) && [o length])
    [s appendFormat: @"<PagerNumber xmlns=\"Contacts:\">%@</PagerNumber>", [o activeSyncRepresentationInContext: context]];

  // Home Address
  addresses = [self childrenWithTag: @"adr"
                       andAttribute: @"type"
                        havingValue: @"home"];
  
  if ([addresses count])
    {
      homeAdr = [addresses objectAtIndex: 0];
      
      if ((o = [homeAdr flattenedValueAtIndex: 2  forKey: @""]))
        [s appendFormat: @"<HomeStreet xmlns=\"Contacts:\">%@</HomeStreet>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [homeAdr flattenedValueAtIndex: 3  forKey: @""]))
        [s appendFormat: @"<HomeCity xmlns=\"Contacts:\">%@</HomeCity>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [homeAdr flattenedValueAtIndex: 4  forKey: @""]))
        [s appendFormat: @"<HomeState xmlns=\"Contacts:\">%@</HomeState>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [homeAdr flattenedValueAtIndex: 5  forKey: @""]))
        [s appendFormat: @"<HomePostalCode xmlns=\"Contacts:\">%@</HomePostalCode>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [homeAdr flattenedValueAtIndex: 6  forKey: @""]))
        [s appendFormat: @"<HomeCountry xmlns=\"Contacts:\">%@</HomeCountry>", [o activeSyncRepresentationInContext: context]];
    }
  
  // Work Address
  addresses = [self childrenWithTag: @"adr"
                       andAttribute: @"type"
                        havingValue: @"work"];
  
  if ([addresses count])
    {
      workAdr = [addresses objectAtIndex: 0];
      
      if ((o = [workAdr flattenedValueAtIndex: 2  forKey: @""]))
        [s appendFormat: @"<BusinessStreet xmlns=\"Contacts:\">%@</BusinessStreet>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [workAdr flattenedValueAtIndex: 3  forKey: @""]))
        [s appendFormat: @"<BusinessCity xmlns=\"Contacts:\">%@</BusinessCity>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [workAdr flattenedValueAtIndex: 4  forKey: @""]))
        [s appendFormat: @"<BusinessState xmlns=\"Contacts:\">%@</BusinessState>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [workAdr flattenedValueAtIndex: 5  forKey: @""]))
        [s appendFormat: @"<BusinessPostalCode xmlns=\"Contacts:\">%@</BusinessPostalCode>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [workAdr flattenedValueAtIndex: 6  forKey: @""]))
        [s appendFormat: @"<BusinessCountry xmlns=\"Contacts:\">%@</BusinessCountry>", [o activeSyncRepresentationInContext: context]];
    }

  // Other, less important fields
  if ((o = [self birthday]))
    [s appendFormat: @"<Birthday xmlns=\"Contacts:\">%@</Birthday>", [o activeSyncRepresentationInContext: context]];

  if ((o = [self note]))
    {
      // It is very important here to NOT set <Truncated>0</Truncated> in the response,
      // otherwise it'll prevent WP8 phones from sync'ing. See #3028 for details.
      o = [o activeSyncRepresentationInContext: context];
      [s appendString: @"<Body xmlns=\"AirSyncBase:\">"];
      [s appendFormat: @"<Type>%d</Type>", 1]; 
      [s appendFormat: @"<EstimatedDataSize>%d</EstimatedDataSize>", [o length]];
      [s appendFormat: @"<Data>%@</Data>", o];
      [s appendString: @"</Body>"];
    }

  if ((o = [self photo]))
    [s appendFormat: @"<Picture xmlns=\"Contacts:\">%@</Picture>", o];
  
  return s;
}

//
//
//
- (void) takeActiveSyncValues: (NSDictionary *) theValues
                    inContext: (WOContext *) context
{
  CardElement *element;
  id o;
  
  // Contact's note
  if ((o = [[theValues objectForKey: @"Body"] objectForKey: @"Data"]))
    [self setNote: o];

  // Categories
  if ((o = [theValues objectForKey: @"Categories"]) && [o length])
    [self setCategories: o];

  // Birthday
  if ((o = [theValues objectForKey: @"Birthday"]))
    {
      o = [o calendarDate];
      [self setBday: [o descriptionWithCalendarFormat: @"%Y-%m-%d" timeZone: nil locale: nil]];
    }

  //
  // Business address information
  //
  // BusinessStreet
  // BusinessCity
  // BusinessPostalCode
  // BusinessState
  // BusinessCountry
  //
  element = [self elementWithTag: @"adr" ofType: @"work"];
  [element setSingleValue: @""
                  atIndex: 1 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"BusinessStreet"]
                  atIndex: 2 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"BusinessCity"]
                  atIndex: 3 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"BusinessState"]
                  atIndex: 4 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"BusinessPostalCode"]
                  atIndex: 5 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"BusinessCountry"]
                  atIndex: 6 forKey: @""];

  //
  // Home address information
  //
  // HomeStreet
  // HomeCity
  // HomePostalCode
  // HomeState
  // HomeCountry
  //
  element = [self elementWithTag: @"adr" ofType: @"home"];
  [element setSingleValue: @""
                  atIndex: 1 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"HomeStreet"]
                  atIndex: 2 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"HomeCity"]
                  atIndex: 3 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"HomeState"]
                  atIndex: 4 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"HomePostalCode"]
                  atIndex: 5 forKey: @""];
  [element setSingleValue: [theValues objectForKey: @"HomeCountry"]
                  atIndex: 6 forKey: @""];

  // Company's name
  if ((o = [theValues objectForKey: @"CompanyName"]))
    [self setOrg: o  units: nil];
  
  // Department
  if ((o = [theValues objectForKey: @"Department"]))
    [self setOrg: nil  units: [NSArray arrayWithObjects:o,nil]];
  
  // Email addresses
  if ((o = [theValues objectForKey: @"Email1Address"]))
    {
      element = [self elementWithTag: @"email" ofType: @"work"];
      [element setSingleValue: [o pureEMailAddress] forKey: @""];
    }
  
  if ((o = [theValues objectForKey: @"Email2Address"]))
    {
      element = [self elementWithTag: @"email" ofType: @"home"];
      [element setSingleValue: [o pureEMailAddress] forKey: @""];
    }
  
  // SOGo currently only supports 2 email addresses ... but AS clients might send 3
  // FIXME: revise this when the GUI revamp is done in SOGo
  if ((o = [theValues objectForKey: @"Email3Address"]))
    {
      element = [self elementWithTag: @"email" ofType: @"three"];
      [element setSingleValue: [o pureEMailAddress] forKey: @""];
    }
  
  // Formatted name
  // MiddleName
  // Suffix   (II)
  // Title    (Mr.)
  [self setFn: [theValues objectForKey: @"FileAs"]];

  [self setNWithFamily: [theValues objectForKey: @"LastName"]
                 given: [theValues objectForKey: @"FirstName"]
            additional: nil prefixes: nil suffixes: nil];
  
  // IM information
  [[self uniqueChildWithTag: @"x-aim"]
    setSingleValue: [theValues objectForKey: @"IMAddress"]
            forKey: @""];

  //
  // Phone numbrrs
  //
  element = [self elementWithTag: @"tel" ofType: @"work"];
  [element setSingleValue: [theValues objectForKey: @"BusinessPhoneNumber"]  forKey: @""];

  element = [self elementWithTag: @"tel" ofType: @"home"];
  [element setSingleValue: [theValues objectForKey: @"HomePhoneNumber"]  forKey: @""];

  element = [self elementWithTag: @"tel" ofType: @"cell"];
  [element setSingleValue: [theValues objectForKey: @"MobilePhoneNumber"]  forKey: @""];

  element = [self elementWithTag: @"tel" ofType: @"fax"];
  [element setSingleValue: [theValues objectForKey: @"BusinessFaxNumber"]  forKey: @""];

  element = [self elementWithTag: @"tel" ofType: @"pager"];
  [element setSingleValue: [theValues objectForKey: @"PagerNumber"]  forKey: @""];
  
  // Job's title
  if ((o = [theValues objectForKey: @"JobTitle"]))
    [self setTitle: o];
  
  // WebPage (work)
  if ((o = [theValues objectForKey: @"WebPage"]))
    [[self elementWithTag: @"url" ofType: @"work"]
          setSingleValue: o  forKey: @""];
  
  if ((o = [theValues objectForKey: @"NickName"]))
    [self setNickname: o];

  if ((o = [theValues objectForKey: @"Picture"]))
    [self setPhoto: o];

}

@end
