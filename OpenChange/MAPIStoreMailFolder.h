/* MAPIStoreMailFolder.h - this file is part of SOGo
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

#ifndef MAPISTOREMAILFOLDER_H
#define MAPISTOREMAILFOLDER_H

#import "MAPIStoreFolder.h"

@class NSNumber;

@class WOContext;

@class SOGoMailAccount;
@class SOGoMailFolder;

@class MAPIStoreMailMessageTable;

@interface MAPIStoreMailFolder : MAPIStoreFolder
{
  SOGoMAPIFSMessage *versionsMessage;
}

- (BOOL) ensureFolderExists;

/* synchronisation & versioning */
- (BOOL) synchroniseCache;
- (NSNumber *) modseqFromMessageChangeNumber: (NSNumber *) changeNum;
- (NSNumber *) messageUIDFromMessageKey: (NSString *) messageKey;
- (NSNumber *) changeNumberForMessageUID: (NSNumber *) messageUid;
- (void) setChangeKey: (NSData *) changeKey
    forMessageWithKey: (NSString *) messageKey;
- (NSData *) changeKeyForMessageWithKey: (NSString *) messageKey;
- (NSData *) predecessorChangeListForMessageWithKey: (NSString *) messageKey;

@end

/* MAPIStoreOutboxFolder is a special subclass of MAPIStoreMailFolder where
   the displayname is always "Outbox" and can not be changed. */
@interface MAPIStoreOutboxFolder : MAPIStoreMailFolder
@end

#endif /* MAPISTOREMAILFOLDER_H */
