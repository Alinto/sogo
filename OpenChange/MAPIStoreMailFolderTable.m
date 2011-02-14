/* MAPIStoreMailFolderTable.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import <EOControl/EOQualifier.h>

#import <Mailer/SOGoMailFolder.h>

#import "NSString+MAPIStore.h"
#import "NSValue+MAPIStore.h"
#import "MAPIStoreTypes.h"

#import "MAPIStoreMailFolderTable.h"

@implementation MAPIStoreMailFolderTable

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  enum MAPISTATUS rc;
  SOGoMailFolder *child;
  EOQualifier *searchQualifier;
  uint32_t intValue;
  
  rc = MAPI_E_SUCCESS;
  switch (propTag)
    {
    case PR_CONTENT_UNREAD:
      child = [self lookupChild: childKey];
      searchQualifier
        = [EOQualifier qualifierWithQualifierFormat: @"flags = %@ AND not flags = %@",
                       @"unseen", @"deleted"];
      intValue = [[child fetchUIDsMatchingQualifier: searchQualifier
                                       sortOrdering: nil] count];
      [self logWithFormat: @"unread count for %@: %u\n", childKey, intValue];
      *data = MAPILongValue (memCtx, intValue);
      break;
    case PR_CONTAINER_CLASS_UNICODE:
      *data = [@"IPF.Note" asUnicodeInMemCtx: memCtx];
      break;
    default:
      rc = [super getChildProperty: data
			    forKey: childKey
			   withTag: propTag];
    }
  
  return rc;
}

@end
