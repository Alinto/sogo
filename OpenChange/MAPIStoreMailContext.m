/* MAPIStoreMailContext.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/SOGoUserFolder.h>

#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMailContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

static Class SOGoUserFolderK;

// @implementation SOGoObject (ZombieD)

// - (void) dealloc
// {
//   [super dealloc];
// }

// @end

@implementation MAPIStoreMailContext

+ (void) initialize
{
  SOGoUserFolderK = [SOGoUserFolder class];
}

- (void) setupModuleFolder
{
  id userFolder, accountsFolder;

  userFolder = [SOGoUserFolderK objectWithName: [authenticator username]
                                   inContainer: MAPIApp];
  [woContext setClientObject: userFolder];
  [userFolder retain]; // LEAK

  accountsFolder = [userFolder lookupName: @"Mail"
                                inContext: woContext
                                  acquire: NO];
  [woContext setClientObject: accountsFolder];
  [accountsFolder retain]; // LEAK

  moduleFolder = [accountsFolder lookupName: @"0"
                                  inContext: woContext
                                    acquire: NO];
  [moduleFolder retain];
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
{
  return [(SOGoMailFolder *) folder toOneRelationshipKeys];
}

// - (int) getCommonTableChildproperty: (void **) data
//                               atURL: (NSString *) childURL
//                             withTag: (uint32_t) proptag
//                            inFolder: (SOGoFolder *) folder
//                             withFID: (uint64_t) fid
// {
//         int rc;

//         rc = MAPI_E_SUCCESS;
//         switch (proptag) {
//         default:
//                 rc = [super getCommonTableChildproperty: data
//                                                   atURL: childURL
//                                                 withTag: proptag
//                                                inFolder: folder
//                                                 withFID: fid];
//         }

//         return rc;
// }

- (int) getMessageTableChildproperty: (void **) data
                               atURL: (NSString *) childURL
                             withTag: (uint32_t) proptag
                            inFolder: (SOGoFolder *) folder
                             withFID: (uint64_t) fid
{
  SOGoMailObject *child;
  NSCalendarDate *offsetDate;
  int rc;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_ICON_INDEX: // TODO
      /* read mail, see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      *data = MAPILongValue (memCtx, 0x00000100);
      break;
    case PR_CONVERSATION_TOPIC:
    case PR_SUBJECT_UNICODE:
      child = [self lookupObject: childURL];
      *data = [[child decodedSubject] asUnicodeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup (memCtx, "IPM.Note");
      break;
    case PR_HASATTACH: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_MESSAGE_DELIVERY_TIME:
      child = [self lookupObject: childURL];
      offsetDate = [[child date] addYear: -1 month: 0 day: 0
                                    hour: 0 minute: 0 second: 0];
      *data = [offsetDate asFileTimeInMemCtx: memCtx];
      // *data = [[child date] asFileTimeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_FLAGS: // TODO
      // NSDictionary *coreInfos;
      // NSArray *flags;
      // child = [self lookupObject: childURL];
      // coreInfos = [child fetchCoreInfos];
      // flags = [coreInfos objectForKey: @"flags"];
      *data = MAPILongValue (memCtx, 0x02 | 0x20); // fromme + unmodified
      break;

    case PR_FLAG_STATUS: // TODO
    case PR_SENSITIVITY: // TODO
    case PR_FOLLOWUP_ICON: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;

    case PR_EXPIRY_TIME: // TODO
    case PR_REPLY_TIME:
      *data = [[NSCalendarDate date] asFileTimeInMemCtx: memCtx];
      break;
      

      // #define PR_ITEM_TEMPORARY_FLAGS                             PROP_TAG(PT_LONG      , 0x1097) /* 0x10970003 */
      // #define PR_SEARCH_KEY                                       PROP_TAG(PT_BINARY    , 0x300b) /* 0x300b0102 */

      // 36030003 - PR_CONTENT_UNREAD
      // 36020003 - PR_CONTENT_COUNT
      // 10970003 - 
      // 81f80003
      // 10950003
      // 819d0003
      // 300b0102
      // 81fa000b
      // 00300040
      // 00150040

    case PR_RECEIVED_BY_NAME:
      child = [self lookupObject: childURL];
      *data = [[child to] asUnicodeInMemCtx: memCtx];
      break;

    case PR_SENT_REPRESENTING_NAME_UNICODE:
      child = [self lookupObject: childURL];
      *data = [[child from] asUnicodeInMemCtx: memCtx];
      break;
    case PR_INTERNET_MESSAGE_ID_UNICODE:
      child = [self lookupObject: childURL];
      *data = [[child messageId] asUnicodeInMemCtx: memCtx];
      break;

    case PR_READ_RECEIPT_REQUESTED: // TODO
      *data = MAPIBoolValue (memCtx, NO);

    default:
      rc = [super getMessageTableChildproperty: data
                                         atURL: childURL
                                       withTag: proptag
                                      inFolder: folder
                                       withFID: fid];
    }
        
  return rc;
}

- (int) getFolderTableChildproperty: (void **) data
                              atURL: (NSString *) childURL
                            withTag: (uint32_t) proptag
                           inFolder: (SOGoFolder *) folder
                            withFID: (uint64_t) fid
{
  int rc;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_CONTENT_UNREAD:
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_CONTAINER_CLASS_UNICODE:
      *data = talloc_strdup (memCtx, "IPF.Note");
      break;
    default:
      rc = [super getFolderTableChildproperty: data
                                        atURL: childURL
                                      withTag: proptag
                                     inFolder: folder
                                      withFID: fid];
    }
  
  return rc;
}

@end
