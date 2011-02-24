/* MAPIStoreFolderTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
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

#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreFolder.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"

#import "MAPIStoreFolderTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>
#include <libmapiproxy.h>

@implementation MAPIStoreFolderTable

static MAPIStoreMapping *mapping;

+ (void) initialize
{
  mapping = [MAPIStoreMapping sharedMapping];
}

- (NSArray *) childKeys
{
  return [(MAPIStoreFolder *) container folderKeys];
}

- (NSArray *) restrictedChildKeys
{
  [self errorWithFormat: @"restrictions are ignored on folder tables"];
  return [self childKeys];
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  return nil;
}

@end
