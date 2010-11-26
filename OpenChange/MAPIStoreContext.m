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
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>

#import "NSArray+MAPIStore.h"
#import "NSCalendarDate+MAPIStore.h"

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"

#import "MAPIStoreContext.h"

#import "NSString+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <libmapiproxy.h>

@interface SOGoFolder (MAPIStoreProtocol)

- (BOOL) create;
- (NSException *) delete;

@end

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davContentLength;
- (void) setMAPIProperties: (NSDictionary *) properties;
- (void) MAPISave;
- (void) MAPISubmit;

@end

@implementation MAPIStoreContext : NSObject

/* sogo://username:password@{contacts,calendar,tasks,journal,notes,mail}/dossier/id */

static Class SOGoObjectK, SOGoMailAccountK, SOGoMailFolderK;
static Class NSArrayK;

static MAPIStoreMapping *mapping;
static NSMutableDictionary *contextClassMapping;

+ (void) initialize
{
  NSArray *classes;
  Class currentClass;
  NSUInteger count, max;
  NSString *moduleName;

  SOGoObjectK = [SOGoObject class];
  SOGoMailAccountK = [SOGoMailAccount class];
  SOGoMailFolderK = [SOGoMailFolder class];
  NSArrayK = [NSArray class];
  mapping = [MAPIStoreMapping sharedMapping];

  contextClassMapping = [NSMutableDictionary new];
  classes = GSObjCAllSubclassesOfClass (self);
  max = [classes count];
  for (count = 0; count < max; count++)
    {
      currentClass = [classes objectAtIndex: count];
      moduleName = [currentClass MAPIModuleName];
      NSLog (@"  registered class '%@' as handler of '%@' contexts",
             NSStringFromClass (currentClass), moduleName);
      [contextClassMapping setObject: currentClass
                              forKey: moduleName];
    }
}

+ (NSString *) MAPIModuleName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) storeMapping
{
}

static inline MAPIStoreContext *
_prepareContextClass (struct mapistore_context *newMemCtx,
                      Class contextClass, NSString *completeURLString,
                      NSString *username, NSString *password)
{
  MAPIStoreContext *context;
  MAPIStoreAuthenticator *authenticator;
  static NSMutableDictionary *registration = nil;

  if (!registration)
    registration = [NSMutableDictionary new];

  if (![registration objectForKey: contextClass])
    {
      [contextClass registerFixedMappings: mapping];
      [registration setObject: [NSNull null]
                       forKey: contextClass];
    }

  context = [contextClass new];
  [context setURI: completeURLString andMemCtx: newMemCtx];
  [context autorelease];

  authenticator = [MAPIStoreAuthenticator new];
  [authenticator setUsername: username];
  [authenticator setPassword: password];
  [context setAuthenticator: authenticator];
  [authenticator release];

  [context setupRequest];
  [context setupModuleFolder];
  [context tearDownRequest];

  return context;
}

+ (id) contextFromURI: (const char *) newUri
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
      baseURL = [NSURL URLWithString: completeURLString];
      if (baseURL)
        {
          module = [baseURL host];
          if (module)
            {
              contextClass = [contextClassMapping objectForKey: module];
              if (contextClass)
                context = _prepareContextClass (newMemCtx,
                                                contextClass,
                                                completeURLString,
                                                [baseURL user],
                                                [baseURL password]);
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
      messageCache = [NSMutableDictionary new];
      subfolderCache = [NSMutableDictionary new];
      messages = [NSMutableDictionary new];
      woContext = [WOContext contextWithRequest: nil];
      [woContext retain];
      
      moduleFolder = nil;
      uri = nil;
      baseContextSet = NO;
    }

  [self logWithFormat: @"-init"];

  return self;
}

- (void) dealloc
{
  [self logWithFormat: @"-dealloc: %@", self];

  [messageCache release];
  [subfolderCache release];
  [messages release];

  [moduleFolder release];
  [woContext release];
  [authenticator release];

  [uri release];

  [super dealloc];
}

- (void) setURI: (NSString *) newUri
      andMemCtx: (struct mapistore_context *) newMemCtx
{
  struct loadparm_context *lpCtx;

  ASSIGN (uri, newUri);
  memCtx = newMemCtx;

  lpCtx = loadparm_init (newMemCtx);
  ldbCtx = mapiproxy_server_openchange_ldb_init (lpCtx);
}

- (void) setAuthenticator: (MAPIStoreAuthenticator *) newAuthenticator
{
  ASSIGN (authenticator, newAuthenticator);
}

