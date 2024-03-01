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

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/NSString+Crypto.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoDefaultsSource.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailAccount.h>

#import "SOGoTool.h"

@interface SOGoToolUpdateSecret : SOGoTool
{
  NSArray *usersWithAuxiliaryAccounts;
}

@end

@implementation SOGoToolUpdateSecret

+ (NSString *) command
{
  return @"update-secret";
}

+ (NSString *) description
{
  return @"Update all database data that needs to be encrypted with a new secret value";
}

- (id) init
{
  if ((self = [super init]))
    {
      usersWithAuxiliaryAccounts = nil;
    }

  return self;
}

- (void) dealloc
{
  [usersWithAuxiliaryAccounts release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "update-secret -n new_secret -o old_secret\n\n"
      "     -n new_secret        the new secret value to encrypt with, if given alone it will assume the data are not currently encrypted\n"
      "     -o old_secret        the current value of the secret if any, if given alone, it will decrypts all current data\n"
      "                          The secret must be a 32 chars long utf-8 strings (128 bits)\n\n"
      "  Example set a secret for the first time:\n"
      "       sogo-tool update-secret -n exemple_NewSuperSecretOfLenght32\n"
      "  Examples change for a new value of secret:\n"
      "       sogo-tool update-secret -n exemple_NewSuperSecretOfLenght32:32 -o exemple_OldSuperSecretOfLenght32\n"
      "  Examples unset the secret and come back to unencrypted data:\n"
      "       sogo-tool update-secret -o exemple_OldSuperSecretOfLenght32\n");
}


- (BOOL) fetchAllUsersForAuxiliaryAccountPassword
{
  NSAutoreleasePool *pool;
  SOGoUserManager *lm;
  NSDictionary *infos;
  NSString *user;
  SOGoSystemDefaults* sd;
  id allUsers;
  int count, max;

  lm = [SOGoUserManager sharedUserManager];

  GCSFolderManager *fm;
  GCSChannelManager *cm;
  NSURL *userProfileUrl;
  EOAdaptorChannel *fc;
  NSArray *users, *attrs;
  NSMutableArray *allSqlUsers;
  NSString *sql, *profileURL;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  profileURL = [sd profileURL];
  if (profileURL)
    userProfileUrl = [[NSURL alloc] initWithString: profileURL];
  else
  {
    NSLog(@"Can't find the value for SOGoProfileURL!");
    return NO;
  }
   
  fm = [GCSFolderManager defaultFolderManager];
  cm = [fm channelManager];
  fc = [cm acquireOpenChannelForURL: userProfileUrl];
  if (fc)
  {
    allSqlUsers = [NSMutableArray new];
    sql = [NSString stringWithFormat: @"SELECT c_uid FROM %@ WHERE c_defaults LIKE '%%AuxiliaryMailAccounts\":[{%%'",
                    [userProfileUrl gcsTableName]];
    [fc evaluateExpressionX: sql];
    attrs = [fc describeResults: NO];
    while ((infos = [fc fetchAttributes: attrs withZone: NULL]))
    {
      user = [infos objectForKey: @"c_uid"];
      if (user)
        [allSqlUsers addObject: user];
    }
    [cm releaseChannel: fc  immediately: YES];

    users = allSqlUsers;
    max = [users count];
    [allSqlUsers autorelease];
  }
  else
  {
    NSLog(@"Can't create channel to %@", userProfileUrl);
    return NO;
  }

  ASSIGN (usersWithAuxiliaryAccounts, users);

  return ([usersWithAuxiliaryAccounts count] > 0);
} 

