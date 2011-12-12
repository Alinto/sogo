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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/SOGoUser.h>

#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIApplication.h"
#import "MAPIStoreAttachment.h"
// #import "MAPIStoreAttachmentTable.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreFolderTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreMessage.h"
#import "MAPIStoreMessageTable.h"
#import "MAPIStoreFAIMessage.h"
#import "MAPIStoreFAIMessageTable.h"
#import "MAPIStoreTypes.h"
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

static Class NSDataK, NSStringK, MAPIStoreFAIMessageK;

static NSMutableDictionary *contextClassMapping;

+ (void) initialize
{
  NSArray *classes;
  Class currentClass;
  NSUInteger count, max;
  NSString *moduleName;

  NSDataK = [NSData class];
  NSStringK = [NSString class];
  MAPIStoreFAIMessageK = [MAPIStoreFAIMessage class];

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
}

static inline enum mapistore_error
_prepareContextClass (Class contextClass,
                      struct mapistore_connection_info *connInfo,
                      struct tdb_wrap *indexingTdb, NSURL *url,
                      MAPIStoreContext **contextP)
{
  MAPIStoreContext *context;
  MAPIStoreAuthenticator *authenticator;
  enum mapistore_error rc;

  context = [[contextClass alloc] initFromURL: url
                           withConnectionInfo: connInfo
                               andTDBIndexing: indexingTdb];
  if (context)
    {
      [context autorelease];

      authenticator = [MAPIStoreAuthenticator new];
      [authenticator setUsername: [url user]];
      [authenticator setPassword: [url password]];
      [context setAuthenticator: authenticator];
      [authenticator release];

      [context setupRequest];
      [context setupBaseFolder: url];
      [context tearDownRequest];
      if (context->baseFolder && [context->baseFolder sogoObject])
        {
          *contextP = context;
          rc = MAPISTORE_SUCCESS;
        }
      else
        rc = MAPISTORE_ERR_DENIED;
    }
  else
    rc = MAPISTORE_ERROR;

  return rc;
}

