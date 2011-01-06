/* MAPIStoreFolderTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
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

#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/SOGoFolder.h>

#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"

#import "MAPIStoreFolderTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>
#include <libmapiproxy.h>

@implementation MAPIStoreFolderTable

static MAPIStoreMapping *mapping;

+ (void) initialize
{
  mapping = [MAPIStoreMapping sharedMapping];
}

- (NSArray *) childKeys
{
  return [NSArray array];
  // return [folder toManyRelationshipKeys];
}

- (NSArray *) restrictedChildKeys
{
  [self errorWithFormat: @"restrictions are ignored on mail folder tables"];
  return [folder toManyRelationshipKeys];
}

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  SOGoFolder *child;
  // id child;
  // struct Binary_r *binaryValue;
  NSString *childURL;
  uint32_t contextId;
  uint64_t mappingId;
  int rc;

  rc = MAPI_E_SUCCESS;
  switch (propTag)
    {
    case PR_FID:
      childURL = [NSString stringWithFormat: @"%@%@", folderURL, childKey];
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
      *data = MAPILongLongValue (memCtx, mappingId);
      break;
    case PR_ACCESS: // TODO
      *data = MAPILongValue (memCtx, 0x63);
      break;
    case PR_ACCESS_LEVEL: // TODO
      *data = MAPILongValue (memCtx, 0x01);
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
      child = [self lookupChild: childKey];
      *data = MAPIBoolValue (memCtx, 0);
                             // [[child toManyRelationshipKeys] count] > 0);
      // *data = MAPIBoolValue (memCtx,
      //                        [[child toManyRelationshipKeys] count] > 0);
      break;
    case PR_CONTENT_COUNT:
      child = [self lookupChild: childKey];
      *data = MAPILongValue (memCtx,
                             [[child toOneRelationshipKeys] count]);
      break;
    // case PR_EXTENDED_FOLDER_FLAGS: // TODO: DOUBT: how to indicate the
    //   // number of subresponses ?
    //   binaryValue = talloc_zero(memCtx, struct Binary_r);
    //   *data = binaryValue;
    //   break;
    default:
      rc = [super getChildProperty: data
			    forKey: childKey
			   withTag: propTag];
    }

  return rc;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  return nil;
}

@end
