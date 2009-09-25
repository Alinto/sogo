/* SOGoContactFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2006, 2007 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSEnumerator.h>

#import <SoObjects/SOGo/SOGoUserManager.h>

#import "SOGoContactGCSFolder.h"
#import "SOGoContactSourceFolder.h"
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

- (NSException *) appendSystemSources
{
  SOGoUserManager *um;
  NSEnumerator *sourceIDs;
  NSString *currentSourceID, *srcDisplayName;
  SOGoContactSourceFolder *currentFolder;

  um = [SOGoUserManager sharedUserManager];
  sourceIDs = [[um addressBookSourceIDs] objectEnumerator]; 
  while ((currentSourceID = [sourceIDs nextObject]))
    {
      srcDisplayName = [um displayNameForSourceWithID: currentSourceID];
      currentFolder = [SOGoContactSourceFolder folderWithName: currentSourceID
					       andDisplayName: srcDisplayName
					       inContainer: self];
      [currentFolder setSource: [um sourceWithID: currentSourceID]];
      [subFolders setObject: currentFolder forKey: currentSourceID];
    }

  return nil;
}

- (NSString *) defaultFolderName
{
  return [self labelForKey: @"Personal Address Book"];
}

@end