- (BOOL) updateSecretFromPlainData: (NSString*) secret
{
  BOOL rc;
  rc = [self fetchAllUsersForAuxiliaryAccountPassword];
  if(rc){
    int i;
    for(i=0; i < [usersWithAuxiliaryAccounts count]; i++){

      SOGoUser* user;
      SOGoDefaultsSource *source;
      int count;
      NSDictionary* account;
      NSArray *aux;
      NSString *password;

      user = [SOGoUser userWithLogin: [usersWithAuxiliaryAccounts objectAtIndex: i]];
      source = [user userDefaults];
      aux = [source objectForKey: @"AuxiliaryMailAccounts"];
      if(!aux)
        continue;

      for (count = 0; count < [aux count]; count++)
      {
        account = [aux objectAtIndex: count];
        if(![[account objectForKey: @"password"] isKindOfClass: [NSString class]])
        {
          NSLog(@"Can't encrypt the password for auxiliary account %@, password is not a string, probabbly already encrypted",
                        [account objectForKey: @"name"]);
          continue;
        }
        password = [account objectForKey: @"password"];
        if([password length] > 0)
        {
          NSDictionary* newPassword;
          NSException* exception = nil;
          newPassword = [password encryptAES256GCM: secret exception:&exception];
          if(exception)
            NSLog(@"Can't encrypt the password: %@", [exception reason]);
          else
            [account setObject: newPassword forKey: @"password"];
        }
        else
          NSLog(@"Password not found! For user: %@ and account %@", user, account);
      }
      [source setObject: aux forKey: @"AuxiliaryMailAccounts"];
      [source synchronize];
    }
  }

  return rc;
}

- (BOOL) updateSecretFromEncryptedData: (NSString*) newSecret oldSecret: (NSString*) oldSecret
{
  BOOL rc;
  rc = [self fetchAllUsersForAuxiliaryAccountPassword];
  if(rc){
    int i;
    for(i=0; i < [usersWithAuxiliaryAccounts count]; i++){

      SOGoUser* user;
      SOGoDefaultsSource *source;
      int count;
      NSDictionary* account, *accountPassword;
      NSArray *aux;
      NSString *password, *iv, *tag;

      user = [SOGoUser userWithLogin: [usersWithAuxiliaryAccounts objectAtIndex: i]];
      source = [user userDefaults];
      aux = [source objectForKey: @"AuxiliaryMailAccounts"];
      if(!aux)
        continue;

      for (count = 0; count < [aux count]; count++)
      {
        account = [aux objectAtIndex: count];
        if(![[account objectForKey: @"password"] isKindOfClass: [NSDictionary class]])
        {
          NSLog(@"Can't decrypt the password for auxiliary account %@, is not a dictionnary",
                        [account objectForKey: @"name"]);
          continue;
        }
        accountPassword = [account objectForKey: @"password"];
        password = [accountPassword objectForKey: @"cypher"];
        iv = [accountPassword objectForKey: @"iv"];
        tag = [accountPassword objectForKey: @"tag"];
        if([password length] > 0)
        {
          NSString* decryptedPassword;
          NSDictionary* encryptedPassword;
          NSException* exception = nil;
          NS_DURING
            decryptedPassword = [password decryptAES256GCM: oldSecret iv: iv tag: tag exception:&exception];
            encryptedPassword = [decryptedPassword encryptAES256GCM: newSecret exception:&exception];
          NS_HANDLER
            encryptedPassword = accountPassword;
            NSLog(@"Can't decrypt the password, unexpected exception");
          NS_ENDHANDLER

          if(exception)
            NSLog(@"Can't decrypt the password: %@", [exception reason]);
          else
            [account setObject: encryptedPassword forKey: @"password"];
        }
        else
          NSLog(@"Password not found! For user: %@ and account %@", user, account);
      }
      [source setObject: aux forKey: @"AuxiliaryMailAccounts"];
      [source synchronize];
    }
  }

  return rc;
}

