/* MAPIStoreSOGo.m - this file is part of SOGo
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

/* OpenChange SOGo storage backend */

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSUserDefaults.h>
#import <NGObjWeb/SoProductRegistry.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoSystemDefaults.h>

#import "MAPIApplication.h"
#import "MAPIStoreAttachment.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreObject.h"
#import "MAPIStoreTable.h"
#import "NSObject+MAPIStore.h"

#import "MAPIStoreSOGo.h"

#undef DEBUG
#include <stdbool.h>
#include <talloc.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

/**
   \details Initialize sogo mapistore backend

   \return MAPISTORE_SUCCESS on success
*/
static int
sogo_init (void)
{
  NSAutoreleasePool *pool;
  SOGoProductLoader *loader;
  Class MAPIApplicationK;
  NSUserDefaults *ud;
  SoProductRegistry *registry;

  pool = [NSAutoreleasePool new];

  /* Here we work around a bug in GNUstep which decodes XML user
     defaults using the system encoding rather than honouring
     the encoding specified in the file. */
  putenv ("GNUSTEP_STRING_ENCODING=NSUTF8StringEncoding");

  [SOGoSystemDefaults sharedSystemDefaults];

  // /* We force the plugin to base its configuration on the SOGo tree. */
  ud = [NSUserDefaults standardUserDefaults];
  [ud registerDefaults: [ud persistentDomainForName: @"sogod"]];

  registry = [SoProductRegistry sharedProductRegistry];
  [registry scanForProductsInDirectory: SOGO_BUNDLES_DIR];

  loader = [SOGoProductLoader productLoader];
  [loader loadProducts: [NSArray arrayWithObject: BACKEND_BUNDLE_NAME]];

  MAPIApplicationK = NSClassFromString (@"MAPIApplication");
  if (MAPIApplicationK)
    [MAPIApplicationK new];

  [pool release];

  return MAPISTORE_SUCCESS;
}

/**
   \details Create a connection context to the sogo backend

   \param mem_ctx pointer to the memory context
   \param uri pointer to the sogo path
   \param private_data pointer to the private backend context 
*/

static int
sogo_create_context(TALLOC_CTX *mem_ctx,
                    struct mapistore_connection_info *conn_info,
                    const char *uri, uint64_t fid,
                    void **private_data)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  Class MAPIStoreContextK;
  id context;
  int rc;

  DEBUG(0, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  MAPIStoreContextK = NSClassFromString (@"MAPIStoreContext");
  if (MAPIStoreContextK)
    {
      context = [MAPIStoreContextK contextFromURI: uri
                               withConnectionInfo: conn_info
                                           andFID: fid
                                         inMemCtx: mem_ctx];
      [context retain];

      cContext = talloc_zero(mem_ctx, sogo_context);
      cContext->objcContext = context;

      *private_data = cContext;

      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERROR;

  [pool release];

  return rc;
}


/**
   \details Delete a connection context from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static int
sogo_delete_context(void *private_data)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;

  pool = [NSAutoreleasePool new];

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  cContext = private_data;
  [cContext->objcContext release];

  [pool release];

  talloc_free (cContext);

  return MAPISTORE_SUCCESS;
}

/**
   \details Delete data associated to a given folder or message

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static int
sogo_release_record(void *private_data, uint64_t fmid, uint8_t type)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  pool = [NSAutoreleasePool new];

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context releaseRecordWithFMID: fmid ofTableType: type];

  [context tearDownRequest];

  [pool release];

  return rc;
}


/**
   \details return the mapistore path associated to a given message or
   folder ID

   \param private_data pointer to the current sogo context
   \param fmid the folder/message ID to lookup
   \param type whether it is a folder or message
   \param path pointer on pointer to the path to return

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE error
*/
static int
sogo_get_path(void *private_data, TALLOC_CTX *mem_ctx,
              uint64_t fmid, uint8_t type, char **path)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context getPath: path ofFMID: fmid withTableType: type inMemCtx: mem_ctx];

  [context tearDownRequest];

  [pool release];

  return rc;
}

static int
sogo_op_get_fid_by_name(void *private_data, uint64_t parent_fid, const char* foldername, uint64_t *fid)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context getFID: fid byName: foldername inParentFID: parent_fid];

  [context tearDownRequest];
  [pool release];

  return rc;
}


