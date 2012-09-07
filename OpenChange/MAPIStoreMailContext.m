/* MAPIStoreMailContext.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSString+misc.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>

#import "MAPIStoreMailFolder.h"
#import "MAPIStoreUserContext.h"
#import "NSString+MAPIStore.h"

#import <SOGo/NSString+Utilities.h>
#import "MAPIApplication.h"
#import "MAPIStoreMailContext.h"

#include <dlinklist.h>
#undef DEBUG
#include <mapistore/mapistore.h>

static Class MAPIStoreMailFolderK, MAPIStoreOutboxFolderK;

@implementation MAPIStoreMailContext

+ (void) initialize
{
  MAPIStoreMailFolderK = [MAPIStoreMailFolder class];
  MAPIStoreOutboxFolderK = [MAPIStoreOutboxFolder class];
}

+ (NSString *) MAPIModuleName
{
  return @"mail";
}

+ (enum mapistore_context_role) MAPIContextRole
{
  return MAPISTORE_MAIL_ROLE;
}

static inline NSString *
MakeDisplayFolderName (NSString *folderName)
{
  NSArray *parts;
  NSString *lastFolder;
  NSUInteger max;
 
  parts = [folderName componentsSeparatedByString: @"/"];
  max = [parts count];
  if (max > 1)
    {
      lastFolder = [parts objectAtIndex: max - 1];
      if ([lastFolder length] == 0)
        lastFolder = [parts objectAtIndex: max - 2];
    }
  else
    lastFolder = folderName;

  return [[lastFolder substringFromIndex: 6] fromCSSIdentifier];
}

+ (struct mapistore_contexts_list *) listContextsForUser: (NSString *) userName
                                         withTDBIndexing: (struct tdb_wrap *) indexingTdb
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_contexts_list *firstContext = NULL, *context;
  NSString *urlBase, *stringData, *currentName, *inboxName, *draftsName, *sentName, *trashName;
  NSArray *unprefixedFolders;
  NSMutableArray *secondaryFolders;
  enum mapistore_context_role role[] = {MAPISTORE_MAIL_ROLE,
                                        MAPISTORE_DRAFTS_ROLE,
                                        MAPISTORE_SENTITEMS_ROLE};
  NSString *folderName[3];
  NSUInteger count, max;
  SOGoMailAccount *accountFolder;
  MAPIStoreUserContext *userContext;
  WOContext *woContext;

  userContext = [MAPIStoreUserContext userContextWithUsername: userName
                                               andTDBIndexing: indexingTdb];
  accountFolder = [[userContext rootFolders] objectForKey: @"mail"];
  woContext = [userContext woContext];

  inboxName = @"folderINBOX";
  folderName[0] = inboxName;

  unprefixedFolders = [[accountFolder draftsFolderNameInContext: woContext]
                        componentsSeparatedByString: @"/"];
  draftsName = [NSString stringWithFormat: @"folder%@",
                         [unprefixedFolders componentsJoinedByString: @"/folder"]];
  folderName[1] = draftsName;

  unprefixedFolders = [[accountFolder sentFolderNameInContext: woContext]
                        componentsSeparatedByString: @"/"];
  sentName = [NSString stringWithFormat: @"folder%@",
                       [unprefixedFolders componentsJoinedByString: @"/folder"]];
  folderName[2] = sentName;

  /* Note: trash is not used as a mail folder, since "Deleted Items" makes use of
     the fallback context */
  unprefixedFolders = [[accountFolder trashFolderNameInContext: woContext]
                        componentsSeparatedByString: @"/"];
  trashName = [NSString stringWithFormat: @"folder%@",
                       [unprefixedFolders componentsJoinedByString: @"/folder"]];

  urlBase = [NSString stringWithFormat: @"sogo://%@:%@@mail/", userName, userName];
  for (count = 0; count < 3; count++)
    {
      context = talloc_zero (memCtx, struct mapistore_contexts_list);
      stringData = [NSString stringWithFormat: @"%@%@", urlBase,
                             [folderName[count] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
      context->url = [stringData asUnicodeInMemCtx: context];
      /* remove "folder" prefix */
      stringData = MakeDisplayFolderName (folderName[count]);
      context->name = [stringData asUnicodeInMemCtx: context];
      context->main_folder = true;
      context->role = role[count];
      context->tag = "tag";
      DLIST_ADD_END (firstContext, context, void);
    }

  secondaryFolders = [[accountFolder toManyRelationshipKeysWithNamespaces: NO]
                       mutableCopy];
  [secondaryFolders autorelease];
  [secondaryFolders removeObject: inboxName];
  [secondaryFolders removeObject: draftsName];
  [secondaryFolders removeObject: sentName];
  [secondaryFolders removeObject: trashName];
  max = [secondaryFolders count];
  for (count = 0; count < max; count++)
    {
      context = talloc_zero (memCtx, struct mapistore_contexts_list);
      currentName = [secondaryFolders objectAtIndex: count];
      stringData = [NSString stringWithFormat: @"%@%@",
                             urlBase, [currentName stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
      context->url = [stringData asUnicodeInMemCtx: context];
      stringData = [[currentName substringFromIndex: 6] fromCSSIdentifier];
      context->name = [stringData asUnicodeInMemCtx: context];
      context->main_folder = false;
      context->role = MAPISTORE_MAIL_ROLE;
      context->tag = "tag";
      DLIST_ADD_END (firstContext, context, void);
    }

  return firstContext;
}

+ (NSString *)
 createRootSecondaryFolderWithFID: (uint64_t) fid
                          andName: (NSString *) newFolderName
                          forUser: (NSString *) userName
{
  NSString *mapistoreURI, *folderName;
  MAPIStoreUserContext *userContext;
  SOGoMailAccount *accountFolder;
  SOGoMailFolder *newFolder;

  userContext = [MAPIStoreUserContext userContextWithUsername: userName
                                               andTDBIndexing: NULL];
  [MAPIApp setUserContext: userContext];
  accountFolder = [[userContext rootFolders] objectForKey: @"mail"];
  folderName = [NSString stringWithFormat: @"folder%@",
                         [newFolderName asCSSIdentifier]];
  newFolder = [SOGoMailFolder objectWithName: folderName
                                 inContainer: accountFolder];
  if ([newFolder create])
    mapistoreURI = [NSString stringWithFormat: @"sogo://%@:%@@mail/%@/",
                             userName, userName,
                             [folderName stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
  else
    mapistoreURI = nil;
  [MAPIApp setUserContext: nil];

  return mapistoreURI;
}

- (Class) MAPIStoreFolderClass
{
  return MAPIStoreMailFolderK;
}

- (id) rootSOGoFolder
{
  return [[userContext rootFolders] objectForKey: @"mail"];
}

- (void) updateURLWithFolderName: (NSString *) newFolderName
{
  NSString *urlString, *escapedName;
  NSMutableArray *pathComponents;
  BOOL hasSlash;
  NSUInteger max, folderNameIdx;
  NSURL *newURL;

  /* we do not need to unescape the url here as it will be reassembled later
     in the method */
  urlString = [contextUrl absoluteString];
  hasSlash = [urlString hasSuffix: @"/"];
  pathComponents = [[urlString componentsSeparatedByString: @"/"]
                     mutableCopy];
  [pathComponents autorelease];
  max = [pathComponents count];
  if (hasSlash)
    folderNameIdx = max - 2;
  else
    folderNameIdx = max - 1;
  escapedName = [newFolderName stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
  [pathComponents replaceObjectAtIndex: folderNameIdx
                            withObject: escapedName];
  urlString = [pathComponents componentsJoinedByString: @"/"];
  newURL = [NSURL URLWithString: urlString];
  ASSIGN (contextUrl, newURL);
}

@end

@implementation MAPIStoreOutboxContext

+ (NSString *) MAPIModuleName
{
  return @"outbox";
}

+ (struct mapistore_contexts_list *) listContextsForUser: (NSString *) userName
                                         withTDBIndexing: (struct tdb_wrap *) indexingTdb
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_contexts_list *context;
  NSString *url, *folderName;
  NSArray *unprefixedFolders;
  SOGoMailAccount *accountFolder;
  MAPIStoreUserContext *userContext;
  WOContext *woContext;

  userContext = [MAPIStoreUserContext userContextWithUsername: userName
                                               andTDBIndexing: indexingTdb];
  accountFolder = [[userContext rootFolders] objectForKey: @"mail"];
  woContext = [userContext woContext];

  unprefixedFolders = [[accountFolder draftsFolderNameInContext: woContext]
                        componentsSeparatedByString: @"/"];
  folderName = [NSString stringWithFormat: @"folder%@",
                         [unprefixedFolders componentsJoinedByString: @"/folder"]];
  url = [NSString stringWithFormat: @"sogo://%@:%@@outbox/%@", userName,
                  userName, folderName];

  context = talloc_zero (memCtx, struct mapistore_contexts_list);
  context->url = [url asUnicodeInMemCtx: context];
  /* TODO: use a localized version of this display name */
  context->name = [@"Outbox" asUnicodeInMemCtx: context];
  context->main_folder = true;
  context->role = MAPISTORE_OUTBOX_ROLE;
  context->tag = "tag";
  context->prev = context;

  return context;
}

- (Class) MAPIStoreFolderClass
{
  return MAPIStoreOutboxFolderK;
}

@end
