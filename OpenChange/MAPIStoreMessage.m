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

- (void) openMessage: (struct mapistore_message *) msg
            inMemCtx: (TALLOC_CTX *) memCtx
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
      if ([self getProperty: &propValue withTag: tags[count] inMemCtx: memCtx]
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
- (int) getSMTPAddrType: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"SMTP" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

/* getters */
- (int) getPrInstId: (void **) data // TODO: DOUBT
           inMemCtx: (TALLOC_CTX *) memCtx
{
  /* we return a unique id based on the key */
  *data = MAPILongLongValue (memCtx, [[sogoObject nameInContainer] hash]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrInstanceNum: (void **) data // TODO: DOUBT
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrRowType: (void **) data // TODO: DOUBT
            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, TBL_LEAF_ROW);

  return MAPISTORE_SUCCESS;
}

- (int) getPrDepth: (void **) data // TODO: DOUBT
          inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccess: (void **) data // TODO
           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x03);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccessLevel: (void **) data // TODO
                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x01);

  return MAPISTORE_SUCCESS;
}

// - (int) getPrViewStyle: (void **) data
// {
//   return [self getLongZero: data inMemCtx: memCtx];
// }

// - (int) getPrViewMajorversion: (void **) data
// {
//   return [self getLongZero: data inMemCtx: memCtx];
// }

- (int) getPidLidSideEffects: (void **) data // TODO
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPidLidCurrentVersion: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 115608); // Outlook 11.5608

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidCurrentVersionName: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"11.0" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAutoProcessState: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x00000000);

  return MAPISTORE_SUCCESS;
}

- (int) getPidNameContentClass: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"Sharing" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrFid: (void **) data
        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [container objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMid: (void **) data
        inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, [self objectId]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageLocaleId: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x0409);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageFlags: (void **) data // TODO
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, MSGFLAG_FROMME | MSGFLAG_READ | MSGFLAG_UNMODIFIED);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageSize: (void **) data // TODO
                inMemCtx: (TALLOC_CTX *) memCtx
{
  /* TODO: choose another name in SOGo for that method */
  *data = MAPILongValue (memCtx, [[sogoObject davContentLength] intValue]);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMsgStatus: (void **) data // TODO
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrImportance: (void **) data // TODO -> subclass?
               inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 1);

  return MAPISTORE_SUCCESS;
}

- (int) getPrPriority: (void **) data // TODO -> subclass?
             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrSensitivity: (void **) data // TODO -> subclass in calendar
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

- (int) getPrSubject: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  [self subclassResponsibility: _cmd];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrNormalizedSubject: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrSubject: data inMemCtx: memCtx];
}

- (int) getPrOriginalSubject: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrNormalizedSubject: data inMemCtx: memCtx];
}

- (int) getPrConversationTopic: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrNormalizedSubject: data inMemCtx: memCtx];
}

- (int) getPrSubjectPrefix: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPrDisplayTo: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPrDisplayCc: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPrDisplayBcc: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getEmptyString: data inMemCtx: memCtx];
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
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  NSURL *contextUrl;

  contextUrl = [[self context] url];
  *data = [[contextUrl user] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  [self subclassResponsibility: _cmd];

  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPrOrigMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrMessageClass: data inMemCtx: memCtx];
}

- (int) getPrHasattach: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPIBoolValue (memCtx,
                         [[self childKeysMatchingQualifier: nil
                                          andSortOrderings: nil] count] > 0);

  return MAPISTORE_SUCCESS;
}

- (int) getPrAssociated: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];;
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
