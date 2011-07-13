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
static NSMutableDictionary *userMAPIStoreMapping;

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

  userMAPIStoreMapping = [NSMutableDictionary new];
}

static inline MAPIStoreContext *
_prepareContextClass (struct mapistore_context *newMemCtx,
                      Class contextClass,
                      struct mapistore_connection_info *connInfo,
                      NSURL *url, uint64_t fid)
{
  static NSMutableDictionary *registration = nil;
  MAPIStoreContext *context;
  MAPIStoreAuthenticator *authenticator;

  if (!registration)
    registration = [NSMutableDictionary new];

  if (![registration objectForKey: contextClass])
    [registration setObject: [NSNull null]
                  forKey: contextClass];

  context = [[contextClass alloc] initFromURL: url
                           withConnectionInfo: connInfo
                                       andFID: fid
                                     inMemCtx: newMemCtx];
  [context autorelease];

  authenticator = [MAPIStoreAuthenticator new];
  [authenticator setUsername: [url user]];
  [authenticator setPassword: [url password]];
  [context setAuthenticator: authenticator];
  [authenticator release];

  [context setupRequest];
  [context setupBaseFolder: url];
  [context->folders setObject: context->baseFolder
                       forKey: [NSNumber numberWithUnsignedLongLong: fid]];
  [context tearDownRequest];

  return context;
}

+ (id) contextFromURI: (const char *) newUri
   withConnectionInfo: (struct mapistore_connection_info *) connInfo
               andFID: (uint64_t) fid
             inMemCtx: (struct mapistore_context *) newMemCtx
{
  MAPIStoreContext *context;
  Class contextClass;
  NSString *module, *completeURLString, *urlString;
  NSURL *baseURL;

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
                context = _prepareContextClass (newMemCtx,
                                                contextClass,
                                                connInfo,
                                                baseURL,
                                                fid);
              else
                NSLog (@"ERROR: unrecognized module name '%@'", module);
            }
        }
      else
        NSLog (@"ERROR: url could not be parsed");
    }
  else
    NSLog (@"ERROR: url is an invalid UTF-8 string");

  return context;
}

- (id) init
{
  if ((self = [super init]))
    {
      folders = [NSMutableDictionary new];
      woContext = [WOContext contextWithRequest: nil];
      [woContext retain];
      baseFolder = nil;
      contextUrl = nil;
      cachedTable = nil;
      cachedFolder = nil;
    }

  return self;
}

- (id)   initFromURL: (NSURL *) newUrl
  withConnectionInfo: (struct mapistore_connection_info *) newConnInfo
              andFID: (uint64_t) newFid
            inMemCtx: (struct mapistore_context *) newMemCtx
{
  NSString *username;

  if ((self = [self init]))
    {
      ASSIGN (contextUrl, newUrl);

      username = [NSString stringWithUTF8String: newConnInfo->username];
      mapping = [userMAPIStoreMapping objectForKey: username];
      if (!mapping)
        {
          [self logWithFormat: @"generating mapping of ids for user '%@'",
                username];
          mapping = [MAPIStoreMapping mappingWithIndexing: newConnInfo->indexing];
          [userMAPIStoreMapping setObject: mapping forKey: username];
        }
      if (![mapping urlFromID: newFid])
        [mapping registerURL: [newUrl absoluteString]
                      withID: newFid];
      contextFid = newFid;
   
      mstoreCtx = newConnInfo->mstore_ctx;
      connInfo = newConnInfo;
    }

  return self;
}

