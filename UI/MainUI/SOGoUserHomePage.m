/* SOGoUserHomePage.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2017 Inverse inc.
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
#import <SOGo/SOGoOpenIdSession.h>
#if defined(SAML2_CONFIG)
#import <SOGo/SOGoSAML2Session.h>
#endif
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoWebAuthenticator.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserProfile.h>
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
  BOOL moduleIsValid;
  NSArray *filters;
  NSURL *moduleURL;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  dd = [[context activeUser] domainDefaults];
  ud = [[context activeUser] userDefaults];

  loginModule = [ud loginModule];
  moduleIsValid = ([loginModule isEqualToString: @"Calendar"] ||
                   [loginModule isEqualToString: @"Contacts"] ||
                   [loginModule isEqualToString: @"Mail"]);
  if (!moduleIsValid)
    {
      [self errorWithFormat: @"login module '%@' not accepted (must be "
            @"'Calendar', 'Contacts' or 'Mail')", loginModule];
    }
  if (!moduleIsValid || ![[context activeUser] canAccessModule: loginModule])
    {
      loginModule = @"Contacts";
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

- (NSDictionary *) _freeBusyFromStartDate: (NSCalendarDate *) startDate
                            toEndDate: (NSCalendarDate *) endDate
                          forFreeBusy: (SOGoFreeBusyObject *) fb
                           andContact: (NSString *) uid
{
  NSCalendarDate *start, *end;
  NSMutableDictionary *freeBusy, *dayData, *hourData;
  NSArray *records;
  NSArray *emails, *partstates;
  NSCalendarDate *currentDate, *currentStartDate, *currentEndDate;
  NSDictionary *record;
  NSString *dayKey, *hourKey, *minuteKey;
  NSEnumerator *freeBusyList, *dayList, *hourList;
  SOGoUser *user;
  int quarter, lastQuarter, recordCount, recordMax, count, i, type, maxBookings, isResource;

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

  freeBusy = [NSMutableDictionary dictionary];
  user = [SOGoUser userWithLogin: [[self clientObject] ownerInContext: context] roles: nil];
  maxBookings = [user numberOfSimultaneousBookings];
  isResource = [user isResource];

  // Fetch freebusy information if the user is NOT a resource or if multiplebookings isn't unlimited
  if (!isResource || maxBookings != 0)
    {
      records = [fb fetchFreeBusyInfosFrom: start to: end forContact: uid];
      recordMax = [records count];
      for (recordCount = 0; recordCount < recordMax; recordCount++)
        {
          record = [records objectAtIndex: recordCount];
          user = [record objectForKey: @"owner"];
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
                              // 0: needs action   (considered busy)
                              // 1: accepted       (busy)
                              // 2: declined       (free)
                              // 3: tentative      (free)
                              // 4: delegated      (free)
                              type = ([[partstates objectAtIndex: i] intValue] < 2 ? 1 : 0);
                            }
                          break;
                        }
                    }
                }

              if (type == 1)
                {
                  // User is busy for this event
                  currentStartDate = [record objectForKey: @"startDate"];
                  currentEndDate = [record objectForKey: @"endDate"];
                  if ([currentStartDate earlierDate: startDate] == currentStartDate)
                    currentStartDate = startDate;
                  dayKey = [currentStartDate shortDateString];
                  dayData = [freeBusy objectForKey: dayKey];
                  if (!dayData)
                    {
                      dayData = [NSMutableDictionary dictionary];
                      [freeBusy setObject: dayData forKey: dayKey];
                    }

                  currentDate = [NSCalendarDate dateWithYear: [currentStartDate yearOfCommonEra]
                                                       month: [currentStartDate monthOfYear]
                                                         day: [currentStartDate dayOfMonth]
                                                        hour: [currentStartDate hourOfDay]
                                                      minute: 0
                                                      second: 0
                                                    timeZone: [currentStartDate timeZone]];

                  // Increment counters for quarters of first hour
                  hourKey = [NSString stringWithFormat: @"%u", (unsigned int)[currentDate hourOfDay]];
                  hourData = [dayData objectForKey: hourKey];
                  if (!hourData)
                    {
                      hourData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithInt: 0], @"0",
                                                      [NSNumber numberWithInt: 0], @"15",
                                                      [NSNumber numberWithInt: 0], @"30",
                                                      [NSNumber numberWithInt: 0], @"45",
                                                      nil];
                      [dayData setObject: hourData forKey: hourKey];
                    }
                  quarter = (int)([currentStartDate minuteOfHour] / 15 + 0.5);
                  if ([currentEndDate timeIntervalSinceDate: currentDate] < 3600)
                    lastQuarter = (int)([currentEndDate minuteOfHour] / 15 + 0.5);
                  else
                    lastQuarter = 4;
                  for (i = 0; i < lastQuarter; i++) {
                    if (i >= quarter)
                      {
                        minuteKey = [NSString stringWithFormat: @"%u", i*15];
                        count = [[hourData objectForKey: minuteKey] intValue] + 1;
                        [hourData setObject: [NSNumber numberWithInt: count] forKey: minuteKey];
                      }
                  }
                  currentDate = [currentDate dateByAddingYears:0 months:0 days:0 hours:1 minutes:0 seconds:0];

                  // Increment counters of fully busy hours
                  while ([currentDate compare: currentEndDate] == NSOrderedAscending &&
                         [currentEndDate timeIntervalSinceDate: currentDate] >= 3600) // 1 hour
                    {
                      if ([currentDate hourOfDay] == 0)
                        {
                          // New day
                          dayKey = [currentDate shortDateString];
                          dayData = [freeBusy objectForKey: dayKey];
                          if (!dayData)
                            {
                              dayData = [NSMutableDictionary dictionary];
                              [freeBusy setObject: dayData forKey: dayKey];
                            }
                        }
                      hourKey = [NSString stringWithFormat: @"%u", (unsigned int)[currentDate hourOfDay]];
                      hourData = [dayData objectForKey: hourKey];
                      if (!hourData)
                        {
                          hourData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                               [NSNumber numberWithInt: 1], @"0",
                                                               [NSNumber numberWithInt: 1], @"15",
                                                               [NSNumber numberWithInt: 1], @"30",
                                                               [NSNumber numberWithInt: 1], @"45",
                                                          nil];
                          [dayData setObject: hourData forKey: hourKey];
                        }
                      else
                        {
                          for (i = 0; i < 4; i++)
                            {
                              minuteKey = [NSString stringWithFormat: @"%u", i*15];
                              count = [[hourData objectForKey: minuteKey] intValue] + 1;
                              [hourData setObject: [NSNumber numberWithInt: count] forKey: minuteKey];
                            }
                        }
                      currentDate = [currentDate dateByAddingYears:0 months:0 days:0 hours:1 minutes:0 seconds:0];
                    }

                  // Increment counters for quarters of last hour
                  if ([currentEndDate timeIntervalSinceDate: currentDate] > 0)
                    {
                      hourKey = [NSString stringWithFormat: @"%u", (unsigned int)[currentDate hourOfDay]];
                      hourData = [dayData objectForKey: hourKey];
                      if (!hourData)
                        {
                          hourData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                               [NSNumber numberWithInt: 0], @"0",
                                                               [NSNumber numberWithInt: 0], @"15",
                                                               [NSNumber numberWithInt: 0], @"30",
                                                               [NSNumber numberWithInt: 0], @"45",
                                                          nil];
                          [dayData setObject: hourData forKey: hourKey];
                        }
                      quarter = (int)([currentEndDate minuteOfHour] / 15 + 0.5);
                      for (i = 0; i < 4; i++)
                        {
                          if (i < quarter)
                            {
                              minuteKey = [NSString stringWithFormat: @"%u", i*15];
                              if (isResource)
                                count = [[hourData objectForKey: minuteKey] intValue] + 1;
                              else
                                count = 1;
                              [hourData setObject: [NSNumber numberWithInt: count] forKey: minuteKey];
                            }
                        }
                    }
                }
            }
        }
      if (maxBookings > 0)
        {
          // Reset the freebusy for the periods that are bellow the maximum number of bookings
          freeBusyList = [freeBusy objectEnumerator];
          while ((dayData = [freeBusyList nextObject]))
            {
              dayList = [dayData objectEnumerator];
              while ((hourData = [dayList nextObject]))
                {
                  hourList = [hourData keyEnumerator];
                  while ((minuteKey = [hourList nextObject]))
                    {
                      count = [[hourData objectForKey: minuteKey] intValue];
                      if (count < maxBookings)
                        i = 0;
                      else
                        i = 1;
                      if (i != count)
                        [hourData setObject: [NSNumber numberWithInt: i] forKey: minuteKey];
                    }
                }
            }
        }
    }

  return freeBusy;
}

- (id <WOActionResults>) readFreeBusyAction
{
  SOGoFreeBusyObject *freebusy;
  NSCalendarDate *startDate, *endDate;
  NSDictionary *jsonResponse;
  NSString *queryDay, *uid;
  NSTimeZone *uTZ;
  SOGoUser *user;
  unsigned int httpStatus;

  user = [context activeUser];
  uTZ = [[user userDefaults] timeZone];
  httpStatus = 200;

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
            {
              httpStatus = 403;
              jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                             @"failure", @"status",
                                           @"Start date is later than end date.", @"message",
                                           nil];
            }
          else
            {
              freebusy = [self clientObject];
              jsonResponse = [self _freeBusyFromStartDate: startDate
                                                toEndDate: endDate
                                              forFreeBusy: freebusy
                                               andContact: uid];
            }
        }
      else
        {
          httpStatus = 403;
          jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"failure", @"status",
                                       @"Invalid end date.", @"message",
                                       nil];
        }
    }
  else
    {
      httpStatus = 403;
      jsonResponse = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"failure", @"status",
                                   @"Invalid start date.", @"message",
                                   nil];
    }

  return [self responseWithStatus: httpStatus
            andJSONRepresentation: jsonResponse];
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
  else if ([[sd authenticationType] isEqualToString: @"openId"])
  {
    SOGoOpenIdSession* session;
    session = [SOGoOpenIdSession OpenIdSession];

    // redirectURL = [session];
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
  NSString *userName, *value;
  SOGoWebAuthenticator *auth;
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

  // We remove the XSRF cookie
  cookie = [WOCookie cookieWithName: @"XSRF-TOKEN"  value: @"discard"];
  [cookie setPath: [NSString stringWithFormat: @"/%@/", [[context request] applicationName]]];
  [cookie setExpires: [date yesterday]];
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
  NSString *contactInfo, *owner;
  NSMutableArray *jsonResponse;
  NSMutableDictionary *jsonLine;
  NSArray *allUsers;
  int count, max;
  BOOL activeUserIsInDomain;

  owner = [[self clientObject] ownerInContext: context];
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

      // We do NOT return the owner from which the search is performed
      if (!activeUserIsInDomain || ![uid isEqualToString: owner])
        {
          jsonLine = [NSMutableDictionary dictionary];
          if ([domain length])
            uid = [NSString stringWithFormat: @"%@@%@", uid, domain];
          [jsonLine setObject: uid forKey: @"uid"];
          [jsonLine setObject: [contact objectForKey: @"cn"] forKey: @"cn"];
          [jsonLine setObject: [contact objectForKey: @"c_email"] forKey: @"c_email"];
          [jsonLine setObject: [NSNumber numberWithBool: [[contact objectForKey: @"isGroup"] boolValue]] forKey: @"isGroup"];
          contactInfo = [contact objectForKey: @"c_info"];
          if (contactInfo)
            [jsonLine setObject: contactInfo forKey: @"c_info"];
          [jsonResponse addObject: jsonLine];
        }
    }

  return jsonResponse;
}

/**
 * @api {get} /so/:username/usersSearch?search=:search Search for users
 * @apiVersion 1.0.0
 * @apiName GetUsersSearch
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/usersSearch?search=john
 *
 * @apiParam {String} search Substring to match against username or email address
 *
 * @apiSuccess (Success 200) {Object[]} users        List of matching users
 * @apiSuccess (Success 200) {String} users.uid      User ID
 * @apiSuccess (Success 200) {String} users.c_email  Main email address
 * @apiSuccess (Success 200) {String} users.cn       Common name
 * @apiSuccess (Success 200) {Number} users.isGroup  1 if the user is a group
 * @apiError   (Error 400) {Object} error            The error message
 */
