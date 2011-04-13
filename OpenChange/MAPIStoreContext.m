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

static MAPIStoreMapping *mapping;
static NSMutableDictionary *contextClassMapping;

static void *ldbCtx = NULL;

+ (void) initialize
{
  NSArray *classes;
  Class currentClass;
  NSUInteger count, max;
  NSString *moduleName;

  NSDataK = [NSData class];
  NSStringK = [NSString class];
  MAPIStoreFAIMessageK = [MAPIStoreFAIMessage class];

  mapping = [MAPIStoreMapping sharedMapping];

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

static inline MAPIStoreContext *
_prepareContextClass (struct mapistore_context *newMemCtx,
                      Class contextClass,
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

  context = [[contextClass alloc] initFromURL: url andFID: fid
                                     inMemCtx: newMemCtx];
  [context autorelease];

  authenticator = [MAPIStoreAuthenticator new];
  [authenticator setUsername: [url user]];
  [authenticator setPassword: [url password]];
  [context setAuthenticator: authenticator];
  [authenticator release];

  [context setupRequest];
  [context setupBaseFolder: url];
  [context tearDownRequest];

  return context;
}

+ (id) contextFromURI: (const char *) newUri
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
      messages = [NSMutableDictionary new];
      woContext = [WOContext contextWithRequest: nil];
      [woContext retain];
      baseFolder = nil;
      contextUrl = nil;
    }

  [self logWithFormat: @"-init"];

  return self;
}

- (id) initFromURL: (NSURL *) newUrl
            andFID: (uint64_t) newFid
          inMemCtx: (struct mapistore_context *) newMemCtx
{
  struct loadparm_context *lpCtx;
  MAPIStoreMapping *mapping;

  if ((self = [self init]))
    {
      if (!ldbCtx)
        {
          lpCtx = loadparm_init (newMemCtx);
          ldbCtx = mapiproxy_server_openchange_ldb_init (lpCtx);
        }

      ASSIGN (contextUrl, newUrl);

      mapping = [MAPIStoreMapping sharedMapping];
      if (![mapping urlFromID: newFid])
        [mapping registerURL: [newUrl absoluteString]
                      withID: newFid];
      contextFid = newFid;
   
      memCtx = newMemCtx;
    }

  return self;
}

