/* MAPIStoreSOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2010, 2011 Inverse inc.
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

/* OpenChange SOGo storage backend */

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSThread.h>
#import <NGObjWeb/SoProductRegistry.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoSystemDefaults.h>

#import "MAPIApplication.h"
#import "MAPIStoreAttachment.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStoreMessage.h"
#import "MAPIStoreMailVolatileMessage.h"
#import "MAPIStoreObject.h"
#import "MAPIStoreTable.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static Class MAPIStoreContextK = Nil;
static BOOL leakDebugging = NO;

static enum mapistore_error
sogo_backend_unexpected_error()
{
  NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO OBJECT");
  abort();
  return MAPISTORE_SUCCESS;
}

static void
sogo_backend_atexit (void)
{
  NSAutoreleasePool *pool;

  GSRegisterCurrentThread ();
  pool = [NSAutoreleasePool new];
  NSLog (@"allocated classes:\n%s", GSDebugAllocationList (YES));
  [pool release];
  GSUnregisterCurrentThread ();
}

/**
   \details Initialize sogo mapistore backend

   \return MAPISTORE_SUCCESS on success
*/
static enum mapistore_error
sogo_backend_init (void)
{
  NSAutoreleasePool *pool;
  SOGoProductLoader *loader;
  Class MAPIApplicationK;
  NSUserDefaults *ud;
  SoProductRegistry *registry;
  char *argv[] = { SAMBA_PREFIX "/sbin/samba", NULL };

  GSRegisterCurrentThread ();
  pool = [NSAutoreleasePool new];

  /* Here we work around a bug in GNUstep which decodes XML user
     defaults using the system encoding rather than honouring
     the encoding specified in the file. */
  putenv ("GNUSTEP_STRING_ENCODING=NSUTF8StringEncoding");

  [NSProcessInfo initializeWithArguments: argv
                                   count: 1
                             environment: environ];

  [SOGoSystemDefaults sharedSystemDefaults];

  /* We force the plugin to base its configuration on the SOGo tree. */
  ud = [NSUserDefaults standardUserDefaults];
  [ud registerDefaults: [ud persistentDomainForName: @"sogod"]];

  if (!leakDebugging && [ud boolForKey: @"SOGoDebugLeaks"])
    {
      NSLog (@"  leak debugging on");
      GSDebugAllocationActive (YES);
      atexit (sogo_backend_atexit);
      leakDebugging = YES;
    }

  registry = [SoProductRegistry sharedProductRegistry];
  [registry scanForProductsInDirectory: SOGO_BUNDLES_DIR];

  loader = [SOGoProductLoader productLoader];
  [loader loadProducts: [NSArray arrayWithObject: BACKEND_BUNDLE_NAME]];

  MAPIApplicationK = NSClassFromString (@"MAPIApplication");
  if (MAPIApplicationK)
    [[MAPIApplicationK new] activateApplication];

  [[SOGoCache sharedCache] disableRequestsCache];
  [[SOGoCache sharedCache] disableLocalCache];

  MAPIStoreContextK = NSClassFromString (@"MAPIStoreContext");

  [pool release];

  return MAPISTORE_SUCCESS;
}

/**
   \details Create a connection context to the sogo backend

   \param mem_ctx pointer to the memory context
   \param uri pointer to the sogo path
   \param private_data pointer to the private backend context 
*/

