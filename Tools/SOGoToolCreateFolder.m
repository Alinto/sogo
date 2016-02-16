/* SOGoToolCreateFolder.m - this file is part of SOGo
 * Implementation of create-folder command for sogo-tool
 *
 * Copyright (C) 2015 Javier Amor Garcia
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoObject.h>

#import <GDLContentStore/GCSFolderManager.h>

#import "SOGoToolRestore.h"

@interface SOGoToolCreateFolder : SOGoToolRestore
{
  NSMutableArray *foldersContents;
  NSString *folderType;
}

@end

@implementation SOGoToolCreateFolder

+ (NSString *) command
{
  return @"create-folder";
}

+ (NSString *) description
{
  return @"create folders for a user";
}

- (id) init
{
  if ((self = [super init]))
    {
      foldersContents = nil;
      folderType = nil;
    }

  return self;
}

- (void) dealloc
{
  [foldersContents release];
  [folderType release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "create-folder user type [displayname ...]\n\n"
           "           user        the user on which the folder(s) will be created\n"
           "           type        type of directory. Calendar or Contacts\n"
           "           displayname display name(s) for the created folder(s)\n\n"
           "Examples:  sogo-tool create-folder user1 Calendar cal1 cal2\n"
           "           sogo-tool create-folder user1 Contacts agenda\n");
}

- (BOOL) createNewFolderOfType: (NSString *) type
                   withContent:  (NSDictionary *) content
{
  NSString *folder;
  NSString *guid;
  GCSFolderManager *fm;
  GCSFolder *gcsFolder;
  BOOL rc;

  guid = [SOGoObject globallyUniqueObjectId];
  folder= [NSString stringWithFormat: @"/Users/%@/%@/%@",
                                      userID, type, guid];
  fm = [GCSFolderManager defaultFolderManager];

  rc = [self createFolder: folder withFM: fm];
  if (!rc)
    {
      NSLog (@"Create directory failed at path %@", folder);
      return NO;
    }

  gcsFolder = [fm folderAtPath: folder];
  if (!gcsFolder)
    {
      NSLog (@"folder '%@' could not be created", folder);
      return NO;
    }

  rc = [self restoreDisplayName: [content objectForKey: @"displayname"]
                       ofFolder: gcsFolder
                         withFM: fm];
  return rc;
}

- (BOOL) proceed
{
  BOOL rc;
  NSUInteger count, i;
  NSDictionary * content;

  rc = YES;
  count = [foldersContents count];
  for (i = 0; i < count; i++)
    {
      content = [foldersContents objectAtIndex: i];
      if (![self createNewFolderOfType: folderType withContent: content])
        {
          rc = NO;
        }
    }

  return rc;
}

- (BOOL) parseArguments
{
  NSString *identifier;
  NSUInteger count, i;
  NSDictionary *content;

  count = [arguments count];
  if (count < 3)
    {
      [self usage];
      return NO;
    }

  identifier = [arguments objectAtIndex: 0];
  if (![self fetchUserID: identifier])
    {
      fprintf (stderr, "Invalid user:%s\n", [identifier cString]);
      return NO;
    }

  folderType = [arguments objectAtIndex: 1];
  if (!([folderType isEqualToString: @"Contacts"] || [folderType isEqualToString: @"Calendar"]))
    {
      fprintf (stderr, "Invalid folder type:%s\n", [folderType cString]);
      return NO;
    }

  foldersContents = [[NSMutableArray alloc] init];
  for (i = 2; i < count; i++)
    {
      content =  [NSDictionary dictionaryWithObject: [arguments objectAtIndex: i]
                                             forKey: @"displayname"];
      [foldersContents addObject: content];
    }

  return YES;
}

@end
