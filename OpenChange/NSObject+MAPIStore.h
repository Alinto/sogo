/* NSObject+MAPIStore.h - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#ifndef NSOBJECT_MAPISTORE_H
#define NSOBJECT_MAPISTORE_H

#import <Foundation/NSObject.h>

#include <talloc.h>
#include <mapistore/mapistore_errors.h>

struct MAPIStoreTallocWrapper
{
  id instance;
};

@interface NSObject (MAPIStoreTallocHelpers)

- (struct MAPIStoreTallocWrapper *) tallocWrapper: (TALLOC_CTX *) tallocCtx;

@end

@interface NSObject (MAPIStoreDataTypes)

- (int) getValue: (void **) data
          forTag: (enum MAPITAGS) propTag
        inMemCtx: (TALLOC_CTX *) memCtx;

/* getter helpers */
- (int) getEmptyString: (void **) data inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getLongZero: (void **) data inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getYes: (void **) data inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getNo: (void **) data inMemCtx: (TALLOC_CTX *) memCtx;
- (int) getSMTPAddrType: (void **) data inMemCtx: (TALLOC_CTX *) memCtx;

@end

@interface NSObject (MAPIStoreExtension)

- (Class) mapistoreMessageClass;

@end

@interface NSObject (MAPIStoreProperties)

+ (enum mapistore_error) getAvailableProperties: (struct SPropTagArray **) propertiesP
                                       inMemCtx: (TALLOC_CTX *) memCtx;
+ (void) fillAvailableProperties: (struct SPropTagArray *) properties
                  withExclusions: (BOOL *) exclusions;

- (enum mapistore_error) getAvailableProperties: (struct SPropTagArray **) propertiesP
                                       inMemCtx: (TALLOC_CTX *) memCtx;
- (BOOL) canGetProperty: (enum MAPITAGS) propTag;

@end

#endif /* NSOBJECT_MAPISTORE_H */