- (void) dealloc
{
  [folders release];
  [cachedTable release];
  [cachedFolder release];

  [baseFolder release];
  [woContext release];
  [authenticator release];

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

- (MAPIStoreObject *) _lookupObjectWithParts: (NSArray *) parts
{
  NSUInteger count, max;
  NSString *currentPart;
  MAPIStoreObject *currentObject;

  currentObject = baseFolder;
  max = [parts count];
  for (count = 0; count < max; count++)
    {
      currentPart = [parts objectAtIndex: count];
      if ([currentPart length] > 0)
        currentObject = [currentObject lookupChild: currentPart];
    }

  return currentObject;
}

- (id) lookupObject: (NSString *) childURL
{
  NSString *baseURL, *subURL;
  MAPIStoreObject *foundObject;
  NSArray *parts;

  baseURL = [contextUrl absoluteString];
  if (![baseURL hasSuffix: @"/"])
    baseURL = [NSString stringWithFormat: @"%@/", baseURL];
  if (![childURL hasSuffix: @"/"])
    childURL = [NSString stringWithFormat: @"%@/", childURL];
  if ([childURL isEqualToString: baseURL])
    foundObject = baseFolder;
  else if ([childURL hasPrefix: baseURL])
    {
      subURL = [childURL substringFromIndex: [baseURL length]];
      parts = [subURL componentsSeparatedByString: @"/"];
      foundObject = [self _lookupObjectWithParts: parts];
      [self logWithFormat: @"returning object '%@'", childURL];
    }
  else
    {
      [self errorWithFormat: @"url '%@' is not a child of this context (%@)",
            childURL, baseURL];
      foundObject = nil;
    }

  /* TODO hierarchy */
  return foundObject;
}

- (id) lookupFolderWithFID: (uint64_t) fid
{
  MAPIStoreFolder *folder;
  NSNumber *fidKey;
  NSString *folderURL;

  fidKey = [NSNumber numberWithUnsignedLongLong: fid];
  folder = [folders objectForKey: fidKey];
  if (!folder)
    {
      /* TODO: should handle folder hierarchies */
      folderURL = [mapping urlFromID: fid];
      if (folderURL)
        {
          folder = [self lookupObject: folderURL];
          if (folder)
            [folders setObject: folder forKey: fidKey];
        }
      else
        [self errorWithFormat: @"folder with url '%@' not found", folderURL];
    }
  [folder setMAPIRetainCount: [folder mapiRetainCount] + 1];

  return folder;
}

- (void) releaseFolderWithFID: (uint64_t) fid
{
  MAPIStoreFolder *folder;
  NSNumber *fidKey;
  uint32_t retainCount;

  fidKey = [NSNumber numberWithUnsignedLongLong: fid];
  folder = [folders objectForKey: fidKey];
  if (folder)
    {
      retainCount = [folder mapiRetainCount];
      if (retainCount == 1)
        [folders removeObjectForKey: fidKey];
      else
        [folder setMAPIRetainCount: retainCount - 1];
    }
}

/**
   \details Create a folder in the sogo backend
   
   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/

- (int) mkDir: (struct SRow *) aRow
      withFID: (uint64_t) fid
  inParentFID: (uint64_t) parentFID
{
  NSString *folderURL, *folderKey;
  MAPIStoreFolder *parentFolder, *newFolder;
  NSNumber *fidKey;
  int rc;

  [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    rc = MAPISTORE_ERR_EXIST;
  else
    {
      fidKey = [NSNumber numberWithUnsignedLongLong: parentFID];
      parentFolder = [folders objectForKey: fidKey];
      if (parentFolder)
        {
          folderKey = [parentFolder createFolder: aRow withFID: fid];
          if (folderKey)
            {
              [parentFolder cleanupCaches];
              folderURL = [NSString stringWithFormat: @"%@%@",
                                    [parentFolder url], folderKey];
              [mapping registerURL: folderURL withID: fid];
              newFolder = [parentFolder lookupChild: folderKey];
              if (newFolder)
                [newFolder setProperties: aRow];
              else
                [NSException raise: @"MAPIStoreIOException"
                            format: @"unable to fetch created folder"];
              rc = MAPISTORE_SUCCESS;
            }
          else
            rc = MAPISTORE_ERROR;
        }
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}


/**
   \details Delete a folder from the sogo backend

   \param private_data pointer to the current sogo context
   \param parentFID the FID for the parent of the folder to delete
   \param fid the FID for the folder to delete

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
- (int) rmDirWithFID: (uint64_t) fid
         inParentFID: (uint64_t) parentFid
{
  [self logWithFormat: @"UNIMPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_ERROR;
}


/**
   \details Open a folder from the sogo backend

   \param private_data pointer to the current sogo context
   \param parentFID the parent folder identifier
   \param fid the identifier of the colder to open

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
- (int) openDir: (uint64_t) fid
{
  MAPIStoreFolder *folder;
  int rc;

  folder = [self lookupFolderWithFID: fid];
  if (folder)
    rc = MAPISTORE_SUCCESS;
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

/**
   \details Close a folder from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
- (int) closeDir
{
  // MAPIStoreFolder *folder;
  // NSNumber *fidKey;
  // uint32_t retainCount;

  // fidKey = [NSNumber numberWithUnsignedLongLong: fid];
  // folder = [folders objectForKey: fidKey];
  // if (folder)
  //   {
  //     rc = MAPISTORE_SUCCESS;
  //     retainCount = [folder mapiRetainCount];
  //     if (retainCount == 0)
  //       {
  //         [self logWithFormat: @"folder with fid %.16x successfully removed"
  //               @" from folder cache",
  //               fmid];
  //         [folders removeObjectForKey: midKey];
  //       }
  //     else
  //       [folder setMAPIRetainCount: retainCount - 1];
  //   }
  // else
  //   rc = MAPISTORE_ERR_NOT_FOUND;

  [self logWithFormat: @"UNIMNPLEMENTED METHOD '%s' -- leak ahead (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_SUCCESS;
}

- (MAPIStoreTable *) _tableForFID: (uint64_t) fid
		     andTableType: (uint8_t) tableType
{
  MAPIStoreFolder *folder;
  MAPIStoreTable *table;
  NSNumber *fidKey;

  if (fid == cachedTableFID && tableType == cachedTableType)
    table = cachedTable;
  else
    {
      [cachedTable release];
      cachedTable = nil;
      [cachedFolder release];
      cachedFolder = nil;
      cachedTableFID = 0;
      cachedTableType = 0;

      fidKey = [NSNumber numberWithUnsignedLongLong: fid];
      folder = [folders objectForKey: fidKey];
      if (folder)
        {
          if (tableType == MAPISTORE_MESSAGE_TABLE)
            table = [folder messageTable];
          else if (tableType == MAPISTORE_FAI_TABLE)
            table = [folder faiMessageTable];
          else if (tableType == MAPISTORE_FOLDER_TABLE)
            table = [folder folderTable];
          else
            {
              table = nil;
              [NSException raise: @"MAPIStoreIOException"
                          format: @"unsupported table type: %d", tableType];
            }

          if (table)
            {
              cachedTableFID = fid;
              cachedTableType = tableType;
              ASSIGN (cachedTable, table);
              ASSIGN (cachedFolder, folder);
            }
        }
      else
        {
          table = nil;
          [self errorWithFormat: @"folder with fid %Lu not found",
                (unsigned long long) fid];
        }
    }

  return table;
}

/**
   \details Read directory content from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
- (int) readCount: (uint32_t *) rowCount
      ofTableType: (uint8_t) tableType
            inFID: (uint64_t) fid
{
  NSArray *keys;
  NSString *url;
  NSNumber *fidKey;
  MAPIStoreFolder *folder;
  int rc;

  /* WARNING: make sure this method is no longer invoked for counting
     table elements */
  [self logWithFormat: @"METHOD '%s' (%d) -- tableType: %d",
	__FUNCTION__, __LINE__, tableType];

  url = [mapping urlFromID: fid];
  if (url)
    {
      fidKey = [NSNumber numberWithUnsignedLongLong: fid];
      folder = [folders objectForKey: fidKey];
      if (folder)
        {
          if (tableType == MAPISTORE_MESSAGE_TABLE)
            keys = [folder messageKeys];
          else if (tableType == MAPISTORE_FOLDER_TABLE)
            keys = [folder folderKeys];
          else if (tableType == MAPISTORE_FAI_TABLE)
            keys = [folder faiMessageKeys];
          *rowCount = [keys count];
          rc = MAPI_E_SUCCESS;
        }
      else
        {
          [self errorWithFormat: @"No folder found for URL: %@", url];
          rc = MAPISTORE_ERR_NOT_FOUND;
        }
    }
  else
    {
      [self errorWithFormat: @"No url found for FID: %lld", fid];
      rc = MAPISTORE_ERR_NOT_FOUND;
    }
    // }
  [self logWithFormat: @"result: count = %d, rc = %d", *rowCount, rc];

  return rc;
}