- (void) dealloc
{
  [self logWithFormat: @"-dealloc"];

  [messages release];

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

- (MAPIStoreFolder *) lookupFolder: (NSString *) folderURL
{
  /* TODO hierarchy */
  return baseFolder;
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
  NSString *folderURL, *folderKey, *parentFolderURL;
  MAPIStoreFolder *parentFolder;
  int rc;

  [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    rc = MAPISTORE_ERR_EXIST;
  else
    {
      parentFolderURL = [mapping urlFromID: parentFID];
      if (parentFolderURL)
        {
          parentFolder = [self lookupFolder: parentFolderURL];
          folderKey = [parentFolder createFolder: aRow];
          if (folderKey)
            {
              folderURL = [NSString stringWithFormat: @"%@%@/",
                                    parentFolderURL, folderKey];
              [mapping registerURL: folderURL withID: fid];
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
    inParentFID: (uint64_t) parentFID
{
  [self logWithFormat:
	  @"UNIMPLEMENTED METHOD '%s' (%d):\n fid=0x%.16x, parentFID=0x%.16x",
	__FUNCTION__, __LINE__,
	(unsigned long long) fid,
	(unsigned long long) parentFID];

  return MAPISTORE_ERROR;
}


/**
   \details Close a folder from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
- (int) closeDir
{
  [self logWithFormat: @"UNIMNPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_SUCCESS;
}

- (MAPIStoreTable *) _tableForFID: (uint64_t) fid
		     andTableType: (uint8_t) tableType
{
  MAPIStoreFolder *folder;
  MAPIStoreTable *table;
  NSString *folderURL;

/* TODO: should handle folder hierarchies */
  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    {
      folder = [self lookupFolder: folderURL];
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
        }
      else
        {
          table = nil;
          [self errorWithFormat: @"folder with url '%@' not found", folderURL];
        }
    }
  else
    {
      table = nil;
      [self errorWithFormat: @"folder with fid %Lu not found",
            (unsigned long long) fid];
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
  MAPIStoreFolder *folder;
  int rc;

  /* WARNING: make sure this method is no longer invoked for counting
     table elements */
  [self logWithFormat: @"METHOD '%s' (%d) -- tableType: %d",
	__FUNCTION__, __LINE__, tableType];

  url = [mapping urlFromID: fid];
  if (url)
    {
      folder = [self lookupFolder: url];
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

- (int) setRestrictions: (const struct mapi_SRestriction *) res
		withFID: (uint64_t) fid
	   andTableType: (uint8_t) tableType
	 getTableStatus: (uint8_t *) tableStatus
{
  MAPIStoreTable *table;

  [self errorWithFormat: @"%s: obsolete method", __FUNCTION__];

  table = [self _tableForFID: fid andTableType: tableType];
  [table setRestrictions: res];
  // FIXME: we should not flush the caches if the restrictions matches
  [table cleanupCaches];

  return MAPISTORE_SUCCESS;
}

- (int) setSortOrder: (const struct SSortOrderSet *) set
             withFID: (uint64_t) fid andTableType: (uint8_t) type
      getTableStatus: (uint8_t *) tableStatus
{
  MAPIStoreTable *table;

  [self errorWithFormat: @"%s: obsolete method", __FUNCTION__];

  table = [self _tableForFID: fid andTableType: type];
  [table setSortOrder: set];
  [table cleanupCaches];

  return MAPISTORE_SUCCESS;
}

- (enum MAPISTATUS) getTableProperty: (void **) data
			     withTag: (enum MAPITAGS) propTag
			  atPosition: (uint32_t) pos
		       withTableType: (uint8_t) tableType
			andQueryType: (enum table_query_type) queryType
			       inFID: (uint64_t) fid
{
  NSString *folderURL;
  MAPIStoreTable *table;
  MAPIStoreObject *object;
  const char *propName;
  int rc;

  [self errorWithFormat: @"%s: obsolete method", __FUNCTION__];

  // [self logWithFormat: @"METHOD '%s' (%d) -- proptag: %s (0x%.8x), pos: %.8x,"
  // 	 @" tableType: %d, queryType: %d, fid: %.16x",
  // 	__FUNCTION__, __LINE__, propName, proptag, pos, tableType, queryType, fid];

  // [self logWithFormat: @"context restriction state is: %@",
  // 	MAPIStringForRestrictionState (restrictionState)];
  // if (restriction)
  //   [self logWithFormat: @"  active qualifier: %@", restriction];

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    {
      table = [self _tableForFID: fid andTableType: tableType];
      *data = NULL;
      object = [table childAtRowID: pos forQueryType: queryType];
      if (object)
        {
          rc = [object getProperty: data withTag: propTag];
          if (rc == MAPISTORE_ERR_NOT_FOUND)
            rc = MAPI_E_NOT_FOUND;
          else if (rc == MAPISTORE_ERR_NO_MEMORY)
            rc = MAPI_E_NOT_ENOUGH_MEMORY;
          else if (rc == MAPISTORE_SUCCESS && *data == NULL)
            {
              propName = get_proptag_name (propTag);
              if (!propName)
                propName = "<unknown>";
              
              [self errorWithFormat: @"both 'success' and NULL data"
                    @" returned for proptag %s(0x%.8x)",
                    propName, propTag];
              rc = MAPI_E_NOT_FOUND;
            }
        }
      else
        rc = MAPI_E_INVALID_OBJECT;
    }
  else
    {
      [self errorWithFormat: @"No url found for FID: %lld", fid];
      rc = MAPI_E_INVALID_OBJECT;
    }

  return rc;
}

- (int) openMessage: (struct mapistore_message *) msg
            withMID: (uint64_t) mid
              inFID: (uint64_t) fid
{
  NSString *messageKey, *folderURL, *messageURL;
  MAPIStoreMessage *message;
  MAPIStoreFolder *folder;
  NSNumber *midKey;
  int rc;

  midKey = [NSNumber numberWithUnsignedLongLong: mid];
  message = [messages objectForKey: midKey];
  if (message)
    rc = MAPISTORE_SUCCESS;
  else
    {
      rc = MAPISTORE_ERR_NOT_FOUND;

      messageURL = [mapping urlFromID: mid];
      if (messageURL)
        {
          messageKey = [self extractChildNameFromURL: messageURL
                                      andFolderURLAt: &folderURL];
          folder = [self lookupFolder: folderURL];
          message = [folder lookupChild: messageKey];
          if (message)
            {
              [message openMessage: msg];
              [messages setObject: message forKey: midKey];
              rc = MAPISTORE_SUCCESS;
            }
        }
    }
  [message setMAPIRetainCount: [message mapiRetainCount] + 1];

  return rc;
}

- (int) createMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
                isAssociated: (BOOL) isAssociated
{
  NSNumber *midKey;
  NSString *folderURL, *childURL;
  MAPIStoreMessage *message;
  MAPIStoreFolder *folder;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, fid: 0x%.16x, associated: %d",
	__FUNCTION__, mid, fid, isAssociated];

  midKey = [NSNumber numberWithUnsignedLongLong: mid];
  message = [messages objectForKey: midKey];
  if (message)
    rc = MAPISTORE_ERR_EXIST;
  else
    {
      folderURL = [mapping urlFromID: fid];
      if (folderURL)
        {
          folder = [self lookupFolder: folderURL];
          message = [folder createMessage: isAssociated];
          if (message)
            {
              [messages setObject: message forKey: midKey];
              [message setMAPIRetainCount: [message mapiRetainCount] + 1];
              childURL = [NSString stringWithFormat: @"%@%@",
                                   folderURL, [message nameInContainer]];
              [mapping registerURL: childURL withID: mid];
              rc = MAPISTORE_SUCCESS;
            }
          else
            rc = MAPISTORE_ERROR;

	// {
	//   if (![folderURL hasSuffix: @"/"])
	//     folderURL = [NSString stringWithFormat: @"%@/", folderURL];
	//   messageURL = [NSString stringWithFormat: @"%@%@", folderURL,
	// 			 [message nameInContainer]];
	//   [mapping registerURL: messageURL withID: mid];


        }
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) _saveOrSubmitChangesInMessageWithMID: (uint64_t) mid
                                    andFlags: (uint8_t) flags
                                        save: (BOOL) isSave
{
  int rc;
  MAPIStoreMessage *message;
  MAPIStoreFolder *folder;
  NSNumber *midKey;
  NSArray *activeTables;
  NSUInteger count, max;
  // NSArray *propKeys;
  struct mapistore_object_notification_parameters *notif_parameters;
  // uint16_t count, max;
  uint64_t folderId;

  midKey = [NSNumber numberWithUnsignedLongLong: mid];
  message = [messages objectForKey: midKey];
  if (message)
    {
      rc = MAPISTORE_SUCCESS;
      folder = (MAPIStoreFolder *) [message container];
      if (isSave)
        {
          /* notifications */
          folderId = [folder objectId];

          /* folder modified */
          notif_parameters
            = talloc_zero(memCtx,
                          struct mapistore_object_notification_parameters);
          notif_parameters->object_id = folderId;
          if ([message isNew])
            {
              notif_parameters->tag_count = 3;
              notif_parameters->tags = talloc_array (notif_parameters,
                                                     enum MAPITAGS, 3);
              notif_parameters->tags[0] = PR_CONTENT_COUNT;
              notif_parameters->tags[1] = PR_MESSAGE_SIZE;
              notif_parameters->tags[2] = PR_NORMAL_MESSAGE_SIZE;
              notif_parameters->new_message_count = true;
              notif_parameters->message_count = [[folder messageKeys] count] + 1;
            }
          mapistore_push_notification (MAPISTORE_FOLDER,
                                       MAPISTORE_OBJECT_MODIFIED,
                                       notif_parameters);

          /* message created */
          if ([message isNew])
            {
              notif_parameters
                = talloc_zero(memCtx,
                              struct mapistore_object_notification_parameters);
              notif_parameters->object_id = [message objectId];
              notif_parameters->folder_id = folderId;

              notif_parameters->tag_count = 0xffff;
              mapistore_push_notification (MAPISTORE_MESSAGE,
                                           MAPISTORE_OBJECT_CREATED,
                                           notif_parameters);
              talloc_free (notif_parameters);
            }

          /* we ensure the table caches are loaded so that old and new state
             can be compared */
          activeTables = ([message isKindOfClass: MAPIStoreFAIMessageK]
                          ? [folder activeFAIMessageTables]
                          : [folder activeMessageTables]);
          max = [activeTables count];
          for (count = 0; count < max; count++)
            [[activeTables objectAtIndex: count] restrictedChildKeys];

          [message save];
 
          /* table modified */
          for (count = 0; count < max; count++)
            [[activeTables objectAtIndex: count]
              notifyChangesForChild: message];
       }
      else
        [message submit];
      [message setIsNew: NO];
      [message resetNewProperties];
      [folder cleanupCaches];
    }
  else
    rc = MAPISTORE_ERROR;

  return rc;
}

- (int) saveChangesInMessageWithMID: (uint64_t) mid
                           andFlags: (uint8_t) flags
{
  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, flags: 0x%x",
	__FUNCTION__, mid, flags];

  return [self _saveOrSubmitChangesInMessageWithMID: mid
                                           andFlags: flags
                                               save: YES];
}

- (int) submitMessageWithMID: (uint64_t) mid
                    andFlags: (uint8_t) flags
{
  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, flags: 0x%x",
	__FUNCTION__, mid, flags];

  return [self _saveOrSubmitChangesInMessageWithMID: mid
                                           andFlags: flags
                                               save: NO];
}

- (int) getProperties: (struct SPropTagArray *) sPropTagArray
          ofTableType: (uint8_t) tableType
                inRow: (struct SRow *) aRow
              withMID: (uint64_t) fmid
{
  NSNumber *midKey;
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

  midKey = [NSNumber numberWithUnsignedLongLong: fmid];
  child = [messages objectForKey: midKey];
  if (child)
    {
      data = talloc_array (memCtx, struct mapistore_property_data,
                           sPropTagArray->cValues);
      memset (data, 0,
              sizeof (struct mapistore_property_data) * sPropTagArray->cValues);
      rc = [child getProperties: data
                       withTags: sPropTagArray->aulPropTag
                       andCount: sPropTagArray->cValues];
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
                  else if (propRc == MAPISTORE_ERR_NO_MEMORY)
                    propRc = MAPI_E_NOT_ENOUGH_MEMORY;
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
      rc = MAPI_E_INVALID_OBJECT;
    }

  return rc;
}

- (int) getPath: (char **) path
         ofFMID: (uint64_t) fmid
  withTableType: (uint8_t) tableType
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
  MAPIStoreMessage *message;
  NSMutableDictionary *properties;
  NSNumber *midKey;
  struct SPropValue *cValue;
  NSUInteger counter;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, fmid, tableType];

  switch (tableType)
    {
    case MAPISTORE_MESSAGE:
      midKey = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midKey];
      if (message)
	{
          properties
            = [NSMutableDictionary dictionaryWithCapacity: aRow->cValues];
	  [self logWithFormat: @"fmid 0x%.16x found", fmid];
	  for (counter = 0; counter < aRow->cValues; counter++)
	    {
	      cValue = aRow->lpProps + counter;
	      [properties setObject: NSObjectFromSPropValue (cValue)
                             forKey: MAPIPropertyKey (cValue->ulPropTag)];
	    }
          [message addNewProperties: properties];
	  [self logWithFormat: @"(%s) message props after op", __PRETTY_FUNCTION__];
	  MAPIStoreDumpMessageProperties (properties);
	  rc = MAPISTORE_SUCCESS;
	}
      else
	{
	  [self errorWithFormat: @"fmid 0x%.16x *not* found (faking success)",
		fmid];
	  rc = MAPISTORE_SUCCESS;
	}
      break;
    case MAPISTORE_FOLDER:
      [self logWithFormat: @"%s: ignored setting of props on folders",
            __FUNCTION__];
      rc = MAPISTORE_SUCCESS;
      break;
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
  MAPIStoreMessage *message;
  NSNumber *midKey;
  NSData *fileData;
  const char *propName;
  int rc;

  propName = get_proptag_name (property);
  if (!propName)
    propName = "<unknown>";
  [self logWithFormat: @"METHOD '%s' -- property: %s(%.8x), fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, propName, property, fmid, tableType];

  fileData = [aFile readDataToEndOfFile];
  switch (tableType)
    {
    case MAPISTORE_MESSAGE:
      midKey = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midKey];
      if (message)
	{
	  [message addNewProperties:
                     [NSDictionary
                       dictionaryWithObject: NSObjectFromStreamData (property,
                                                                     fileData)
                       forKey: MAPIPropertyKey (property)]];
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

- (int) getProperty: (enum MAPITAGS) property
	   withFMID: (uint64_t) fmid
	ofTableType: (uint8_t) tableType
	   intoFile: (NSFileHandle *) aFile
{
  MAPIStoreMessage *message;
  NSNumber *midKey;
  NSData *fileData;
  const char *propName;
  enum MAPISTATUS rc;

  propName = get_proptag_name (property);
  if (!propName)
    propName = "<unknown>";
  [self logWithFormat: @"METHOD '%s' -- property: %s(%.8x), fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, propName, property, fmid, tableType];

  switch (tableType)
    {
    case MAPISTORE_MESSAGE:
      midKey = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midKey];
      if (message)
      	{
	  fileData = [[message newProperties] objectForKey: MAPIPropertyKey (property)];
          if ([fileData isKindOfClass: NSStringK])
            fileData = [fileData dataUsingEncoding: NSUTF16LittleEndianStringEncoding];
	  if (fileData)
	    {
              if (![fileData isKindOfClass: NSDataK])
                [self
                  errorWithFormat: @"data class not handled for streams: %@",
                  NSStringFromClass ([fileData class])];
	      [aFile writeData: fileData];
	      rc = MAPI_E_SUCCESS;
	    }
	  else
	    {
	      [self errorWithFormat: @"no data for property %s(%.8x)"
		    @" in mid %.16x", propName, property, fmid];
	      rc = MAPI_E_NOT_FOUND;
	    }
	}
      else
	{
	  [self errorWithFormat: @"no message found with mid %.16x", fmid];
	  rc = MAPI_E_INVALID_OBJECT;
	}
      break;
	
      // 	  [message setObject: NSObjectFromStreamData (property, fileData)
      // 		   forKey: MAPIPropertyNumber (property)];
      // 	  rc = MAPISTORE_SUCCESS;
      // 	}
      // else
    case MAPISTORE_FOLDER:
      [self errorWithFormat: @"%s: folder properties not handled yet",
            __FUNCTION__];
      rc = MAPI_E_NOT_FOUND;
      break;
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
            __FUNCTION__, tableType];
      rc = MAPI_E_INVALID_OBJECT;
    }

  return rc;
}

- (NSDictionary *) _convertRecipientFromRow: (struct RecipientRow *) row
{
  NSMutableDictionary *recipient;
  NSString *value;
  SOGoUser *recipientUser;

  recipient = [NSMutableDictionary dictionaryWithCapacity: 5];

  if ((row->RecipientFlags & 0x07) == 1)
    {
      value = [NSString stringWithUTF8String: row->X500DN.recipient_x500name];
      [recipient setObject: value forKey: @"x500dn"];

      recipientUser = [SOGoUser userWithLogin: [value lowercaseString]];
      if (recipientUser)
        {
          value = [recipientUser cn];
          if ([value length] > 0)
            [recipient setObject: value forKey: @"fullName"];
          value = [[recipientUser allEmails] objectAtIndex: 0];
          if ([value length] > 0)
            [recipient setObject: value forKey: @"email"];
        }
    }
  else
    {
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
    }

  return recipient;
}

- (int) modifyRecipientsWithMID: (uint64_t) mid
			 inRows: (struct ModifyRecipientRow *) rows
		      withCount: (NSUInteger) max
{
  static NSString *recTypes[] = { @"orig", @"to", @"cc", @"bcc" };
  MAPIStoreMessage *message;
  NSDictionary *newProperties;
  NSMutableDictionary *recipients;
  NSMutableArray *list;
  NSString *recType;
  struct ModifyRecipientRow *currentRow;
  NSUInteger count;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x", __FUNCTION__, mid];

  message = [messages
	      objectForKey: [NSNumber numberWithUnsignedLongLong: mid]];
  if (message)
    {
      recipients = [NSMutableDictionary new];
      newProperties = [NSDictionary dictionaryWithObject: recipients
                                                  forKey: @"recipients"];
      [recipients release];
      for (count = 0; count < max; count++)
	{
	  currentRow = rows + count;

	  if (currentRow->RecipClass >= MAPI_ORIG
	      && currentRow->RecipClass < MAPI_BCC)
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
      [message addNewProperties: newProperties];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) deleteMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
                   withFlags: (uint8_t) flags
{
  NSString *childURL, *folderURL, *childKey;
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
				andFolderURLAt: &folderURL];
      folder = [self lookupFolder: folderURL];
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
                    = talloc_zero(memCtx,
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
                  mapistore_push_notification (MAPISTORE_FOLDER,
                                               MAPISTORE_OBJECT_MODIFIED,
                                               notif_parameters);
                  talloc_free(notif_parameters);

                  /* message notification */
                  notif_parameters
                    = talloc_zero(memCtx,
                                  struct mapistore_object_notification_parameters);
                  notif_parameters->object_id = mid;
                  notif_parameters->folder_id = fid;
                  /* Exchange sends a fnevObjectCreated!! */
                  mapistore_push_notification (MAPISTORE_MESSAGE,
                                               MAPISTORE_OBJECT_CREATED,
                                               notif_parameters);
                  talloc_free(notif_parameters);

                  /* table notification */
                  for (count = 0; count < max; count++)
                    [[activeTables objectAtIndex: count]
                      notifyChangesForChild: message];
                }
              [self logWithFormat: @"sucessfully deleted object at URL: %@", childURL];
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

- (int) releaseRecordWithFMID: (uint64_t) fmid
		  ofTableType: (uint8_t) tableType
{
  NSNumber *midKey;
  MAPIStoreMessage *message;
  NSUInteger retainCount;
  int rc;

  switch (tableType)
    {
    case MAPISTORE_MESSAGE_TABLE:
      rc = MAPISTORE_SUCCESS;
      midKey = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midKey];
      if (message)
	{
	  retainCount = [message mapiRetainCount];
	  if (retainCount == 0)
	    {
	      [self logWithFormat: @"message with mid %.16x successfully removed"
		    @" from message cache",
		    fmid];
	      [messages removeObjectForKey: midKey];
	    }
	  else
            [message setMAPIRetainCount: retainCount - 1];
	}
      else
	[self warnWithFormat: @"message with mid %.16x not found"
	      @" in message cache", fmid];
      break;
    case MAPISTORE_FOLDER_TABLE:
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
	    __FUNCTION__, tableType];
      [self logWithFormat: @"  fmid: 0x%.16x  tableType: %d", fmid, tableType];
      
      rc = MAPISTORE_ERR_INVALID_PARAMETER;
    }

  return rc;
}

- (int) getFoldersList: (struct indexing_folders_list **) folders_list
              withFMID: (uint64_t) fmid
{
  int rc;
  NSString *currentURL, *url;
  NSMutableArray *nsFolderList;
  uint64_t fid;

  [self logWithFormat: @"METHOD '%s' -- fmid: 0x%.16x", __FUNCTION__, fmid];

  rc = MAPI_E_SUCCESS;

  url = [contextUrl absoluteString];
  currentURL = [mapping urlFromID: fmid];
  if (currentURL && ![currentURL isEqualToString: url]
      && [currentURL hasPrefix: url])
    {
      nsFolderList = [NSMutableArray arrayWithCapacity: 32];
      [self extractChildNameFromURL: currentURL
		     andFolderURLAt: &currentURL];
      while (currentURL && rc == MAPI_E_SUCCESS
             && ![currentURL isEqualToString: url])
        {
          fid = [mapping idFromURL: currentURL];
          if (fid == NSNotFound)
	    {
	      [self logWithFormat: @"no fid found for url '%@'", currentURL];
	      rc = MAPI_E_NOT_FOUND;
	    }
          else
            {
              [nsFolderList addObject: [NSNumber numberWithUnsignedLongLong: fid]];
	      [self extractChildNameFromURL: currentURL
			     andFolderURLAt: &currentURL];
            }
        }

      if (rc != MAPI_E_NOT_FOUND)
        {
          fid = [mapping idFromURL: url];
	  [nsFolderList addObject: [NSNumber numberWithUnsignedLongLong: fid]];
	  [self logWithFormat: @"resulting folder list: %@", nsFolderList];
          *folders_list = [nsFolderList asFoldersListInCtx: memCtx];
        }
    }
  else
    rc = MAPI_E_NOT_FOUND;

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

  mapping = [MAPIStoreMapping sharedMapping];

  if (key)
    childURL = [NSString stringWithFormat: @"%@%@", folderURL, key];
  else
    childURL = folderURL;
  mappingId = [mapping idFromURL: childURL];
  if (mappingId == NSNotFound)
    {
      openchangedb_get_new_folderID (ldbCtx, &mappingId);
      [mapping registerURL: childURL withID: mappingId];
      contextId = 0;
      mapistore_search_context_by_uri (memCtx, [folderURL UTF8String] + 7,
                                       &contextId);
      mapistore_indexing_record_add_mid (memCtx, contextId, mappingId);
    }

  return mappingId;
}

/* proof of concept */
- (int) getTable: (void **) tablePtr
     andRowCount: (uint32_t *) countPtr
         withFID: (uint64_t) fid
       tableType: (uint8_t) tableType
     andHandleId: (uint32_t) handleId
{
  MAPIStoreTable *table;

  table = [self _tableForFID: fid andTableType: tableType];
  [table retain];
  [table setHandleId: handleId];
  *countPtr = [[table childKeys] count];
  *tablePtr = table;

  return MAPISTORE_SUCCESS;
}

- (int) getAttachmentTable: (void **) tablePtr
               andRowCount: (uint32_t *) count
                   withMID: (uint64_t) mid
{
  MAPIStoreAttachmentTable *attTable;
  MAPIStoreMessage *message;
  NSNumber *midKey;
  int rc;

  rc = MAPISTORE_ERR_NOT_FOUND;

  midKey = [NSNumber numberWithUnsignedLongLong: mid];
  message = [messages objectForKey: midKey];
  if (message)
    {
      *count = [[message childKeysMatchingQualifier: nil
                                   andSortOrderings: nil] count];
      attTable = [message attachmentTable];
      *tablePtr = attTable;
      if (attTable)
        {
          [attTable retain];
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
}

- (int) getAttachment: (void **) attachmentPtr
              withAID: (uint32_t) aid
                inMID: (uint64_t) mid
{
  MAPIStoreMessage *message;
  MAPIStoreAttachment *attachment;
  NSNumber *midKey;
  NSArray *keys;
  int rc;

  rc = MAPISTORE_ERR_NOT_FOUND;

  midKey = [NSNumber numberWithUnsignedLongLong: mid];
  message = [messages objectForKey: midKey];
  if (message)
    {
      keys = [message childKeysMatchingQualifier: nil
                                andSortOrderings: nil];
      if (aid < [keys count])
        {
          attachment = [message lookupChild: [keys objectAtIndex: aid]];
          *attachmentPtr = attachment;
          if (attachment)
            {
              [attachment retain];
              rc = MAPISTORE_SUCCESS;
            }
        }
    }

  return rc;
}

- (int) createAttachment: (void **) attachmentPtr
                   inAID: (uint32_t *) aid
             withMessage: (uint64_t) mid
{
  MAPIStoreMessage *message;
  MAPIStoreAttachment *attachment;
  NSNumber *midKey;
  int rc;

  rc = MAPISTORE_ERR_NOT_FOUND;

  midKey = [NSNumber numberWithUnsignedLongLong: mid];
  message = [messages objectForKey: midKey];
  if (message)
    {
      attachment = [message createAttachment];
      if (attachment)
        {
          [attachment retain];
          *attachmentPtr = attachment;
          *aid = [attachment AID];
          rc = MAPISTORE_SUCCESS;
        }
    }

  return rc;
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
