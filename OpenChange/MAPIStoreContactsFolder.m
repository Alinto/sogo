/* MAPIStoreContactsFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

#import <Foundation/NSURL.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <EOControl/EOQualifier.h>
#import <SOGo/SOGoPermissions.h>
#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactFolders.h>

#import "MAPIApplication.h"
#import "MAPIStoreContactsContext.h"
#import "MAPIStoreContactsMessage.h"
#import "MAPIStoreContactsMessageTable.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContactsFolder.h"

#include <util/time.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreContactsFolder

- (MAPIStoreMessageTable *) messageTable
{
  [self synchroniseCache];
  return [MAPIStoreContactsMessageTable tableForContainer: self];
}

- (NSString *) component
{
  return @"vcard";
}

- (MAPIStoreMessage *) createMessage
{
  MAPIStoreMessage *newMessage;
  SOGoContactGCSEntry *newEntry;
  NSString *name;

  name = [NSString stringWithFormat: @"%@.vcf",
                   [SOGoObject globallyUniqueObjectId]];
  newEntry = [SOGoContactGCSEntry objectWithName: name
				     inContainer: sogoObject];
  [newEntry setIsNew: YES];
  newMessage = [MAPIStoreContactsMessage mapiStoreObjectWithSOGoObject: newEntry
                                                           inContainer: self];

  return newMessage;
}

- (NSArray *) rolesForExchangeRights: (uint32_t) rights
{
  NSMutableArray *roles;

  roles = [NSMutableArray arrayWithCapacity: 6];
  if (rights & RightsCreateItems)
    [roles addObject: SOGoRole_ObjectCreator];
  if (rights & RightsDeleteAll)
    [roles addObject: SOGoRole_ObjectEraser];
  if (rights & RightsEditAll)
    [roles addObject: SOGoRole_ObjectEditor];
  if (rights & RightsReadItems)
    [roles addObject: SOGoRole_ObjectViewer];

  return roles;
}

- (uint32_t) exchangeRightsForRoles: (NSArray *) roles
{
  uint32_t rights = 0;

  if ([roles containsObject: SOGoRole_ObjectCreator])
    rights |= RightsCreateItems;
  if ([roles containsObject: SOGoRole_ObjectEraser])
    rights |= RightsDeleteAll;
  if ([roles containsObject: SOGoRole_ObjectEditor])
    rights |= RightsEditAll;
  if ([roles containsObject: SOGoRole_ObjectViewer])
    rights |= RightsReadItems;
  if (rights != 0)
    rights |= RoleNone; /* actually "folder visible" */
 
  return rights;
}

- (BOOL) subscriberCanModifyMessages
{
  return [[self activeUserRoles] containsObject: SOGoRole_ObjectEditor];
}

- (BOOL) subscriberCanReadMessages
{
  return [[self activeUserRoles] containsObject: SOGoRole_ObjectViewer];
}

- (int) getPidTagDefaultPostMessageClass: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.Contact" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

@end
