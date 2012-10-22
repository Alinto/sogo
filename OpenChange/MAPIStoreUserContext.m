/* MAPIStoreUserContext.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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
#import <Foundation/NSMapTable.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGImap4/NGImap4Connection.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/NSString+Utilities.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>

#import "GCSSpecialQueries+OpenChange.h"
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
      [contextsTable setObject: userContext forKey: username];
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
      containersBag = [NSMutableArray new];
      rootFolders = nil;

      mapping = nil;

      userDbTableExists = NO;
      folderTableURL = nil;

      authenticator = nil;
      woContext = [WOContext contextWithRequest: nil];
      [woContext retain];
    }

  return self;
}

- (NSString *) _readUserPassword: (NSString *) newUsername
{
  NSString *password, *path;
  NSData *content;
 
  password = nil;
  
  path = [NSString stringWithFormat: SAMBA_PRIVATE_DIR
		   @"/mapistore/%@/password", newUsername];

  content = [NSData dataWithContentsOfFile: path];

  if (content)
    {
      password = [[NSString alloc] initWithData: content
				       encoding: NSUTF8StringEncoding];
      [password autorelease];
    }

  return password;
}

- (id) initWithUsername: (NSString *) newUsername
         andTDBIndexing: (struct tdb_wrap *) indexingTdb
{
  NSString *userPassword;

  if ((self = [self init]))
    {
      /* "username" will be retained by table */
      username = newUsername;
      if (indexingTdb)
        ASSIGN (mapping, [MAPIStoreMapping mappingForUsername: username
                                                 withIndexing: indexingTdb]);

      authenticator = [MAPIStoreAuthenticator new];
      [authenticator setUsername: username];
      /* TODO: very hackish (IMAP access) */
      userPassword = [self _readUserPassword: newUsername];
      if ([userPassword length] == 0)
        userPassword = username;
      [authenticator setPassword: userPassword];
    }

  return self;
}

- (void) dealloc
{
  [userFolder release];
  [containersBag release];
  [rootFolders release];

  [woContext release];
  [authenticator release];
  [mapping release];

  [folderTableURL release];

  [sogoUser release];

  [contextsTable removeObjectForKey: username];

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

- (NSTimeZone *) timeZone
{
  if (!timeZone)
    {
      SOGoUser *user;

      user = [self sogoUser];
      timeZone = [[user userDefaults] timeZone];
      [timeZone retain];
    }

  return timeZone;
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

- (NSDictionary *) rootFolders
{
  SOGoMailAccounts *accountsFolder;
  id currentFolder;
  NGImap4Connection *connection;
  NSDictionary *hierarchy;
  NSArray *flags;

  if (!rootFolders)
    {
      rootFolders = [NSMutableDictionary new];
      [self userFolder];
      [woContext setClientObject: userFolder];

      /* Calendar */
      currentFolder = [userFolder lookupName: @"Calendar"
                                   inContext: woContext
                                     acquire: NO];
      [rootFolders setObject: currentFolder
                      forKey: @"calendar"];
      [rootFolders setObject: currentFolder
                      forKey: @"tasks"];

      /* Contacts */
      currentFolder = [userFolder lookupName: @"Contacts"
                                   inContext: woContext
                                     acquire: NO];
      [rootFolders setObject: currentFolder
                      forKey: @"contacts"];

      /* Mail */
      accountsFolder = [userFolder lookupName: @"Mail"
                                    inContext: woContext
                                      acquire: NO];
      [containersBag addObject: accountsFolder];
      [woContext setClientObject: accountsFolder];
      currentFolder = [accountsFolder lookupName: @"0"
                                       inContext: woContext
                                         acquire: NO];

      [rootFolders setObject: currentFolder
                      forKey: @"mail"];
      connection = [currentFolder imap4Connection];
      [connection enableExtensions: [NSArray arrayWithObject: @"QRESYNC"]];

      /* ensure the folder cache is filled */
      [currentFolder toManyRelationshipKeysWithNamespaces: YES];
      hierarchy = [connection
                    cachedHierarchyResultsForURL: [currentFolder imap4URL]];
      flags = [[hierarchy  objectForKey: @"list"] objectForKey: @"/INBOX"];
      inboxHasNoInferiors = [flags containsObject: @"noinferiors"];
    }

  return rootFolders;
}

- (BOOL) inboxHasNoInferiors
{
  [self rootFolders];

  return inboxHasNoInferiors;
}

- (MAPIStoreMapping *) mapping
{
  return mapping;
}


/* OpenChange db table */

- (NSURL *) folderTableURL
{
  NSString *urlString, *ocFSTableName;
  NSMutableArray *parts;
  SOGoUser *user;

  if (!folderTableURL)
    {
      user = [self sogoUser];
      urlString = [[user domainDefaults] folderInfoURL];
      parts = [[urlString componentsSeparatedByString: @"/"]
                mutableCopy];
      [parts autorelease];
      if ([parts count] == 5)
        {
          /* If "OCSFolderInfoURL" is properly configured, we must have 5
             parts in this url. */
          ocFSTableName = [NSString stringWithFormat: @"socfs_%@",
                                    [username asCSSIdentifier]];
          [parts replaceObjectAtIndex: 4 withObject: ocFSTableName];
          folderTableURL
            = [NSURL URLWithString: [parts componentsJoinedByString: @"/"]];
          [folderTableURL retain];
        }
      else
        [NSException raise: @"MAPIStoreIOException"
                    format: @"'OCSFolderInfoURL' is not set"];
    }

  return folderTableURL;
}

- (void) ensureFolderTableExists
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSString *tableName, *query;
  GCSSpecialQueries *queries;

  [self folderTableURL];

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: folderTableURL];
  
  /* FIXME: make use of [EOChannelAdaptor describeTableNames] instead */
  tableName = [[folderTableURL path] lastPathComponent];
  if ([channel evaluateExpressionX:
        [NSString stringWithFormat: @"SELECT count(*) FROM %@",
                  tableName]])
    {
      queries = [channel specialQueries];
      query = [queries createOpenChangeFSTableWithName: tableName];
      if ([channel evaluateExpressionX: query])
        [NSException raise: @"MAPIStoreIOException"
                    format: @"could not create special table '%@'", tableName];
    }
  else
    [channel cancelFetch];


  [cm releaseChannel: channel]; 
}

/* SOGo context objects */
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