- (MAPIStoreAuthenticator *) authenticator
{
  return authenticator;
}

- (void) setupRequest
{
  NSMutableDictionary *info;

  [MAPIApp setMAPIStoreContext: self];
  info = [[NSThread currentThread] threadDictionary];
  [info setObject: woContext forKey:@"WOContext"];
}

- (void) tearDownRequest
{
  NSMutableDictionary *info;

  info = [[NSThread currentThread] threadDictionary];
  [info removeObjectForKey:@"WOContext"];
  [MAPIApp setMAPIStoreContext: nil];
}

- (void) setupModuleFolder
{
  [self subclassResponsibility: _cmd];
}

// - (void) _setNewLastObject: (id) newLastObject
// {
//   id currentObject, container;

//   if (newLastObject != lastObject)
//     {
//       currentObject = lastObject;
//       while (currentObject)
//         {
//           container = [currentObject container];
//           [currentObject release];
//           currentObject = container;
//         }

//       currentObject = newLastObject;
//       while (currentObject)
//         {
//           [currentObject retain];
//           currentObject = [currentObject container];
//         }

//       lastObject = newLastObject;
//     }
// }

- (id) lookupObject: (NSString *) objectURLString
{
  id object;
  NSURL *objectURL;
  NSArray *path;
  int count, max;
  NSString *pathString, *nameInContainer;

  objectURL = [NSURL URLWithString: objectURLString];
  if (objectURL)
    {
      object = moduleFolder;

      pathString = [objectURL path];
      if ([pathString hasPrefix: @"/"])
        pathString = [pathString substringFromIndex: 1];
      if ([pathString length] > 0)
        {
          path = [pathString componentsSeparatedByString: @"/"];
          max = [path count];
          if (max > 0)
            {
              for (count = 0;
                   object && count < max;
                   count++)
                {
                  nameInContainer = [[path objectAtIndex: count]
                                      stringByUnescapingURL];
                  object = [object lookupName: nameInContainer
                                    inContext: woContext
                                      acquire: NO];
                  if ([object isKindOfClass: SOGoObjectK])
                    [woContext setClientObject: object];
                  else
                    object = nil;
                }
            }
        }
  
      // [self _setNewLastObject: object];
      // ASSIGN (lastObjectURL, objectURLString);
    }
  else
    {
      object = nil;
      [self errorWithFormat: @"url string gave nil NSURL: '%@'", objectURLString];
    }

  [woContext setClientObject: object];
        
  return object;
}