static enum mapistore_error
sogo_backend_create_context(TALLOC_CTX *mem_ctx,
                            struct mapistore_connection_info *conn_info,
                            struct tdb_wrap *indexingTdb,
                            const char *uri, void **context_object)
{
  NSAutoreleasePool *pool;
  MAPIStoreContext *context;
  int rc;

  DEBUG(0, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  GSRegisterCurrentThread ();
  pool = [NSAutoreleasePool new];

  if (MAPIStoreContextK)
    {
      rc = [MAPIStoreContextK openContext: &context
                                  withURI: uri
                           connectionInfo: conn_info
                           andTDBIndexing: indexingTdb];
      if (rc == MAPISTORE_SUCCESS)
        *context_object = [context tallocWrapper: mem_ctx];
    }
  else
    rc = MAPISTORE_ERROR;

  [pool release];
  GSUnregisterCurrentThread ();

  return rc;
}

static enum mapistore_error
sogo_backend_create_root_folder (const char *username,
                                 enum mapistore_context_role role,
                                 uint64_t fid, const char *name,
                                 // struct tdb_wrap *indexingTdb,
                                 TALLOC_CTX *mem_ctx, char **mapistore_urip)
{
  NSAutoreleasePool *pool;
  NSString *userName, *folderName;
  NSString *mapistoreUri;
  int rc;

  DEBUG(0, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  GSRegisterCurrentThread ();
  pool = [NSAutoreleasePool new];

  if (MAPIStoreContextK)
    {
      userName = [NSString stringWithUTF8String: username];
      folderName = [NSString stringWithUTF8String: name];
      rc = [MAPIStoreContextK createRootFolder: &mapistoreUri
                                       withFID: fid
                                       andName: folderName
                                       forUser: userName
                                      withRole: role];
      if (rc == MAPISTORE_SUCCESS)
        *mapistore_urip = [mapistoreUri asUnicodeInMemCtx: mem_ctx];
    }
  else
    rc = MAPISTORE_ERROR;

  [pool release];
  GSUnregisterCurrentThread ();

  return rc;
}

static enum mapistore_error
sogo_backend_list_contexts(const char *username, struct tdb_wrap *indexingTdb,
                           TALLOC_CTX *mem_ctx,
                           struct mapistore_contexts_list **contexts_listp)
{
  NSAutoreleasePool *pool;
  NSString *userName;
  int rc;

  DEBUG(0, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  GSRegisterCurrentThread ();
  pool = [NSAutoreleasePool new];

  if (MAPIStoreContextK)
    {
      userName = [NSString stringWithUTF8String: username];
      *contexts_listp = [MAPIStoreContextK listAllContextsForUser: userName
                                                  withTDBIndexing: indexingTdb
                                                         inMemCtx: mem_ctx];
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERROR;

  [pool release];
  GSUnregisterCurrentThread ();

  return rc;
}

// andFID: fid
// uint64_t fid,
//   void **private_data)

/**
   \details return the mapistore path associated to a given message or
   folder ID

   \param private_data pointer to the current sogo context
   \param fmid the folder/message ID to lookup
   \param type whether it is a folder or message
   \param path pointer on pointer to the path to return

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE error
*/
static enum mapistore_error
sogo_context_get_path(void *backend_object, TALLOC_CTX *mem_ctx,
                      uint64_t fmid, char **path)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (backend_object)
    {
      wrapper = backend_object;
      context = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [context getPath: path ofFMID: fmid inMemCtx: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_context_get_root_folder(void *backend_object, TALLOC_CTX *mem_ctx,
                             uint64_t fid, void **folder_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreContext *context;
  MAPIStoreFolder *folder;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (backend_object)
    {
      wrapper = backend_object;
      context = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [context getRootFolder: &folder withFID: fid];
      if (rc == MAPISTORE_SUCCESS)
        *folder_object = [folder tallocWrapper: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

/**
   \details Open a folder from the sogo backend

   \param private_data pointer to the current sogo context
   \param parent_fid the parent folder identifier
   \param fid the identifier of the colder to open

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static enum mapistore_error
sogo_folder_open_folder(void *folder_object, TALLOC_CTX *mem_ctx, uint64_t fid, void **childfolder_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder, *childFolder;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder openFolder: &childFolder withFID: fid];
      if (rc == MAPISTORE_SUCCESS)
        *childfolder_object = [childFolder tallocWrapper: mem_ctx];
      // [context tearDownRequest];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

/**
   \details Create a folder in the sogo backend
   
   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static enum mapistore_error
sogo_folder_create_folder(void *folder_object, TALLOC_CTX *mem_ctx,
                          uint64_t fid, struct SRow *aRow,
                          void **childfolder_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder, *childFolder;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder createFolder: &childFolder withRow: aRow andFID: fid];
      if (rc == MAPISTORE_SUCCESS)
        *childfolder_object = [childFolder tallocWrapper: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

/**
   \details Delete a folder from the sogo backend

   \param private_data pointer to the current sogo context
   \param parent_fid the FID for the parent of the folder to delete
   \param fid the FID for the folder to delete

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static enum mapistore_error
sogo_folder_delete(void *folder_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder deleteFolder];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
       rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_folder_get_child_count(void *folder_object, enum mapistore_table_type table_type, uint32_t *child_count)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder getChildCount: child_count ofTableType: table_type];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_folder_open_message(void *folder_object,
                         TALLOC_CTX *mem_ctx,
                         uint64_t mid, bool write_access,
                         void **message_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder;
  MAPIStoreMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder openMessage: &message
                       withMID: mid
                    forWriting: write_access
                      inMemCtx: mem_ctx];
      if (rc == MAPISTORE_SUCCESS)
        *message_object = [message tallocWrapper: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_folder_create_message(void *folder_object,
                           TALLOC_CTX *mem_ctx,
                           uint64_t mid,
                           uint8_t associated,
                           void **message_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder;
  MAPIStoreMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder createMessage: &message
                         withMID: mid
		    isAssociated: associated];
      if (rc == MAPISTORE_SUCCESS)
        *message_object = [message tallocWrapper: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_folder_delete_message(void *folder_object, uint64_t mid, uint8_t flags)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder deleteMessageWithMID: mid andFlags: flags];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_folder_move_copy_messages(void *folder_object,
                               void *source_folder_object,
                               uint32_t mid_count,
                               uint64_t *src_mids, uint64_t *t_mids,
                               struct Binary_r **target_change_keys,
                               uint8_t want_copy)
{
  MAPIStoreFolder *sourceFolder, *targetFolder;
  NSAutoreleasePool *pool;
  struct MAPIStoreTallocWrapper *wrapper;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      targetFolder = wrapper->MAPIStoreSOGoObject;

      wrapper = source_folder_object;
      sourceFolder = wrapper->MAPIStoreSOGoObject;

      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [targetFolder moveCopyMessagesWithMIDs: src_mids
                                         andCount: mid_count
                                       fromFolder: sourceFolder
                                         withMIDs: t_mids
                                    andChangeKeys: target_change_keys
                                         wantCopy: want_copy];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_folder_get_deleted_fmids(void *folder_object, TALLOC_CTX *mem_ctx,
                              enum mapistore_table_type table_type, uint64_t change_num,
                              struct I8Array_r **fmidsp, uint64_t *cnp)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder getDeletedFMIDs: fmidsp
                             andCN: cnp
                  fromChangeNumber: change_num
                       inTableType: table_type
                          inMemCtx: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_folder_open_table(void *folder_object, TALLOC_CTX *mem_ctx,
                       enum mapistore_table_type table_type, uint32_t handle_id,
                       void **table_object, uint32_t *row_count)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder getTable: &table
                andRowCount: row_count
                  tableType: table_type
                andHandleId: handle_id];
      if (rc == MAPISTORE_SUCCESS)
        *table_object = [table tallocWrapper: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_folder_modify_permissions(void *folder_object, uint8_t flags,
                               uint16_t pcount,
                               struct PermissionData *permissions)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreFolder *folder;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (folder_object)
    {
      wrapper = folder_object;
      folder = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [folder modifyPermissions: permissions
                           withCount: pcount
                            andFlags: flags];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_get_message_data(void *message_object,
                              TALLOC_CTX *mem_ctx,
                              struct mapistore_message **msg_dataP)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (message_object)
    {
      wrapper = message_object;
      message = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      [message getMessageData: msg_dataP
                     inMemCtx: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
      rc = MAPISTORE_SUCCESS;
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_create_attachment (void *message_object, TALLOC_CTX *mem_ctx, void **attachment_object, uint32_t *aidp)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreMessage *message;
  MAPIStoreAttachment *attachment;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (message_object)
    {
      wrapper = message_object;
      message = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [message createAttachment: &attachment inAID: aidp];
      if (rc == MAPISTORE_SUCCESS)
        *attachment_object = [attachment tallocWrapper: mem_ctx];
      // [context tearDownRequest];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
       rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_open_attachment (void *message_object, TALLOC_CTX *mem_ctx,
                              uint32_t aid, void **attachment_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreMessage *message;
  MAPIStoreAttachment *attachment;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (message_object)
    {
      wrapper = message_object;
      message = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [message getAttachment: &attachment withAID: aid];
      if (rc == MAPISTORE_SUCCESS)
        *attachment_object = [attachment tallocWrapper: mem_ctx];
      // [context tearDownRequest];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_get_attachment_table (void *message_object, TALLOC_CTX *mem_ctx, void **table_object, uint32_t *row_count)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreMessage *message;
  MAPIStoreAttachmentTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (message_object)
    {
      wrapper = message_object;
      message = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [message getAttachmentTable: &table
                           andRowCount: row_count];
      if (rc == MAPISTORE_SUCCESS)
        *table_object = [table tallocWrapper: mem_ctx];
      // [context tearDownRequest];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_modify_recipients (void *message_object,
                                struct SPropTagArray *columns,
                                uint16_t count,
                                struct mapistore_message_recipient *recipients)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (message_object)
    {
      wrapper = message_object;
      message = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [message modifyRecipientsWithRecipients: recipients
                                          andCount: count
                                        andColumns: columns];
      // [context tearDownRequest];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_set_read_flag (void *message_object, uint8_t flag)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (message_object)
    {
      wrapper = message_object;
      message = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [message setReadFlag: flag];
      // [context tearDownRequest];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_save (void *message_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (message_object)
    {
      wrapper = message_object;
      message = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [message saveMessage];
      // [context tearDownRequest];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_submit (void *message_object, enum SubmitFlags flags)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreMailVolatileMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (message_object)
    {
      wrapper = message_object;
      message = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [message submitWithFlags: flags];
      // [context tearDownRequest];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_message_attachment_open_embedded_message
(void *attachment_object,
 TALLOC_CTX *mem_ctx, void **message_object,
 uint64_t *midP,
 struct mapistore_message **msg)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreAttachment *attachment;
  MAPIStoreAttachmentMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (attachment_object)
    {
      wrapper = attachment_object;
      attachment = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [attachment openEmbeddedMessage: &message
                                   withMID: midP
                          withMAPIStoreMsg: msg
                                  inMemCtx: mem_ctx];
      if (rc == MAPISTORE_SUCCESS)
        *message_object = [message tallocWrapper: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error sogo_table_get_available_properties(void *table_object,
                                               TALLOC_CTX *mem_ctx, struct SPropTagArray **propertiesP)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (table_object)
    {
      wrapper = table_object;
      table = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [table getAvailableProperties: propertiesP inMemCtx: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_table_set_columns (void *table_object, uint16_t count, enum MAPITAGS *properties)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (table_object)
    {
      wrapper = table_object;
      table = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [table setColumns: properties
                   withCount: count];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_table_set_restrictions (void *table_object, struct mapi_SRestriction *restrictions, uint8_t *table_status)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (table_object)
    {
      wrapper = table_object;
      table = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      [table setRestrictions: restrictions];
      [table cleanupCaches];
      rc = MAPISTORE_SUCCESS;
      *table_status = TBLSTAT_COMPLETE;
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_table_set_sort_order (void *table_object, struct SSortOrderSet *sort_order, uint8_t *table_status)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (table_object)
    {
      wrapper = table_object;
      table = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      [table setSortOrder: sort_order];
      [table cleanupCaches];
      rc = MAPISTORE_SUCCESS;
      *table_status = TBLSTAT_COMPLETE;
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_table_get_row (void *table_object, TALLOC_CTX *mem_ctx,
                    enum mapistore_query_type query_type, uint32_t row_id,
                    struct mapistore_property_data **data)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (table_object)
    {
      wrapper = table_object;
      table = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [table getRow: data withRowID: row_id andQueryType: query_type
                inMemCtx: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_table_get_row_count (void *table_object,
                          enum mapistore_query_type query_type,
                          uint32_t *row_countp)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (table_object)
    {
      wrapper = table_object;
      table = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [table getRowCount: row_countp
                withQueryType: query_type];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_table_handle_destructor (void *table_object, uint32_t handle_id)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (table_object)
    {
      wrapper = table_object;
      table = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      [table destroyHandle: handle_id];
      [pool release];
      GSUnregisterCurrentThread ();
      rc = MAPISTORE_SUCCESS;
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error sogo_properties_get_available_properties(void *object,
                                                    TALLOC_CTX *mem_ctx,
                                                    struct SPropTagArray **propertiesP)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreObject *propObject;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (object)
    {
      wrapper = object;
      propObject = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [propObject getAvailableProperties: propertiesP inMemCtx: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_properties_get_properties (void *object,
                                TALLOC_CTX *mem_ctx,
                                uint16_t count, enum MAPITAGS *properties,
                                struct mapistore_property_data *data)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreObject *propObject;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (object)
    {
      wrapper = object;
      propObject = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [propObject getProperties: data withTags: properties
                            andCount: count
                            inMemCtx: mem_ctx];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_properties_set_properties (void *object, struct SRow *aRow)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreObject *propObject;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (object)
    {
      wrapper = object;
      propObject = wrapper->MAPIStoreSOGoObject;
      GSRegisterCurrentThread ();
      pool = [NSAutoreleasePool new];
      rc = [propObject addPropertiesFromRow: aRow];
      [pool release];
      GSUnregisterCurrentThread ();
    }
  else
    {
      rc = sogo_backend_unexpected_error();
    }

  return rc;
}

static enum mapistore_error
sogo_manager_generate_uri (TALLOC_CTX *mem_ctx, 
                           const char *user, 
                           const char *folder, 
                           const char *message, 
                           const char *rootURI,
                           char **uri)
{
  NSAutoreleasePool *pool;
  NSString *partialURLString, *username, *directory;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  if (uri == NULL) return MAPISTORE_ERR_INVALID_PARAMETER;

  /* This fixes a crash occurring during the instantiation of the
     NSAutoreleasePool below. */
  GSRegisterCurrentThread ();
  pool = [NSAutoreleasePool new];

  // printf("rootURI = %s\n", rootURI);
  if (rootURI)
    partialURLString = [NSString stringWithUTF8String: rootURI];
  else
    {
      /* sogo uri are of type: sogo://[username]:[password]@[folder type]/folder/id */
      username = [NSString stringWithUTF8String: (user ? user : "*")];
      /* Do proper directory lookup here */
      directory = [NSString stringWithUTF8String: (folder ? folder : "*")];
      partialURLString = [NSString stringWithFormat: @"sogo://%@:*@%@", username, directory];
    }
  if (![partialURLString hasSuffix: @"/"])
    partialURLString = [partialURLString stringByAppendingString: @"/"];

  if (message)
    partialURLString = [partialURLString stringByAppendingFormat: @"%s.eml", message];

  // printf("uri = %s\n", [partialURLString UTF8String]);
  *uri = talloc_strdup (mem_ctx, [partialURLString UTF8String]);

  [pool release];
  GSUnregisterCurrentThread ();

  return MAPISTORE_SUCCESS;
}

/**
   \details Entry point for mapistore SOGO backend

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE error
*/
int mapistore_init_backend(void)
{
  struct mapistore_backend	backend;
  int				ret;
  static BOOL                   registered = NO;

  if (registered)
    ret = MAPISTORE_SUCCESS;
  else
    {
      registered = YES;

      backend.backend.name = "SOGo";
      backend.backend.description = "mapistore SOGo backend";
      backend.backend.namespace = "sogo://";
      backend.backend.init = sogo_backend_init;
      backend.backend.create_context = sogo_backend_create_context;
      backend.backend.create_root_folder = sogo_backend_create_root_folder;
      backend.backend.list_contexts = sogo_backend_list_contexts;
      backend.context.get_path = sogo_context_get_path;
      backend.context.get_root_folder = sogo_context_get_root_folder;
      backend.folder.open_folder = sogo_folder_open_folder;
      backend.folder.create_folder = sogo_folder_create_folder;
      backend.folder.delete = sogo_folder_delete;
      backend.folder.open_message = sogo_folder_open_message;
      backend.folder.create_message = sogo_folder_create_message;
      backend.folder.delete_message = sogo_folder_delete_message;
      backend.folder.move_copy_messages = sogo_folder_move_copy_messages;
      backend.folder.get_deleted_fmids = sogo_folder_get_deleted_fmids;
      backend.folder.get_child_count = sogo_folder_get_child_count;
      backend.folder.open_table = sogo_folder_open_table;
      backend.folder.modify_permissions = sogo_folder_modify_permissions;
      backend.message.create_attachment = sogo_message_create_attachment;
      backend.message.get_attachment_table = sogo_message_get_attachment_table;
      backend.message.open_attachment = sogo_message_open_attachment;
      backend.message.open_embedded_message = sogo_message_attachment_open_embedded_message;
      backend.message.get_message_data = sogo_message_get_message_data;
      backend.message.modify_recipients = sogo_message_modify_recipients;
      backend.message.set_read_flag = sogo_message_set_read_flag;
      backend.message.save = sogo_message_save;
      backend.message.submit = sogo_message_submit;
      backend.table.get_available_properties = sogo_table_get_available_properties;
      backend.table.set_restrictions = sogo_table_set_restrictions;
      backend.table.set_sort_order = sogo_table_set_sort_order;
      backend.table.set_columns = sogo_table_set_columns;
      backend.table.get_row = sogo_table_get_row;
      backend.table.get_row_count = sogo_table_get_row_count;
      backend.table.handle_destructor = sogo_table_handle_destructor;
      backend.properties.get_available_properties = sogo_properties_get_available_properties;
      backend.properties.get_properties = sogo_properties_get_properties;
      backend.properties.set_properties = sogo_properties_set_properties;
      backend.manager.generate_uri = sogo_manager_generate_uri;

      /* Register ourselves with the MAPISTORE subsystem */
      ret = mapistore_backend_register (&backend);
      if (ret != MAPISTORE_SUCCESS)
        DEBUG(0, ("Failed to register the '%s' mapistore backend!\n", backend.backend.name));
    }

  return ret;
}
