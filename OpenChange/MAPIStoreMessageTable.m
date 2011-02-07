/* MAPIStoreMessageTable.m - this file is part of SOGo
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

#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/SOGoFolder.h>
#import <SOGo/SOGoObject.h>

#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMessageTable.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <libmapiproxy.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>
#include <talloc.h>

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davEntityTag;
- (NSString *) davContentLength;

@end

@implementation MAPIStoreMessageTable

static MAPIStoreMapping *mapping;

+ (void) initialize
{
  mapping = [MAPIStoreMapping sharedMapping];
}

- (NSArray *) childKeys
{
  return [folder toOneRelationshipKeys];
}

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  int rc;
  uint32_t contextId;
  uint64_t mappingId;
  NSString *stringValue, *childURL;
  NSUInteger length;
  id child;

  rc = MAPI_E_SUCCESS;
  switch (propTag)
    {
    case PR_INST_ID: // TODO: DOUBT
      /* we return a unique id based on the key */
      *data = MAPILongLongValue (memCtx, [childKey hash]);
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
      *data = MAPILongValue (memCtx, 0x03);
      break;
    case PR_ACCESS_LEVEL: // TODO
      *data = MAPILongValue (memCtx, 0x01);
      break;
    case PR_VIEW_STYLE:
    case PR_VIEW_MAJORVERSION:
      *data = MAPILongValue (memCtx, 0);
      break;
    case PidLidSideEffects: // TODO
      *data = MAPILongValue (memCtx, 0x00000000);
      break;
    case PidLidCurrentVersion:
      *data = MAPILongValue (memCtx, 115608); // Outlook 11.5608
      break;
    case PidLidCurrentVersionName:
      *data = [@"11.0" asUnicodeInMemCtx: memCtx];
      break;
    case PidLidAutoProcessState:
      *data = MAPILongValue (memCtx, 0x00000000);
      break;
    case PidNameContentClass:
      *data = [@"Sharing" asUnicodeInMemCtx: memCtx];
      break;

    // case PR_VD_NAME_UNICODE:
    //   *data = [@"PR_VD_NAME_UNICODE fake value" asUnicodeInMemCtx: memCtx];
    //   break;
    // case PR_VD_VERSION:
    //   /* mandatory value... wtf? */g
    //   *data = MAPILongValue (memCtx, 8);
    //   break;
    case PR_FID:
      *data = MAPILongLongValue (memCtx, fid);
      break;
    case PR_MID:
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
    case PR_MESSAGE_CODEPAGE:
    case PR_INTERNET_CPID:
      *data = MAPILongValue (memCtx, 1200);
      break;
    case PR_MESSAGE_LOCALE_ID:
      *data = MAPILongValue (memCtx, 0x0409);
      break;
    case PR_MESSAGE_FLAGS: // TODO
      *data = MAPILongValue (memCtx, MSGFLAG_FROMME | MSGFLAG_READ | MSGFLAG_UNMODIFIED);
      break;
    case PR_MESSAGE_SIZE: // TODO
      child = [self lookupChild: childKey];
      /* TODO: choose another name in SOGo for that method */
      *data = MAPILongValue (memCtx, [[child davContentLength] intValue]);
      break;
    case PR_MSG_STATUS: // TODO
      *data = MAPILongValue (memCtx, 0);
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
    case PR_CHANGE_KEY:
      child = [self lookupChild: childKey];
      stringValue = [child davEntityTag];
      length = [stringValue length];
      if (length < 6) /* guid = 16 bytes */
	{
	  length += 6;
	  stringValue = [NSString stringWithFormat: @"000000%@",
				  stringValue];
	}
      if (length > 6)
	stringValue = [stringValue substringFromIndex: length - 7];
      stringValue = [NSString stringWithFormat: @"SOGo%@%@%@",
			      stringValue, stringValue, stringValue];
      *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
		asShortBinaryInMemCtx: memCtx];
      break;

    case PR_ORIGINAL_SUBJECT_UNICODE:
    case PR_CONVERSATION_TOPIC_UNICODE:
      rc = [self getChildProperty: data forKey: childKey
                          withTag: PR_NORMALIZED_SUBJECT_UNICODE];
      break;

    case PR_SUBJECT_PREFIX_UNICODE:
      *data = [@"" asUnicodeInMemCtx: memCtx];
      break;
    case PR_NORMALIZED_SUBJECT_UNICODE:
      rc = [self getChildProperty: data forKey: childKey
                          withTag: PR_SUBJECT_UNICODE];
      break;

    case PR_DISPLAY_TO_UNICODE:
    case PR_DISPLAY_CC_UNICODE:
    case PR_DISPLAY_BCC_UNICODE:
    case PR_ORIGINAL_DISPLAY_TO_UNICODE:
    case PR_ORIGINAL_DISPLAY_CC_UNICODE:
    case PR_ORIGINAL_DISPLAY_BCC_UNICODE:
      *data = [@"" asUnicodeInMemCtx: memCtx];
      break;
    case PR_LAST_MODIFIER_NAME_UNICODE:
      *data = [@"openchange" asUnicodeInMemCtx: memCtx];
      break;

    default:
      rc = [super getChildProperty: data
			    forKey: childKey
			   withTag: propTag];
    }

  return rc;
}

- (void) setSortOrder: (const struct SSortOrderSet *) set
{
  [self logWithFormat: @"unimplemented method: %@", NSStringFromSelector (_cmd)];
}

@end
