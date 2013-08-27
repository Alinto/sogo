/* SOGoToolUserPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2013 Inverse inc.
 *
 * Author: Ludovic Marcotte  <lmarcotte@inverse.ca>
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
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSieveManager.h>

#import "SOGoTool.h"

typedef enum
{
  UserPreferencesUnknown = -1,
  UserPreferencesGet = 0,
  UserPreferencesSet = 1,
  UserPreferencesUnset = 2,
} SOGoUserPreferencesCommand;

@interface SOGoToolUserPreferences : SOGoTool
@end

@implementation SOGoToolUserPreferences

+ (void) initialize
{
}

+ (NSString *) command
{
  return @"user-preferences";
}

+ (NSString *) description
{
  return @"set user defaults / settings in the database";
}

- (void) usage
{
  fprintf (stderr, "user-preferences get|set|unset defaults|settings user [-p credentialFile] key [value|-f filename]\n\n"
      "     user              the user of whom to set the defaults/settings key/value\n"
      "     value             the JSON-formatted value of the key\n\n"
      "  -p credentialFile    Specify the file containing the sieve admin credentials\n"
      "                       The file should contain a single line:\n"
      "                         username:password\n"
      "  Examples:\n"
      "       sogo-tool user-preferences get defaults janedoe SOGoLanguage\n"
      "       sogo-tool user-preferences unset settings janedoe Mail\n"
      "       sogo-tool user-preferences set defaults janedoe SOGoTimeFormat '{\"SOGoTimeFormat\":\"%%I:%%M %%p\"}'\n");
}

//
// possible values are: get | set | unset
//
- (SOGoUserPreferencesCommand) _cmdFromString: (NSString *) theString
{
  if ([theString length] > 2)
    {
      if ([theString caseInsensitiveCompare: @"get"] == NSOrderedSame)
        return UserPreferencesGet;
      else if  ([theString caseInsensitiveCompare: @"set"] == NSOrderedSame)
        return UserPreferencesSet;
      else if ([theString caseInsensitiveCompare: @"unset"] == NSOrderedSame)
        return UserPreferencesUnset;
    }

  return UserPreferencesUnknown;
}

// If we got any of those keys for "defaults", we regenerate the Sieve script
//
// Forward
// SOGoSieveFilters
// Vacation
//
- (BOOL) _updateSieveScripsForkey: (NSString *) theKey
                          manager: (SOGoSieveManager *) theManager
                            login: (NSString *) theLogin
{
  if ([theKey caseInsensitiveCompare: @"Forward"] == NSOrderedSame ||
      [theKey caseInsensitiveCompare: @"SOGoSieveFilters"] == NSOrderedSame ||
      [theKey caseInsensitiveCompare: @"Vacation"] == NSOrderedSame)
    {
      /* credentials file handling */
      NSData *credsData;
      NSRange r;
      NSString *credsFile, *creds, *authname, *authpwd;
      authname = nil;
      authpwd = nil;


      credsFile = [[NSUserDefaults standardUserDefaults] stringForKey: @"p"];
      if (credsFile)
        {
          /* TODO: add back support for user:pwd here? */
          credsData = [NSData dataWithContentsOfFile: credsFile];
          if (credsData == nil)
            {
              NSLog(@"Error reading credential file '%@'", credsFile);
              return NO;
            }

          creds = [[NSString alloc] initWithData: credsData
                                        encoding: NSUTF8StringEncoding];
          [creds autorelease];
          creds = [creds stringByTrimmingCharactersInSet: 
                    [NSCharacterSet characterSetWithCharactersInString: @"\r\n"]];

          r = [creds rangeOfString: @":"];
          authname = [creds substringToIndex: r.location];
          authpwd = [creds substringFromIndex: r.location+1];
        }
      if (authname == nil || authpwd == nil)
        {
          NSLog(@"To update Sieve scripts, you must provide the \"-p credentialFile\" parameter");
          return NO;
        }
      
      return [theManager updateFiltersForLogin: theLogin
                                      authname: authname
                                      password: authpwd
                                       account: nil];
    }
  
  return YES;
}



