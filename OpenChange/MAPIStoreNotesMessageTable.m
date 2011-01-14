/* MAPIStoreNotesMessageTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
 *
 * Author: Ludovic Marcotte <lmarcotte@inverse.ca>
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

#import <SOGo/SOGoFolder.h>
#import <SOGo/SOGoObject.h>

#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreNotesMessageTable.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <libmapiproxy.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>
#include <talloc.h>


@implementation MAPIStoreNotesMessageTable

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  int rc;

  rc = MAPI_E_SUCCESS;
  switch (propTag)
    {
    case PR_ICON_INDEX: // TODO
      /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      // *longValue = 0x00000300 for blue
      // *longValue = 0x00000301 for green
      // *longValue = 0x00000302 for pink
      // *longValue = 0x00000303 for yellow
      // *longValue = 0x00000304 for white
      *data = MAPILongValue (memCtx, 0x00000303);
      break;

    default:
      rc = [super getChildProperty: data
			    forKey: childKey
			   withTag: propTag];
    }

  return rc;
}

@end
