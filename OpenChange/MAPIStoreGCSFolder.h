/* MAPIStoreGCSFolder.h - this file is part of SOGo
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

#ifndef MAPISTOREGCSFOLDER_H
#define MAPISTOREGCSFOLDER_H

#import "MAPIStoreFolder.h"

@class NSArray;
@class NSCalendarDate;
@class NSData;
@class NSMutableDictionary;
@class NSNumber;
@class NSString;

@interface MAPIStoreGCSFolder : MAPIStoreFolder
{
  SOGoMAPIFSMessage *versionsMessage;
  NSArray *activeUserRoles;
  EOQualifier *componentQualifier;
}

/* synchronisation */
- (BOOL) synchroniseCache;
- (void) updateVersionsForMessageWithKey: (NSString *) messageKey
                           withChangeKey: (NSData *) newChangeKey;
- (NSNumber *) lastModifiedFromMessageChangeNumber: (NSNumber *) changeNum;
- (NSNumber *) changeNumberForMessageWithKey: (NSString *) messageKey;

- (NSData *) changeKeyForMessageWithKey: (NSString *) messageKey;
- (NSData *) predecessorChangeListForMessageWithKey: (NSString *) messageKey;
- (void) setChangeKey: (NSData *) changeKey
    forMessageWithKey: (NSString *) messageKey;

- (NSArray *) activeUserRoles;

- (EOQualifier *) componentQualifier;
- (EOQualifier *) contentComponentQualifier;

/* subclasses */
- (EOQualifier *) aclQualifier;
- (NSString *) component;

@end

#endif /* MAPISTOREGCSFOLDER_H */