+ (int) openContext: (MAPIStoreContext **) contextPtr
            withURI: (const char *) newUri
     connectionInfo: (struct mapistore_connection_info *) newConnInfo
     andTDBIndexing: (struct tdb_wrap *) indexingTdb
{
  MAPIStoreContext *context;
  Class contextClass;
  NSString *module, *completeURLString, *urlString;
  NSURL *baseURL;
  int rc = MAPISTORE_ERR_NOT_FOUND;

  NSLog (@"METHOD '%s' (%d) -- uri: '%s'", __FUNCTION__, __LINE__, newUri);

  context = nil;

  urlString = [NSString stringWithUTF8String: newUri];
  if (urlString)
    {
      completeURLString = [@"sogo://" stringByAppendingString: urlString];
      if (![completeURLString hasSuffix: @"/"])
	completeURLString = [completeURLString stringByAppendingString: @"/"];
      baseURL = [NSURL URLWithString: [completeURLString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
      if (baseURL)
        {
          module = [baseURL host];
          if (module)
            {
              contextClass = [contextClassMapping objectForKey: module];
              if (contextClass)
                {
                  rc = _prepareContextClass (contextClass,
                                             newConnInfo, indexingTdb, 
                                             baseURL, &context);
                  if (rc == MAPISTORE_SUCCESS)
                    {
                      *contextPtr = context;
		      mapistore_mgmt_backend_register_user (newConnInfo,
                                                            "SOGo",
                                                            [[[context authenticator] username] UTF8String]);
                    }
                }
              else
                NSLog (@"ERROR: unrecognized module name '%@'", module);
            }
        }
      else
        NSLog (@"ERROR: url could not be parsed");
    }
  else
    NSLog (@"ERROR: url is an invalid UTF-8 string");

  return rc;
}

- (id) init
{
  if ((self = [super init]))
    {
      woContext = [WOContext contextWithRequest: nil];
      [woContext retain];
      baseFolder = nil;
      contextUrl = nil;
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
      username = [NSString stringWithUTF8String: newConnInfo->username];
      ASSIGN (activeUser, [SOGoUser userWithLogin: username]);
      if (!activeUser)
        {
          [self errorWithFormat: @"user '%@' not found in SOGo environment",
                username];
          [self release];
          return nil;
        }
      [woContext setActiveUser: activeUser];
      username = [newUrl user];
      if ([username length] == 0)
        {
          [self errorWithFormat:
                  @"attempt to instantiate a context with an empty owner"];
          [self release];
          return nil;
        }
      ASSIGN (ownerUser, [SOGoUser userWithLogin: username]);
      if (!ownerUser)
        {
          [self errorWithFormat:
                  @"attempt to instantiate a context without a valid owner"];
          [self release];
          return nil;
        }
      ASSIGN (mapping, [MAPIStoreMapping mappingForUsername: username
                                               withIndexing: indexingTdb]);
      [mapping increaseUseCount];
      ASSIGN (contextUrl, newUrl);
      mstoreCtx = newConnInfo->mstore_ctx;
      connInfo = newConnInfo;
    }

  return self;
}

- (void) dealloc
{
  mapistore_mgmt_backend_unregister_user ([self connectionInfo], "SOGo", 
                                          [[[self authenticator] username]
                                            UTF8String]);
  [baseFolder release];
  [woContext release];
  [authenticator release];
  [mapping decreaseUseCount];
  [mapping release];
  [contextUrl release];

  [super dealloc];
}

- (WOContext *) woContext
{
  return woContext;
}

- (MAPIStoreMapping *) mapping
{
  return mapping;
}

- (void) setAuthenticator: (MAPIStoreAuthenticator *) newAuthenticator
{
  ASSIGN (authenticator, newAuthenticator);
}

- (MAPIStoreAuthenticator *) authenticator
{
  return authenticator;
}

- (NSURL *) url
{
  return contextUrl;
}

- (struct mapistore_connection_info *) connectionInfo
{
  return connInfo;
}

- (void) setupRequest
{
  NSMutableDictionary *info;

  [MAPIApp setMAPIStoreContext: self];
  info = [[NSThread currentThread] threadDictionary];
  [info setObject: woContext forKey: @"WOContext"];
}

- (void) tearDownRequest
{
  NSMutableDictionary *info;

  info = [[NSThread currentThread] threadDictionary];
  [info removeObjectForKey: @"WOContext"];
  [MAPIApp setMAPIStoreContext: nil];
}

- (SOGoUser *) activeUser
{
  return activeUser;
}

- (SOGoUser *) ownerUser
{
  return ownerUser;
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
  objectURL = [mapping urlFromID: fmid];
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

- (int) getRootFolder: (MAPIStoreFolder **) folderPtr
              withFID: (uint64_t) newFid
{
  if (![mapping urlFromID: newFid])
    [mapping registerURL: [contextUrl absoluteString]
                  withID: newFid];
  *folderPtr = baseFolder;

  return (baseFolder) ? MAPISTORE_SUCCESS: MAPISTORE_ERROR;
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
  uint64_t mappingId;
  uint32_t contextId;
  void *rootObject;

  if (key)
    childURL = [NSString stringWithFormat: @"%@%@", folderURL, key];
  else
    childURL = folderURL;
  mappingId = [mapping idFromURL: childURL];
  if (mappingId == NSNotFound)
    {
      [self warnWithFormat: @"no id exist yet, requesting one..."];
      openchangedb_get_new_folderID (connInfo->oc_ctx, &mappingId);
      [mapping registerURL: childURL withID: mappingId];
      contextId = 0;

      // FIXME: + 7 to skip the BOM or what?
      mapistore_search_context_by_uri (mstoreCtx, [folderURL UTF8String] + 7,
                                       &contextId, &rootObject);
      owner = [ownerUser login];
      mapistore_indexing_record_add_mid (mstoreCtx, contextId,
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

- (void) setupBaseFolder: (NSURL *) newURL
{
  [self subclassResponsibility: _cmd];
}

@end
