/* SOGoToolUserPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2013 Inverse inc.
 *
 * Author: Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>

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

@interface SOGoToolExpireAutoReply : SOGoTool
@end

@implementation SOGoToolExpireAutoReply

+ (void) initialize
{
}

+ (NSString *) command
{
  return @"expire-autoreply";
}

+ (NSString *) description
{
  return @"disable auto reply for reached end dates";
}

- (void) usage
{
  fprintf (stderr, "expire-autoreply -p credentialFile\n\n"
     "  -p credentialFile    Specify the file containing the sieve admin credentials\n"
     "                       The file should contain a single line:\n"
     "                         username:password\n"
     "\n"
     "The expire-autoreply action should be configured as a daily cronjob.\n");
}

- (BOOL) removeAutoReplyForLogin: (NSString *) theLogin
               withSieveUsername: (NSString *) theUsername
                     andPassword: (NSString *) thePassword
{
  NSMutableDictionary *vacationOptions;
  SOGoUserDefaults *userDefaults;
  SOGoUser *user;
  BOOL result;

  user = [SOGoUser userWithLogin: theLogin];
  userDefaults = [user userDefaults];
  vacationOptions = [[userDefaults vacationOptions] mutableCopy];
  [vacationOptions autorelease];

  [vacationOptions setObject: [NSNumber numberWithBool: NO] forKey: @"enabled"];
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

      result = [account updateFiltersWithUsername: theUsername  andPassword: thePassword];
      if (!result)
        {
          // Can't update Sieve script -- Reactivate auto-reply
          [vacationOptions setObject: [NSNumber numberWithBool: YES] forKey: @"enabled"];
          [userDefaults setVacationOptions: vacationOptions];
          [userDefaults synchronize];
        }
    }

  return result;
}

- (void) expireAutoReplyWithUsername: (NSString *) theUsername
                         andPassword: (NSString *) thePassword
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSArray *attrs;
  NSDictionary *infos, *defaults, *vacationOptions;
  NSString *sql, *profileURL, *user, *c_defaults;
  NSURL *tableURL;
  SOGoSystemDefaults *sd;
  BOOL enabled;
  unsigned int endTime, now;

  now = [[NSCalendarDate calendarDate] timeIntervalSince1970];
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
              c_defaults = [infos objectForKey: @"c_defaults"];
              if ([c_defaults isNotNull])
                {
                  defaults = [c_defaults objectFromJSONString];
                  vacationOptions = (NSDictionary *) [defaults objectForKey: @"Vacation"];
                  enabled = [[vacationOptions objectForKey: @"enabled"] boolValue];
                  if (enabled)
                    {
                      enabled = [[vacationOptions objectForKey: @"endDateEnabled"] boolValue];
                      if (enabled)
                        {
                          endTime = [[vacationOptions objectForKey: @"endDate"] intValue];
                          if (endTime <= now)
                            {
                              if ([self removeAutoReplyForLogin: user
                                               withSieveUsername: theUsername
                                                     andPassword: thePassword])
                                NSLog(@"Removed auto-reply of user %@", user);
                              else
                                NSLog(@"An error occured while removing auto-reply of user %@", user);
                            }
                        }
                    }
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
     [self expireAutoReplyWithUsername: authname andPassword: authpwd];
     rc = YES;
   }

  if (!rc)
    [self usage];
  
  return rc;
}

@end
