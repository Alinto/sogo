/* UIxFolderActions.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2014 Inverse inc.
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

#ifndef UIXFOLDERACTIONS_H
#define UIXFOLDERACTIONS_H

#import <NGObjWeb/WODirectAction.h>

@class NSString;
@class NSMutableString;
@class NSMutableDictionary;

@class LDAPUserManager;
@class SOGoGCSFolder;
@class SOGoUserSettings;

@interface UIxFolderActions : WODirectAction
{
  SOGoGCSFolder *clientObject;
  LDAPUserManager *um;
  SOGoUserSettings *us;
  NSString *owner;
  NSString *login;
  NSString *baseFolder;
  NSMutableDictionary *moduleSettings;
  BOOL isMailInvitation;
}

- (WOResponse *) subscribeAction;
- (WOResponse *) unsubscribeAction;
- (WOResponse *) canAccessContentAction;
- (WOResponse *) activateFolderAction;
- (WOResponse *) deactivateFolderAction;
- (WOResponse *) newguidAction;

@end

#endif /* UIXFOLDERACTIONS_H */