- (BOOL) run
{
  NSString *userId, *type, *key, *value;
  NSString *jsonValueFile;
  SOGoUserPreferencesCommand cmd;
  id o;
  
  BOOL rc;
  int max;
  
  max = [sanitizedArguments count];
  rc = NO;

  if (max > 3)
    {
      SOGoDefaultsSource *source;
      SOGoSieveManager *manager;
      SOGoUser *user;

      cmd = [self _cmdFromString: [sanitizedArguments objectAtIndex: 0]];

      type = [sanitizedArguments objectAtIndex: 1];
      userId = [sanitizedArguments objectAtIndex: 2];
      key = [sanitizedArguments objectAtIndex: 3];

      user = [SOGoUser userWithLogin: userId];
      manager = [SOGoSieveManager sieveManagerForUser: user];

      if ([type caseInsensitiveCompare: @"defaults"] == NSOrderedSame)
        source = [user userDefaults];
      else
        source = [user userSettings];

      switch (cmd)
        {
          case UserPreferencesGet:
                 o = [source objectForKey: key];

                 if (o)
                   {
                     printf("%s: %s\n", [key UTF8String], [[o jsonRepresentation] UTF8String]);
                     rc = YES;
                   }
                 else
                   {
                     NSLog(@"Value for key \"%@\" not found in %@", key, type);
                     return rc;
                   }
                 break;

          case UserPreferencesSet:
                 if (max > 4)
                   {
                     /* value specified on command line */
                     value = [sanitizedArguments objectAtIndex: 4];
                   }
                 else
                   {
                     /* value is to be found in file specified with -f filename */
                     jsonValueFile = [[NSUserDefaults standardUserDefaults]
                                                       stringForKey: @"f"];

                     if (jsonValueFile == nil)
                       {
                         NSLog(@"No value specified, aborting");
                         [self usage];
                         return rc;
                       }
                     else
                       {

                         NSData *data = [NSData dataWithContentsOfFile: jsonValueFile];
                         if (data == nil)
                           {
                             NSLog(@"Error reading file '%@'", jsonValueFile);
                             [self usage];
                             return rc;
                           }
                         value = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
                         [value autorelease];
                       }
                   }
                 o = [value objectFromJSONString];

                 //
                 // We support setting only "values" - for example, setting :
                 //
                 // SOGoDayStartTime to 9:00
                 //
                 // Values in JSON must be a dictionary so we must support passing:
                 // 
                 // key == SOGoDayStartTime
                 // value == '{"SOGoDayStartTime":  "09:00"}'
                 //
                 // to achieve what we want.
                 //
                 if (o && [o count] == 1)
                  {
                    [source setObject: [[o allValues] lastObject] forKey: key];
                  }
                 //
                 // We also support passing values that are already dictionaries so in this
                 // case, we simply set it to the passed key.
                 //
                 else if (o)
                   {
                     [source setObject: o  forKey: key];
                   }
                 else
                   {
                     NSLog(@"Invalid JSON input - no changes performed in the database. The supplied value was: %@", value);
                     [self usage];
                     return rc;
                   }

                 rc = [self _updateSieveScripsForkey: key
                                             manager: manager
                                               login: userId];
                 if (rc)
                   [source synchronize];
                 else
                   NSLog(@"Error updating sieve script, not updating database");

                 break;

          case UserPreferencesUnset:
                 [source removeObjectForKey: key];
                 rc = [self _updateSieveScripsForkey: key
                                             manager: manager
                                               login: userId];
                 if (rc)
                   [source synchronize];
                 else
                   NSLog(@"Error updating sieve script, not updating database");

                 break;
          case UserPreferencesUnknown:
                 break;
        }
    }

  if (!rc)
    {
      [self usage];
    }

  return rc;
}

@end
