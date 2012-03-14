/* NSArray+MAPIStore.h - this file is part of SOGo
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

#ifndef NSARRAY_MAPISTORE_H
#define NSARRAY_MAPISTORE_H

#import <Foundation/NSArray.h>

@interface NSArray (MAPIStoreFolders)

/* mapi structs */
+ (id) arrayFromMAPIMVLong: (const struct mapi_MV_LONG_STRUCT *) mvLong;
+ (id) arrayFromMAPIMVUnicode: (const struct mapi_SLPSTRArrayW *) mvUnicode;
+ (id) arrayFromMAPIMVString: (const struct mapi_SLPSTRArray *) mvString;
+ (id) arrayFromMAPIMVBinary: (const struct mapi_SBinaryArray *) mvBinary;
+ (id) arrayFromMAPIMVGuid: (const struct mapi_SGuidArray *) mvGuid;

+ (id) arrayFromMVShort: (const struct ShortArray_r *) mvShort;
+ (id) arrayFromMVLong: (const struct LongArray_r *) mvLong;
- (struct LongArray_r *) asMVLongInMemCtx: (void *) memCtx;
+ (id) arrayFromMVI8: (const struct I8Array_r *) mvI8;
+ (id) arrayFromMVString: (const struct StringArray_r *) mvString;
+ (id) arrayFromMVUnicode: (const struct StringArrayW_r *) mvUnicode;
- (struct StringArrayW_r *) asMVUnicodeInMemCtx: (void *) memCtx;
+ (id) arrayFromMVBinary: (const struct BinaryArray_r *) mvBinary;
- (struct BinaryArray_r *) asMVBinaryInMemCtx: (void *) memCtx;
+ (id) arrayFromMVGuid: (const struct FlatUIDArray_r *) mvGuid;
+ (id) arrayFromMVFileTime: (const struct DateTimeArray_r *) mvGuid;

@end

#endif /* NSARRAY+MAPISTORE_H */
