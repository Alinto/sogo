/* SOGoUserHomePage.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
#import <SOGo/SOGoCASSession.h>
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

#define intervalSeconds 900 /* 15 minutes */

@interface SOGoUserHomePage : UIxComponent

@end

@implementation SOGoUserHomePage

- (id <WOActionResults>) defaultAction
{
  SOGoUserFolder *co;
  NSString *loginModule;
  SOGoUserDefaults *ud;
  NSURL *moduleURL;

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

  int recordCount, recordMax, count, startInterval, endInterval, i, type;

  recordMax = [records count];
  user = [SOGoUser userWithLogin: [[self clientObject] ownerInContext: context]
		     roles: nil];

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

	  currentDate = [record objectForKey: @"startDate"];
	  if ([currentDate earlierDate: startDate] == currentDate)
	    startInterval = 0;
	  else
	    startInterval = ([currentDate timeIntervalSinceDate: startDate]
			     / intervalSeconds);

	  currentDate = [record objectForKey: @"endDate"];
	  if ([currentDate earlierDate: endDate] == endDate)
	    endInterval = itemCount - 1;
	  else
	    endInterval = ([currentDate timeIntervalSinceDate: startDate]
			   / intervalSeconds);

	  if (type == 1)
	    for (count = startInterval; count < endInterval; count++)
	      *(items + count) = 1;
	}
    }
}

- (NSString *) _freeBusyFromStartDate: (NSCalendarDate *) startDate
                            toEndDate: (NSCalendarDate *) endDate
                          forFreeBusy: (SOGoFreeBusyObject *) fb
                           andContact: (NSString *) uid
{
  NSMutableArray *freeBusy;
  unsigned int *freeBusyItems;
  NSTimeInterval interval;
  unsigned int count, intervals;

  interval = [endDate timeIntervalSinceDate: startDate] + 60;
  intervals = interval / intervalSeconds; /* slices of 15 minutes */

  freeBusyItems = NSZoneCalloc (NULL, intervals, sizeof (int));
  [self _fillFreeBusyItems: freeBusyItems count: intervals
	       withRecords: [fb fetchFreeBusyInfosFrom: startDate to: endDate forContact: uid]
        fromStartDate: startDate toEndDate: endDate];

  freeBusy = [NSMutableArray arrayWithCapacity: intervals];
  for (count = 0; count < intervals; count++)
    [freeBusy
      addObject: [NSString stringWithFormat: @"%d", *(freeBusyItems + count)]];
  NSZoneFree (NULL, freeBusyItems);

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
    redirectURL = [SOGoCASSession CASURLWithAction: @"logout"
                                     andParameters: nil];
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
  [date setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];

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
  allUsers = [users
	       sortedArrayUsingSelector: @selector (caseInsensitiveDisplayNameCompare:)];

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
          if ([domain length])
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
  NSEnumerator *foldersEnum;
  NSDictionary *currentFolder;

  response = [context response];
  [response setStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"Content-Type"];
  foldersEnum = [folders objectEnumerator];
  while ((currentFolder = [foldersEnum nextObject]))
    [response appendContentString:
		[currentFolder keysWithFormat: @";%{displayName}:%{name}:%{type}"]];

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
  folders
    = [userFolder foldersOfType: folderType
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
