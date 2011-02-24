/* MAPIStoreAttachment.m - this file is part of $PROJECT_NAME_HERE$
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

#import "MAPIStoreAttachment.h"

#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreAttachment

- (void) setAID: (uint32_t) newAID
{
  aid = newAID;
}

- (uint32_t) AID
{
  return aid;
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
{
  return  MAPISTORE_ERR_NOT_FOUND;
}

@end
