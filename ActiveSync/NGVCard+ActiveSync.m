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

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

@implementation NGVCard (ActiveSync)

//
// This function is called for each elements which can be ghosted according to specs. 
// https://msdn.microsoft.com/en-us/library/gg650908%28v=exchg.80%29.aspx
//
- (BOOL) _isGhosted: (NSString *) element
           inContext: (WOContext *) context
{
  NSArray *supportedElements;

  supportedElements = [context objectForKey: @"SupportedElements"];

  // If the client does not include a Supported element in the initial Sync command request for
  // a folder, then all of the elements that can be ghosted are considered not ghosted.
  if (!supportedElements)
    return NO;

  // If the client includes an empty Supported element in the initial Sync command request for 
  // a folder, then all elements that can be ghosted are considered ghosted.
  if (![supportedElements count])
    return YES;

  // If the client includes a Supported element that contains child elements in the initial 
  // Sync command request for a folder, then each child element of that Supported element is 
  // considered not ghosted. All elements that can be ghosted that are not included as child 
  // elements of the Supported element are considered ghosted. 
  if (!([supportedElements indexOfObject: element] == NSNotFound))
    return YES;

  return NO;
}

- (NSString *) activeSyncRepresentationInContext: (WOContext *) context
{
  NSArray *emails, *addresses, *categories, *elements;
  NSMutableArray *other_addresses;
  CardElement *n, *homeAdr, *workAdr, *otherAdr;
  NSMutableString *s, *a;
  NSString *url;
  id o;

  int i;

  s = [NSMutableString string];
  n = [self n];
  
  if ((o = [n flattenedValueAtIndex: 0 forKey: @""]))
    [s appendFormat: @"<LastName xmlns=\"Contacts:\">%@</LastName>", [o activeSyncRepresentationInContext: context]];

  if ((o = [n flattenedValueAtIndex: 1 forKey: @""]))
    [s appendFormat: @"<FirstName xmlns=\"Contacts:\">%@</FirstName>", [o activeSyncRepresentationInContext: context]];

  if ((o = [n flattenedValueAtIndex: 2 forKey: @""]))
    [s appendFormat: @"<MiddleName xmlns=\"Contacts:\">%@</MiddleName>", [o activeSyncRepresentationInContext: context]];

  if ((o = [n flattenedValueAtIndex: 3 forKey: @""]))
    [s appendFormat: @"<Title xmlns=\"Contacts:\">%@</Title>", [o activeSyncRepresentationInContext: context]];

  if ((o = [n flattenedValueAtIndex: 4 forKey: @""]))
    [s appendFormat: @"<Suffix xmlns=\"Contacts:\">%@</Suffix>", [o activeSyncRepresentationInContext: context]];

  if ((o = [self fn]))
    [s appendFormat: @"<FileAs xmlns=\"Contacts:\">%@</FileAs>", [o activeSyncRepresentationInContext: context]];

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
    [s appendFormat: @"<Email1Address xmlns=\"Contacts:\">%@</Email1Address>", [o activeSyncRepresentationInContext: context]];
  
  
  // Secondary email addresses (2 and 3)
  emails = [self secondaryEmails];

  for (i = 0; i < [emails count]; i++)
    {
      o = [[emails objectAtIndex: i] flattenedValuesForKey: @""];
      
      [s appendFormat: @"<Email%dAddress xmlns=\"Contacts:\">%@</Email%dAddress>", i+2, [o activeSyncRepresentationInContext: context], i+2];

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
      a = [NSMutableString string];
      
      if ((o = [homeAdr flattenedValueAtIndex: 2  forKey: @""]))
        [a appendString: [o activeSyncRepresentationInContext: context]];

      if ((o = [homeAdr flattenedValueAtIndex: 1  forKey: @""]) && [o length])
        [a appendFormat: @"\n%@", [o activeSyncRepresentationInContext: context]];
      
      [s appendFormat: @"<HomeStreet xmlns=\"Contacts:\">%@</HomeStreet>", a];

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
      a = [NSMutableString string];
      
      if ((o = [workAdr flattenedValueAtIndex: 2  forKey: @""]))
        [a appendString: [o activeSyncRepresentationInContext: context]];

      if ((o = [workAdr flattenedValueAtIndex: 1  forKey: @""]) && [o length])
        [a appendFormat: @"\n%@", [o activeSyncRepresentationInContext: context]];

      [s appendFormat: @"<BusinessStreet xmlns=\"Contacts:\">%@</BusinessStreet>", a];
      
      if ((o = [workAdr flattenedValueAtIndex: 3  forKey: @""]))
        [s appendFormat: @"<BusinessCity xmlns=\"Contacts:\">%@</BusinessCity>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [workAdr flattenedValueAtIndex: 4  forKey: @""]))
        [s appendFormat: @"<BusinessState xmlns=\"Contacts:\">%@</BusinessState>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [workAdr flattenedValueAtIndex: 5  forKey: @""]))
        [s appendFormat: @"<BusinessPostalCode xmlns=\"Contacts:\">%@</BusinessPostalCode>", [o activeSyncRepresentationInContext: context]];
      
      if ((o = [workAdr flattenedValueAtIndex: 6  forKey: @""]))
        [s appendFormat: @"<BusinessCountry xmlns=\"Contacts:\">%@</BusinessCountry>", [o activeSyncRepresentationInContext: context]];
    }


  // Other Address

  other_addresses = [[self childrenWithTag: @"adr"] mutableCopy];
  [other_addresses removeObjectsInArray: [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"work"]];
  [other_addresses removeObjectsInArray: [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"home"]];

  if ([other_addresses count])
    {
      otherAdr = [other_addresses objectAtIndex: 0];
      a = [NSMutableString string];

      if ((o = [otherAdr flattenedValueAtIndex: 2  forKey: @""]))
        [a appendString: [o activeSyncRepresentationInContext: context]];

      if ((o = [otherAdr flattenedValueAtIndex: 1  forKey: @""]) && [o length])
        [a appendFormat: @"\n%@", [o activeSyncRepresentationInContext: context]];

      [s appendFormat: @"<OtherStreet xmlns=\"Contacts:\">%@</OtherStreet>", a];

      if ((o = [otherAdr flattenedValueAtIndex: 3  forKey: @""]))
        [s appendFormat: @"<OtherCity xmlns=\"Contacts:\">%@</OtherCity>", [o activeSyncRepresentationInContext: context]];

      if ((o = [otherAdr flattenedValueAtIndex: 4  forKey: @""]))
        [s appendFormat: @"<OtherState xmlns=\"Contacts:\">%@</OtherState>", [o activeSyncRepresentationInContext: context]];

      if ((o = [otherAdr flattenedValueAtIndex: 5  forKey: @""]))
        [s appendFormat: @"<OtherPostalCode xmlns=\"Contacts:\">%@</OtherPostalCode>", [o activeSyncRepresentationInContext: context]];

      if ((o = [otherAdr flattenedValueAtIndex: 6  forKey: @""]))
        [s appendFormat: @"<OtherCountry xmlns=\"Contacts:\">%@</OtherCountry>", [o activeSyncRepresentationInContext: context]];
    }

  // Other, less important fields
  if ((o = [self birthday]))
    {
      [s appendFormat: @"<Birthday xmlns=\"Contacts:\">%@</Birthday>",
         [[o dateByAddingYears: 0 months: 0 days: 0
                         hours: -12 minutes: 0
                       seconds: 0]
              activeSyncRepresentationInContext: context]];
    }

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
  NSMutableArray *addressLines, *other_addresses;
  id o, l, m, f, p, s;

  l = m = f = p = s = nil;

  // Contact's note
  if ((o = [[theValues objectForKey: @"Body"] objectForKey: @"Data"]))
    [self setNote: o];

  // Categories
  if ((o = [theValues objectForKey: @"Categories"]) && [o length])
    [self setCategories: o];
  else
    [[self children] removeObjectsInArray: [self childrenWithTag: @"Categories"]];

  // Birthday
  if ((o = [theValues objectForKey: @"Birthday"]))
    {
      o = [o calendarDate];
      [self setBday: [o descriptionWithCalendarFormat: @"%Y-%m-%d" timeZone: nil locale: nil]];
    }
  else if (![self _isGhosted: @"Birthday" inContext: context])
    {
      [self setBday: @""];
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

  if ((o = [theValues objectForKey: @"BusinessStreet"]) || ![self _isGhosted: @"BusinessStreet" inContext: context])
    {
      addressLines = [NSMutableArray arrayWithArray: [o componentsSeparatedByString: @"\n"]];

      [element setSingleValue: @""
                      atIndex: 1 forKey: @""];
      [element setSingleValue: [addressLines count] ? [addressLines objectAtIndex: 0] : @""
                      atIndex: 2 forKey: @""];

      // Extended address line. If there are more than 2 address lines we add them to the extended address line.
      if ([addressLines count] > 1)
        {
          [addressLines removeObjectAtIndex: 0];
          [element setSingleValue: [addressLines componentsJoinedByString: @" "]
                          atIndex: 1 forKey: @""];
        }
     }

  if ((o = [theValues objectForKey: @"BusinessCity"]) || ![self _isGhosted: @"BusinessCity" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"BusinessCity"]
                      atIndex: 3 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"BusinessState"]) || ![self _isGhosted: @"BusinessState" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"BusinessState"]
                      atIndex: 4 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"BusinessPostalCode"]) || ![self _isGhosted: @"BusinessPostalCode" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"BusinessPostalCode"]
                      atIndex: 5 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"BusinessCountry"]) || ![self _isGhosted: @"BusinessCountry" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"BusinessCountry"]
                      atIndex: 6 forKey: @""];
    }

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

  if ((o = [theValues objectForKey: @"HomeStreet"]) || ![self _isGhosted: @"HomeStreet" inContext: context])
    {
      addressLines = [NSMutableArray arrayWithArray: [o componentsSeparatedByString: @"\n"]];

      [element setSingleValue: @""
                      atIndex: 1 forKey: @""];
      [element setSingleValue: [addressLines count] ? [addressLines objectAtIndex: 0] : @""
                      atIndex: 2 forKey: @""];

      // Extended address line. If there are more then 2 address lines we add them to the extended address line.
      if ([addressLines count] > 1)
        {
          [addressLines removeObjectAtIndex: 0];
          [element setSingleValue: [addressLines componentsJoinedByString: @" "]
                          atIndex: 1 forKey: @""];
        }
    }

  if ((o = [theValues objectForKey: @"HomeCity"]) || ![self _isGhosted: @"HomeCity" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"HomeCity"]
                      atIndex: 3 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"HomeState"]) || ![self _isGhosted: @"HomeState" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"HomeState"]
                      atIndex: 4 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"HomePostalCode"]) || ![self _isGhosted: @"HomePostalCode" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"HomePostalCode"]
                      atIndex: 5 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"HomeCountry"]) || ![self _isGhosted: @"HomeCountry" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"HomeCountry"]
                      atIndex: 6 forKey: @""];
    }

   // OtherCountry
   //

  other_addresses = [[self childrenWithTag: @"adr"] mutableCopy];
  [other_addresses removeObjectsInArray: [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"work"]];
  [other_addresses removeObjectsInArray: [self childrenWithTag: @"adr" andAttribute: @"type" havingValue: @"home"]];

  if ([other_addresses count])
    element = [other_addresses objectAtIndex: 0];
  else
    {
      element = [CardElement elementWithTag: @"adr"];
      [self addChild: element];
    }

  if ((o = [theValues objectForKey: @"OtherStreet"]) || ![self _isGhosted: @"OtherStreet" inContext: context])
    {
      addressLines = [NSMutableArray arrayWithArray: [o componentsSeparatedByString: @"\n"]];

      [element setSingleValue: @""
                       atIndex: 1 forKey: @""];
      [element setSingleValue: [addressLines count] ? [addressLines objectAtIndex: 0] : @""
                       atIndex: 2 forKey: @""];

      // Extended address line. If there are more then 2 address lines we add them to the extended address line.
      if ([addressLines count] > 1)
        {
          [addressLines removeObjectAtIndex: 0];
          [element setSingleValue: [addressLines componentsJoinedByString: @" "]
                          atIndex: 1 forKey: @""];
        }
    }

  if ((o = [theValues objectForKey: @"OtherCity"]) || ![self _isGhosted: @"OtherCity" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"OtherCity"]
                      atIndex: 3 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"OtherState"]) || ![self _isGhosted: @"OtherState" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"OtherState"]
                      atIndex: 4 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"OtherPostalCode"]) || ![self _isGhosted: @"OtherPostalCode" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"OtherPostalCode"]
                      atIndex: 5 forKey: @""];
    }

  if ((o = [theValues objectForKey: @"OtherCountry"]) || ![self _isGhosted: @"OtherCountry" inContext: context])
    {
      [element setSingleValue: [theValues objectForKey: @"OtherCountry"]
                      atIndex: 6 forKey: @""];
    }

  // Company's name
  if ((o = [theValues objectForKey: @"CompanyName"]))
    [self setOrg: o  units: nil];
  else if (![self _isGhosted: @"CompanyName" inContext: context])
    [self setOrg: @""  units: nil];
  
  // Department
  if ((o = [theValues objectForKey: @"Department"]))
    [self setOrg: nil  units: [NSArray arrayWithObjects:o,nil]];
  else if (![self _isGhosted: @"Department" inContext: context])
    [self setOrg: nil  units: [NSArray arrayWithObjects:@"",nil]];
  
  // Email addresses
  if ((o = [theValues objectForKey: @"Email1Address"]) || ![self _isGhosted: @"Email1Address" inContext: context])
    {
      element = [self elementWithTag: @"email" ofType: @"work"];
      [element setSingleValue: [o pureEMailAddress] forKey: @""];
    }
  
  if ((o = [theValues objectForKey: @"Email2Address"]) || ![self _isGhosted: @"Email2Address" inContext: context])
    {
      element = [self elementWithTag: @"email" ofType: @"home"];
      [element setSingleValue: [o pureEMailAddress] forKey: @""];
    }
  
  // SOGo currently only supports 2 email addresses ... but AS clients might send 3
  // FIXME: revise this when the GUI revamp is done in SOGo
  if ((o = [theValues objectForKey: @"Email3Address"]) || ![self _isGhosted: @"Email3Address" inContext: context])
    {
      element = [self elementWithTag: @"email" ofType: @"three"];
      [element setSingleValue: [o pureEMailAddress] forKey: @""];
    }
  
  // Formatted name
  // MiddleName
  // Suffix   (II)
  // Title    (Mr.)
  if ((o = [theValues objectForKey: @"FileAs"]) || ![self _isGhosted: @"FileAs" inContext: context])
    [self setFn: [theValues objectForKey: @"FileAs"]];

  if ((o = [theValues objectForKey: @"LastName"]) || ![self _isGhosted: @"LastName" inContext: context])
    l = o ? o : @"";

  if ((o = [theValues objectForKey: @"FirstName"]) || ![self _isGhosted: @"FirstName" inContext: context])
    f = o ? o : @"";

  if ((o = [theValues objectForKey: @"MiddleName"]) || ![self _isGhosted: @"MiddleName" inContext: context])
    m = o ? o : @"";

  if ((o = [theValues objectForKey: @"Title"]) || ![self _isGhosted: @"Title" inContext: context])
    p = o ? o : @"";

  if ((o = [theValues objectForKey: @"Suffix"]) || ![self _isGhosted: @"Suffix" inContext: context])
    s = o ? o : @"";

  [self setNWithFamily: l given: f additional: m prefixes: p suffixes: s];

  // IM information
  if ((o = [theValues objectForKey: @"IMAddress"]) || ![self _isGhosted: @"IMAddress" inContext: context])
    [[self uniqueChildWithTag: @"x-aim"]
      setSingleValue: [theValues objectForKey: @"IMAddress"]
              forKey: @""];

  //
  // Phone numbrrs
  //
  if ((o = [theValues objectForKey: @"BusinessPhoneNumber"]) || ![self _isGhosted: @"BusinessPhoneNumber" inContext: context])
    {
      element = [self elementWithTag: @"tel" ofType: @"work"];
      [element setSingleValue: [theValues objectForKey: @"BusinessPhoneNumber"]  forKey: @""];
    }

  if ((o = [theValues objectForKey: @"HomePhoneNumber"]) || ![self _isGhosted: @"HomePhoneNumber" inContext: context])
    {
      element = [self elementWithTag: @"tel" ofType: @"home"];
      [element setSingleValue: [theValues objectForKey: @"HomePhoneNumber"]  forKey: @""];
    }

  if ((o = [theValues objectForKey: @"MobilePhoneNumber"]) || ![self _isGhosted: @"MobilePhoneNumber" inContext: context])
    {
      element = [self elementWithTag: @"tel" ofType: @"cell"];
      [element setSingleValue: [theValues objectForKey: @"MobilePhoneNumber"]  forKey: @""];
    }

  if ((o = [theValues objectForKey: @"BusinessFaxNumber"]) || ![self _isGhosted: @"BusinessFaxNumber" inContext: context])
    {
      element = [self elementWithTag: @"tel" ofType: @"fax"];
      [element setSingleValue: [theValues objectForKey: @"BusinessFaxNumber"]  forKey: @""];
    }

  if ((o = [theValues objectForKey: @"PagerNumber"]) || ![self _isGhosted: @"PagerNumber" inContext: context])
    {
      element = [self elementWithTag: @"tel" ofType: @"pager"];
      [element setSingleValue: [theValues objectForKey: @"PagerNumber"]  forKey: @""];
    }
  
  // Job's title
  if ((o = [theValues objectForKey: @"JobTitle"]) || ![self _isGhosted: @"JobTitle" inContext: context])
    [self setTitle: o];
  
  // WebPage (work)
  if ((o = [theValues objectForKey: @"WebPage"]) || ![self _isGhosted: @"WebPage" inContext: context])
    [[self elementWithTag: @"url" ofType: @"work"]
          setSingleValue: o  forKey: @""];
  
  if ((o = [theValues objectForKey: @"NickName"]) || ![self _isGhosted: @"NickName" inContext: context])
    [self setNickname: o];

  if ((o = [theValues objectForKey: @"Picture"]))
    [self setPhoto: o];

}

@end
