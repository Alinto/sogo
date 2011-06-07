/* MAPIStoreMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
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
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoObject.h>

#import "MAPIStoreAttachmentTable.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davEntityTag;
- (NSString *) davContentLength;

@end

@implementation MAPIStoreMessage

- (id) init
{
  if ((self = [super init]))
    {
      mapiRetainCount = 0;
      attachmentKeys = nil;
      attachmentParts = nil;
      activeTables = [NSMutableArray new];
    }

  return self;
}

- (void) dealloc
{
  [attachmentKeys release];
  [attachmentParts release];
  [activeTables release];
  [super dealloc];
}

- (void) setMAPIRetainCount: (uint32_t) newCount
{
  mapiRetainCount = newCount;
}

- (uint32_t) mapiRetainCount
{
  return mapiRetainCount;
}

- (void) openMessage: (struct mapistore_message *) msg
{
  static enum MAPITAGS tags[] = { PR_SUBJECT_PREFIX_UNICODE,
                                  PR_NORMALIZED_SUBJECT_UNICODE };
  struct SRowSet *recipients;
  struct SRow *properties;
  NSInteger count, max;
  const char *propName;
  void *propValue;

  // [self logWithFormat: @"INCOMPLETE METHOD '%s' (%d): no recipient handling",
  //       __FUNCTION__, __LINE__];

  recipients = talloc_zero (memCtx, struct SRowSet);
  recipients->cRows = 0;
  recipients->aRow = NULL;
  msg->recipients = recipients;

  max = 2;
  properties = talloc_zero (memCtx, struct SRow);
  properties->cValues = 0;
  properties->ulAdrEntryPad = 0;
  properties->lpProps = talloc_array (properties, struct SPropValue, max);
  for (count = 0; count < max; count++)
    {
      if ([self getProperty: &propValue withTag: tags[count]]
          == MAPI_E_SUCCESS)
	{
	  if (propValue == NULL)
	    {
	      propName = get_proptag_name (tags[count]);
	      if (!propName)
		propName = "<unknown>";
	      [self errorWithFormat: @"both 'success' and NULL data"
		    @" returned for proptag %s(0x%.8x)",
		    propName, tags[count]];
	    }
	  else
	    {
	      set_SPropValue_proptag (properties->lpProps + properties->cValues,
				      tags[count],
				      propValue);
	      properties->cValues++;
	    }
	}
    }
  msg->properties = properties;
}

/* helper getters */
- (int) getSMTPAddrType: (void **) data
{
  *data = [@"SMTP" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

/* getters */
- (int) getPrInstId: (void **) data // TODO: DOUBT
{
  /* we return a unique id based on the key */
  *data = MAPILongLongValue (memCtx, [[sogoObject nameInContainer] hash]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrInstanceNum: (void **) data // TODO: DOUBT
{
  return [self getLongZero: data];
}

- (int) getPrRowType: (void **) data // TODO: DOUBT
{
  *data = MAPILongValue (memCtx, TBL_LEAF_ROW);

  return MAPISTORE_SUCCESS;
}

- (int) getPrDepth: (void **) data // TODO: DOUBT
{
  *data = MAPILongLongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccess: (void **) data // TODO
{
  *data = MAPILongValue (memCtx, 0x03);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccessLevel: (void **) data // TODO
{
  *data = MAPILongValue (memCtx, 0x01);

  return MAPISTORE_SUCCESS;
}

// - (int) getPrViewStyle: (void **) data
// {
//   return [self getLongZero: data];
// }

// - (int) getPrViewMajorversion: (void **) data
// {
//   return [self getLongZero: data];
// }

- (int) getPidLidSideEffects: (void **) data // TODO
{
  return [self getLongZero: data];
}

- (int) getPidLidCurrentVersion: (void **) data
{
  *data = MAPILongValue (memCtx, 115608); // Outlook 11.5608

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidCurrentVersionName: (void **) data
{
  *data = [@"11.0" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAutoProcessState: (void **) data
{
  *data = MAPILongValue (memCtx, 0x00000000);

  return MAPISTORE_SUCCESS;
}

- (int) getPidNameContentClass: (void **) data
{
  *data = [@"Sharing" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrFid: (void **) data
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMid: (void **) data
{
  *data = MAPILongLongValue (memCtx, [self objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageLocaleId: (void **) data
{
  *data = MAPILongValue (memCtx, 0x0409);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageFlags: (void **) data // TODO
{
  *data = MAPILongValue (memCtx, MSGFLAG_FROMME | MSGFLAG_READ | MSGFLAG_UNMODIFIED);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageSize: (void **) data // TODO
{
  /* TODO: choose another name in SOGo for that method */
  *data = MAPILongValue (memCtx, [[sogoObject davContentLength] intValue]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMsgStatus: (void **) data // TODO
{
  return [self getLongZero: data];
}

- (int) getPrImportance: (void **) data // TODO -> subclass?
{
  *data = MAPILongValue (memCtx, 1);

  return MAPISTORE_SUCCESS;
}

- (int) getPrPriority: (void **) data // TODO -> subclass?
{
  return [self getLongZero: data];
}

- (int) getPrSensitivity: (void **) data // TODO -> subclass in calendar
{
  return [self getLongZero: data];
}

- (int) getPrSubject: (void **) data
{
  [self subclassResponsibility: _cmd];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrNormalizedSubject: (void **) data
{
  return [self getPrSubject: data];
}

- (int) getPrOriginalSubject: (void **) data
{
  return [self getPrNormalizedSubject: data];
}

- (int) getPrConversationTopic: (void **) data
{
  return [self getPrNormalizedSubject: data];
}

- (int) getPrSubjectPrefix: (void **) data
{
  return [self getEmptyString: data];
}

- (int) getPrDisplayTo: (void **) data
{
  return [self getEmptyString: data];
}

- (int) getPrDisplayCc: (void **) data
{
  return [self getEmptyString: data];
}

- (int) getPrDisplayBcc: (void **) data
{
  return [self getEmptyString: data];
}

// - (int) getPrOriginalDisplayTo: (void **) data
// {
//   return [self getPrDisplayTo: data];
// }

// - (int) getPrOriginalDisplayCc: (void **) data
// {
//   return [self getPrDisplayCc: data];
// }

// - (int) getPrOriginalDisplayBcc: (void **) data
// {
//   return [self getPrDisplayBcc: data];
// }

- (int) getPrLastModifierName: (void **) data
{
  NSURL *contextUrl;

  contextUrl = [[self context] url];
  *data = [[contextUrl user] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
{
  [self subclassResponsibility: _cmd];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrOrigMessageClass: (void **) data
{
  return [self getPrMessageClass: data];
}

- (int) getPrHasattach: (void **) data
{
  *data = MAPIBoolValue (memCtx,
                         [[self childKeysMatchingQualifier: nil
                                          andSortOrderings: nil] count] > 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAssociated: (void **) data
{
  return [self getNo: data];
}

- (void) save
{
  [self subclassResponsibility: _cmd];
}

- (void) submit
{
  [self subclassResponsibility: _cmd];
}

- (MAPIStoreAttachment *) createAttachment
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (MAPIStoreAttachmentTable *) attachmentTable
{
  return [MAPIStoreAttachmentTable tableForContainer: self];
}

- (void) addActiveTable: (MAPIStoreTable *) activeTable
{
  [activeTables addObject: activeTable];
}

- (void) removeActiveTable: (MAPIStoreTable *) activeTable
{
  [activeTables removeObject: activeTable];
}

@end
