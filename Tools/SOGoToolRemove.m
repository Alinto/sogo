/* SOGoToolRemove.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2017 Inverse inc.
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

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SOGo/SOGoSystemDefaults.h>

#import "SOGoTool.h"

/* TODO:
   - handle database connectivity errors
*/

static GCSFolderManager *fm = nil;
static NSURL *tableURL = nil;

@interface SOGoToolRemove : SOGoTool
@end

@implementation SOGoToolRemove

+ (void) initialize
{
  NSString *profileURL;
  SOGoSystemDefaults *sd;

  if (!fm)
    fm = [GCSFolderManager defaultFolderManager];

  if (!tableURL)
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      profileURL = [sd profileURL];
      if (profileURL)
        tableURL = [[NSURL alloc] initWithString: profileURL];
    }
}

+ (NSString *) command
{
  return @"remove";
}

+ (NSString *) description
{
  return @"remove user data and settings from the db";
}

- (void) usage
{
  fprintf (stderr, "remove user1 [user2] ...\n\n"
	   "         user       the user of whom to remove the data\n");
}

- (NSArray *) _userFolderPaths: (NSString *) userId
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql;
  NSArray *attrs;
  NSDictionary *row;
  NSMutableArray *paths;

  paths = [NSMutableArray arrayWithCapacity: 16];

  folderLocation = [fm folderInfoLocation];
  cm = [GCSChannelManager defaultChannelManager];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if ([fc isOpen])
    {
      sql
	= [NSString stringWithFormat: (@"SELECT c_path FROM %@"
				       @" WHERE c_path2 = '%@'"),
		    [folderLocation gcsTableName],
                    userId];
      if (![fc evaluateExpressionX: sql])
        {
          attrs = [fc describeResults: NO];
          while ((row = [fc fetchAttributes: attrs withZone: NULL]))
            [paths addObject: [row objectForKey: @"c_path"]];
        }
      [cm releaseChannel: fc];
    }

  return paths;
}

- (void) _removeUserFolders: (NSString *) userId
{
  NSArray *folderPaths;
  NSString *path;
  int count, max;

  folderPaths = [self _userFolderPaths: userId];
  max = [folderPaths count];
  if (max > 0)
    for (count = 0; count < max; count++)
      {
        path = [folderPaths objectAtIndex: count];
        [fm deleteFolderAtPath: path];
        if (verbose)
          NSLog (@"Deleting %@", path);
      }
  else
    NSLog (@"No folder returned for user '%@'", userId);
}

- (void) _removeUserPreferences: (NSString *) userId
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSString *sql;
 
  cm = [GCSChannelManager defaultChannelManager];
  fc = [cm acquireOpenChannelForURL: tableURL];
  if ([fc isOpen])
    {
      sql
	= [NSString stringWithFormat: (@"DELETE FROM %@"
				       @" WHERE c_uid = '%@'"),
		    [tableURL gcsTableName],
                    userId];
      if ([fc evaluateExpressionX: sql])
        NSLog (@"Unable to delete the preference record for '%@'", userId);
      else if (verbose)
        NSLog (@"Removed preference record for '%@'", userId);
      [cm releaseChannel: fc];
    }
}

- (BOOL) run
{
  NSString *userId;
  int count, max;
  BOOL rc;

  max = [arguments count];
  if (max > 0)
    {
      for (count = 0; count < max; count++)
        {
          userId = [arguments objectAtIndex: count];
          [self _removeUserFolders: userId];
          [self _removeUserPreferences: userId];
        }
      rc = YES;
    }
  else
    {
      [self usage];
      rc = NO;
    }

  return rc;
}

@end