/**
   \details Create a folder in the sogo backend
   
   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static int
sogo_op_mkdir(void *private_data, uint64_t parent_fid, uint64_t fid,
	      struct SRow *aRow)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context mkDir: aRow withFID: fid inParentFID: parent_fid];

  [context tearDownRequest];
  [pool release];

  return rc;
}


/**
   \details Delete a folder from the sogo backend

   \param private_data pointer to the current sogo context
   \param parent_fid the FID for the parent of the folder to delete
   \param fid the FID for the folder to delete

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static int
sogo_op_rmdir(void *private_data, uint64_t parent_fid, uint64_t fid)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context rmDirWithFID: fid inParentFID: parent_fid];

  [context tearDownRequest];
  [pool release];

  return rc;
}


/**
   \details Open a folder from the sogo backend

   \param private_data pointer to the current sogo context
   \param parent_fid the parent folder identifier
   \param fid the identifier of the colder to open

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static int
sogo_op_opendir(void *private_data, uint64_t fid)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context openDir: fid];

  [context tearDownRequest];
  [pool release];

  return rc;
}


/**
   \details Close a folder from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static int
sogo_op_closedir(void *private_data)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context closeDir];

  [context tearDownRequest];
  [pool release];

  return rc;
}


/**
   \details Read directory content from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
static int
sogo_op_readdir_count(void *private_data, 
		      uint64_t fid,
		      uint8_t table_type,
		      uint32_t *RowCount)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context readCount: RowCount ofTableType: table_type inFID: fid];

  [context tearDownRequest];
  [pool release];

  return rc;
}

static int
sogo_op_openmessage(void *private_data,
                    TALLOC_CTX *mem_ctx,
		    uint64_t fid,
		    uint64_t mid,
		    struct mapistore_message *msg)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  if (!context)
    DEBUG (5, ("  context data is empty, failure ahead..."));
  rc = [context openMessage: msg withMID: mid inFID: fid inMemCtx: mem_ctx];
  if (rc)
    DEBUG (5, ("  failure opening message\n"));

  [context tearDownRequest];
  [pool release];

  return rc;
}


static int
sogo_op_createmessage(void *private_data,
		      uint64_t fid,
		      uint64_t mid,
		      uint8_t associated)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context createMessageWithMID: mid inFID: fid
                isAssociated: associated];

  [context tearDownRequest];
  [pool release];

  return rc;
}

static int
sogo_op_savechangesmessage(void *private_data,
			   uint64_t mid,
			   uint8_t flags)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context saveChangesInMessageWithMID: mid andFlags: flags];

  [context tearDownRequest];
  [pool release];

  return rc;
}

static int
sogo_op_submitmessage(void *private_data,
		      uint64_t mid,
		      uint8_t flags)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context submitMessageWithMID: mid andFlags: flags];

  [context tearDownRequest];
  [pool release];

  return rc;
}

static int
sogo_op_getprops(void *private_data,
                 TALLOC_CTX *mem_ctx,
		 uint64_t fmid, 
		 uint8_t type, 
		 struct SPropTagArray *SPropTagArray,
		 struct SRow *aRow)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context getProperties: SPropTagArray
		  ofTableType: type
			inRow: aRow
		      withMID: fmid
                     inMemCtx: mem_ctx];

  [context tearDownRequest];
  [pool release];

  return rc;
}


static int
sogo_op_setprops(void *private_data,
		 uint64_t fmid,
		 uint8_t type,
		 struct SRow *aRow)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context setPropertiesWithFMID: fmid ofTableType: type inRow: aRow];

  [context tearDownRequest];
  [pool release];

  return rc;
}

static int
sogo_op_modifyrecipients(void *private_data,
			 uint64_t mid,
			 struct ModifyRecipientRow *rows,
			 uint16_t count)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context modifyRecipientsWithMID: mid
		inRows: rows
		withCount: count];

  [context tearDownRequest];
  [pool release];

  return rc;
}

static int
sogo_op_deletemessage(void *private_data,
                      uint64_t fid,
		      uint64_t mid,
		      uint8_t flags)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  [context setupRequest];

  rc = [context deleteMessageWithMID: mid inFID: fid withFlags: flags];

  [context tearDownRequest];
  [pool release];

  return rc;
}

static int
sogo_op_set_restrictions (void *private_data, uint64_t fid, uint8_t type,
			  struct mapi_SRestriction *res, uint8_t *tableStatus)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  if (context)
    {
      [context setupRequest];

      rc = [context setRestrictions: res
		    withFID: fid andTableType: type
		    getTableStatus: tableStatus];

      [context tearDownRequest];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO CONTEXT");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_op_set_sort_order (void *private_data, uint64_t fid, uint8_t type,
                        struct SSortOrderSet *set, uint8_t *tableStatus)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  if (context)
    {
      [context setupRequest];
      rc = [context setSortOrder: set
                         withFID: fid andTableType: type
                  getTableStatus: tableStatus];
      [context tearDownRequest];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO CONTEXT");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

/**
   proof of concept
*/
static int
sogo_pocop_open_table(void *private_data, TALLOC_CTX *mem_ctx,
                      uint64_t fid, uint8_t table_type,
                      uint32_t handle_id,
                      void **table_object, uint32_t *row_count)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  MAPIStoreTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  if (context)
    {
      [context setupRequest];
      rc = [context getTable: &table
                 andRowCount: row_count
                     withFID: fid
                   tableType: table_type
                 andHandleId: handle_id];
      if (rc == MAPISTORE_SUCCESS)
        *table_object = [table tallocWrapper: mem_ctx];
      [context tearDownRequest];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO CONTEXT");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_get_attachment_table (void *private_data, TALLOC_CTX *mem_ctx, uint64_t mid, void **table_object, uint32_t *row_count)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  MAPIStoreAttachmentTable *table;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  if (context)
    {
      [context setupRequest];
      rc = [context getAttachmentTable: &table
                           andRowCount: row_count
                               withMID: mid];
      *table_object = [table tallocWrapper: mem_ctx];
      [context tearDownRequest];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO CONTEXT");
      rc = MAPI_E_NOT_FOUND;
    }

  [pool release];

  return rc;
}

