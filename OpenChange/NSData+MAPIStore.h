/* NSData+MAPIStore.h - this file is part of SOGo
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

#ifndef NSDATA_MAPISTORE_H
#define NSDATA_MAPISTORE_H

#import <Foundation/NSData.h>

@interface NSData (MAPIStoreDataTypes)

+ (id) dataWithBinary: (const struct Binary_r *) binData;
- (struct Binary_r *) asBinaryInMemCtx: (void *) memCtx;

+ (id) dataWithShortBinary: (const struct SBinary_short *) binData;
- (struct SBinary_short *) asShortBinaryInMemCtx: (void *) memCtx;

+ (id) dataWithFlatUID: (const struct FlatUID_r *) flatUID;
- (struct FlatUID_r *) asFlatUIDInMemCtx: (void *) memCtx;

+ (id) dataWithGUID: (const struct GUID *) guid;
- (struct GUID *) asGUIDInMemCtx: (void *) memCtx;

+ (id) dataWithXID: (const struct XID *) xid;
- (struct XID *) asXIDInMemCtx: (void *) memCtx;

+ (id) dataWithChangeKeyGUID: (NSString *) guidString
                      andCnt: (NSData *) globCnt;

@end

@interface NSMutableData (MAPIStoreDataTypes)

- (void) appendUInt8: (uint8_t) value;
- (void) appendUInt16: (uint16_t) value;
- (void) appendUInt32: (uint32_t) value;

@end

#endif /* NSDATA_MAPISTORE_H */
