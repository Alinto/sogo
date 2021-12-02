/* SOGoToolUpdateAutoReply.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2019 Inverse inc.
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSNull+misc.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/NSString+Utilities.h>
#import "SOGo/SOGoCredentialsFile.h"
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>

#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailAccount.h>

#import "SOGoTool.h"

#define statusquoAutoReply 0
#define enableAutoReply    1
#define disableAutoReply   2

@interface SOGoToolUpdateAutoReply : SOGoTool
@end

@implementation SOGoToolUpdateAutoReply

+ (void) initialize
{
}

+ (NSString *) command
{
  return @"update-autoreply";
}

+ (NSString *) description
{
  return @"enable or disable auto reply for reached start/end dates";
}

- (void) usage
{
  fprintf (stderr, "update-autoreply -p credentialFile\n\n"
     "  -p credentialFile    Specify the file containing the sieve admin credentials\n"
     "                       The file should contain a single line:\n"
     "                         username:password\n"
     "\n"
     "The update-autoreply action should be configured as a daily cronjob.\n");
}

- (BOOL) checkConstraintsForRow: (NSDictionary *) infos
{
  NSArray  *weekdays, *startTime, *endTime;
  NSCalendarDate *now, *startDate, *endDate;
  NSDictionary *defaults, *vacationOptions;
  NSString *c_defaults;
  NSTimeZone *timeZone;
  unsigned int beginOfDaysSecs, endDateTime, startDateTime, result;

  result = statusquoAutoReply;
  c_defaults = [infos objectForKey: @"c_defaults"];
  startDate = endDate = nil;

  if ([c_defaults isNotNull])
    {
      defaults = [c_defaults objectFromJSONString];
      vacationOptions = (NSDictionary *) [defaults objectForKey: @"Vacation"];
      if ([[vacationOptions objectForKey: @"enabled"] boolValue])
        {
          timeZone = [NSTimeZone timeZoneWithName: (NSString *)[defaults objectForKey: @"SOGoTimeZone"]];
          now = [NSCalendarDate calendarDate];
          [now setTimeZone: timeZone];

          beginOfDaysSecs = [[now beginOfDay] timeIntervalSince1970];

          // We handle the start date
          if ([[vacationOptions objectForKey: @"startDateEnabled"] boolValue])
            {
              startDateTime = [[vacationOptions objectForKey: @"startDate"] intValue];
              if (beginOfDaysSecs >= startDateTime)
                result = enableAutoReply;
              else
                result = disableAutoReply;
            }
          // We handle the end date
          if ([[vacationOptions objectForKey: @"endDateEnabled"] boolValue])
            {
              endDateTime = [[vacationOptions objectForKey: @"endDate"] intValue];
              if (endDateTime < beginOfDaysSecs)
                result = disableAutoReply;
            }
          if (result != disableAutoReply)
            {
              // We handle the start time
              if ([[vacationOptions objectForKey: @"startTimeEnabled"] boolValue])
                {
                  startTime = [[vacationOptions objectForKey: @"startTime"] componentsSeparatedByString: @":"];
                  startDate = [NSCalendarDate dateWithYear: [now yearOfCommonEra]
                                                     month: [now monthOfYear]
                                                       day: [now dayOfMonth]
                                                      hour: [[startTime objectAtIndex: 0] intValue]
                                                    minute: [[startTime objectAtIndex: 1] intValue]
                                                    second: [now secondOfMinute]
                                                  timeZone: [now timeZone]];
                  if ([startDate compare: now] == NSOrderedSame ||
                      [startDate compare: now] == NSOrderedAscending)
                    result = enableAutoReply;
                }
              // We handle the end time
              // NOTE: if end time is enabled, start time must be defined
              if ([[vacationOptions objectForKey: @"endTimeEnabled"] boolValue])
                {
                  endTime = [[vacationOptions objectForKey: @"endTime"] componentsSeparatedByString: @":"];
                  endDate = [NSCalendarDate dateWithYear: [now yearOfCommonEra]
                                                   month: [now monthOfYear]
                                                     day: [now dayOfMonth]
                                                    hour: [[endTime objectAtIndex: 0] intValue]
                                                  minute: [[endTime objectAtIndex: 1] intValue]
                                                  second: [now secondOfMinute]
                                                timeZone: [now timeZone]];
                  if ([endDate compare: now] == NSOrderedSame ||
                      [endDate compare: now] == NSOrderedAscending)
                    {
                      if ([startDate compare: endDate] == NSOrderedAscending ||
                          result != enableAutoReply)
                        result = disableAutoReply;
                    }
                }
            }
          if (result != disableAutoReply)
            {
              // We handle the weekdays
              if ([[vacationOptions objectForKey: @"weekdaysEnabled"] boolValue])
                {
                  weekdays = [vacationOptions objectForKey: @"days"];
                  if ([weekdays containsObject: [NSString stringWithFormat: @"%i", [now dayOfWeek]]])
                    result = enableAutoReply;
                  else
                    result = disableAutoReply;
                }
            }
        }
    }

  return result;
}

- (BOOL) updateAutoReplyForLogin: (NSString *) theLogin
               withSieveUsername: (NSString *) theUsername
                     andPassword: (NSString *) thePassword
		       disabling: (BOOL) disabling
{
  NSMutableDictionary *vacationOptions;
  SOGoUserDefaults *userDefaults;
  SOGoUser *user;
  BOOL result;
  NSException *error;

  user = [SOGoUser userWithLogin: theLogin];

  userDefaults = [user userDefaults];
  vacationOptions = [[userDefaults vacationOptions] mutableCopy];
  [vacationOptions autorelease];

  if (disabling)
    {
      [vacationOptions setObject: [NSNumber numberWithBool: NO] forKey: @"enabled"];
    }
  else
    {
      // We do NOT enable the vacation message automatically if the domain
      // preference is disabled by default.
      if (![[user domainDefaults] vacationPeriodEnabled])
        {
          NSLog(@"SOGoVacationPeriodEnabled set to NO for the domain - ignoring.");
          return NO;
        }

      [vacationOptions setObject: [NSNumber numberWithBool: NO] forKey: @"startDateEnabled"];
    }

  [userDefaults setVacationOptions: vacationOptions];
  result = [userDefaults synchronize];

  if (result)
    {
      SOGoUserFolder *home;
      SOGoMailAccounts *folder;
      SOGoMailAccount *account;
      WOContext *localContext;
      Class SOGoMailAccounts_class;

      [[SOGoProductLoader productLoader] loadProducts: [NSArray arrayWithObject: @"Mailer.SOGo"]];
      SOGoMailAccounts_class = NSClassFromString(@"SOGoMailAccounts");

      localContext = [WOContext context];
      [localContext setActiveUser: user];

      home = [user homeFolderInContext: localContext];
      folder = [SOGoMailAccounts_class objectWithName: @"Mail" inContainer: home];
      account = [folder lookupName: @"0" inContext: localContext acquire: NO];
      [account setContext: localContext];

      error = [account updateFiltersWithUsername: theUsername
                                      andPassword: thePassword
                                  forceActivation: NO];
      if (error)
        {
          // Can't update Sieve script -- Reactivate auto-reply
	  if (disabling)
	    [vacationOptions setObject: [NSNumber numberWithBool: YES] forKey: @"enabled"];
	  else
	    [vacationOptions setObject: [NSNumber numberWithBool: YES] forKey: @"startDateEnabled"];
          [userDefaults setVacationOptions: vacationOptions];
          [userDefaults synchronize];
          result = NO;
        }
    }

  return result;
}

- (void) updateAutoReplyWithUsername: (NSString *) theUsername
                         andPassword: (NSString *) thePassword
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSArray *attrs;
  NSDictionary *infos;
  NSString *sql, *profileURL, *user;
  NSURL *tableURL;
  SOGoSystemDefaults *sd;
  unsigned int result;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  profileURL = [sd profileURL];
  if (!profileURL)
    {
      NSLog(@"Couldn't obtain the profileURL. (Hint: SOGoProfileURL)");
    }
  else
    {
      tableURL = [[NSURL alloc] initWithString: profileURL];
      cm = [GCSChannelManager defaultChannelManager];
      channel = [cm acquireOpenChannelForURL: tableURL];
      if (!channel)
        {
          NSLog(@"Couldn't acquire channel for profileURL");
        }
      else
        {
          sql = [NSString stringWithFormat: @"SELECT c_uid, c_defaults FROM %@",
                          [tableURL gcsTableName]];
          [channel evaluateExpressionX: sql];
          attrs = [channel describeResults: NO];
          while ((infos = [channel fetchAttributes: attrs withZone: NULL]))
            {
              user = [infos objectForKey: @"c_uid"];
              if (verbose)
                NSLog(@"Checking user %@\n", user);
              result = [self checkConstraintsForRow: infos];
              if (result == enableAutoReply)
                {
                  if ([self updateAutoReplyForLogin: user
                                  withSieveUsername: theUsername
                                        andPassword: thePassword
                                          disabling: NO])
                    NSLog(@"Enabled auto-reply of user %@", user);
                  else
                    NSLog(@"An error occured while enabling auto-reply of user %@", user);
                }
              else if (result == disableAutoReply)
                {
                  if ([self updateAutoReplyForLogin: user
                                  withSieveUsername: theUsername
                                        andPassword: thePassword
                                          disabling: YES])
                    NSLog(@"Removed auto-reply of user %@", user);
                  else
                    NSLog(@"An error occured while removing auto-reply of user %@", user);
                }
            }
        }
    }
}

- (BOOL) run
{
  NSRange r;
  NSString *creds, *credsFilename, *authname, *authpwd;
  SOGoCredentialsFile *cf;
  BOOL rc;
  int max;
  
  max = [sanitizedArguments count];
  creds = nil;
  authname = nil;
  authpwd = nil;
  rc = NO;

  credsFilename = [[NSUserDefaults standardUserDefaults] stringForKey: @"p"];
  if (credsFilename)
    {
      cf = [SOGoCredentialsFile credentialsFromFile: credsFilename];
      authname = [cf username];
      authpwd = [cf password];
    }

  /* DEPRECATED: this is only kept around to avoid breaking existing setups */
  if (max > 0)
    {
      /* assume we got the creds directly on the cli */
      creds = [sanitizedArguments objectAtIndex: 0];
      if (creds)
        {
          r = [creds rangeOfString: @":"];
          if (r.location == NSNotFound)
            {
              NSLog(@"Invalid credential string format (user:pass)");
            }
          else
            {
              authname = [creds substringToIndex: r.location];
              authpwd = [creds substringFromIndex: r.location+1];
            }
        }
    }


  if (authname && authpwd)
   {
     [self updateAutoReplyWithUsername: authname andPassword: authpwd];
     rc = YES;
   }

  if (!rc)
    [self usage];
  
  return rc;
}

@end
