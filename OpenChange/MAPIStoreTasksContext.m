/* MAPIStoreTasksContext.m - this file is part of SOGo
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

#import <NGCards/iCalToDo.h>
#import <Appointments/SOGoTaskObject.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoGCSFolder+MAPIStore.h"

#import "MAPIStoreTasksContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

static Class SOGoUserFolderK;

@implementation MAPIStoreTasksContext

+ (void) initialize
{
  SOGoUserFolderK = [SOGoUserFolder class];
}

- (void) setupModuleFolder
{
  id userFolder;

  userFolder = [SOGoUserFolderK objectWithName: [authenticator username]
                                   inContainer: MAPIApp];
  [woContext setClientObject: userFolder];
  [userFolder retain]; // LEAK

  moduleFolder = [userFolder lookupName: @"Calendar"
                              inContext: woContext
                                acquire: NO];
  [moduleFolder retain];
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
{
  return [(SOGoGCSFolder *) folder componentKeysWithType: @"vtodo"];
}

- (int) getMessageTableChildproperty: (void **) data
                               atURL: (NSString *) childURL
                             withTag: (uint32_t) proptag
                            inFolder: (SOGoFolder *) folder
                             withFID: (uint64_t) fid
{
  uint32_t *longValue;
  uint8_t *boolValue;
  NSString *status;
  // id child;
  id task;
  int rc;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_ICON_INDEX: // TODO
      longValue = talloc_zero(memCtx, uint32_t);
      *longValue = 0x00000500; /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      // Unassigned recurring task 0x00000501
      // Assignee's task 0x00000502
      // Assigner's task 0x00000503
      // Task request 0x00000504
      // Task acceptance 0x00000505
      // Task rejection 0x00000506
      *data = longValue;
      break;
    case PR_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup(memCtx, "IPM.Task");
      break;
    case PR_SUBJECT_UNICODE: // SUMMARY
    case PR_NORMALIZED_SUBJECT_UNICODE:
    case PR_CONVERSATION_TOPIC_UNICODE:
      task = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[task summary] asUnicodeInMemCtx: memCtx];
      break;
    case 0x8124000b: // completed
      boolValue = talloc_zero(memCtx, uint8_t);
      task = [[self lookupObject: childURL] component: NO secure: NO];
      *boolValue = [[task status] isEqualToString: @"COMPLETED"];
      *data = boolValue;
      break;
    case 0x81250040: // completion date
      task = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[task completed] asFileTimeInMemCtx: memCtx];
      break;
    case PR_CREATION_TIME:
      task = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[task created] asFileTimeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_DELIVERY_TIME:
    case PR_CLIENT_SUBMIT_TIME:
    case PR_LOCAL_COMMIT_TIME:
    case PR_LAST_MODIFICATION_TIME:
      task = [[self lookupObject: childURL] component: NO secure: NO];
      *data = [[task lastModified] asFileTimeInMemCtx: memCtx];
      break;
    case 0x81200003: // status
      longValue = talloc_zero(memCtx, uint32_t);
      task = [[self lookupObject: childURL] component: NO secure: NO];
      status = [task status];
      if (![status length]
          || [status isEqualToString: @"NEEDS-ACTIONS"])
        *longValue = 0;
      else if ([status isEqualToString: @"IN-PROCESS"])
        *longValue = 1;
      else if ([status isEqualToString: @"COMPLETED"])
        *longValue = 2;
      *data = longValue;
      break;
      /* Completed */
      // -	0x81380003 = -2000
      // +	0x81380003 = -4000
      
      // 68330048
      // 68420102
    case 0x68340003:
    case 0x683a0003:
    case 0x68410003:
      longValue = talloc_zero(memCtx, uint32_t);
      *longValue = 0;
      *data = longValue;
      break;

    default:
      rc = [super getMessageTableChildproperty: data
                                         atURL: childURL
                                       withTag: proptag
                                      inFolder: folder
                                       withFID: fid];
    }

  return rc;
}

@end
