/* MAPIStoreContext.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSObject+Values.h>

#import <SOGo/SOGoFolder.h>
#import <SOGo/SOGoUser.h>

#import "MAPIStoreAttachment.h"
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
#include "samba-dlinklist.h"
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
                                               withIndexing: (struct indexing_context *) indexing
                                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_contexts_list *list, *current;
  NSArray *classes;
  Class currentClass;
  NSUInteger count, max;

  list = NULL;

  // User context is activated on initialization
  [MAPIStoreUserContext userContextWithUsername: userName
                                 andTDBIndexing: indexing];

  classes = GSObjCAllSubclassesOfClass (self);
  max = [classes count];
  for (count = 0; count < max; count++)
    {
      currentClass = [classes objectAtIndex: count];
      current = [currentClass listContextsForUser: userName
                                     withIndexing: indexing
                                         inMemCtx: memCtx];
      if (current)
        DLIST_CONCATENATE(list, current);
    }

  return list;
}

+ (struct mapistore_contexts_list *) listContextsForUser: (NSString *) userName
                                            withIndexing: (struct indexing_context *) indexing
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
  completeURL = [NSURL URLWithString: urlString];

  return completeURL;
}

+ (enum mapistore_error) openContext: (MAPIStoreContext **) contextPtr
                             withURI: (const char *) newUri
                      connectionInfo: (struct mapistore_connection_info *) newConnInfo
                      andTDBIndexing: (struct indexing_context *) indexing
{
  MAPIStoreContext *context;
  Class contextClass;
  NSString *module;
  NSURL *baseURL;
  enum mapistore_error rc = MAPISTORE_ERR_NOT_FOUND;

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
                                           andTDBIndexing: indexing];
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
      andTDBIndexing: (struct indexing_context *) indexing
{
  NSString *username;

  if (newConnInfo == NULL)
    {
      return nil;
    }

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
                                             andTDBIndexing: indexing]);
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

- (enum mapistore_error) getPath: (char **) path
                          ofFMID: (uint64_t) fmid
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  enum mapistore_error rc;
  NSString *objectURL, *url;

  url = [contextUrl absoluteString];
  // FIXME transform percent escapes but not for user part of the url
  //[xxxx stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
  objectURL = [[userContext mapping] urlFromID: fmid];
  if (objectURL)
    {
      if ([objectURL hasPrefix: url])
        {
          *path = [[objectURL substringFromIndex: 7] asUnicodeInMemCtx: memCtx];
          [self logWithFormat: @"found path '%s' for fmid 0x%.16"PRIx64"", *path, fmid];
          rc = MAPISTORE_SUCCESS;
        }
      else
        {
          [self logWithFormat: @"context (%@, %@) does not contain "
                               @"found fmid: 0x%.16"PRIx64"", objectURL, url, fmid];
          *path = NULL;
          rc = MAPISTORE_SUCCESS;
        }
    }
  else
    {
      [self errorWithFormat: @"%s: you should *never* get here", __PRETTY_FUNCTION__];
      *path = NULL;
      rc = MAPISTORE_SUCCESS;
    }

  return rc;
}

- (void) ensureContextFolder
{
}

- (enum mapistore_error) getRootFolder: (MAPIStoreFolder **) folderPtr
                               withFID: (uint64_t) newFid
{
  enum mapistore_error rc;
  MAPIStoreFolder *baseFolder;
  SOGoFolder *currentFolder;
  WOContext *woContext;
  NSString *path;
  NSArray *pathComponents;
  NSUInteger count, max;

  [userContext activate];
  woContext = [userContext woContext];

  [self ensureContextFolder];
  currentFolder = [self rootSOGoFolder];
  [containersBag addObject: currentFolder];

  /* HACK:
     -[NSURL path] returns unescaped strings in theory. In pratice, sometimes
     it does, sometimes not. Therefore we use the result of our own
     implementation of -[NSString
     stringByReplacingPercentEscapeUsingEncoding:], which returns nil if the
     original string contains non-ascii chars, from which we can determine
     whether the path was unescaped or not. */
  path = [[contextUrl path]
           stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
  if (!path)
    path = [contextUrl path];

  if ([path hasPrefix: @"/"])
    path = [path substringFromIndex: 1];
  if ([path hasSuffix: @"/"])
    path = [path substringToIndex: [path length] - 1];
  if ([path length] > 0)
    {
      pathComponents = [path componentsSeparatedByString: @"/"];
      max = [pathComponents count];
      for (count = 0; currentFolder && count < max; count++)
        {
          [woContext setClientObject: currentFolder];
          currentFolder = [currentFolder
                            lookupName: [pathComponents objectAtIndex: count]
                            inContext: woContext
                            acquire: NO];
          if ([currentFolder isKindOfClass: SOGoObjectK]) /* class common to all
                                                             SOGo folder types */
            [containersBag addObject: currentFolder];
          else
            currentFolder = nil;
        }
    }

  if (currentFolder)
    {
      baseFolder = [[self MAPIStoreFolderClass]
                     mapiStoreObjectWithSOGoObject: currentFolder
                                       inContainer: nil];
      [baseFolder setContext: self];

      if ([[userContext sogoUser] isEqual: activeUser]
          || [baseFolder subscriberCanReadMessages])
        {
          *folderPtr = baseFolder;
          rc = MAPISTORE_SUCCESS;
        }
      else
        rc = MAPISTORE_ERR_DENIED;

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
  NSString *childURL;
  MAPIStoreMapping *mapping;
  uint64_t mappingId;
  enum mapistore_error ret;

  if (key)
    childURL = [NSString stringWithFormat: @"%@%@", folderURL,
                  [key stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
  else
    childURL = folderURL;
  mapping = [userContext mapping];
  mappingId = [mapping idFromURL: childURL];
  if (mappingId == NSNotFound)
    {
      const char *owner;

      [self logWithFormat: @"No id exist yet for '%@', requesting one", childURL];
      owner = [[userContext username] UTF8String];
      ret = mapistore_indexing_get_new_folderID_as_user (connInfo->mstore_ctx, owner, &mappingId);
      if (ret == MAPISTORE_SUCCESS)
        [mapping registerURL: childURL withID: mappingId];
      else
        [self errorWithFormat: @"Error trying to get new folder id (%d): %s",
              ret, mapistore_errstr (ret)];
    }

  return mappingId;
}

/* Get new change number from openchange db interface using
   resource's owner user */
- (uint64_t) getNewChangeNumber
{
  const char *owner;
  enum MAPISTATUS retval;
  uint64_t newVersionNumber;

  owner = [[userContext username] UTF8String];
  retval = openchangedb_get_new_changeNumber (connInfo->oc_ctx, owner, &newVersionNumber);
  if (retval != MAPI_E_SUCCESS)
    [NSException raise: @"MAPIStoreIOException"
                format: @"Impossible to get new change number for %s: %s", owner,
                 mapi_get_errstr (retval)];

  return newVersionNumber;
}

/* Get new change numbers from openchange db interface using
   resource's owner user */
- (NSArray *) getNewChangeNumbers: (uint64_t) max
{
  const char *owner;
  enum MAPISTATUS retval;
  TALLOC_CTX *memCtx;
  NSMutableArray *newChangeNumbers;
  uint64_t count;
  struct UI8Array_r *numbers;
  NSString *newNumber;

  memCtx = talloc_new (NULL);
  if (!memCtx)
    [NSException raise: @"MAPIStoreIOException"
                format: @"Not enough memory to allocate change numbers"];

  newChangeNumbers = [NSMutableArray arrayWithCapacity: max];
  owner = [[userContext username] UTF8String];

  retval = openchangedb_get_new_changeNumbers (connInfo->oc_ctx, memCtx, owner, max, &numbers);
  if (retval != MAPI_E_SUCCESS || numbers->cValues != max)
    {
      talloc_free (memCtx);
      [NSException raise: @"MAPIStoreIOException"
                  format: @"Failing to get %d new change numbers: %s", max,
                          mapi_get_errstr (retval)];
    }

  for (count = 0; count < max; count++)
    {
      newNumber = [NSString stringWithUnsignedLongLong: numbers->lpui8[count]];
      [newChangeNumbers addObject: newNumber];
    }

  talloc_free (memCtx);

  return newChangeNumbers;
}

/* Get new fmids from mapistore_indexing interface using resource's
   owner user */
- (NSArray *) getNewFMIDs: (uint64_t) max
{
  const char *owner;
  enum mapistore_error ret;
  NSMutableArray *newFMIDs;
  NSString *newNumber;
  uint64_t count, newFID;

  newFMIDs = [NSMutableArray arrayWithCapacity: max];
  /* Get the resource's owner name */
  owner = [[userContext username] UTF8String];

  for (count = 0; count < max; count++)
    {
      ret = mapistore_indexing_get_new_folderID_as_user (connInfo->mstore_ctx, owner, &newFID);
      if (ret != MAPISTORE_SUCCESS)
          [NSException raise: @"MAPIStoreIOException"
                      format: @"Impossible to get new fmid for %s", owner];

      newNumber = [NSString stringWithUnsignedLongLong: newFID];
      [newFMIDs addObject: newNumber];
    }

  return newFMIDs;
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
