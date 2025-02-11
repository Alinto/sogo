/* SOGoToolUserPreferences.m - this file is part of SOGo
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

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/NSString+Crypto.h>
#import <SOGo/SOGoProductLoader.h>
#import "SOGo/SOGoCredentialsFile.h"
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailAccount.h>

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
      "  -F                   force the activation of the sieve script in case external scripts. Must be the las targument after -p credentialsFile"
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
                            login: (NSString *) theLogin
{
  if ([theKey caseInsensitiveCompare: @"Forward"] == NSOrderedSame ||
      [theKey caseInsensitiveCompare: @"SOGoSieveFilters"] == NSOrderedSame ||
      [theKey caseInsensitiveCompare: @"Vacation"] == NSOrderedSame)
    {
      /* credentials file handling */
      NSString *credsFilename=nil, *authname=nil, *authpwd=nil;
      SOGoCredentialsFile *cf;

      credsFilename = [[NSUserDefaults standardUserDefaults] stringForKey: @"p"];
      if (credsFilename)
        {
          cf = [SOGoCredentialsFile credentialsFromFile: credsFilename];
          authname = [cf username];
          authpwd = [cf password];
        }

      if (authname == nil || authpwd == nil)
        {
          NSLog(@"To update Sieve scripts, you must provide the \"-p credentialFile\" parameter");
          return NO;
        }

      /* update sieve script */
      NSException *error;
      SOGoUser *user;
      SOGoUserFolder *home;
      SOGoMailAccounts *folder;
      SOGoMailAccount *account;
      WOContext *localContext;
      Class SOGoMailAccounts_class;

      [[SOGoProductLoader productLoader] loadProducts: [NSArray arrayWithObject: @"Mailer.SOGo"]];
      SOGoMailAccounts_class = NSClassFromString(@"SOGoMailAccounts");

      user = [SOGoUser userWithLogin: theLogin];
      localContext = [WOContext context];
      [localContext setActiveUser: user];

      home = [user homeFolderInContext: localContext];
      folder = [SOGoMailAccounts_class objectWithName: @"Mail" inContainer: home];
      account = [folder lookupName: @"0" inContext: localContext acquire: NO];
      [account setContext: localContext];

      if([[arguments lastObject] isEqualToString: @"-F"])
      {
        error = [account updateFiltersWithUsername: authname
                                      andPassword: authpwd
                                  forceActivation: YES];
      }
      else
      {
        error = [account updateFiltersWithUsername: authname
                                      andPassword: authpwd
                                  forceActivation: NO];
      }

      if (error)
        return NO;
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
      SOGoUser *user;

      cmd = [self _cmdFromString: [sanitizedArguments objectAtIndex: 0]];

      type = [sanitizedArguments objectAtIndex: 1];
      userId = [sanitizedArguments objectAtIndex: 2];
      key = [sanitizedArguments objectAtIndex: 3];

      user = [SOGoUser userWithLogin: userId];

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
              if([key isEqualToString: @"AuxiliaryMailAccounts"])
              {
                //May need to decrypt password for auxiliary accounts
                NSString* sogoSecret;
                sogoSecret = [[SOGoSystemDefaults sharedSystemDefaults] sogoSecretValue];
                if(sogoSecret)
                {
                  NSDictionary* account, *accountPassword;
                  NSString *password, *iv, *tag;
                  int i;
                  for(i=0; i < [o count]; i++)
                  {
                    account = [o objectAtIndex: i];
                    if(![account objectForKey: @"password"])
                      continue;
                    if([[account objectForKey: @"password"] isKindOfClass: [NSString class]])
                      NSLog(@"WARNING: your sogo.conf has a secret SOGoSecretValue but the password for account %@ is not encrypted", userId);
                    else
                    {
                      accountPassword = [account objectForKey: @"password"];
                      password = [accountPassword objectForKey: @"cypher"];
                      iv = [accountPassword objectForKey: @"iv"];
                      tag = [accountPassword objectForKey: @"tag"];
                      if([password length] > 0)
                      {
                        NSString* newPassword;
                        NSException* exception = nil;
                        NS_DURING
                          newPassword = [password decryptAES256GCM: sogoSecret iv: iv tag: tag exception:&exception];
                          if(exception)
                            NSLog(@"Can't decrypt the password: %@", [exception reason]);
                          else
                            [account setObject: newPassword forKey: @"password"];
                        NS_HANDLER
                          NSLog(@"Can't decrypt the password, unexpected exception");
                        NS_ENDHANDLER
                      }
                      else
                        NSLog(@"Password not found! For user: %@ and account %@", user, account);        
                    }
                  }
                }                
              }
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
            if (![arguments containsObject: @"-f"])
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
            if (o && [o isKindOfClass: [NSDictionary class]] && [o count] == 1)
            {
              o = [[o allValues] lastObject];
            }

            //
            // We also support passing values that are already dictionaries so in this
            // case, we simply set it to the passed key.
            //
            if (o)
            {
              if([key isEqualToString: @"AuxiliaryMailAccounts"])
              {
                //May need to encrypt password for auxiliary accounts
                NSString* sogoSecret;
                sogoSecret = [[SOGoSystemDefaults sharedSystemDefaults] sogoSecretValue];
                if(sogoSecret)
                {
                  int i;
                  NSDictionary *account, *newPassword;
                  NSString *password;
                  if(![o isKindOfClass: [NSArray class]])
                  {
                      NSLog(@"The value for AuxiliaryMailAccounts is supposed to be an Array (even for 1 account) but is %@",
                                    [o class]);
                      return rc;
                  }
                  for (i = 0; i < [o count]; i++)
                  {
                    account = [o objectAtIndex: i];
                    if(![[account objectForKey: @"password"] isKindOfClass: [NSString class]])
                    {
                      NSLog(@"Can't encrypt the password for auxiliary account %@, password is not a string",
                                    [account objectForKey: @"name"]);
                      continue;
                    }
                    password = [account objectForKey: @"password"];
                    if([password length] > 0)
                    {
                      NSString* newPassword;
                      NSException* exception = nil;
                      newPassword = [password encryptAES256GCM: sogoSecret exception:&exception];
                      if(exception)
                        NSLog(@"Can't encrypt the password: %@", [exception reason]);
                      else
                        [account setObject: newPassword forKey: @"password"];
                    }
                    else
                      NSLog(@"Password not given for account %@", account);
                  }
                }
              }
              [source setObject: o forKey: key];
            }
            else
              {
                NSLog(@"Invalid JSON input - no changes performed in the database. The supplied value was: %@", value);
                [self usage];
                return rc;
              }

            rc = [self _updateSieveScripsForkey: key
                                          login: userId];
            if (rc)
              [source synchronize];
            else
              NSLog(@"Error updating sieve script, not updating database");

            break;

          case UserPreferencesUnset:
                 [source removeObjectForKey: key];
                 rc = [self _updateSieveScripsForkey: key
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
