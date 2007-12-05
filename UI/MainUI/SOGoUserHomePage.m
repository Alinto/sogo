/* SOGoUserHomePage.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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
#import <Foundation/NSURL.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <Appointments/SOGoFreeBusyObject.h>
#import <SoObjects/SOGo/SOGoWebAuthenticator.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserFolder.h>
#import <SoObjects/SOGo/NSCalendarDate+SOGo.h>
#import <SOGoUI/UIxComponent.h>

static NSString *defaultModule = nil;

@interface SOGoUserHomePage : UIxComponent

@end

@implementation SOGoUserHomePage

+ (void) initialize
{
  NSUserDefaults *ud;

  if (!defaultModule)
    {
      ud = [NSUserDefaults standardUserDefaults];
      defaultModule = [ud stringForKey: @"SOGoUIxDefaultModule"];
      if (defaultModule)
	{
	  if (!([defaultModule isEqualToString: @"Calendar"]
		|| [defaultModule isEqualToString: @"Contacts"]
		|| [defaultModule isEqualToString: @"Mail"]))
	    {
	      [self logWithFormat: @"default module '%@' not accepted (must be"
		    @"'Calendar', 'Contacts' or Mail)", defaultModule];
	      defaultModule = @"Calendar";
	    }
	}
      else
	defaultModule = @"Calendar";
      [self logWithFormat: @"default module set to '%@'", defaultModule];
      [defaultModule retain];
    }
}

- (id <WOActionResults>) defaultAction
{
  SOGoUserFolder *co;
  NSURL *moduleURL;

  co = [self clientObject];
  moduleURL = [NSURL URLWithString: defaultModule
		     relativeToURL: [co soURL]];

  return [self redirectToLocation: [moduleURL absoluteString]];
}

- (void) _fillFreeBusyItems: (NSMutableArray *) items
                withRecords: (NSEnumerator *) records
              fromStartDate: (NSCalendarDate *) startDate
                  toEndDate: (NSCalendarDate *) endDate
{
  NSDictionary *record;
  int count, startInterval, endInterval, value;
  NSNumber *status;
  NSCalendarDate *currentDate;
  
  while ((record = [records nextObject]))
    {
      status = [record objectForKey: @"c_status"];
 
      value = [[record objectForKey: @"c_startdate"] intValue];
      currentDate = [NSCalendarDate dateWithTimeIntervalSince1970: value];
      if ([currentDate earlierDate: startDate] == currentDate)
        startInterval = 0;
      else
        startInterval
          = ([currentDate timeIntervalSinceDate: startDate] / 900);

      value = [[record objectForKey: @"c_enddate"] intValue];
      currentDate = [NSCalendarDate dateWithTimeIntervalSince1970: value];
      if ([currentDate earlierDate: endDate] == endDate)
        endInterval = [items count] - 1;
      else
        endInterval = ([currentDate timeIntervalSinceDate: startDate] / 900);

      for (count = startInterval; count < endInterval; count++)
        [items replaceObjectAtIndex: count withObject: status];
    }
}
 
- (NSString *) _freeBusyAsTextFromStartDate: (NSCalendarDate *) startDate
                                  toEndDate: (NSCalendarDate *) endDate
                                forFreeBusy: (SOGoFreeBusyObject *) fb
{
  NSEnumerator *records;
  NSMutableArray *freeBusyItems;
  NSTimeInterval interval;
  int count, intervals;

  interval = [endDate timeIntervalSinceDate: startDate] + 60;
  intervals = interval / 900; /* slices of 15 minutes */
  freeBusyItems = [NSMutableArray arrayWithCapacity: intervals];
  for (count = 1; count < intervals; count++)
    [freeBusyItems addObject: @"0"];

  records = [[fb fetchFreeBusyInfosFrom: startDate to: endDate] objectEnumerator];
  [self _fillFreeBusyItems: freeBusyItems withRecords: records
        fromStartDate: startDate toEndDate: endDate];

  return [freeBusyItems componentsJoinedByString: @","];
}

