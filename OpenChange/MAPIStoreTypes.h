/* MAPIStoreTypes.h - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
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

#ifndef MAPISTORETYPES_H
#define MAPISTORETYPES_H

#import <Foundation/NSValue.h>

#include <stdbool.h>
#include <talloc.h>
#include <util/time.h>
#include <gen_ndr/exchange.h>

@class NSData;
@class NSDictionary;
@class NSTimeZone;

extern NSTimeZone *utcTZ;

uint8_t *MAPIBoolValue (void *memCtx, BOOL value);
uint32_t *MAPILongValue (void *memCtx, uint32_t value);
uint64_t *MAPILongLongValue (void *memCtx, uint64_t value);
double *MAPIDoubleValue (void *memCtx, double value);

id NSObjectFromSPropValue (const struct SPropValue *);
id NSObjectFromMAPISPropValue (const struct mapi_SPropValue *);
id NSObjectFromValuePointer (enum MAPITAGS, const void *);

NSComparisonResult MAPICNCompare (uint64_t cn1, uint64_t cn2, void *);
NSComparisonResult MAPIChangeKeyGUIDCompare (id ck1, id ck2, void *);

static inline NSNumber *
MAPIPropertyKey (enum MAPITAGS propTag)
{
#if (GS_SIZEOF_LONG == 4)
  return [NSNumber numberWithUnsignedLong: propTag];
#elif (GS_SIZEOF_INT == 4)
  return [NSNumber numberWithUnsignedInt: propTag];
#else
#error No suitable type for 4 bytes integers
#endif
}

void MAPIStoreDumpMessageProperties (NSDictionary *properties);

#endif /* MAPISTORETYPES_H */