- (id <WOActionResults>) usersSearchAction
{
  NSMutableArray *users;
  NSArray *currentUsers;
  NSDictionary *message;
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
      result = [self responseWithStatus: 200
                  andJSONRepresentation: [NSDictionary dictionaryWithObject: users forKey: @"users"]];
    }
  else
    {
      message = [NSDictionary dictionaryWithObject: [self labelForKey: @"Missing search parameter"]
                                          forKey: @"error"];
      result = [self responseWithStatus: 400 andJSONRepresentation: message];
    }

  return result;
}

- (WOResponse *) _foldersResponseForResults: (NSArray *) folders
{
  WOResponse *response;

  response = [context response];
  [response setStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"Content-Type"];

  [response appendContentString: [[NSDictionary dictionaryWithObject: folders
                                                              forKey: @"folders"] JSONRepresentation]];

  return response;
}

/**
 * @api {get} /so/:username/foldersSearch?type=:type Search for folders
 * @apiVersion 1.0.0
 * @apiName GetFoldersSearch
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/foldersSearch?type=contact
 *
 * @apiParam {String} type Either 'calendar' or 'contact'. If nothing is specifed, its both.
 *
 * @apiSuccess (Success 200) {Object[]} folders           List of matching folders
 * @apiSuccess (Success 200) {String} folders.name        Path of folder
 * @apiSuccess (Success 200) {String} folders.displayName Human readable name
 * @apiSuccess (Success 200) {String} folders.owner       Username of owner
 * @apiSuccess (Success 200) {String} folders.type        Either 'calendar' or 'contact'
 * @apiError   (Error 400) {Object} error                 The error message
 */
