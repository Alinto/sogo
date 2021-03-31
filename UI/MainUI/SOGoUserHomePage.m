/* SOGoUserHomePage.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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
#import <Foundation/NSURL.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <Appointments/SOGoFreeBusyObject.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>

#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoCASSession.h>
#if defined(SAML2_CONFIG)
#import <SOGo/SOGoSAML2Session.h>
#endif
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoWebAuthenticator.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoSession.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGoUI/UIxComponent.h>

#import <SBJson/NSObject+SBJSON.h>

#define INTERVALSECONDS 900 /* 15 minutes */
#define PADDING 8
#define HALFPADDING PADDING/2

@interface SOGoUserHomePage : UIxComponent

@end

@implementation SOGoUserHomePage

- (id <WOActionResults>) defaultAction
{
  SOGoUserFolder *co;
  NSString *loginModule;
  SOGoSystemDefaults *sd;
  SOGoDomainDefaults *dd;
  SOGoUserDefaults *ud;
  NSArray *filters;
  NSURL *moduleURL;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  dd = [[context activeUser] domainDefaults];
  ud = [[context activeUser] userDefaults];

  loginModule = [ud loginModule];
  if (!([loginModule isEqualToString: @"Calendar"]
        || [loginModule isEqualToString: @"Contacts"]
        || [loginModule isEqualToString: @"Mail"]))
    {
      [self errorWithFormat: @"login module '%@' not accepted (must be"
            @"'Calendar', 'Contacts' or 'Mail')", loginModule];
      loginModule = @"Calendar";
    }

  // We check if we must write the Sieve scripts to the server
  // upon first login if no user preferences are found, and the SOGo
  // admin has defined SOGoSieveFilters in the domain or system settings
  if ([dd sieveScriptsEnabled] && [[[ud source] values] count] == 0 &&
      ((filters = [[dd source] objectForKey: @"SOGoSieveFilters"]) || (filters = [[sd source] objectForKey: @"SOGoSieveFilters"])))
    {
      SOGoMailAccount *account;
      SOGoMailAccounts *folder;

      [ud setSieveFilters: filters];
      [ud synchronize];

      folder = [[self clientObject] mailAccountsFolder: @"Mail"
					     inContext: context];
      account = [folder lookupName: @"0" inContext: context acquire: NO];
      [account updateFilters];
    }

  co = [self clientObject];
  moduleURL = [NSURL URLWithString: loginModule
		     relativeToURL: [co soURL]];

  return [self redirectToLocation: [moduleURL absoluteString]];
}

- (void) _fillFreeBusyItems: (unsigned int *) items
		      count: (unsigned int) itemCount
                withRecords: (NSArray *) records
              fromStartDate: (NSCalendarDate *) startDate
                  toEndDate: (NSCalendarDate *) endDate
{
  NSArray *emails, *partstates;
  NSCalendarDate *currentDate;
  NSDictionary *record;
  SOGoUser *user;

  int recordCount, recordMax, count, startInterval, endInterval, i, type, maxBookings, isResource, delta;

  recordMax = [records count];
  user = [SOGoUser userWithLogin: [[self clientObject] ownerInContext: context] roles: nil];
  maxBookings = [user numberOfSimultaneousBookings];
  isResource = [user isResource];

  // Fetch freebusy information if the user is NOT a resource or if multiplebookings isn't unlimited
  if (!isResource || maxBookings != 0)
    {
      for (recordCount = 0; recordCount < recordMax; recordCount++)
        {
          record = [records objectAtIndex: recordCount];
          if ([[record objectForKey: @"c_isopaque"] boolValue])
            {
              type = 0;

              // If the event has NO organizer (which means it's the user that has created it) OR
              // If we are the organizer of the event THEN we are automatically busy
              if ([[record objectForKey: @"c_orgmail"] length] == 0 ||
                  [user hasEmail: [record objectForKey: @"c_orgmail"]])
                {
                  type = 1;
                }
              else
                {
                  // We check if the user has accepted/declined or needs action
                  // on the current event.
                  emails = [[record objectForKey: @"c_partmails"] componentsSeparatedByString: @"\n"];

                  for (i = 0; i < [emails count]; i++)
                    {
                      if ([user hasEmail: [emails objectAtIndex: i]])
                        {
                          // We now fetch the c_partstates array and get the participation
                          // status of the user for the event
                          partstates = [[record objectForKey: @"c_partstates"] componentsSeparatedByString: @"\n"];
		    
                          if (i < [partstates count])
                            {
                              type = ([[partstates objectAtIndex: i] intValue] < 2 ? 1 : 0);
                            }
                          break;
                        }
                    }
                }

              if (type == 1)
                {
                  // User is busy for this event; update items bit string
                  currentDate = [record objectForKey: @"startDate"];
                  if ([currentDate earlierDate: startDate] == currentDate)
                    startInterval = 0;
                  else
                    startInterval = ([currentDate timeIntervalSinceDate: startDate]
                                     / INTERVALSECONDS);

                  delta = [[currentDate timeZoneDetail] timeZoneSecondsFromGMT] - [[startDate timeZoneDetail] timeZoneSecondsFromGMT];
                  startInterval += (delta/INTERVALSECONDS);
                  startInterval = (startInterval < -(HALFPADDING) ? -(HALFPADDING) : startInterval);

                  currentDate = [record objectForKey: @"endDate"];
                  if ([currentDate earlierDate: endDate] == endDate)
                    endInterval = itemCount - 1;
                  else
                    endInterval = ([currentDate timeIntervalSinceDate: startDate]
                                   / INTERVALSECONDS);
                  
                  delta = [[currentDate timeZoneDetail] timeZoneSecondsFromGMT] - [[startDate timeZoneDetail] timeZoneSecondsFromGMT];
                  endInterval += (delta/INTERVALSECONDS);
                  endInterval = (endInterval < 0 ? 0 : endInterval);
                  endInterval = (endInterval > itemCount+HALFPADDING ? itemCount+HALFPADDING : endInterval);

                  // Update bit string representation
                  // If the user is a resource with restristed amount of bookings, keep the sum of overlapping events
                  for (count = startInterval; count < endInterval; count++)
                    {
                      *(items + count) = (isResource && maxBookings > 0) ? *(items + count) + 1 : 1;
                    }
                }
            }
        }
      if (maxBookings > 0)
        {
          // Reset the freebusy for the periods that are bellow the maximum number of bookings
          for (count = 0; count < itemCount; count++)
            {
              if (*(items + count) < maxBookings)
                *(items + count) = 0;
              else
                *(items + count) = 1;
            }
        }
    }
}