- (NSString *) _createFolder: (struct SRow *) aRow
                 inParentURL: (NSString *) parentFolderURL
{
  NSString *newFolderURL;
  NSString *folderName, *nameInContainer;
  SOGoFolder *parentFolder, *newFolder;
  int i;

  newFolderURL = nil;

  folderName = nil;
  for (i = 0; !folderName && i < aRow->cValues; i++)
    {
      if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME_UNICODE)
        folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszW];
      else if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME)
        folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszA];
    }

  if (folderName)
    {
      parentFolder = [self lookupObject: parentFolderURL];
      if (parentFolder)
        {
          if ([parentFolder isKindOfClass: SOGoMailAccountK]
              || [parentFolder isKindOfClass: SOGoMailFolderK])
            {
              nameInContainer = [NSString stringWithFormat: @"folder%@",
                                          [folderName asCSSIdentifier]];
              newFolder = [SOGoMailFolderK objectWithName: nameInContainer
                                              inContainer: parentFolder];
              if ([newFolder create])
                newFolderURL = [NSString stringWithFormat: @"%@/%@",
                                         parentFolderURL,
                                         [nameInContainer stringByEscapingURL]];
            }
        }
    }

  return newFolderURL;
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
  NSString *folderURL, *parentFolderURL;
  int rc;

  [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    rc = MAPISTORE_ERR_EXIST;
  else
    {
      parentFolderURL = [mapping urlFromID: parentFID];
      if (!parentFolderURL)
        [self errorWithFormat: @"No url found for FID: %lld", parentFID];
      if (parentFolderURL)
        {
          folderURL = [self _createFolder: aRow inParentURL: parentFolderURL];
          if (folderURL)
            {
              [mapping registerURL: folderURL withID: fid];
              // if ([sogoFolder isKindOfClass: SOGoMailAccountK])
              //         [sogoFolder subscribe];
              rc = MAPISTORE_SUCCESS;
            }
          else
            rc = MAPISTORE_ERR_NOT_FOUND;
        }
      else
        rc = MAPISTORE_ERR_NO_DIRECTORY;
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
    inParentFID: (uint64_t) parentFID
{
  [self logWithFormat: @"UNIMPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_ERROR;
}


/**
   \details Close a folder from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
- (int) closeDir
{
  [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_SUCCESS;
}

- (NSArray *) _messageKeysForFolderURL: (NSString *) folderURL
{
  NSArray *keys;
  SOGoFolder *folder;

  keys = [messageCache objectForKey: folderURL];
  if (!keys)
    {
      folder = [self lookupObject: folderURL];
      if (folder)
        keys = [self getFolderMessageKeys: folder];
      else
        keys = (NSArray *) [NSNull null];
      [messageCache setObject: keys forKey: folderURL];
    }

  return keys;
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
{
  [self subclassResponsibility: _cmd];
  
  return (NSArray *) [NSNull null];
}

- (NSArray *) _subfolderKeysForFolderURL: (NSString *) folderURL
{
  NSArray *keys;
  SOGoFolder *folder;

  keys = [subfolderCache objectForKey: folderURL];
  if (!keys)
    {
      folder = [self lookupObject: folderURL];
      if (folder)
        {
          keys = [folder toManyRelationshipKeys];
          if (!keys)
            keys = (NSArray *) [NSNull null];
        }
      else
        keys = (NSArray *) [NSNull null];
      [subfolderCache setObject: keys forKey: folderURL];
    }

  return keys;
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
  NSArray *ids;
  NSString *url;
  int rc;

  [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  url = [mapping urlFromID: fid];
  if (url)
    {
      switch (tableType)
        {
        case MAPISTORE_FOLDER_TABLE:
          ids = [self _subfolderKeysForFolderURL: url];
          break;
        case MAPISTORE_MESSAGE_TABLE:
          ids = [self _messageKeysForFolderURL: url];
          break;
        default:
          [self errorWithFormat: @"%s: value of tableType not handled: %d",
                __FUNCTION__, tableType];
          rc = MAPISTORE_ERR_INVALID_PARAMETER;
          ids = nil;
        }
      
      if ([ids isKindOfClass: NSArrayK])
        {
          rc = MAPI_E_SUCCESS;
          *rowCount = [ids count];
        }
      else
        rc = MAPISTORE_ERR_NO_DIRECTORY;
    }
  else
    {
      [self errorWithFormat: @"No url found for FID: %lld", fid];
      rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) getCommonTableChildproperty: (void **) data
                              atURL: (NSString *) childURL
                            withTag: (uint32_t) proptag
                           inFolder: (SOGoFolder *) folder
                            withFID: (uint64_t) fid
{
  // NSString *stringValue;
  id child;
  // uint64_t *llongValue;
  // uint32_t *longValue;
  int rc;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_DISPLAY_NAME_UNICODE:
      child = [self lookupObject: childURL];
      *data = [[child displayName] asUnicodeInMemCtx: memCtx];
      break;
    default:
      // *data = NULL;
      rc = MAPI_E_NOT_FOUND;
      // if ((proptag & 0x001F) == 0x001F)
      //   {
      //     stringValue = [NSString stringWithFormat: @"Unhandled unicode value: 0x%x", proptag];
      //     *data = [stringValue asUnicodeInMemCtx: memCtx];
      //     rc = MAPI_E_SUCCESS;
          [self errorWithFormat: @"Unknown proptag (returned): %.8x for child '%@'",
                proptag, childURL];
      //   }
      // else
      //   {
      //     [self errorWithFormat: @"Unknown proptag: %.8x for child '%@'",
      //           proptag, childURL];
          // *data = NULL;
	  rc = MAPI_E_NOT_FOUND;
          break;
        }

  return rc;
}

- (int) getMessageTableChildproperty: (void **) data
                               atURL: (NSString *) childURL
                             withTag: (uint32_t) proptag
                            inFolder: (SOGoFolder *) folder
                             withFID: (uint64_t) fid
{
  int rc;
  uint32_t contextId;
  uint64_t mappingId;
  NSString *folderURL;
  id child;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_INST_ID: // TODO: DOUBT
      /* we return a unique id based on the url */
      *data = MAPILongLongValue (memCtx, [childURL hash]);
      break;
    case PR_INSTANCE_NUM: // TODO: DOUBT
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_ROW_TYPE: // TODO: DOUBT
      *data = MAPILongValue (memCtx, TBL_LEAF_ROW);
      break;
    case PR_DEPTH: // TODO: DOUBT
      *data = MAPILongLongValue (memCtx, 0);
      break;
    case PR_ACCESS: // TODO
      *data = MAPILongValue (memCtx, 0x02);
      break;
    case PR_ACCESS_LEVEL: // TODO
      *data = MAPILongValue (memCtx, 0x00000000);
      break;
    case PR_VD_VERSION:
      /* mandatory value... wtf? */
      *data = MAPILongValue (memCtx, 8);
      break;
    case PR_FID:
      *data = MAPILongLongValue (memCtx, fid);
      break;
    case PR_MID:
      mappingId = [mapping idFromURL: childURL];
      if (mappingId == NSNotFound)
        {
          openchangedb_get_new_folderID (ldbCtx, &mappingId);
          [mapping registerURL: childURL withID: mappingId];
          folderURL = [mapping urlFromID: fid];
          NSAssert (folderURL != nil,
                    @"folder URL is expected to be known here");
          contextId = 0;
          mapistore_search_context_by_uri (memCtx, [uri UTF8String] + 7,
                                           &contextId);
          NSAssert (contextId > 0, @"no matching context found");
          mapistore_indexing_record_add_mid (memCtx, contextId, mappingId);
        }
      *data = MAPILongLongValue (memCtx, mappingId);
      break;
    case PR_MESSAGE_CODEPAGE:
      *data = MAPILongValue (memCtx, 0x0000); // use folder object codepage
      break;
    case PR_MESSAGE_LOCALE_ID:
      *data = MAPILongValue (memCtx, 0x0409);
      break;
    case PR_MESSAGE_FLAGS: // TODO
      *data = MAPILongValue (memCtx, 0x02 | 0x20); // fromme + unmodified
      break;
    case PR_MESSAGE_SIZE: // TODO
      child = [self lookupObject: childURL];
      /* TODO: choose another name in SOGo for that method */
      *data = MAPILongValue (memCtx, [[child davContentLength] intValue]);
      break;
    case PR_MSG_STATUS: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_SUBJECT_PREFIX_UNICODE: // TODO
      *data = [@"" asUnicodeInMemCtx: memCtx];
      break;
    case PR_IMPORTANCE: // TODO -> subclass?
      *data = MAPILongValue (memCtx, 1);
      break;
    case PR_PRIORITY: // TODO -> subclass?
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_SENSITIVITY: // TODO -> subclass in calendar
      *data = MAPILongValue (memCtx, 0);
      break;

      /* those are queried while they really pertain to the
         addressbook module */
      // #define PR_OAB_LANGID                                       PROP_TAG(PT_LONG      , 0x6807) /* 0x68070003 */
      // case PR_OAB_NAME_UNICODE:
      // case PR_OAB_CONTAINER_GUID_UNICODE:

      // 0x68420102  PidTagScheduleInfoDelegatorWantsCopy (BOOL)

    default:
      rc = [self getCommonTableChildproperty: data
                                       atURL: childURL
                                     withTag: proptag
                                    inFolder: folder
                                     withFID: fid];
    }

  return rc;
}

- (NSString *) _parentURLFromURL: (NSString *) urlString
{
  NSString *newURL;
  NSArray *parts;
  NSMutableArray *newParts;

  parts = [urlString componentsSeparatedByString: @"/"];
  if ([parts count] > 3)
    {
      newParts = [parts mutableCopy];
      [newParts autorelease];
      [newParts removeLastObject];
      newURL = [newParts componentsJoinedByString: @"/"];
    }
  else
    newURL = nil;

  return newURL;
}

- (int) getFolderTableChildproperty: (void **) data
                              atURL: (NSString *) childURL
                            withTag: (uint32_t) proptag
                           inFolder: (SOGoFolder *) folder
                            withFID: (uint64_t) fid
{
  // id child;
  struct Binary_r *binaryValue;
  uint32_t contextId;
  uint64_t mappingId;
  int rc;
  NSString *folderURL;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_FID:
       mappingId = [mapping idFromURL: childURL];
       if (mappingId == NSNotFound)
         {
           openchangedb_get_new_folderID (ldbCtx, &mappingId);
           [mapping registerURL: childURL withID: mappingId];
           folderURL = [mapping urlFromID: fid];
           NSAssert (folderURL != nil,
                     @"folder URL is expected to be known here");
           contextId = 0;
           mapistore_search_context_by_uri (memCtx, [uri UTF8String] + 7,
                                            &contextId);
           NSAssert (contextId > 0, @"no matching context found");
           mapistore_indexing_record_add_fid (memCtx, contextId, mappingId);
         }
        //   mappingId = [mapping idFromURL: childURL];
        // }
      *data = MAPILongLongValue (memCtx, mappingId);
      break;
    case PR_PARENT_FID:
      *data = MAPILongLongValue (memCtx, fid);
      break;
    case PR_ATTR_HIDDEN:
    case PR_ATTR_SYSTEM:
    case PR_ATTR_READONLY:
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_SUBFOLDERS:
      *data = MAPIBoolValue (memCtx,
                             [[self _subfolderKeysForFolderURL: childURL]
                               count] > 0);
      break;
    case PR_CONTENT_COUNT:
      *data = MAPILongValue (memCtx,
                             [[self _messageKeysForFolderURL: childURL]
                               count]);
      break;
    case PR_EXTENDED_FOLDER_FLAGS: // TODO: DOUBT: how to indicate the
      // number of subresponses ?
      binaryValue = talloc_zero(memCtx, struct Binary_r);
      *data = binaryValue;
      break;
    default:
      rc = [self getCommonTableChildproperty: data
                                       atURL: childURL
                                     withTag: proptag
                                    inFolder: folder
                                     withFID: fid];
    }

  return rc;
}

