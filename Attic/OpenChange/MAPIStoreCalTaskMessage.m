/* MAPIStoreCalTaskMessage.h - this file is part of SOGo
 *
 * Copyright (C) 2016 Enrique J. Hernandez
 *
 * Author: Enrique J. Hernandez <ejhernandez@zentyal.com>
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
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/SOGoPermissions.h>

#import "MAPIStoreFolder.h"
#import "MAPIStoreCalTaskMessage.h"

@implementation MAPIStoreCalTaskMessage

/* It must be implemented by subclasses */
- (NSUInteger) sensitivity
{
  [self subclassResponsibility: _cmd];

  return 0;
}

- (NSArray *) expandRoles: (NSArray *) roles
{
  return [container expandRoles: roles];
}

- (BOOL) subscriberCanModifyMessage
{
  BOOL rc;
  NSArray *roles;
 
  roles = [self activeUserRoles];
 
  if (isNew)
    rc = [roles containsObject: SOGoRole_ObjectCreator];
  else
    rc = ([roles containsObject: SOGoCalendarRole_ComponentModifier]
          || [roles containsObject: SOGoCalendarRole_ComponentResponder]);

  /* Check if the message is owned and it has permission to edit it */
  if (!rc && [roles containsObject: MAPIStoreRightEditOwn])
    {
      NSString *currentUser;

      currentUser = [[container context] activeUser];
      rc = [currentUser isEqual: [self ownerUser]];
    }

  if (!rc)
    {
      NSUInteger sensitivity;

      /* Get sensitivity of the message to check if the user can
         modify the message */
      sensitivity = [self sensitivity];
      /* FIXME: Use OpenChange constant names */
      switch (sensitivity)
        {
        case 0:  /* PUBLIC */
          rc = [roles containsObject: SOGoCalendarRole_PublicModifier]
               || [roles containsObject: SOGoCalendarRole_PublicResponder];
          break;
        case 1:  /* PERSONAL */
        case 2:  /* PRIVATE */
          rc = [roles containsObject: SOGoCalendarRole_PrivateModifier]
               || [roles containsObject: SOGoCalendarRole_PrivateResponder];
          break;
        case 3:  /* CONFIDENTIAL */
          rc = [roles containsObject: SOGoCalendarRole_ConfidentialModifier]
               || [roles containsObject: SOGoCalendarRole_ConfidentialResponder];
        }
    }
  return rc;
}

- (BOOL) subscriberCanReadMessage
{
  NSArray *roles;

  roles = [self activeUserRoles];

  return ([roles containsObject: SOGoCalendarRole_ComponentViewer]
          || [roles containsObject: SOGoCalendarRole_ComponentDAndTViewer]
          || [self subscriberCanModifyMessage]);
}

@end