//
//
//
- (NSString *) _freeBusyFromStartDate: (NSCalendarDate *) startDate
                            toEndDate: (NSCalendarDate *) endDate
                          forFreeBusy: (SOGoFreeBusyObject *) fb
                           andContact: (NSString *) uid
{
  NSCalendarDate *start, *end;
  NSMutableArray *freeBusy;
  unsigned int *freeBusyItems;
  NSTimeInterval interval;
  unsigned int count, intervals;

  // We "copy" the start/end date because -fetchFreeBusyInfosFrom will mess
  // with the timezone and we don't want that to properly calculate the delta
  // DO NOT USE -copy HERE - it'll simply return [self retain].
  start = [NSCalendarDate dateWithYear: [startDate yearOfCommonEra]
                                 month: [startDate monthOfYear]
                                   day: [startDate dayOfMonth]
                                  hour: [startDate hourOfDay]
                                minute: [startDate minuteOfHour]
                                second: [startDate secondOfMinute]
                              timeZone: [startDate timeZone]];
  
  end = [NSCalendarDate dateWithYear: [endDate yearOfCommonEra]
                               month: [endDate monthOfYear]
                                 day: [endDate dayOfMonth]
                                hour: [endDate hourOfDay]
                              minute: [endDate minuteOfHour]
                              second: [endDate secondOfMinute]
                            timeZone: [endDate timeZone]];

  interval = [endDate timeIntervalSinceDate: startDate] + 60;

  // Slices of 15 minutes. The +8 is to take into account that we can
  // have a timezone change during the freebusy lookup. We have +4 at the
  // beginning and +4 at the end.
  intervals = interval / INTERVALSECONDS + PADDING;

  // Build a bit string representation of the freebusy data for the period
  freeBusyItems = calloc(intervals, sizeof (unsigned int));
  [self _fillFreeBusyItems: (freeBusyItems+HALFPADDING)
                     count: (intervals-PADDING)
	       withRecords: [fb fetchFreeBusyInfosFrom: start to: end forContact: uid]
             fromStartDate: startDate
                 toEndDate: endDate];

  // Convert bit string to a NSArray. We also skip by the default the non-requested information.
  freeBusy = [NSMutableArray arrayWithCapacity: intervals];
  for (count = HALFPADDING; count < (intervals-HALFPADDING); count++)
    {
      [freeBusy addObject: [NSString stringWithFormat: @"%d", *(freeBusyItems + count)]];
    }
  free(freeBusyItems);

  // Return a NSString representation
  return [freeBusy componentsJoinedByString: @","];
}

