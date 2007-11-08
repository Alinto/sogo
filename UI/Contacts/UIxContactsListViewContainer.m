/* UIxContactsListViewContainer.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/SoObjects.h>
#import <NGExtensions/NSObject+Values.h>

#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/Contacts/SOGoContactFolder.h>
#import <SoObjects/Contacts/SOGoContactFolders.h>

#import "UIxContactsListViewContainer.h"

@class SOGoContactFolders;

@implementation UIxContactsListViewContainer

- (id) init
{
  if ((self = [super init]))
    {
      selectorComponentClass = nil;
    }

  return self;
}

- (void) setSelectorComponentClass: (NSString *) aComponentClass
{
  selectorComponentClass = aComponentClass;
}

- (NSString *) selectorComponentName
{
  return selectorComponentClass;
}

- (WOElement *) selectorComponent
{
  WOElement *newComponent;
//   Class componentClass;

//   componentClass = NSClassFromString(selectorComponentClass);
//   if (componentClass)
//     {
  newComponent = [self pageWithName: selectorComponentClass];
//     }
//   else
//     newComponent = nil;

  return newComponent;
}

- (void) setCurrentFolder: (id) folder
{
  currentFolder = folder;
}

- (NSArray *) contactFolders
{
  SOGoContactFolders *folderContainer;

  folderContainer = [[self clientObject] container];

  return [folderContainer subFolders];
}

- (NSString *) currentContactFolderId
{
  return [NSString stringWithFormat: @"/%@",
                   [currentFolder nameInContainer]];
}

- (NSString *) currentContactFolderName
{
  NSString *folderName, *defaultFolderName;

  folderName = [currentFolder displayName];
  defaultFolderName = [[currentFolder container] defaultFolderName];
  if ([folderName isEqualToString: folderName])
    folderName = [self labelForKey: folderName];

  return folderName;
}

- (NSString *) currentContactFolderOwner
{
  return [currentFolder ownerInContext: context];
}

- (BOOL) hasContactSelectionButtons
{
  return (selectorComponentClass != nil);
}

- (BOOL) isPopup
{
  return [[self queryParameterForKey: @"popup"] boolValue];
}

@end
