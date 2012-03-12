/* MAPIStoreContext.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSThread.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/SOGoUser.h>

#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreAttachment.h"
// #import "MAPIStoreAttachmentTable.h"
#import "MAPIStoreFallbackContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreFolderTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreMessage.h"
#import "MAPIStoreMessageTable.h"
#import "MAPIStoreFAIMessage.h"
#import "MAPIStoreFAIMessageTable.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "NSArray+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContext.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <util/attr.h>
#include <libmapiproxy.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>
#include <talloc.h>

/* TODO: homogenize method names and order of parameters */

@implementation MAPIStoreContext : NSObject

/* sogo://username:password@{contacts,calendar,tasks,journal,notes,mail}/dossier/id */

static Class NSExceptionK, MAPIStoreFallbackContextK, SOGoObjectK;

static NSMutableDictionary *contextClassMapping;

+ (void) initialize
{
  NSArray *classes;
  Class currentClass;
  NSUInteger count, max;
  NSString *moduleName;

  NSExceptionK = [NSException class];
  SOGoObjectK = [SOGoObject class];

  contextClassMapping = [NSMutableDictionary new];
  classes = GSObjCAllSubclassesOfClass (self);
  max = [classes count];
  for (count = 0; count < max; count++)
    {
      currentClass = [classes objectAtIndex: count];
      moduleName = [currentClass MAPIModuleName];
      if (moduleName)
	{
	  [contextClassMapping setObject: currentClass
                                  forKey: moduleName];
	  NSLog (@"  registered class '%@' as handler of '%@' contexts",
		 NSStringFromClass (currentClass), moduleName);
	}
    }

  MAPIStoreFallbackContextK = [MAPIStoreFallbackContext class];
}

+ (struct mapistore_contexts_list *) listAllContextsForUser: (NSString *)  userName
                                            withTDBIndexing: (struct tdb_wrap *) indexingTdb
                                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_contexts_list *list, *current;
  NSArray *classes;
  Class currentClass;
  NSUInteger count, max;
  MAPIStoreUserContext *userContext;

  list = NULL;

  userContext = [MAPIStoreUserContext userContextWithUsername: userName
                                               andTDBIndexing: indexingTdb];
  [userContext activateWithUser: [userContext sogoUser]];

  classes = GSObjCAllSubclassesOfClass (self);
  max = [classes count];
  for (count = 0; count < max; count++)
    {
      currentClass = [classes objectAtIndex: count];
      current = [currentClass listContextsForUser: userName
                                  withTDBIndexing: indexingTdb
                                         inMemCtx: memCtx];
      if (current)
        DLIST_CONCATENATE(list, current, void);
    }

  return list;
}

+ (struct mapistore_contexts_list *) listContextsForUser: (NSString *) userName
                                         withTDBIndexing: (struct tdb_wrap *) indexingTdb
                                                inMemCtx: (TALLOC_CTX *) memCtx
{
  return NULL;
}

static Class
MAPIStoreLookupContextClassByRole (Class self, enum mapistore_context_role role)
{
  static NSMutableDictionary *classMapping = nil;
  Class currentClass;
  enum mapistore_context_role classRole;
  NSNumber *roleNbr;
  NSArray *classes;
  NSUInteger count, max;

  if (!classMapping)
    {
      classMapping = [NSMutableDictionary new];
      classes = GSObjCAllSubclassesOfClass (self);
      max = [classes count];
      for (count = 0; count < max; count++)
        {
          currentClass = [classes objectAtIndex: count];
          classRole = [currentClass MAPIContextRole];
          if (classRole != -1)
            {
              roleNbr = [NSNumber numberWithUnsignedInt: classRole];
              [classMapping setObject: currentClass
                               forKey: roleNbr];
            }
        }
    }

  roleNbr = [NSNumber numberWithUnsignedInt: role];

  return [classMapping objectForKey: roleNbr];
}