- (id <WOActionResults>) readFreeBusyAction
{
  WOResponse *response;
  SOGoFreeBusyObject *freebusy;
  NSCalendarDate *startDate, *endDate;
  NSString *queryDay, *uid;
  NSTimeZone *uTZ;
  SOGoUser *user;

  user = [context activeUser];
  uTZ = [[user userDefaults] timeZone];

  uid = [self queryParameterForKey: @"uid"];
  queryDay = [self queryParameterForKey: @"sday"];
  if ([queryDay length] == 8)
    {
      startDate = [NSCalendarDate dateFromShortDateString: queryDay
                                       andShortTimeString: @"0000"
                                               inTimeZone: uTZ];
      queryDay = [self queryParameterForKey: @"eday"];
      if ([queryDay length] == 8)
        {
          endDate = [NSCalendarDate dateFromShortDateString: queryDay
                                         andShortTimeString: @"2359"
                                                 inTimeZone: uTZ];

          if ([startDate earlierDate: endDate] == endDate)
            response = [self responseWithStatus: 403
                                      andString: @"Start date is later than end date."];
          else
            {
             freebusy = [self clientObject];
              response
                = [self responseWithStatus: 200
                                 andString: [self _freeBusyFromStartDate: startDate
                                                               toEndDate: endDate
                                                             forFreeBusy: freebusy
                                                              andContact: uid]];
            }
        }
      else
        response = [self responseWithStatus: 403
                                  andString: @"Invalid end date."];
    }
  else
    response = [self responseWithStatus: 403
                              andString: @"Invalid start date."];

  return response;
}

- (NSString *) _logoutRedirectURL
{
  NSString *redirectURL;
  SOGoSystemDefaults *sd;
  id container;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  if ([[sd authenticationType] isEqualToString: @"cas"])
    {
      redirectURL = [SOGoCASSession CASURLWithAction: @"logout"
                                       andParameters: nil];
    }
#if defined(SAML2_CONFIG)
  else if ([[sd authenticationType] isEqualToString: @"saml2"])
    {
      NSString *username, *password, *domain, *value;
      SOGoSAML2Session *saml2Session;
      SOGoWebAuthenticator *auth;
      LassoServer *server;
      LassoLogout *logout;   
      NSArray *creds;
  
      auth = [[self clientObject] authenticatorInContext: context];
      value = [[context request] cookieValueForKey: [auth cookieNameInContext: context]];
      creds = [auth parseCredentials: value];

      value = [SOGoSession valueForSessionKey: [creds lastObject]];
      
      domain = nil;
      
      [SOGoSession decodeValue: value
                      usingKey: [creds objectAtIndex: 0]
                         login: &username
                        domain: &domain
                      password: &password];

      saml2Session = [SOGoSAML2Session SAML2SessionWithIdentifier: password
                                                        inContext: context];
      
      server = [SOGoSAML2Session lassoServerInContext: context];
      
      logout = lasso_logout_new(server);

      lasso_profile_set_session_from_dump(LASSO_PROFILE(logout), [[saml2Session session] UTF8String]);
      lasso_profile_set_identity_from_dump(LASSO_PROFILE(logout), [[saml2Session session] UTF8String]);
      lasso_logout_init_request(logout, NULL, LASSO_HTTP_METHOD_REDIRECT);
      lasso_logout_build_request_msg(logout);
      redirectURL = [NSString stringWithFormat: @"%s", LASSO_PROFILE(logout)->msg_url];

      // We destroy our cache entry, the session will be taken care by the caller
      [[SOGoCache sharedCache] removeSAML2LoginDumpsForIdentifier: password];
    }      
#endif
  else
    {
      container = [[self clientObject] container];
      redirectURL = [container baseURLInContext: context];
    }
  
  return redirectURL;
}

- (WOCookie *) _logoutCookieWithDate: (NSCalendarDate *) date
{
  SOGoWebAuthenticator *auth;
  NSString *cookieName, *appName;
  WOCookie *cookie;

  cookie = nil;

  auth = [[self clientObject] authenticatorInContext: context];
  if ([auth respondsToSelector: @selector (cookieNameInContext:)])
    {
      cookieName = [auth cookieNameInContext: context];
      if ([cookieName length])
        {
          cookie = [WOCookie cookieWithName: cookieName value: @"discard"];
          appName = [[context request] applicationName];
          [cookie setPath: [NSString stringWithFormat: @"/%@/", appName]];
          [cookie setExpires: [date yesterday]];
        }
    }

  return cookie;
}

