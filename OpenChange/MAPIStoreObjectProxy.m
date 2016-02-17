/* MAPIStoreObjectProxy.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
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

#import "MAPIStorePropertySelectors.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreObjectProxy.h"

#undef DEBUG
#include <stdbool.h>
#include <talloc.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreObjectProxy

- (id) init
{
  if ((self = [super init]))
    {
      classGetters = (IMP *) MAPIStorePropertyGettersForClass (isa);
    }

  return self;
}

- (enum mapistore_error) getProperty: (void **) data
                             withTag: (enum MAPITAGS) propTag
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  MAPIStorePropertyGetter method;
  uint16_t propValue;
  SEL methodSel;
  int rc;

  propValue = (propTag & 0xffff0000) >> 16;
  methodSel = MAPIStoreSelectorForPropertyGetter (propValue);
  method = (MAPIStorePropertyGetter) classGetters[propValue];
  if (method)
    rc = method (self, methodSel, data, memCtx);
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

@end