- (int) getTableProperty: (void **) data
                 withTag: (uint32_t) proptag
              atPosition: (uint32_t) pos
           withTableType: (uint8_t) tableType
                   inFID: (uint64_t) fid
{
  NSArray *children;
  NSString *folderURL, *childURL, *childName;
  SOGoFolder *folder;
  int rc;

  // [self logWithFormat: @"METHOD '%s' (%d) -- proptag: 0x%.8x, pos: %ld, tableType: %d, fid: %lld",
  //       __FUNCTION__, __LINE__, proptag, pos, tableType, fid];

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    {
      folder = [self lookupObject: folderURL];
      switch (tableType)
        {
        case MAPISTORE_FOLDER_TABLE:
          children = [self _subfolderKeysForFolderURL: folderURL];
          break;
        case MAPISTORE_MESSAGE_TABLE:
          children = [self _messageKeysForFolderURL: folderURL];
          break;
        default:
          [self errorWithFormat: @"%s: value of tableType not handled: %d",
                __FUNCTION__, tableType];
          children = nil;
          break;
        }

      if ([children count] > pos)
        {
          childName = [children objectAtIndex: pos];
          childURL = [folderURL stringByAppendingFormat: @"/%@",
                                [childName stringByEscapingURL]];

          if (tableType == MAPISTORE_FOLDER_TABLE)
            {
              [self logWithFormat: @"  querying child folder at URL: %@", childURL];
              rc = [self getFolderTableChildproperty: data
                                               atURL: childURL
                                             withTag: proptag
                                            inFolder: folder
                                             withFID: fid];
            }
          else
            {
              // [self logWithFormat: @"  querying child message at URL: %@", childURL];
              rc = [self getMessageTableChildproperty: data
                                                atURL: childURL
                                              withTag: proptag
                                             inFolder: folder
                                              withFID: fid];
            }
          /* Unhandled: */
          // #define PR_EXPIRY_TIME                                      PROP_TAG(PT_SYSTIME   , 0x0015) /* 0x00150040 */
          // #define PR_REPLY_TIME                                       PROP_TAG(PT_SYSTIME   , 0x0030) /* 0x00300040 */
          // #define PR_SENSITIVITY                                      PROP_TAG(PT_LONG      , 0x0036) /* 0x00360003 */
          // #define PR_MESSAGE_DELIVERY_TIME                            PROP_TAG(PT_SYSTIME   , 0x0e06) /* 0x0e060040 */
          // #define PR_FOLLOWUP_ICON                                    PROP_TAG(PT_LONG      , 0x1095) /* 0x10950003 */
          // #define PR_ITEM_TEMPORARY_FLAGS                             PROP_TAG(PT_LONG      , 0x1097) /* 0x10970003 */
          // #define PR_SEARCH_KEY                                       PROP_TAG(PT_BINARY    , 0x300b) /* 0x300b0102 */
          // #define PR_CONTENT_COUNT                                    PROP_TAG(PT_LONG      , 0x3602) /* 0x36020003 */
          // #define PR_CONTENT_UNREAD                                   PROP_TAG(PT_LONG      , 0x3603) /* 0x36030003 */
          // #define PR_FID                                              PROP_TAG(PT_I8        , 0x6748) /* 0x67480014 */
          // unknown 36de0003 http://social.msdn.microsoft.com/Forums/en-US/os_exchangeprotocols/thread/17c68add-1f62-4b68-9d83-f9ec7c1c6c9b
          // unknown 819d0003
          // unknown 81f80003
          // unknown 81fa000b

        }
      else
        rc = MAPISTORE_ERROR;
    }
  else
    {
      [self errorWithFormat: @"No url found for FID: %lld", fid];
      rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) openMessage: (struct mapistore_message *) msg
            withMID: (uint64_t) mid
              inFID: (uint64_t) fid
{
  NSString *childURL;
  int rc;

  childURL = [mapping urlFromID: mid];
  if (childURL)
    {
      rc = [self openMessage: msg atURL: childURL];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) openMessage: (struct mapistore_message *) msg
              atURL: (NSString *) childURL
{
  [self logWithFormat: @"UNIMPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_ERROR;
}

- (int) createMessagePropertiesWithMID: (uint64_t) mid
                                 inFID: (uint64_t) fid
{
  NSMutableDictionary *newMessage;
  NSNumber *midNbr;

  newMessage = [NSMutableDictionary new];
  [newMessage setObject: [NSNumber numberWithUnsignedLongLong: fid]
                 forKey: @"fid"];
  midNbr = [NSNumber numberWithUnsignedLongLong: mid];
  [newMessage setObject: midNbr forKey: @"mid"];
  [messages setObject: newMessage forKey: midNbr];
  [newMessage release];

  return MAPISTORE_SUCCESS;
}

- (id) createMessageInFolder: (id) parentFolder
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (id) _createMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
{
  NSString *folderURL, *messageURL;
  SOGoFolder *parentFolder;
  id message;

  message = nil;

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    {
      parentFolder = [self lookupObject: folderURL];
      if (parentFolder)
        {
          message = [self createMessageInFolder: parentFolder];
          if (message)
            {
              if (![folderURL hasSuffix: @"/"])
                folderURL = [NSString stringWithFormat: @"%@/", folderURL];
              messageURL = [NSString stringWithFormat: @"%@%@", folderURL,
                                     [message nameInContainer]];
              [mapping registerURL: messageURL withID: mid];
            }
        }
    }
  else
    [self errorWithFormat: @"registered message without a valid fid (%.16x)", fid];

  return message;
}

- (int) _saveOrSubmitChangesInMessageWithMID: (uint64_t) mid
                                    andFlags: (uint8_t) flags
                                        save: (BOOL) isSave
{
  int rc;
  id message;
  NSMutableDictionary *messageProperties;
  NSString *messageURL;
  uint64_t fid;

  messageProperties = [messages objectForKey:
                                  [NSNumber numberWithUnsignedLongLong: mid]];
  if (messageProperties)
    {
      messageURL = [mapping urlFromID: mid];
      if (messageURL)
        message = [self lookupObject: messageURL];
      else
        {
          fid = [[messageProperties objectForKey: @"fid"]
                  unsignedLongLongValue];
          message = [self _createMessageWithMID: mid inFID: fid];
        }
      if (message)
        {
          [message setMAPIProperties: messageProperties];
          if (isSave)
            [message MAPISave];
          else
            [message MAPISubmit];
          rc = MAPISTORE_SUCCESS;
        }
      else
        rc = MAPISTORE_ERROR;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) saveChangesInMessageWithMID: (uint64_t) mid
                           andFlags: (uint8_t) flags
{
  return [self _saveOrSubmitChangesInMessageWithMID: mid
                                           andFlags: flags
                                               save: YES];
}

- (int) submitMessageWithMID: (uint64_t) mid
                    andFlags: (uint8_t) flags
{
  return [self _saveOrSubmitChangesInMessageWithMID: mid
                                           andFlags: flags
                                               save: NO];
}

- (int) getProperties: (struct SPropTagArray *) sPropTagArray
          ofTableType: (uint8_t) tableType
                inRow: (struct SRow *) aRow
              withMID: (uint64_t) fmid
{
  NSString *childURL;
  int rc;

  childURL = [mapping urlFromID: fmid];
  if (childURL)
    {
      switch (tableType)
        {
        case MAPISTORE_MESSAGE:
          rc = [self getMessageProperties: sPropTagArray inRow: aRow
                                    atURL: childURL];
          break;
        case MAPISTORE_FOLDER:
        default:
          [self errorWithFormat: @"%s: value of tableType not handled: %d",
                __FUNCTION__, tableType];
          rc = MAPISTORE_ERROR;
          break;
        }
    }
  else
    {
      [self errorWithFormat: @"No url found for FMID: %lld", fmid];
      rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) getMessageProperties: (struct SPropTagArray *) sPropTagArray
                       inRow: (struct SRow *) aRow
                       atURL: (NSString *) childURL
{
  id child;
  NSInteger count;
  void *propValue;
  uint32_t tag;
  int rc;

  child = [self lookupObject: childURL];
  if (child)
    {
      aRow->lpProps = talloc_array (aRow, struct SPropValue,
                                    sPropTagArray->cValues);
      for (count = 0; count < sPropTagArray->cValues; count++)
        {
          tag = sPropTagArray->aulPropTag[count];
          if ([self getMessageTableChildproperty: &propValue
                                           atURL: childURL
                                         withTag: tag
                                        inFolder: nil
                                         withFID: 0]
              == MAPI_E_SUCCESS)
            {
	      set_SPropValue_proptag (&(aRow->lpProps[aRow->cValues]),
				      tag, propValue);
	      aRow->cValues++;
	    }
        }
      rc = MAPI_E_SUCCESS;
    }
  else
    rc = MAPI_E_NOT_FOUND;

  return rc;
}

// struct indexing_context_list {
// 	struct tdb_wrap			*index_ctx;
// 	char				*username;
// 	uint32_t			ref_count;
// 	struct indexing_context_list	*prev;
// 	struct indexing_context_list	*next;
// };

// struct tdb_wrap {
// 	struct tdb_context	*tdb;
// 	const char		*name;
// 	struct tdb_wrap		*prev;
// 	struct tdb_wrap		*next;
// };

- (int) getPath: (char **) path
         ofFMID: (uint64_t) fmid
  withTableType: (uint8_t) tableType
{
  int rc;
  NSString *objectURL;
  // TDB_DATA key, dbuf;

  objectURL = [mapping urlFromID: fmid];
  if (objectURL)
    {
      if ([objectURL hasPrefix: uri])
        {
          *path = [[objectURL substringFromIndex: 7] asUnicodeInMemCtx: memCtx];
          rc = MAPISTORE_SUCCESS;
        }
      else
        {
          /* An id was found that is not part of this context...x */
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

  [self logWithFormat: @"getPath....  %lld -> (%s, %d)", fmid, *path, rc];

  return rc;
}

- (int) getFID: (uint64_t *) fid
        byName: (const char *) foldername
   inParentFID: (uint64_t) parent_fid
{
  [self logWithFormat: @"METHOD '%s' (%d) -- foldername: %s, parent_fid: %lld",
        __FUNCTION__, __LINE__, foldername, parent_fid];

  return MAPISTORE_ERROR;
}

- (int) setPropertiesWithFMID: (uint64_t) fmid
                  ofTableType: (uint8_t) tableType
                        inRow: (struct SRow *) aRow
{
  NSMutableDictionary *message;
  NSNumber *midNbr;
  struct SPropValue *cValue;
  NSUInteger counter;
  int rc;

  switch (tableType)
    {
    case MAPISTORE_MESSAGE:
      midNbr = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midNbr];
      if (message)
	{
	  for (counter = 0; counter < aRow->cValues; counter++)
	    {
	      cValue = &(aRow->lpProps[counter]);
	      [message setObject: NSObjectFromSPropValue (cValue)
                          forKey: MAPIPropertyNumber (cValue->ulPropTag)];
	    }
	  rc = MAPISTORE_SUCCESS;
	}
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
      break;
    case MAPISTORE_FOLDER:
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
            __FUNCTION__, tableType];
      rc = MAPISTORE_ERROR;
    }

  return rc;
}

- (int) setProperty: (enum MAPITAGS) property
	   withFMID: (uint64_t) fmid
	ofTableType: (uint8_t) tableType
	   fromFile: (NSFileHandle *) aFile
{
  NSMutableDictionary *message;
  NSNumber *midNbr;
  NSData *fileData;
  int rc;

  fileData = [aFile readDataToEndOfFile];
  switch (tableType)
    {
    case MAPISTORE_MESSAGE:
      midNbr = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midNbr];
      if (message)
	{
	  [message setObject: NSObjectFromStreamData (property, fileData)
		   forKey: MAPIPropertyNumber (property)];
	  rc = MAPISTORE_SUCCESS;
	}
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
      break;
    case MAPISTORE_FOLDER:
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
            __FUNCTION__, tableType];
      rc = MAPISTORE_ERROR;
    }

  return rc;
}

- (NSDictionary *) _convertRecipientFromRow: (struct RecipientRow *) row
{
  NSMutableDictionary *recipient;
  NSString *value;

  recipient = [NSMutableDictionary dictionaryWithCapacity: 5];

  if ((row->RecipientFlags & 0x07) == 1)
    {
      value = [NSString stringWithUTF8String: row->X500DN.recipient_x500name];
      [recipient setObject: value forKey: @"x500dn"];
    }

  switch ((row->RecipientFlags & 0x208))
    {
    case 0x08:
      // TODO: we cheat
      value = [NSString stringWithUTF8String: row->EmailAddress.lpszA];
      break;
    case 0x208:
      value = [NSString stringWithUTF8String: row->EmailAddress.lpszW];
      break;
    default:
      value = nil;
    }
  if (value)
    [recipient setObject: value forKey: @"email"];

  switch ((row->RecipientFlags & 0x210))
    {
    case 0x10:
      // TODO: we cheat
      value = [NSString stringWithUTF8String: row->DisplayName.lpszA];
      break;
    case 0x210:
      value = [NSString stringWithUTF8String: row->DisplayName.lpszW];
      break;
    default:
      value = nil;
    }
  if (value)
    [recipient setObject: value forKey: @"fullName"];

  return recipient;
}

- (int) modifyRecipientsWithMID: (uint64_t) mid
			 inRows: (struct ModifyRecipientRow *) rows
		      withCount: (NSUInteger) max
{
  static NSString *recTypes[] = { @"orig", @"to", @"cc", @"bcc" };
  NSMutableDictionary *message, *recipients;
  NSMutableArray *list;
  NSString *recType;
  struct ModifyRecipientRow *currentRow;
  NSUInteger count;
  int rc;

  message = [messages
	      objectForKey: [NSNumber numberWithUnsignedLongLong: mid]];
  if (message)
    {
      recipients = [NSMutableDictionary new];
      [message setObject: recipients forKey: @"recipients"];
      [recipients release];
      for (count = 0; count < max; count++)
	{
	  currentRow = rows + count;
	  if (currentRow->RecipClass >= 0
	      && currentRow->RecipClass < 3)
	    {
	      recType = recTypes[currentRow->RecipClass];
	      list = [recipients objectForKey: recType];
	      if (!list)
		{
		  list = [NSMutableArray new];
		  [recipients setObject: list forKey: recType];
		  [list release];
		}
	      [list addObject: [self _convertRecipientFromRow:
				       &(currentRow->RecipientRow)]];
	    }
	}
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) deleteMessageWithMID: (uint64_t) mid
                   withFlags: (uint8_t) flags
{
  [self logWithFormat: @"UNIMPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_ERROR;
}

- (int) getFoldersList: (struct indexing_folders_list **) folders_list
              withFMID: (uint64_t) fmid
{
  int rc;
  NSString *currentURL;
  NSMutableArray *nsFolderList;
  uint64_t fid;

  rc = MAPI_E_SUCCESS;

  currentURL = [mapping urlFromID: fmid];
  if (currentURL && ![currentURL isEqualToString: uri]
      && [currentURL hasPrefix: uri])
    {
      nsFolderList = [NSMutableArray arrayWithCapacity: 32];
      currentURL = [self _parentURLFromURL: currentURL];
      while (currentURL && rc == MAPI_E_SUCCESS
             && ![currentURL isEqualToString: uri])
        {
          fid = [mapping idFromURL: currentURL];
          if (fid == NSNotFound)
            rc = MAPI_E_NOT_FOUND;
          else
            {
              [nsFolderList insertObject: [NSNumber numberWithUnsignedLongLong: fid]
                                 atIndex: 0];
              currentURL = [self _parentURLFromURL: currentURL];
            }
        }

      if (rc != MAPI_E_NOT_FOUND)
        {
          fid = [mapping idFromURL: uri];
          [nsFolderList insertObject: [NSNumber numberWithUnsignedLongLong: fid]
                             atIndex: 0];
          *folders_list = [nsFolderList asFoldersListInCtx: memCtx];
        }
    }
  else
    rc = MAPI_E_NOT_FOUND;

  return rc;
}

@end