- (id <WOActionResults>) logoffAction
{
  SOGoWebAuthenticator *auth;
  NSString *userName, *value;
  WOResponse *response;
  NSCalendarDate *date;
  WOCookie *cookie;
  NSArray *creds;
   
  userName = [[context activeUser] login];
  [self logWithFormat: @"user '%@' logged off", userName];

  response = [self redirectToLocation: [self _logoutRedirectURL]];

  date = [NSCalendarDate calendarDate];
  [date setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];

  // We cleanup the memecached/database session cache. We do this before
  // invoking _logoutCookieWithDate: in order to obtain its value.
  auth = [[self clientObject] authenticatorInContext: context];
  if ([auth respondsToSelector: @selector (cookieNameInContext:)])
    {
       value = [[context request] cookieValueForKey: [auth cookieNameInContext: context]];
       creds = [auth parseCredentials: value];
       
       if ([creds count] > 1)
	 [SOGoSession deleteValueForSessionKey: [creds objectAtIndex: 1]]; 
    }

  cookie = [self _logoutCookieWithDate: date];
  if (cookie)
    [response addCookie: cookie];

  [response setHeader: [date rfc822DateString] forKey: @"Last-Modified"];
  [response setHeader: @"no-store, no-cache, must-revalidate,"
            @" max-age=0, post-check=0, pre-check=0"
               forKey: @"Cache-Control"];
  [response setHeader: @"no-cache" forKey: @"Pragma"];


  return response;
}

- (NSMutableArray *) _usersForResults: (NSArray *) users
                             inDomain: (NSString *) domain
{
  NSString *uid;
  NSDictionary *contact;
  NSString *contactInfo, *login;
  NSMutableArray *jsonResponse, *jsonLine;
  NSArray *allUsers;
  int count, max;
  BOOL activeUserIsInDomain;

  login = [[context activeUser] login];
  activeUserIsInDomain = ([domain length] == 0 || [[[context activeUser] domain] isEqualToString: domain]);

  // We sort our array - this is pretty useful for the Web
  // interface of SOGo.
  allUsers = [users sortedArrayUsingSelector: @selector (caseInsensitiveDisplayNameCompare:)];

  max = [allUsers count];
  jsonResponse = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      contact = [allUsers objectAtIndex: count];
      uid = [contact objectForKey: @"c_uid"];

      // We do NOT return the current authenticated user
      if (!activeUserIsInDomain || ![uid isEqualToString: login])
        {
          jsonLine = [NSMutableArray arrayWithCapacity: 4];
          if ([domain length] && [uid rangeOfString: @"@"].location == NSNotFound)
            uid = [NSString stringWithFormat: @"%@@%@", uid, domain];
          [jsonLine addObject: uid];
          [jsonLine addObject: [contact objectForKey: @"cn"]];
          [jsonLine addObject: [contact objectForKey: @"c_email"]];
          [jsonLine addObject: [NSNumber numberWithBool: [[contact objectForKey: @"isGroup"] boolValue]]];
          contactInfo = [contact objectForKey: @"c_info"];
          if (contactInfo)
            [jsonLine addObject: contactInfo];
          [jsonResponse addObject: jsonLine];
        }
    }

  return jsonResponse;
}

- (id <WOActionResults>) usersSearchAction
{
  NSMutableArray *users;
  NSArray *currentUsers;
  NSString *contact, *domain, *uidDomain;
  NSEnumerator *visibleDomains;
  id <WOActionResults> result;
  SOGoUserManager *um;
  SOGoSystemDefaults *sd;

  contact = [self queryParameterForKey: @"search"];
  if ([contact length])
    {
      um = [SOGoUserManager sharedUserManager];
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      domain = [[context activeUser] domain];
      uidDomain = [sd enableDomainBasedUID]? domain : nil;
      users = [self _usersForResults: [um fetchUsersMatching: contact
                                                    inDomain: domain]
                            inDomain: uidDomain];
      if ([domain length])
        {
          // Add results from visible domains
          visibleDomains = [[sd visibleDomainsForDomain: domain] objectEnumerator];
          while ((domain = [visibleDomains nextObject]))
            {
              currentUsers = [self _usersForResults: [um fetchUsersMatching: contact
                                                                   inDomain: domain]
                                         inDomain: uidDomain];
              [users addObjectsFromArray: currentUsers];
            }
        }
      result = [self responseWithStatus: 200 andJSONRepresentation: users];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400
                          reason: @"missing 'search' parameter"];

  return result;
}

- (WOResponse *) _foldersResponseForResults: (NSArray *) folders
{
  WOResponse *response;

  response = [context response];
  [response setStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"Content-Type"];

  [response appendContentString: [folders JSONRepresentation]];

  return response;
}

- (id <WOActionResults>) foldersSearchAction
{
  NSString *folderType;
  NSArray *folders;
  id <WOActionResults> result;
  SOGoUserFolder *userFolder;

  folderType = [self queryParameterForKey: @"type"];
  userFolder = [self clientObject];
  folders = [userFolder foldersOfType: folderType
                               forUID: [userFolder ownerInContext: context]];
  result = [self _foldersResponseForResults: folders];
  
  return result;
}

- (id) recoverAction
{
  return [self responseWithStatus: 200
                        andString: @"Full recovery in place."];
}

@end
