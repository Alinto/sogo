/* MAPIStoreNotesMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

#import <Foundation/NSDictionary.h>

#import "MAPIStoreTypes.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreNotesMessage.h"

#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreNotesMessage

- (int) getPidTagIconIndex: (void **) data // TODO
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
  // *longValue = 0x00000300 for blue
  // *longValue = 0x00000301 for green
  // *longValue = 0x00000302 for pink
  // *longValue = 0x00000303 for yellow
  // *longValue = 0x00000304 for white
  *data = MAPILongValue (memCtx, 0x00000303);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMessageClass: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.StickyNote" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

@end
