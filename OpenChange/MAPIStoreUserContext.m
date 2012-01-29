/* MAPIStoreUserContext.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2012 Inverse inc
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

#import <Foundation/NSMapTable.h>
#import <Foundation/NSThread.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGImap4/NGImap4Connection.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMapping.h"

#import "MAPIStoreUserContext.h"

static NSMapTable *contextsTable = nil;

@implementation MAPIStoreUserContext

+ (void) initialize
{
  contextsTable = [NSMapTable mapTableWithStrongToWeakObjects];
  [contextsTable retain];
}

+ (id) userContextWithUsername: (NSString *) username
                andTDBIndexing: (struct tdb_wrap *) indexingTdb;
{
  id userContext;

  userContext = [contextsTable objectForKey: username];
  if (!userContext)
    {
      userContext = [[self alloc] initWithUsername: username
                                    andTDBIndexing: indexingTdb];
      [userContext autorelease];
    }

  return userContext;
}

- (id) init
{
  if ((self = [super init]))
    {
      username = nil;
      sogoUser = nil;

      userFolder = nil;
      calendarRoot = nil;
      contactsRoot = nil;
      mailRoot = nil;

      containersBag = [NSMutableArray new];

      mapping = nil;

      authenticator = nil;
      woContext = [WOContext contextWithRequest: nil];
      [woContext retain];
    }

  return self;
}

- (id) initWithUsername: (NSString *) newUsername
         andTDBIndexing: (struct tdb_wrap *) indexingTdb
{
  if ((self = [self init]))
    {
      /* "username" will be retained by table */
      username = newUsername;
      if (indexingTdb)
        ASSIGN (mapping, [MAPIStoreMapping mappingForUsername: username
                                                 withIndexing: indexingTdb]);
      [contextsTable setObject: self forKey: username];

      authenticator = [MAPIStoreAuthenticator new];
      [authenticator setUsername: username];

      /* TODO: very hackish (IMAP access) */
      [authenticator setPassword: username];
    }

  return self;
}

- (void) dealloc
{
  [contextsTable removeObjectForKey: username];

  [userFolder release];
  [calendarRoot release];
  [contactsRoot release];
  [mailRoot release];
  [containersBag release];

  [authenticator release];
  [mapping release];

  [username release];
  [sogoUser release];

  [super dealloc];
}

- (NSString *) username
{
  return username;
}

- (SOGoUser *) sogoUser
{
  if (!sogoUser)
    ASSIGN (sogoUser, [SOGoUser userWithLogin: username]);

  return sogoUser;
}

- (SOGoUserFolder *) userFolder
{
  if (!userFolder)
    {
       userFolder = [SOGoUserFolder objectWithName: username
                                       inContainer: MAPIApp];
       [userFolder retain];
    }

  return userFolder;
}

- (SOGoAppointmentFolders *) calendarRoot
{
  if (!calendarRoot)
    {
      [self userFolder];
      [woContext setClientObject: userFolder];

      calendarRoot = [userFolder lookupName: @"Calendar"
                                  inContext: woContext
                                    acquire: NO];
      [calendarRoot retain];
    }

  return calendarRoot;
}

- (SOGoContactFolders *) contactsRoot
{
  if (!contactsRoot)
    {
      [self userFolder];
      [woContext setClientObject: userFolder];

      contactsRoot = [userFolder lookupName: @"Contacts"
                                  inContext: woContext
                                    acquire: NO];
      [contactsRoot retain];
    }

  return contactsRoot;
}

- (SOGoMailAccount *) mailRoot
{
  SOGoMailAccounts *accountsFolder;

  if (!mailRoot)
    {
      [self userFolder];
      [woContext setClientObject: userFolder];

      accountsFolder = [userFolder lookupName: @"Mail"
                                    inContext: woContext
                                      acquire: NO];
      [containersBag addObject: accountsFolder];
      [woContext setClientObject: accountsFolder];

      mailRoot = [accountsFolder lookupName: @"0"
                                  inContext: woContext
                                    acquire: NO];
      [[mailRoot imap4Connection]
         enableExtension: @"QRESYNC"];
      [mailRoot retain];
    }

  return mailRoot;
}

- (MAPIStoreMapping *) mapping
{
  return mapping;
}

- (WOContext *) woContext
{
  return woContext;
}

- (MAPIStoreAuthenticator *) authenticator
{
  return authenticator;
}

- (void) activateWithUser: (SOGoUser *) activeUser;
{
  NSMutableDictionary *info;

  [MAPIApp setUserContext: self];
  [woContext setActiveUser: activeUser];
  info = [[NSThread currentThread] threadDictionary];
  [info setObject: woContext forKey: @"WOContext"];
}

@end