- (NSString *) _freeBusyAsText
{
  SOGoFreeBusyObject *co;
  NSCalendarDate *startDate, *endDate;
  NSString *queryDay, *additionalDays;
  NSTimeZone *uTZ;
  SOGoUser *user;

  co = [self clientObject];
  user = [context activeUser];
  uTZ = [user timeZone];

  queryDay = [self queryParameterForKey: @"sday"];
  if ([queryDay length])
    startDate = [NSCalendarDate dateFromShortDateString: queryDay
                                andShortTimeString: @"0000"
                                inTimeZone: uTZ];
  else
    {
      startDate = [NSCalendarDate calendarDate];
      [startDate setTimeZone: uTZ];
      startDate = [startDate hour: 0 minute: 0];
    }

  queryDay = [self queryParameterForKey: @"eday"];
  if ([queryDay length])
    endDate = [NSCalendarDate dateFromShortDateString: queryDay
                              andShortTimeString: @"2359"
                              inTimeZone: uTZ];
  else
    endDate = [startDate hour: 23 minute: 59];

  additionalDays = [self queryParameterForKey: @"additional"];
  if ([additionalDays length] > 0)
    endDate = [endDate dateByAddingYears: 0 months: 0
                       days: [additionalDays intValue]
                       hours: 0 minutes: 0 seconds: 0];

  return [self _freeBusyAsTextFromStartDate: startDate toEndDate: endDate
               forFreeBusy: co];
}

- (id <WOActionResults>) readFreeBusyAction
{
  WOResponse *response;

  response = [context response];
  [response setStatus: 200];
//   [response setHeader: @"text/plain; charset=iso-8859-1"
//             forKey: @"Content-Type"];
  [response appendContentString: [self _freeBusyAsText]];

  return response;
}

- (id <WOActionResults>) logoffAction
{
  WOResponse *response;
  WOCookie *cookie;
  SOGoWebAuthenticator *auth;
  id container;
  NSCalendarDate *date;

  container = [[self clientObject] container];

  response = [context response];
  [response setStatus: 302];
  [response setHeader: [container baseURLInContext: context]
	    forKey: @"location"];
  auth = [[self clientObject] authenticatorInContext: context];

  date = [NSCalendarDate calendarDate];
  [date setTimeZone: [NSTimeZone timeZoneWithAbbreviation: @"GMT"]];

  cookie = [WOCookie cookieWithName: [auth cookieNameInContext: context]
		     value: @"discard"];
  [cookie setPath: @"/"];
  [cookie setExpires: [date yesterday]];
  [response addCookie: cookie];

  [response setHeader: [date rfc822DateString] forKey: @"Last-Modified"];
  [response setHeader: @"no-store, no-cache, must-revalidate, max-age=0"
	    forKey: @"Cache-Control"];
  [response setHeader: @"post-check=0, pre-check=0" forKey: @"Cache-Control"];
  [response setHeader: @"no-cache" forKey: @"Pragma"];

  return response;
}

- (NSString *) _foldersStringForFolders: (NSEnumerator *) folders
{
  NSMutableString *foldersString;
  NSDictionary *currentFolder;

  foldersString = [NSMutableString new];
  [foldersString autorelease];

  currentFolder = [folders nextObject];
  while (currentFolder)
    {
      [foldersString appendFormat: @";%@:%@:%@",
		     [currentFolder objectForKey: @"displayName"],
		     [currentFolder objectForKey: @"name"],
		     [currentFolder objectForKey: @"type"]];
      currentFolder = [folders nextObject];
    }

  return foldersString;
}

- (WOResponse *) _foldersResponseForResults: (NSDictionary *) results
{
  WOResponse *response;
  NSString *uid, *foldersString;
  NSMutableString *responseString;
  NSDictionary *contact;
  NSEnumerator *contacts;
  NSArray *folders;

  response = [context response];
  [response setStatus: 200];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"Content-Type"];

  responseString = [NSMutableString new];
  contacts = [[results allKeys] objectEnumerator];
  while ((contact = [contacts nextObject]))
    {
      uid = [contact objectForKey: @"c_uid"];
      folders = [results objectForKey: contact];
      foldersString
	= [self _foldersStringForFolders: [folders objectEnumerator]];
      [responseString appendFormat: @"%@:%@:%@%@\n", uid,
		      [contact objectForKey: @"cn"],
		      [contact objectForKey: @"c_email"],
		      foldersString];
    }
  [response appendContentString: responseString];
  [responseString release];

  return response;
}

- (id <WOActionResults>) foldersSearchAction
{
  NSString *contact, *folderType;
  NSDictionary *folders;
  id <WOActionResults> result;

  contact = [self queryParameterForKey: @"search"];
  if ([contact length])
    {
      folderType = [self queryParameterForKey: @"type"];
      if ([folderType length])
	{
	  folders = [[self clientObject] foldersOfType: folderType
					 matchingUID: contact];
	  result = [self _foldersResponseForResults: folders];
	}
      else
	result = [NSException exceptionWithHTTPStatus: 400
			      reason: @"missing 'type' parameter"];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 400
                          reason: @"missing 'search' parameter"];

  return result;
}

@end