// - (void) logRestriction: (struct mapi_SRestriction *) res
// 	      withState: (MAPIRestrictionState) state
// {
//   NSString *resStr;

//   resStr = MAPIStringForRestriction (res);

//   [self logWithFormat: @"%@  -->  %@", resStr, MAPIStringForRestrictionState (state)];
// }

- (int) openMessage: (MAPIStoreMessage **) messagePtr
     andMessageData: (struct mapistore_message **) dataPtr
            withMID: (uint64_t) mid
              inFID: (uint64_t) fid
           inMemCtx: (TALLOC_CTX *) memCtx;
{
  NSString *messageKey, *messageURL;
  MAPIStoreMessage *message;
  MAPIStoreFolder *folder;
  NSNumber *fidKey;
  int rc = MAPISTORE_ERR_NOT_FOUND;

  messageURL = [mapping urlFromID: mid];
  if (messageURL)
    {
      fidKey = [NSNumber numberWithUnsignedLongLong: fid];
      folder = [folders objectForKey: fidKey];
      messageKey = [self extractChildNameFromURL: messageURL
                                  andFolderURLAt: NULL];
      message = [folder lookupChild: messageKey];
      if (message)
        {
          [message getMessageData: dataPtr inMemCtx: memCtx];
          *messagePtr = message;
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) createMessage: (MAPIStoreMessage **) messagePtr
              withMID: (uint64_t) mid
                inFID: (uint64_t) fid
         isAssociated: (BOOL) isAssociated
{
  NSNumber *fidKey;
  NSString *childURL;
  MAPIStoreMessage *message;
  MAPIStoreFolder *folder;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, fid: 0x%.16x, associated: %d",
	__FUNCTION__, mid, fid, isAssociated];

  if ([mapping urlFromID: mid])
    rc = MAPISTORE_ERR_EXIST;
  else
    {
      fidKey = [NSNumber numberWithUnsignedLongLong: fid];
      folder = [folders objectForKey: fidKey];
      if (folder)
        {
          message = [folder createMessage: isAssociated];
          if (message)
            {
              childURL = [NSString stringWithFormat: @"%@%@",
                                   [folder url], [message nameInContainer]];
              [mapping registerURL: childURL withID: mid];
              *messagePtr = message;
              rc = MAPISTORE_SUCCESS;
            }
          else
            rc = MAPISTORE_ERROR;
        }
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) getProperties: (struct SPropTagArray *) sPropTagArray
          ofTableType: (uint8_t) tableType
                inRow: (struct SRow *) aRow
              withMID: (uint64_t) fmid
             inMemCtx: (TALLOC_CTX *) memCtx
{
  NSNumber *fidKey;
  MAPIStoreObject *child;
  NSInteger count;
  void *propValue;
  const char *propName;
  enum MAPITAGS tag;
  enum MAPISTATUS propRc;
  struct mapistore_property_data *data;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, fmid, tableType];

  fidKey = [NSNumber numberWithUnsignedLongLong: fmid];
  child = [folders objectForKey: fidKey];
  if (child)
    {
      data = talloc_array (memCtx, struct mapistore_property_data,
                           sPropTagArray->cValues);
      memset (data, 0,
              sizeof (struct mapistore_property_data) * sPropTagArray->cValues);
      rc = [child getProperties: data
                       withTags: sPropTagArray->aulPropTag
                       andCount: sPropTagArray->cValues
                       inMemCtx: memCtx];
      if (rc == MAPISTORE_SUCCESS)
        {
	  aRow->lpProps = talloc_array (aRow, struct SPropValue,
					sPropTagArray->cValues);
          aRow->cValues = sPropTagArray->cValues;
	  for (count = 0; count < sPropTagArray->cValues; count++)
	    {
	      tag = sPropTagArray->aulPropTag[count];
	      propValue = data[count].data;
	      propRc = data[count].error;
	      // propName = get_proptag_name (tag);
	      // if (!propName)
	      //   propName = "<unknown>";
	      // [self logWithFormat: @"  lookup of property %s (%.8x) returned %d",
	      // 	propName, tag, propRc];
	      
	      if (propRc == MAPI_E_SUCCESS && !propValue)
		{
		  propName = get_proptag_name (tag);
		  if (!propName)
		    propName = "<unknown>";
		  [self errorWithFormat: @"both 'success' and NULL data"
			@" returned for proptag %s(0x%.8x)",
			propName, tag];
		  propRc = MAPI_E_NOT_FOUND;
		}
	      
	      if (propRc != MAPI_E_SUCCESS)
		{
                  if (propRc == MAPISTORE_ERR_NOT_FOUND)
                    propRc = MAPI_E_NOT_FOUND;
                  // else if (propRc == MAPISTORE_ERR_NO_MEMORY)
                  //   propRc = MAPI_E_NOT_ENOUGH_MEMORY;
		  if (propValue)
		    talloc_free (propValue);
		  propValue = MAPILongValue (memCtx, propRc);
		  tag = (tag & 0xffff0000) | 0x000a;
		}
              set_SPropValue_proptag (aRow->lpProps + count, tag, propValue);
	    }
	}
      talloc_free (data);
    }
  else
    {
      [self errorWithFormat: @"no message/folder found for fmid %lld", fmid];
      abort();
      rc = MAPI_E_INVALID_OBJECT;
    }

  return rc;
}

- (int) getPath: (char **) path
         ofFMID: (uint64_t) fmid
  withTableType: (uint8_t) tableType
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
          rc = MAPI_E_SUCCESS;
        }
      else
        {
	  [self logWithFormat: @"context (%@, %@) does not contain"
		@" found fmid: 0x%.16x",
		objectURL, url, fmid];
          *path = NULL;
          rc = MAPI_E_NOT_FOUND;
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
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

- (int) setPropertiesWithFMID: (uint64_t) fmid
                  ofTableType: (uint8_t) tableType
                        inRow: (struct SRow *) aRow
{
  MAPIStoreFolder *folder;
  NSNumber *fidKey;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- fid: 0x%.16x, tableType: %d",
	__FUNCTION__, fmid, tableType];

  fidKey = [NSNumber numberWithUnsignedLongLong: fmid];
  switch (tableType)
    {
    case MAPISTORE_FOLDER:
      folder = [folders objectForKey: fidKey];
      if (folder)
        rc = [folder setProperties: aRow];
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
      break;
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
            __FUNCTION__, tableType];
      [NSException raise: @"MAPIStoreIOException"
                  format: @"unsupported object type"];
      rc = MAPISTORE_ERROR;
    }

  return rc;
}

