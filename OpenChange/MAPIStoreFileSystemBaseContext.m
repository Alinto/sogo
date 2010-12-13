/* MAPIStoreFileSystemBaseContext.m - this file is part of SOGo
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

/* A generic parent class for all context that will store their data on the
   disk in the form of a plist. */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGExtensions/NSObject+Logs.h>

#import "EOQualifier+MAPIFS.h"

#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"

#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "NSCalendarDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "NSValue+MAPIStore.h"

#undef DEBUG
#include <talloc.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <libmapi/libmapi.h>
#include <libmapiproxy.h>

#import "MAPIStoreFileSystemBaseContext.h"

@implementation MAPIStoreFileSystemBaseContext

+ (NSString *) MAPIModuleName
{
  return nil;
}

- (void) setupModuleFolder
{
  [self logWithFormat: @"invoked %s", __PRETTY_FUNCTION__];
  moduleFolder = [SOGoMAPIFSFolder folderWithURL: [NSURL URLWithString: uri]];
  [moduleFolder retain];
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
		 matchingQualifier: (EOQualifier *) qualifier
{
  NSMutableArray *messageKeys;
  NSArray *allKeys;
  NSUInteger count, max;
  NSString *messageKey;

  allKeys = [(SOGoMAPIFSFolder *) folder toOneRelationshipKeys];
  if (qualifier)
    {
      [self logWithFormat: @"%s: getting restricted keys", __PRETTY_FUNCTION__];
      max = [allKeys count];
      messageKeys = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
	{
	  messageKey = [allKeys objectAtIndex: count];
	  if ([qualifier evaluateMAPIFSMessage:
			    [folder lookupName: messageKey
				     inContext: nil
				       acquire: NO]])
	    [messageKeys addObject: messageKey];
	}
    }
  else
    messageKeys = (NSMutableArray *) allKeys;

  return messageKeys;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  return [NSString stringWithFormat: @"%@", MAPIPropertyKey (property)];
}

- (id) createMessageInFolder: (id) parentFolder
{
  return [moduleFolder newMessage];
}

- (enum MAPISTATUS) getMessageTableChildproperty: (void **) data
					   atURL: (NSString *) childURL
					 withTag: (enum MAPITAGS) proptag
					inFolder: (SOGoFolder *) folder
					 withFID: (uint64_t) fid
{
  SOGoMAPIFSMessage *message;
  NSDictionary *properties;
  NSString *folderURL;
  MAPIStoreMapping *mapping;
  uint16_t valueType;
  uint32_t contextId;
  uint64_t mappingId;
  id value;
  int rc;

  message = [self lookupObject: childURL];
  if (message)
    {
      properties = [message properties];
      value = [properties objectForKey: MAPIPropertyKey (proptag)];
      if (value)
	{
	  rc = MAPI_E_SUCCESS;

	  // [self logWithFormat: @"property %.8x found", proptag];
	  valueType = (proptag & 0xffff);
	  switch (valueType)
	    {
	    case PT_NULL:
	      *data = NULL;
	      break;
	    case PT_SHORT:
	      *data = [value asShortInMemCtx: memCtx];
	      break;
	    case PT_LONG:
	      *data = [value asLongInMemCtx: memCtx];
	      break;
	    case PT_BOOLEAN:
	      *data = [value asBooleanInMemCtx: memCtx];
	      break;
	    case PT_DOUBLE:
	      *data = [value asDoubleInMemCtx: memCtx];
	      break;
	    case PT_UNICODE:
	    case PT_STRING8:
	      *data = [value asUnicodeInMemCtx: memCtx];
	      break;
	    case PT_SYSTIME:
	      *data = [value asFileTimeInMemCtx: memCtx];
	      break;
	    case PT_BINARY:
	      *data = [value asShortBinaryInMemCtx: memCtx];
	      break;
	    default:
	      [self errorWithFormat: @"object type not handled: %d (0x%.4x)",
		    valueType, valueType];
	      *data = NULL;
	      rc = MAPI_E_NO_SUPPORT;
	    }
	}
      else
	{
	  if (proptag == PR_MID)
	    {
	      rc = MAPI_E_SUCCESS;
	      mapping = [MAPIStoreMapping sharedMapping];
	      mappingId = [mapping idFromURL: childURL];
	      if (mappingId == NSNotFound)
		{
		  mappingId = [[properties objectForKey: @"mid"]
				unsignedLongLongValue];
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
	    }
	  else
	    rc = [super getMessageTableChildproperty: data
					       atURL: childURL
					     withTag: proptag
					    inFolder: folder
					     withFID: fid];
	}
    }
  else
    {
      [self logWithFormat: @"object at url '%@' *not* found", childURL];
      rc = MAPI_E_INVALID_OBJECT;
    }

  return rc;
}

- (MAPIRestrictionState) evaluateBitmaskRestriction: (struct mapi_SBitmaskRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier
{
  [self errorWithFormat: @"%s: UNIMPLEMENTED METHOD, returning true",
	__PRETTY_FUNCTION__];
  // ^PR_VIEW_STYLE(0x68340003) & 0x00000001

  return MAPIRestrictionStateAlwaysTrue;
}

- (int) openMessage: (struct mapistore_message *) msg
              atURL: (NSString *) childURL
{
  static enum MAPITAGS tags[] = { PR_SUBJECT_UNICODE, PR_HASATTACH,
				  PR_MESSAGE_DELIVERY_TIME, PR_MESSAGE_FLAGS,
				  PR_FLAG_STATUS, PR_SENSITIVITY,
				  PR_SENT_REPRESENTING_NAME_UNICODE,
				  PR_INTERNET_MESSAGE_ID_UNICODE,
				  PR_READ_RECEIPT_REQUESTED };
  id child;
  struct SRowSet *recipients;
  struct SRow *properties;
  NSInteger count, max;
  int rc;
  void *propValue;

  [self logWithFormat: @"INCOMPLETE METHOD '%s' (%d): no recipient handling",
	__FUNCTION__, __LINE__];
  child = [self lookupObject: childURL];
  if (child)
    {
      recipients = talloc_zero (memCtx, struct SRowSet);
      recipients->cRows = 0;
      recipients->aRow = NULL;
      msg->recipients = recipients;

      max = 9;

      properties = talloc_zero (memCtx, struct SRow);
      properties->cValues = 0;
      properties->ulAdrEntryPad = 0;
      properties->lpProps = talloc_array (properties, struct SPropValue, max);
      for (count = 0; count < max; count++)
        {
          if ([self getMessageTableChildproperty: &propValue
                                           atURL: childURL
                                         withTag: tags[count]
                                        inFolder: nil
                                         withFID: 0]
              == MAPI_E_SUCCESS)
            {
              set_SPropValue_proptag (&(properties->lpProps[properties->cValues]),
                                      tags[count],
                                      propValue);
              properties->cValues++;
            }
        }

      msg->properties = properties;
      
      rc = MAPI_E_SUCCESS;
    }
  else
    rc = MAPI_E_NOT_FOUND;

  return rc;
}

@end
