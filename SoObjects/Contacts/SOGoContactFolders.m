/* SOGoContactFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2006, 2007 Inverse groupe conseil
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

/* MailItems                IPF.Note
   ContactItems             IPF.Contact
   AppointmentItems         IPF.Appointment
   NoteItems                IPF.StickyNote
   TaskItems                IPF.Task
   JournalItems             IPF.Journal     */

// #import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSEnumerator.h>

// #import <NGObjWeb/NSException+HTTP.h>
// #import <NGObjWeb/WOApplication.h>
// #import <NGObjWeb/WOContext.h>
// #import <NGObjWeb/WOContext+SoObjects.h>
// #import <NGObjWeb/WOResponse.h>
// #import <NGObjWeb/SoUser.h>

// #import <GDLContentStore/GCSFolderManager.h>
// #import <GDLContentStore/GCSChannelManager.h>
// #import <GDLAccess/EOAdaptorChannel.h>
// #import <GDLContentStore/NSURL+GCS.h>

#import <SoObjects/SOGo/LDAPUserManager.h>
// #import <SoObjects/SOGo/SOGoPermissions.h>

#import "SOGoContactGCSFolder.h"
#import "SOGoContactLDAPFolder.h"
#import "SOGoContactFolders.h"

@implementation SOGoContactFolders

+ (NSString *) gcsFolderType
{
  return @"Contact";
}

+ (Class) subFolderClass
{
  return [SOGoContactGCSFolder class];
}

- (void) appendSystemSources
{
  LDAPUserManager *um;
  NSEnumerator *sourceIDs;
  NSString *currentSourceID, *displayName;
  SOGoContactLDAPFolder *currentFolder;

  um = [LDAPUserManager sharedUserManager];
  sourceIDs = [[um addressBookSourceIDs] objectEnumerator]; 
  currentSourceID = [sourceIDs nextObject];
  while (currentSourceID)
    {
      displayName = [um displayNameForSourceWithID: currentSourceID];
      currentFolder = [SOGoContactLDAPFolder folderWithName: currentSourceID
					     andDisplayName: displayName
					     inContainer: self];
      [currentFolder setLDAPSource: [um sourceWithID: currentSourceID]];
      [subFolders setObject: currentFolder forKey: currentSourceID];
      currentSourceID = [sourceIDs nextObject];
    }
}

@end