static int
sogo_pocop_get_attachment (void *private_data, TALLOC_CTX *mem_ctx, uint64_t mid, uint32_t aid, void **attachment_object)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  MAPIStoreAttachment *attachment;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  if (context)
    {
      [context setupRequest];
      rc = [context getAttachment: &attachment withAID: aid inMID: mid];
      if (rc == MAPISTORE_SUCCESS)
        *attachment_object = [attachment tallocWrapper: mem_ctx];
      [context tearDownRequest];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO CONTEXT");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_create_attachment (void *private_data, TALLOC_CTX *mem_ctx, uint64_t mid, uint32_t *aid, void **attachment_object)
{
  NSAutoreleasePool *pool;
  sogo_context *cContext;
  MAPIStoreContext *context;
  MAPIStoreAttachment *attachment;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  cContext = private_data;
  context = cContext->objcContext;
  if (context)
    {
      [context setupRequest];
      rc = [context createAttachment: &attachment inAID: aid
                         withMessage: mid];
      if (rc == MAPISTORE_SUCCESS)
        *attachment_object = [attachment tallocWrapper: mem_ctx];
      [context tearDownRequest];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO CONTEXT");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_open_embedded_message (void *attachment_object,
                                  TALLOC_CTX *mem_ctx,
                                  uint64_t *mid, enum OpenEmbeddedMessage_OpenModeFlags flags,
                                  struct mapistore_message *msg, void **message_object)
{
  struct MAPIStoreTallocWrapper *wrapper;
  NSAutoreleasePool *pool;
  MAPIStoreAttachment *attachment;
  MAPIStoreAttachmentMessage *message;
  int rc;

  DEBUG (5, ("[SOGo: %s:%d]\n", __FUNCTION__, __LINE__));

  pool = [NSAutoreleasePool new];

  if (attachment_object)
    {
      wrapper = attachment_object;
      attachment = wrapper->MAPIStoreSOGoObject;
      pool = [NSAutoreleasePool new];
      rc = [attachment openEmbeddedMessage: &message
                                   withMID: mid
                          withMAPIStoreMsg: msg andFlags: flags];
      if (rc == MAPISTORE_SUCCESS)
        *message_object = [message tallocWrapper: mem_ctx];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO CONTEXT");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int sogo_pocop_get_available_table_properties(void *table_object,
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
      pool = [NSAutoreleasePool new];
      rc = [table getAvailableProperties: propertiesP inMemCtx: mem_ctx];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO DATA");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_set_table_columns (void *table_object, uint16_t count, enum MAPITAGS *properties)
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
      pool = [NSAutoreleasePool new];
      rc = [table setColumns: properties
                   withCount: count];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO DATA");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_set_table_restrictions (void *table_object, struct mapi_SRestriction *restrictions, uint8_t *table_status)
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
      pool = [NSAutoreleasePool new];
      [table setRestrictions: restrictions];
      [table cleanupCaches];
      rc = MAPISTORE_SUCCESS;
      *table_status = TBLSTAT_COMPLETE;
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO DATA");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_set_table_sort_order (void *table_object, struct SSortOrderSet *sort_order, uint8_t *table_status)
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
      pool = [NSAutoreleasePool new];
      [table setSortOrder: sort_order];
      [table cleanupCaches];
      rc = MAPISTORE_SUCCESS;
      *table_status = TBLSTAT_COMPLETE;
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO DATA");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_get_table_row (void *table_object, TALLOC_CTX *mem_ctx,
                          enum table_query_type query_type, uint32_t row_id,
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
      pool = [NSAutoreleasePool new];
      rc = [table getRow: data withRowID: row_id andQueryType: query_type
                inMemCtx: mem_ctx];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO DATA");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int sogo_pocop_get_available_properties(void *object,
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
      pool = [NSAutoreleasePool new];
      rc = [propObject getAvailableProperties: propertiesP inMemCtx: mem_ctx];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO DATA");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_get_properties (void *object,
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
      pool = [NSAutoreleasePool new];
      rc = [propObject getProperties: data withTags: properties
                            andCount: count
                            inMemCtx: mem_ctx];
      [pool release];
    }
  else
    {
      NSLog (@"  UNEXPECTED WEIRDNESS: RECEIVED NO DATA");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

static int
sogo_pocop_set_properties (void *object, struct SRow *aRow)
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
      pool = [NSAutoreleasePool new];
      rc = [propObject setProperties: aRow];
      [pool release];
    }
  else
    {
      NSLog (@"  bad object pointer");
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

/**
   \details Entry point for mapistore SOGO backend

   \return MAPI_E_SUCCESS on success, otherwise MAPISTORE error
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
      
      /* Fill in our name */
      backend.name = "SOGo";
      backend.description = "mapistore SOGo backend";
      backend.namespace = "sogo://";

      backend.init = sogo_init;
      backend.create_context = sogo_create_context;
      backend.delete_context = sogo_delete_context;
      backend.release_record = sogo_release_record;

      backend.get_path = sogo_get_path;
      backend.op_get_fid_by_name = sogo_op_get_fid_by_name;

      backend.op_mkdir = sogo_op_mkdir;
      backend.op_rmdir = sogo_op_rmdir;
      backend.op_opendir = sogo_op_opendir;
      backend.op_closedir = sogo_op_closedir;
      backend.op_readdir_count = sogo_op_readdir_count;
      backend.op_set_restrictions = sogo_op_set_restrictions;
      backend.op_set_sort_order = sogo_op_set_sort_order;
      backend.op_openmessage = sogo_op_openmessage;
      backend.op_createmessage = sogo_op_createmessage;
      backend.op_modifyrecipients = sogo_op_modifyrecipients;
      backend.op_savechangesmessage = sogo_op_savechangesmessage;
      backend.op_submitmessage = sogo_op_submitmessage;
      backend.op_deletemessage = sogo_op_deletemessage;

      backend.op_setprops = sogo_op_setprops;
      backend.op_getprops = sogo_op_getprops;

      /* proof of concept */
      backend.folder.open_table = sogo_pocop_open_table;
      backend.message.get_attachment_table = sogo_pocop_get_attachment_table;
      backend.message.get_attachment = sogo_pocop_get_attachment;
      backend.message.create_attachment = sogo_pocop_create_attachment;
      backend.message.open_embedded_message = sogo_pocop_open_embedded_message;
      backend.table.get_available_properties = sogo_pocop_get_available_table_properties;
      backend.table.set_restrictions = sogo_pocop_set_table_restrictions;
      backend.table.set_sort_order = sogo_pocop_set_table_sort_order;
      backend.table.set_columns = sogo_pocop_set_table_columns;
      backend.table.get_row = sogo_pocop_get_table_row;
      backend.properties.get_available_properties = sogo_pocop_get_available_properties;
      backend.properties.get_properties = sogo_pocop_get_properties;
      backend.properties.set_properties = sogo_pocop_set_properties;

      /* Register ourselves with the MAPISTORE subsystem */
      ret = mapistore_backend_register(&backend);
      if (ret != MAPISTORE_SUCCESS) {
        DEBUG(0, ("Failed to register the '%s' mapistore backend!\n", backend.name));
      }
    }

  return ret;
}
