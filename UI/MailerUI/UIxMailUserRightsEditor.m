/* UIxMailUserRightsEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <NGObjWeb/WORequest.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxMailUserRightsEditor.h"

@implementation UIxMailUserRightsEditor

- (void) setUserCanReadMails: (BOOL) userCanReadMails
{
  if (userCanReadMails)
    [self appendRight: SOGoRole_ObjectViewer];
  else
    [self removeRight: SOGoRole_ObjectViewer];
}

- (BOOL) userCanReadMails
{
  return [userRights containsObject: SOGoRole_ObjectViewer];
}

- (void) setUserCanMarkMailsRead: (BOOL) userCanMarkMailsRead
{
  if (userCanMarkMailsRead)
    [self appendRight: SOGoMailRole_SeenKeeper];
  else
    [self removeRight: SOGoMailRole_SeenKeeper];
}

- (BOOL) userCanMarkMailsRead
{
  return [userRights containsObject: SOGoMailRole_SeenKeeper];
}

- (void) setUserCanWriteMails: (BOOL) userCanWriteMails
{
  if (userCanWriteMails)
    [self appendRight: SOGoMailRole_Writer];
  else
    [self removeRight: SOGoMailRole_Writer];
}

- (BOOL) userCanWriteMails
{
  return [userRights containsObject: SOGoMailRole_Writer];
}

- (void) setUserCanInsertMails: (BOOL) userCanInsertMails
{
  if (userCanInsertMails)
    [self appendRight: SOGoRole_ObjectCreator];
  else
    [self removeRight: SOGoRole_ObjectCreator];
}

- (BOOL) userCanInsertMails
{
  return [userRights containsObject: SOGoRole_ObjectCreator];
}

- (void) setUserCanPostMails: (BOOL) userCanPostMails
{
  if (userCanPostMails)
    [self appendRight: SOGoMailRole_Poster];
  else
    [self removeRight: SOGoMailRole_Poster];
}

- (BOOL) userCanPostMails
{
  return [userRights containsObject: SOGoMailRole_Poster];
}

- (void) setUserCanCreateSubfolders: (BOOL) userCanCreateSubfolders
{
  if (userCanCreateSubfolders)
    [self appendRight: SOGoRole_FolderCreator];
  else
    [self removeRight: SOGoRole_FolderCreator];
}

- (BOOL) userCanCreateSubfolders
{
  return [userRights containsObject: SOGoRole_FolderCreator];
}

- (void) setUserCanRemoveFolder: (BOOL) userCanRemoveFolder
{
  if (userCanRemoveFolder)
    [self appendRight: SOGoRole_FolderEraser];
  else
    [self removeRight: SOGoRole_FolderEraser];
}

- (BOOL) userCanRemoveFolder
{
  return [userRights containsObject: SOGoRole_FolderEraser];
}

- (void) setUserCanEraseMails: (BOOL) userCanEraseMails
{
  if (userCanEraseMails)
    [self appendRight: SOGoRole_ObjectEraser];
  else
    [self removeRight: SOGoRole_ObjectEraser];
}

- (BOOL) userCanEraseMails
{
  return [userRights containsObject: SOGoRole_ObjectEraser];
}

- (void) setUserCanExpungeFolder: (BOOL) userCanExpungeFolder
{
  if (userCanExpungeFolder)
    [self appendRight: SOGoMailRole_Expunger];
  else
    [self removeRight: SOGoMailRole_Expunger];
}

- (BOOL) userCanExpungeFolder
{
  return [userRights containsObject: SOGoMailRole_Expunger];
}

- (void) setUserIsAdministrator: (BOOL) userIsAdministrator
{
  if (userIsAdministrator)
    [self appendRight: SOGoMailRole_Administrator];
  else
    [self removeRight: SOGoMailRole_Administrator];
}

- (BOOL) userIsAdministrator
{
  return [userRights containsObject: SOGoMailRole_Administrator];
}

- (void) updateRights
{
  WORequest *request;

  request = [context request];

  if ([[request formValueForKey: SOGoRole_ObjectViewer] length] > 0)
    [self appendRight: SOGoRole_ObjectViewer];
  else
    [self removeRight: SOGoRole_ObjectViewer];

  if ([[request formValueForKey: SOGoMailRole_SeenKeeper] length] > 0)
    [self appendRight: SOGoMailRole_SeenKeeper];
  else
    [self removeRight: SOGoMailRole_SeenKeeper];

  if ([[request formValueForKey: SOGoMailRole_Writer] length] > 0)
    [self appendRight: SOGoMailRole_Writer];
  else
    [self removeRight: SOGoMailRole_Writer];

  if ([[request formValueForKey: SOGoRole_ObjectCreator] length] > 0)
    [self appendRight: SOGoRole_ObjectCreator];
  else
    [self removeRight: SOGoRole_ObjectCreator];

  if ([[request formValueForKey: SOGoMailRole_Poster] length] > 0)
    [self appendRight: SOGoMailRole_Poster];
  else
    [self removeRight: SOGoMailRole_Poster];

  if ([[request formValueForKey: SOGoRole_FolderCreator] length] > 0)
    [self appendRight: SOGoRole_FolderCreator];
  else
    [self removeRight: SOGoRole_FolderCreator];

  if ([[request formValueForKey: SOGoRole_FolderEraser] length] > 0)
    [self appendRight: SOGoRole_FolderEraser];
  else
    [self removeRight: SOGoRole_FolderEraser];

  if ([[request formValueForKey: SOGoRole_ObjectEraser] length] > 0)
    [self appendRight: SOGoRole_ObjectEraser];
  else
    [self removeRight: SOGoRole_ObjectEraser];

  if ([[request formValueForKey: SOGoMailRole_Expunger] length] > 0)
    [self appendRight: SOGoMailRole_Expunger];
  else
    [self removeRight: SOGoMailRole_Expunger];

  if ([[request formValueForKey: SOGoMailRole_Administrator] length] > 0)
    [self appendRight: SOGoMailRole_Administrator];
  else
    [self removeRight: SOGoMailRole_Administrator];
}

@end
 