+ (enum mapistore_error) createRootFolder: (NSString **) mapistoreUriP
                                  withFID: (uint64_t) fid
                                  andName: (NSString *) folderName
                                  forUser: (NSString *) userName
                                 withRole: (enum mapistore_context_role) role
{
  Class contextClass;
  NSString *mapistoreURI;
  enum mapistore_error rc = MAPISTORE_SUCCESS;

  contextClass = MAPIStoreLookupContextClassByRole (self, role);
  if (!contextClass)
    contextClass = MAPIStoreFallbackContextK;

  mapistoreURI = [contextClass createRootSecondaryFolderWithFID: fid
                                                        andName: folderName
                                                        forUser: userName];
  if (!mapistoreURI && contextClass != MAPIStoreFallbackContextK)
    mapistoreURI = [MAPIStoreFallbackContextK createRootSecondaryFolderWithFID: fid
                                                                       andName: folderName
                                                                       forUser: userName];
  if (mapistoreURI)
    *mapistoreUriP = mapistoreURI;
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

static inline NSURL *CompleteURLFromMapistoreURI (const char *uri)
{
  NSString *urlString;
  NSURL *completeURL;

  urlString = [NSString stringWithFormat: @"sogo://%@",
                        [NSString stringWithUTF8String: uri]];
  if (![urlString hasSuffix: @"/"])
    urlString = [urlString stringByAppendingString: @"/"];
  completeURL = [NSURL URLWithString: [urlString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];

  return completeURL;
}

+ (int) openContext: (MAPIStoreContext **) contextPtr
            withURI: (const char *) newUri
     connectionInfo: (struct mapistore_connection_info *) newConnInfo
     andTDBIndexing: (struct tdb_wrap *) indexingTdb
{
  MAPIStoreContext *context;
  Class contextClass;
  NSString *module;
  NSURL *baseURL;
  int rc = MAPISTORE_ERR_NOT_FOUND;

  NSLog (@"METHOD '%s' (%d) -- uri: '%s'", __FUNCTION__, __LINE__, newUri);

  context = nil;

  baseURL = CompleteURLFromMapistoreURI (newUri);
  if (baseURL)
    {
      module = [baseURL host];
      if (module)
        {
          contextClass = [contextClassMapping objectForKey: module];
          if (contextClass)
            {
              context = [[contextClass alloc] initFromURL: baseURL
                                       withConnectionInfo: newConnInfo
                                           andTDBIndexing: indexingTdb];
              if (context)
                {
                  [context autorelease];
                  rc = MAPISTORE_SUCCESS;
                  *contextPtr = context;
                }
            }
          else
            NSLog (@"ERROR: unrecognized module name '%@'", module);
        }
    }
  else
    NSLog (@"ERROR: url could not be parsed");

  return rc;
}

- (id) init
{
  if ((self = [super init]))
    {
      activeUser = nil;
      userContext = nil;
      contextUrl = nil;
      containersBag = [NSMutableArray new];
    }

  return self;
}

- (id)   initFromURL: (NSURL *) newUrl
  withConnectionInfo: (struct mapistore_connection_info *) newConnInfo
      andTDBIndexing: (struct tdb_wrap *) indexingTdb
{
  NSString *username;

  if ((self = [self init]))
    {
      ASSIGN (contextUrl, newUrl);

      username = [newUrl user];
      if ([username length] == 0)
        {
          [self errorWithFormat:
                  @"attempt to instantiate a context with an empty owner"];
          [self release];
          return nil;
        }

      ASSIGN (userContext,
              [MAPIStoreUserContext userContextWithUsername: username
                                             andTDBIndexing: indexingTdb]);

      mapistore_mgmt_backend_register_user (newConnInfo,
                                            "SOGo",
                                            [username UTF8String]);

      connInfo = newConnInfo;
      username = [NSString stringWithUTF8String: newConnInfo->username];
      ASSIGN (activeUser, [SOGoUser userWithLogin: username]);
      if (!activeUser)
        {
          [self errorWithFormat: @"user '%@' not found in SOGo environment",
                username];
          [self release];
          return nil;
        }
    }

  return self;
}

- (void) dealloc
{
  mapistore_mgmt_backend_unregister_user ([self connectionInfo], "SOGo", 
                                          [[userContext username]
                                            UTF8String]);
  [contextUrl release];
  [userContext release];
  [containersBag release];

  [super dealloc];
}

- (MAPIStoreUserContext *) userContext
{
  return userContext;
}

- (NSURL *) url
{
  return contextUrl;
}

- (struct mapistore_connection_info *) connectionInfo
{
  return connInfo;
}

- (SOGoUser *) activeUser
{
  return activeUser;
}

// - (void) logRestriction: (struct mapi_SRestriction *) res
// 	      withState: (MAPIRestrictionState) state
// {
//   NSString *resStr;

//   resStr = MAPIStringForRestriction (res);

//   [self logWithFormat: @"%@  -->  %@", resStr, MAPIStringForRestrictionState (state)];
// }

- (int) getPath: (char **) path
         ofFMID: (uint64_t) fmid
       inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  NSString *objectURL, *url;
  // TDB_DATA key, dbuf;

  url = [contextUrl absoluteString];
  objectURL = [[userContext mapping] urlFromID: fmid];
  if (objectURL)
    {
      if ([objectURL hasPrefix: url])
        {
          *path = [[objectURL substringFromIndex: 7]
		    asUnicodeInMemCtx: memCtx];
	  [self logWithFormat: @"found path '%s' for fmid %.16x",
		*path, fmid];
          rc = MAPISTORE_SUCCESS;
        }
      else
        {
	  [self logWithFormat: @"context (%@, %@) does not contain"
		@" found fmid: 0x%.16x",
		objectURL, url, fmid];
          *path = NULL;
          rc = MAPISTORE_SUCCESS;
        }
    }
  else
    {
      [self errorWithFormat: @"%s: you should *never* get here", __PRETTY_FUNCTION__];
      // /* attempt to populate our mapping dict with data from indexing.tdb */
      // key.dptr = (unsigned char *) talloc_asprintf (memCtx, "0x%.16llx",
      //                                               (long long unsigned int )fmid);
      // key.dsize = strlen ((const char *) key.dptr);

      // dbuf = tdb_fetch (memCtx->indexing_list->index_ctx->tdb, key);
      // talloc_free (key.dptr);
      // uri = talloc_strndup (memCtx, (const char *)dbuf.dptr, dbuf.dsize);
      *path = NULL;
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (void) ensureContextFolder
{
}

- (int) getRootFolder: (MAPIStoreFolder **) folderPtr
              withFID: (uint64_t) newFid
{
  enum mapistore_error rc;
  MAPIStoreMapping *mapping;
  MAPIStoreFolder *baseFolder;
  SOGoFolder *currentFolder;
  WOContext *woContext;
  NSString *path;
  NSArray *pathComponents;
  NSUInteger count, max;

  mapping = [userContext mapping];
  if (![mapping urlFromID: newFid])
    [mapping registerURL: [contextUrl absoluteString]
                  withID: newFid];

  [userContext activateWithUser: activeUser];
  woContext = [userContext woContext];

  [self ensureContextFolder];
  currentFolder = [self rootSOGoFolder];
  path = [contextUrl path];
  if ([path hasPrefix: @"/"])
    path = [path substringFromIndex: 1];
  if ([path hasSuffix: @"/"])
    path = [path substringToIndex: [path length] - 1];
  pathComponents = [path componentsSeparatedByString: @"/"];
  max = [pathComponents count];
  for (count = 0; currentFolder && count < max; count++)
    {
      [woContext setClientObject: currentFolder];
      currentFolder
        = [currentFolder lookupName: [pathComponents objectAtIndex: count]
                          inContext: woContext
                            acquire: NO];
      if ([currentFolder isKindOfClass: SOGoObjectK]) /* class common to all
                                                         SOGo folder types */
        [containersBag addObject: currentFolder];
      else
        currentFolder = nil;
    }

  if (currentFolder)
    {
      baseFolder = [[self MAPIStoreFolderClass]
                     mapiStoreObjectWithSOGoObject: currentFolder
                                       inContainer: nil];
      [baseFolder setContext: self];

      *folderPtr = baseFolder;
      rc = MAPISTORE_SUCCESS;
    }
  else if ([[userContext sogoUser] isEqual: activeUser])
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    rc = MAPISTORE_ERR_DENIED;

  return rc;
}

/* utils */

- (NSString *) extractChildNameFromURL: (NSString *) objectURL
			andFolderURLAt: (NSString **) folderURL;
{
  NSString *childKey;
  NSRange lastSlash;
  NSUInteger slashPtr;

  if ([objectURL hasSuffix: @"/"])
    objectURL = [objectURL substringToIndex: [objectURL length] - 2];
  lastSlash = [objectURL rangeOfString: @"/"
			       options: NSBackwardsSearch];
  if (lastSlash.location != NSNotFound)
    {
      slashPtr = NSMaxRange (lastSlash);
      childKey = [objectURL substringFromIndex: slashPtr];
      if ([childKey length] == 0)
	childKey = nil;
      if (folderURL)
	*folderURL = [objectURL substringToIndex: slashPtr];
    }
  else
    childKey = nil;

  return childKey;
}

- (uint64_t) idForObjectWithKey: (NSString *) key
                    inFolderURL: (NSString *) folderURL
{
  NSString *childURL, *owner;
  MAPIStoreMapping *mapping;
  uint64_t mappingId;
  uint32_t contextId;
  void *rootObject;

  if (key)
    childURL = [NSString stringWithFormat: @"%@%@", folderURL, key];
  else
    childURL = folderURL;
  mapping = [userContext mapping];
  mappingId = [mapping idFromURL: childURL];
  if (mappingId == NSNotFound)
    {
      [self warnWithFormat: @"no id exist yet, requesting one..."];
      openchangedb_get_new_folderID (connInfo->oc_ctx, &mappingId);
      [mapping registerURL: childURL withID: mappingId];
      contextId = 0;

      mapistore_search_context_by_uri (connInfo->mstore_ctx, [folderURL UTF8String] + 7,
                                       &contextId, &rootObject);
      owner = [userContext username];
      mapistore_indexing_record_add_mid (connInfo->mstore_ctx, contextId,
                                         [owner UTF8String], mappingId);
    }

  return mappingId;
}

- (uint64_t) getNewChangeNumber
{
  uint64_t newVersionNumber;

  if (openchangedb_get_new_changeNumber (connInfo->oc_ctx, &newVersionNumber)
      != MAPI_E_SUCCESS)
    abort ();

  return newVersionNumber;
}

/* subclasses */

+ (NSString *) MAPIModuleName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

+ (enum mapistore_context_role) MAPIContextRole
{
  return -1;
}

+ (NSString *)
 createRootSecondaryFolderWithFID: (uint64_t) fid
                          andName: (NSString *) folderName
                          forUser: (NSString *) userName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (Class) MAPIStoreFolderClass
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (id) rootSOGoFolder
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
