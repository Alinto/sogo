/* SOGoToolCleanup.m - this file is part of SOGo
 *
 * Copyright (C) 2016-2020 Inverse inc.
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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SOGo/SOGoUserManager.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoSystemDefaults.h>

#import "SOGoTool.h"

@interface SOGoToolCleanup : SOGoTool
{
  NSArray *usersToCleanup;
  unsigned int days;
}

@end

@implementation SOGoToolCleanup

+ (NSString *) command
{
  return @"cleanup";
}

+ (NSString *) description
{
  return @"cleanup deleted elements of user(s)";
}

- (id) init
{
  if ((self = [super init]))
    {
      usersToCleanup = nil;
      days = 0;
    }

  return self;
}

- (void) dealloc
{
  [usersToCleanup release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "cleanup [days] [user]...\n\n"
           "           days       the age of deleted records to purge in days\n"
           "           user       the user to purge the records or ALL for everybody\n\n"
           "Example:   sogo-tool cleanup jdoe\n");
}

- (BOOL) fetchUserIDs: (NSArray *) users
{
  NSAutoreleasePool *pool;
  SOGoUserManager *lm;
  NSDictionary *infos;
  NSString *user;
  id allUsers;
  int count, max;

  lm = [SOGoUserManager sharedUserManager];

  max = [users count];
  user = [users objectAtIndex: 0];
  if (max == 1 && [user isEqualToString: @"ALL"])
    {
      GCSFolderManager *fm;
      GCSChannelManager *cm;
      NSURL *folderLocation;
      EOAdaptorChannel *fc;
      NSArray *attrs;
      NSMutableArray *allSqlUsers;
      NSString *sql;

      fm = [GCSFolderManager defaultFolderManager];
      cm = [fm channelManager];
      folderLocation = [fm folderInfoLocation];
      fc = [cm acquireOpenChannelForURL: folderLocation];
      if (fc)
        {
          allSqlUsers = [NSMutableArray new];
          sql = [NSString stringWithFormat: @"SELECT DISTINCT c_path2 FROM %@",
                          [folderLocation gcsTableName]];
          [fc evaluateExpressionX: sql];
          attrs = [fc describeResults: NO];
          while ((infos = [fc fetchAttributes: attrs withZone: NULL]))
            {
              user = [infos objectForKey: @"c_path2"];
              if (user)
                [allSqlUsers addObject: user];
            }
          [cm releaseChannel: fc  immediately: YES];

          users = allSqlUsers;
          max = [users count];
          [allSqlUsers autorelease];
        }
    }

  pool = [[NSAutoreleasePool alloc] init];
  allUsers = [NSMutableArray new];
  for (count = 0; count < max; count++)
    {
      if (count > 0 && count%100 == 0)
        {
          DESTROY(pool);
          pool = [[NSAutoreleasePool alloc] init];
        }

      user = [users objectAtIndex: count];
      infos = [lm contactInfosForUserWithUIDorEmail: user];
      if (infos)
        [allUsers addObject: infos];
      else
        {
          // We haven't found the user based on the GCS table name
          // Let's try to strip the domain part and search again.
          // This can happen when using SOGoEnableDomainBasedUID (YES)
          // but login in SOGo using a UID without domain (DomainLessLogin gets set)
          NSRange r;

          r = [user rangeOfString: @"@"];

          if (r.location != NSNotFound)
            {
              user = [user substringToIndex: r.location];
              infos = [lm contactInfosForUserWithUIDorEmail: user];
              if (infos)
                [allUsers addObject: infos];
              else
                NSLog (@"user '%@' unknown", user);
            }
          else
            NSLog (@"user '%@' unknown", user);
        }
    }
  [allUsers autorelease];

  ASSIGN (usersToCleanup, allUsers);
  DESTROY(pool);

  return ([usersToCleanup count] > 0);
}

- (BOOL) parseArguments
{
  BOOL rc;
  NSRange usersRange;
  int max;

  max = [arguments count];
  if (max > 1)
    {
      days = [[arguments objectAtIndex: 0] intValue];
      usersRange.location = 1;
      usersRange.length = max - 1;
      rc = [self fetchUserIDs: [arguments subarrayWithRange: usersRange]];
    }
  else
    {
      [self usage];
      rc = NO;
    }

  return rc;
}

- (BOOL) cleanupFolder: (NSString *) folder
                withFM: (GCSFolderManager *) fm
{
  GCSFolder *gcsFolder;
  NSException *error;
  BOOL rc;
  unsigned int count;

  gcsFolder = [fm folderAtPath: folder];

  count = [gcsFolder recordsCountDeletedBefore: days];
  error = nil;
  if (count > 0)
    error = [gcsFolder purgeDeletedRecordsBefore: days];
  if (error)
    {
      NSLog(@"Unable to purge records of folder %@", folder);
      rc = NO;
    }
  else
    {
      NSLog(@"Purged %u records from folder %@", count, folder);
      rc = YES;
    }

  return rc;
}

- (BOOL) cleanupUserFolders: (NSString *) uid
{
  GCSFolderManager *fm;
  NSArray *folders;
  int count, max;
  NSString *basePath, *folder;

  fm = [GCSFolderManager defaultFolderManager];
  basePath = [NSString stringWithFormat: @"/Users/%@", uid];
  folders = [fm listSubFoldersAtPath: basePath recursive: YES];
  max = [folders count];
  for (count = 0; count < max; count++)
    {
      folder = [NSString stringWithFormat: @"%@/%@", basePath, [folders objectAtIndex: count]];
      //NSLog (@"folder %d: %@", count, folder);
      [self cleanupFolder: folder withFM: fm];
    }

  return YES;
}

- (BOOL) cleanupUser: (NSDictionary *) theUser
{
  NSString *gcsUID, *domain;
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  domain = [theUser objectForKey: @"c_domain"];
  gcsUID = [theUser objectForKey: @"c_uid"];

  if ([sd enableDomainBasedUID] && [gcsUID rangeOfString: @"@"].location == NSNotFound)
    gcsUID = [NSString stringWithFormat: @"%@@%@", gcsUID, domain];

  return [self cleanupUserFolders: gcsUID];
}

- (BOOL) proceed
{
  NSAutoreleasePool *pool;
  int count, max;
  BOOL rc;

  rc = YES;

  pool = [NSAutoreleasePool new];

  max = [usersToCleanup count];
  for (count = 0; rc && count < max; count++)
    {
      rc = [self cleanupUser: [usersToCleanup objectAtIndex: count]];
      if ((count % 10) == 0)
        [pool emptyPool];
    }

  [pool release];

  return rc;
}

- (BOOL) run
{
  return ([self parseArguments] && [self proceed]);
}

@end
