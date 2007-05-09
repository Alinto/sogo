/* UIxFolderActions.h - this file is part of SOGo
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

#ifndef UIXFOLDERACTIONS_H
#define UIXFOLDERACTIONS_H

#import <NGObjWeb/WODirectAction.h>

@class NSString;
@class NSUserDefaults;
@class NSMutableString;
@class NSMutableDictionary;

@class LDAPUserManager;
@class SOGoFolder;

@interface UIxFolderActions : WODirectAction
{
  SOGoFolder *clientObject;
  LDAPUserManager *um;
  NSUserDefaults *ud;
  NSString *owner;
  NSString *login;
  NSString *baseFolder;
  NSMutableString *subscriptionPointer;
  NSMutableDictionary *moduleSettings;
}

- (WOResponse *) subscribeAction;
- (WOResponse *) unsubscribeAction;
- (WOResponse *) canAccessContentAction;
- (WOResponse *) activateFolderAction;
- (WOResponse *) deactivateFolderAction;

@end

#endif /* UIXFOLDERACTIONS_H */