- (int) deleteMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
                   withFlags: (uint8_t) flags
{
  NSString *childURL, *childKey;
  NSNumber *fidKey;
  MAPIStoreFolder *folder;
  MAPIStoreMessage *message;
  NSArray *activeTables;
  NSUInteger count, max;
  struct mapistore_object_notification_parameters *notif_parameters;
  int rc;

  [self logWithFormat: @"-deleteMessageWithMID: mid: 0x%.16x  flags: %d", mid, flags];
  
  childURL = [mapping urlFromID: mid];
  if (childURL)
    {
      [self logWithFormat: @"-deleteMessageWithMID: url (%@) found for object", childURL];

      childKey = [self extractChildNameFromURL: childURL
                                andFolderURLAt: NULL];

      fidKey = [NSNumber numberWithUnsignedLongLong: fid];
      folder = [folders objectForKey: fidKey];

      message = [folder lookupChild: childKey];
      if (message)
        {
          /* we ensure the table caches are loaded so that old and new state
             can be compared */
          /* we ensure the table caches are loaded so that old and new state
             can be compared */
          activeTables = ([message isKindOfClass: MAPIStoreFAIMessageK]
                          ? [folder activeFAIMessageTables]
                          : [folder activeMessageTables]);
          max = [activeTables count];
          for (count = 0; count < max; count++)
            [[activeTables objectAtIndex: count] restrictedChildKeys];

          if ([[message sogoObject] delete])
            {
              rc = MAPISTORE_ERROR;
              [self logWithFormat: @"ERROR deleting object at URL: %@", childURL];
            }
          else
            {
              if (![message isNew])
                {
                  /* folder notification */
                  notif_parameters
                    = talloc_zero(NULL,
                                  struct mapistore_object_notification_parameters);
                  notif_parameters->object_id = fid;
                  notif_parameters->tag_count = 5;
                  notif_parameters->tags = talloc_array (notif_parameters,
                                                         enum MAPITAGS, 5);
                  notif_parameters->tags[0] = PR_CONTENT_COUNT;
                  notif_parameters->tags[1] = PR_DELETED_COUNT_TOTAL;
                  notif_parameters->tags[2] = PR_MESSAGE_SIZE;
                  notif_parameters->tags[3] = PR_NORMAL_MESSAGE_SIZE;
                  notif_parameters->tags[4] = PR_DELETED_MSG_COUNT;
                  notif_parameters->new_message_count = true;
                  notif_parameters->message_count = [[folder messageKeys]
                                                      count] - 1;
                  mapistore_push_notification (connInfo->mstore_ctx,
                                               MAPISTORE_FOLDER,
                                               MAPISTORE_OBJECT_MODIFIED,
                                               notif_parameters);
                  talloc_free(notif_parameters);

                  /* message notification */
                  notif_parameters
                    = talloc_zero(NULL,
                                  struct mapistore_object_notification_parameters);
                  notif_parameters->object_id = mid;
                  notif_parameters->folder_id = fid;
                  /* Exchange sends a fnevObjectCreated!! */
                  mapistore_push_notification (connInfo->mstore_ctx,
                                               MAPISTORE_MESSAGE,
                                               MAPISTORE_OBJECT_CREATED,
                                               notif_parameters);
                  talloc_free(notif_parameters);

                  /* table notification */
                  for (count = 0; count < max; count++)
                    [[activeTables objectAtIndex: count]
                      notifyChangesForChild: message];
                }
              [self logWithFormat: @"successfully deleted object at URL: %@", childURL];
              [mapping unregisterURLWithID: mid];
              [folder cleanupCaches];
              rc = MAPISTORE_SUCCESS;
            }
        }
      else
        rc = MAPI_E_INVALID_OBJECT;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

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
  uint64_t mappingId;
  uint32_t contextId;

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
      mapistore_search_context_by_uri (mstoreCtx, [folderURL UTF8String] + 7,
                                       &contextId);
      mapistore_indexing_record_add_mid (mstoreCtx, contextId, mappingId);
    }

  return mappingId;
}

/* proof of concept */
- (int) getTable: (MAPIStoreTable **) tablePtr
     andRowCount: (uint32_t *) countPtr
         withFID: (uint64_t) fid
       tableType: (uint8_t) tableType
     andHandleId: (uint32_t) handleId
{
  MAPIStoreTable *table;

  table = [self _tableForFID: fid andTableType: tableType];
  [table setHandleId: handleId];
  *countPtr = [[table childKeys] count];
  *tablePtr = table;

  return MAPISTORE_SUCCESS;
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