- (id <WOActionResults>) foldersSearchAction
{
  NSString *folderType;
  NSMutableArray *folders;
  id <WOActionResults> result;
  SOGoUserFolder *userFolder;


  folderType = [self queryParameterForKey: @"type"];
  folders = [NSMutableArray array];
  userFolder = [self clientObject];

  if ([folderType length])
    {
      [folders addObjectsFromArray: [userFolder foldersOfType: folderType
                                                       forUID: [userFolder ownerInContext: context]]];
    }
  else
    {
      [folders addObjectsFromArray: [userFolder foldersOfType: @"calendar"
                                                        forUID: [userFolder ownerInContext: context]]];
      [folders addObjectsFromArray: [userFolder foldersOfType: @"contact"
                                                       forUID: [userFolder ownerInContext: context]]];
    }
  
  result = [self _foldersResponseForResults: folders];

  return result;
}

/**
 * @api {get} /so/:username/date Get current day
 * @apiVersion 1.0.0
 * @apiName GetCurrentDate
 * @apiGroup Common
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/date
 *
 * @apiSuccess (Success 200) {String} weekday      Full weekday name according to user's locale
 * @apiSuccess (Success 200) {String} month        Full month name according to user's locale
 * @apiSuccess (Success 200) {String} day          Day of month as two digit decimal number (leading zero)
 * @apiSuccess (Success 200) {String} year         Year as a decimal number with century
 * @apiSuccess (Success 200) {Object} abbr         Abbreviations
 * @apiSuccess (Success 200) {String} abbr.weekday Abbreviated weekday name according to user's locale
 * @apiSuccess (Success 200) {String} abbr.month   Abbreviated month name according to user's locale
 */
- (id <WOActionResults>) dateAction
{
  return [self responseWithStatus: 200 andJSONRepresentation: [[context activeUser] currentDay]];
}

- (id) recoverAction
{
  return [self responseWithStatus: 200
                        andString: @"Full recovery in place."];
}

@end
