/* SOGoToolInitUser.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Alinto
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
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOComponent.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoParentFolder.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserFolder.h>

#import "SOGoToolRestore.h"


@interface NSObject (UIxJSONPreferences)

- (NSString *) jsonDefaults;

@end

@interface SOGoToolInitUser : SOGoToolRestore
{
  NSArray *usersToInit;
  NSString *language;
}

@end

@implementation SOGoToolInitUser

+ (NSString *) command
{
  return @"init-user";
}

+ (NSString *) description
{
  return @"create the personal folders and preferences of user(s) without requiring a login";
}

- (id) init
{
  if ((self = [super init]))
    {
      usersToInit = nil;
      language = nil;
    }

  return self;
}

- (void) dealloc
{
  [usersToInit release];
  [language release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "init-user [-l language] user1 [user2] ...\n\n"
           "           user       the user whose personal folders must be created\n"
           "           language   the language of the user's preferences, as chosen\n"
           "                      at login (defaults to the domain or system one)\n\n"
           "Creates the personal calendar and the personal address book of the\n"
           "user(s) and initializes their preferences, as it would otherwise only\n"
           "happen upon their first login.\n\n"
           "Example:   sogo-tool init-user jdoe\n"
           "           sogo-tool init-user -l French jdoe jsmith\n");
}

- (BOOL) parseArguments
{
  NSArray *supportedLanguages;
  NSString *requestedLanguage;

  if ([sanitizedArguments count] < 1)
    {
      [self usage];
      return NO;
    }

  requestedLanguage = [[NSUserDefaults standardUserDefaults] stringForKey: @"l"];
  if ([requestedLanguage length])
    {
      supportedLanguages = [[SOGoSystemDefaults sharedSystemDefaults]
                             supportedLanguages];
      if (![supportedLanguages containsObject: requestedLanguage])
        {
          fprintf (stderr, "Unsupported language: %s\n",
                   [requestedLanguage UTF8String]);
          return NO;
        }
      ASSIGN (language, requestedLanguage);
    }

  ASSIGN (usersToInit, sanitizedArguments);

  return YES;
}

/* The lookup of the "personal" folder triggers its creation when it does not
   exist yet, provided the active user is the owner of the folder. */
- (BOOL) _initFolderOfType: (NSString *) folderType
            withUserFolder: (SOGoUserFolder *) userFolder
                 inContext: (WOContext *) localContext
{
  SOGoParentFolder *parentFolder;
  id folder;

  parentFolder = [userFolder lookupName: folderType
                              inContext: localContext
                                acquire: NO];
  if (![parentFolder isKindOfClass: [SOGoParentFolder class]])
    {
      NSLog (@"module '%@' is not available for user '%@'", folderType, userID);
      return NO;
    }
  [parentFolder setContext: localContext];

  folder = [parentFolder lookupPersonalFolder: @"personal"
                               ignoringRights: YES];
  if (![folder isKindOfClass: [SOGoGCSFolder class]])
    {
      NSLog (@"personal folder of module '%@' could not be created for user"
             @" '%@'", folderType, userID);
      return NO;
    }

  if (verbose)
    NSLog (@"personal folder of module '%@' is ready for user '%@'",
           folderType, userID);

  return YES;
}

/* Upon the first login, the c_defaults of the user are materialized when the
   web interface loads: -[UIxJSONPreferences jsonDefaults] resolves every
   default through the domain and system defaults, writes them into the user's
   profile and synchronizes it. We invoke that very method so that an
   initialized user is indistinguishable from a user who has logged in. */
- (BOOL) _initDefaultsOfUser: (SOGoUser *) user
                   inContext: (WOContext *) localContext
{
  WOComponent *jsonPreferences;
  Class jsonPreferencesKlass;

  /* The language must be set before the component is built: -jsonDefaults only
     materializes the defaults that are missing, and the labels it localizes
     (the calendar and contacts categories) are looked up in the languages of
     the context, which are those of the user. */
  if (language)
    [[user userDefaults] setLanguage: language];
  
  if (![WOApplication application])
    [[WOApplication alloc] init];

  jsonPreferencesKlass = NSClassFromString (@"UIxJSONPreferences");
  if (!jsonPreferencesKlass)
    {
      NSLog (@"class 'UIxJSONPreferences' is unavailable, defaults of user"
             @" '%@' cannot be initialized", userID);
      return NO;
    }

  jsonPreferences = [[[jsonPreferencesKlass alloc]
                       initWithContext: localContext] autorelease];

  if (![jsonPreferences jsonDefaults])
    {
      NSLog (@"defaults of user '%@' could not be initialized", userID);
      return NO;
    }

  if (verbose)
    NSLog (@"defaults of user '%@' are ready", userID);

  return YES;
}

- (BOOL) _initUser
{
  SOGoUserFolder *userFolder;
  WOContext *localContext;
  SOGoUser *user;
  BOOL rc;

  user = [SOGoUser userWithLogin: userID];
  if (!user)
    {
      NSLog (@"user '%@' could not be instantiated", userID);
      return NO;
    }

  localContext = [WOContext context];
  [localContext setActiveUser: user];

  rc = [self _initDefaultsOfUser: user inContext: localContext];

  userFolder = [SOGoUserFolder objectWithName: userID inContainer: nil];
  [userFolder setContext: localContext];

  rc = [self _initFolderOfType: @"Calendar"
                withUserFolder: userFolder
                     inContext: localContext] && rc;
  rc = [self _initFolderOfType: @"Contacts"
                withUserFolder: userFolder
                     inContext: localContext] && rc;

  return rc;
}

- (BOOL) proceed
{
  NSAutoreleasePool *pool;
  NSString *identifier;
  NSUInteger count, max;
  BOOL rc;

  rc = YES;
  max = [usersToInit count];
  for (count = 0; count < max; count++)
    {
      pool = [NSAutoreleasePool new];
      identifier = [usersToInit objectAtIndex: count];
      if ([self fetchUserID: identifier])
        {
          if (![self _initUser])
            rc = NO;
        }
      else
        {
          fprintf (stderr, "Invalid user: %s\n", [identifier UTF8String]);
          rc = NO;
        }
      [pool release];
    }

  return rc;
}

- (BOOL) run
{
  return ([self parseArguments] && [self proceed]);
}

@end