- (BOOL) updateToPlainData: (NSString*) oldSecret
{
  BOOL rc;
  rc = [self fetchAllUsersForAuxiliaryAccountPassword];
  if(rc){
    int i;
    for(i=0; i < [usersWithAuxiliaryAccounts count]; i++){

      SOGoUser* user;
      SOGoDefaultsSource *source;
      int count;
      NSDictionary* account, *accountPassword;
      NSArray *aux;
      NSString *password, *iv, *tag;

      user = [SOGoUser userWithLogin: [usersWithAuxiliaryAccounts objectAtIndex: i]];
      source = [user userDefaults];
      aux = [source objectForKey: @"AuxiliaryMailAccounts"];
      if(!aux)
        continue;

      for (count = 0; count < [aux count]; count++)
      {
        account = [aux objectAtIndex: count];
        if(![[account objectForKey: @"password"] isKindOfClass: [NSDictionary class]])
        {
          NSLog(@"Can't decrypt the password for auxiliary account %@, is not a dictionnary",
                        [account objectForKey: @"name"]);
          continue;
        }
        accountPassword = [account objectForKey: @"password"];
        password = [accountPassword objectForKey: @"cypher"];
        iv = [accountPassword objectForKey: @"iv"];
        tag = [accountPassword objectForKey: @"tag"];
        if([password length] > 0)
        {
          NSString* newPassword;
          NSException* exception = nil;
          NS_DURING
            newPassword = [password decryptAES256GCM: oldSecret iv: iv tag: tag exception:&exception];
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
      [source setObject: aux forKey: @"AuxiliaryMailAccounts"];
      [source synchronize];
    }
  }
  return rc;
}


- (BOOL) checkArguments: (NSArray*)args
{
  int size, i;
  NSString *type1, *type2;
  size = [args count];
  if (size != 2 && size != 4)
  {
    NSLog(@"Wrong number of arguments, should be 2 or 4 and was %d", size);
    return NO;
  }
  for(i=0; i<size; i++)
  {
    if(![[args objectAtIndex:i] isKindOfClass: [NSString class]])
    {
      NSLog(@"One of the argument is not a string");
      return NO;
    }
  }

  type1 = [args objectAtIndex:0];
  if (![type1 isEqualToString: @"-n"] && ![type1 isEqualToString: @"-o"])
  {
    NSLog(@"First argument is not '-n' nor '-o' but %@", type1);
    return NO;
  }
  
  if ([[args objectAtIndex:1] length] != 32)
  {
    NSLog(@"Second argument is supposed to be a 32 chars long secret but is %@", [args objectAtIndex:1]);
    return NO;
  }

  if(size == 4)
  {
    type2 = [args objectAtIndex:2];
    if (![type2 isEqualToString: @"-n"] && ![type2 isEqualToString: @"-o"])
    {
      NSLog(@"Third argument is not '-n' nor '-o' but %@", type2);
      return NO;
    }
    if ([type2 isEqualToString: type1])
    {
      NSLog(@"Third argument (%@) cannot be the same as the first %@", type2, type1);
      return NO;
    }
    if ([[args objectAtIndex:3] length] != 32)
    {
      NSLog(@"Fourth argument is supposed to be a 32 chars long secret but is %@", [args objectAtIndex:3]);
      return NO;
    }
  }
  
  return YES;
}

- (BOOL) run
{

  int max, i;
  BOOL rc;
  
  max = [arguments count];
  rc = [self checkArguments: arguments];

  if (!rc)
  {
    [self usage];
  }
  else
  {
    if(max == 2)
    {
      if([[arguments objectAtIndex:0] isEqualToString: @"-n"])
        [self updateSecretFromPlainData: [arguments objectAtIndex:1]];
      else
        [self updateToPlainData: [arguments objectAtIndex:1]];
    }
    else
    {
      if([[arguments objectAtIndex:0] isEqualToString: @"-n"])
        [self updateSecretFromEncryptedData: [arguments objectAtIndex:1] oldSecret: [arguments objectAtIndex:3]];
      else
        [self updateSecretFromEncryptedData: [arguments objectAtIndex:3] oldSecret: [arguments objectAtIndex:1]];
    }
  }

  return rc;
}

@end
