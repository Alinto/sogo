/* MAPIStoreTasksFolder.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <EOControl/EOQualifier.h>
#import <SOGo/SOGoPermissions.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoTaskObject.h>

#import "MAPIApplication.h"
#import "MAPIStoreTasksContext.h"
#import "MAPIStoreTasksMessage.h"
#import "MAPIStoreTasksMessageTable.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreTasksFolder.h"

#include <util/time.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreTasksFolder

- (MAPIStoreMessageTable *) messageTable
{
  [self synchroniseCache];
  return [MAPIStoreTasksMessageTable tableForContainer: self];
}

- (NSString *) component
{
  return @"vtodo";
}

- (MAPIStoreMessage *) createMessage
{
  MAPIStoreMessage *newMessage;
  SOGoTaskObject *newEntry;
  NSString *name;

  name = [NSString stringWithFormat: @"%@.ics",
                   [SOGoObject globallyUniqueObjectId]];
  newEntry = [SOGoTaskObject objectWithName: name
                                inContainer: sogoObject];
  [newEntry setIsNew: YES];
  newMessage = [MAPIStoreTasksMessage mapiStoreObjectWithSOGoObject: newEntry
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
    {
      [roles addObject: SOGoCalendarRole_PublicModifier];
      [roles addObject: SOGoCalendarRole_PrivateModifier];
      [roles addObject: SOGoCalendarRole_ConfidentialModifier];
    }
  else if (rights & RightsReadItems)
    {
      [roles addObject: SOGoCalendarRole_PublicViewer];
      [roles addObject: SOGoCalendarRole_PrivateViewer];
      [roles addObject: SOGoCalendarRole_ConfidentialViewer];
    }

  return roles;
}

- (uint32_t) exchangeRightsForRoles: (NSArray *) roles
{
  uint32_t rights = 0;

  if ([roles containsObject: SOGoRole_ObjectCreator])
    rights |= RightsCreateItems;
  if ([roles containsObject: SOGoRole_ObjectEraser])
    rights |= RightsDeleteAll;
  if ([roles containsObject: SOGoCalendarRole_PublicModifier]
      && [roles containsObject: SOGoCalendarRole_PrivateModifier]
      && [roles containsObject: SOGoCalendarRole_ConfidentialModifier])
    rights |= RightsReadItems | RightsEditAll;
  else if ([roles containsObject: SOGoCalendarRole_PublicViewer]
           && [roles containsObject: SOGoCalendarRole_PrivateViewer]
           && [roles containsObject: SOGoCalendarRole_ConfidentialViewer])
    rights |= RightsReadItems;
  if (rights != 0)
    rights |= RoleNone; /* actually "folder visible" */
 
  return rights;
}

- (EOQualifier *) aclQualifier
{
  return [EOQualifier qualifierWithQualifierFormat:
            [(SOGoAppointmentFolder *) sogoObject aclSQLListingFilter]];
}

- (int) getPidTagDefaultPostMessageClass: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [@"IPM.Task" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

@end
