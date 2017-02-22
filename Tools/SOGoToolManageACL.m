/* SOGoToolManageACL.m - this file is part of SOGo
 *
 * Copyright (C) 2017 Inverse inc.
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

#import <GDLContentStore/EOQualifier+GCS.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/NGVCard.h>

#import "SOGoTool.h"

typedef enum
{
  ManageACLUnknown = -1,
  ManageACLGet = 0,
  ManageACLAdd = 1,
  ManageACLRemove = 2,
} SOGoManageACLCommand;

@interface SOGoToolManageACL : SOGoTool
{
  SOGoManageACLCommand command;
  NSString *owner;
  NSString *folder;
  NSString *user;
  NSArray *rights;
}

@end

@implementation SOGoToolManageACL

+ (NSString *) command
{
  return @"manage-acl";
}

+ (NSString *) description
{
  return @"manage user's ACL";
}

- (id) init
{
  if ((self = [super init]))
    {
      command = ManageACLUnknown;
      owner = nil;
      folder = nil;
      user = nil;
      rights = nil;
    }

  return self;
}

- (void) dealloc
{
  [owner release];
  [folder release];
  [user release];
  [rights release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "manage-acl get|add|remove owner folder user <rights>\n\n"
	   "           get        get ACL information of folder for user\n"
	   "           add        add ACL information of folder for user\n"
	   "           remove     remove all ACL information of folder for user\n"
           "           owner      the user owning the folder\n"
	   "           folder     the folder - Calendar/<ID> or Contacst/<ID>\n"
	   "           user       the user to get/set rights for - 'ALL', '<default>', 'anonymous' are supported\n"
           "           rights     rights to add\n\n"
           "Example:   sogo-tool manage-acl get jdoe Calendar/personal\n\n"
           "Note:      You can add only one access right at the time. To set them all at once,\n"
           "           invoke 'remove' first to remove them all.\n\n");
}

- (BOOL) parseArguments
{
  NSString *s;
  BOOL rc;
  int max;

  max = [arguments count];
  if (max > 3 && max < 6)
    {
      s = [arguments objectAtIndex: 0];
      if ([s isEqualToString: @"get"])
	command = ManageACLGet;
      else if ([s isEqualToString: @"add"])
	{
	  command = ManageACLAdd;
	  rights = RETAIN([[arguments objectAtIndex: 4] objectFromJSONString]);
	}
      else if ([s isEqualToString: @"remove"])
	command = ManageACLRemove;
      else
	{
	  [self usage];
	  return NO;
	}

      owner = RETAIN([arguments objectAtIndex: 1]);
      folder = RETAIN([arguments objectAtIndex: 2]);
      user = RETAIN([arguments objectAtIndex: 3]);

      rc = YES;
    }
  else
    {
      [self usage];
      rc = NO;
    }

  return rc;
}

- (NSArray *) _fetchUserIDs
{
  NSMutableArray *allUsers, *allSQLUsers;
  NSAutoreleasePool *pool;
  SOGoUserManager *lm;
  NSDictionary *infos;
  NSString *u;

  int count, max;

  lm = [SOGoUserManager sharedUserManager];
  allSQLUsers = [[NSMutableArray alloc] init];
  allUsers = [[NSMutableArray alloc] init];

  if ([user isEqualToString: @"ALL"])
    {
      GCSChannelManager *cm;
      NSURL *folderLocation;
      GCSFolderManager *fm;
      EOAdaptorChannel *fc;
      NSArray *attrs;
      NSString *sql;

      fm = [GCSFolderManager defaultFolderManager];
      cm = [fm channelManager];
      folderLocation = [fm folderInfoLocation];
      fc = [cm acquireOpenChannelForURL: folderLocation];
      if (fc)
        {
          allSQLUsers = [NSMutableArray new];
          sql = [NSString stringWithFormat: @"SELECT DISTINCT c_path2 FROM %@",
                          [folderLocation gcsTableName]];
          [fc evaluateExpressionX: sql];
          attrs = [fc describeResults: NO];
          while ((infos = [fc fetchAttributes: attrs withZone: NULL]))
            {
              u = [infos objectForKey: @"c_path2"];
              if (u)
                [allSQLUsers addObject: u];
            }
          [cm releaseChannel: fc];
        }

      // We add our system users
      [allSQLUsers addObject: @"<default>"];

      if ([[SOGoSystemDefaults sharedSystemDefaults] enablePublicAccess])
	[allSQLUsers addObject: @"anonymous"];
    }
  else
    [allSQLUsers addObject: user];

  pool = [[NSAutoreleasePool alloc] init];
  max = [allSQLUsers count];

  for (count = 0; count < max; count++)
    {
      if (count > 0 && count%100 == 0)
        {
          DESTROY(pool);
          pool = [[NSAutoreleasePool alloc] init];
        }

      u = [allSQLUsers objectAtIndex: count];

      // We skip lookup for our 'system users' but keep them to set ACLs
      if ([u isEqualToString: @"anonymous"] || [u isEqualToString: @"<default>"])
	{
	  [allUsers addObject: u];
	  continue;
	}

      // Skip the owner
      if ([u isEqualToString: owner])
	continue;

      infos = [lm contactInfosForUserWithUIDorEmail: u];
      if (infos)
        [allUsers addObject: [infos objectForKey: @"c_uid"]];
      else
        {
          // We haven't found the user based on the GCS table name
          // Let's try to strip the domain part and search again.
          // This can happen when using SOGoEnableDomainBasedUID (YES)
          // but login in SOGo using a UID without domain (DomainLessLogin gets set)
          NSRange r;

          r = [u rangeOfString: @"@"];

          if (r.location != NSNotFound)
            {
              u = [u substringToIndex: r.location];
              infos = [lm contactInfosForUserWithUIDorEmail: u];
              if (infos)
                [allUsers addObject: [infos objectForKey: @"c_uid"]];
              else
                NSLog (@"user '%@' unknown", u);
            }
          else
            NSLog (@"user '%@' unknown", u);
        }
    }

  DESTROY(pool);
  RELEASE(allSQLUsers);

  return AUTORELEASE(allUsers);
}


- (void) addACLForUser: (NSString *) theUser
                folder: (GCSFolder *) theFolder
{
  NSString *currentRole, *SQL, *path, *u;
  EOAdaptorChannel *channel;
  NSArray *allUsers;
  int i, j;

  channel = [theFolder acquireAclChannel];
  path = [NSString stringWithFormat: @"%@/%@", owner, folder];
  allUsers = [self _fetchUserIDs];

  for (i = 0; i < [allUsers count]; i++)
    {
      u = [allUsers objectAtIndex: i];
      NSLog(@"Settings rights for user %@", u);
      for (j = 0; j < [rights count]; j++)
	{
	  currentRole = [rights objectAtIndex: j];
	  if ([GCSFolderManager singleStoreMode])
	    SQL = [NSString stringWithFormat: @"INSERT INTO %@"
			    @" (c_object, c_uid, c_role, c_folder_id)"
			    @" VALUES ('/%@', '%@', '%@', %@)",
			    [theFolder aclTableName],
			    path, u, currentRole, [theFolder folderId]];
	  else
	    SQL = [NSString stringWithFormat: @"INSERT INTO %@"
			    @" (c_object, c_uid, c_role)"
			    @" VALUES ('/%@', '%@', '%@')",
			    [theFolder aclTableName],
			    path, u, currentRole];
	  [channel evaluateExpressionX: SQL];
	}
    }
}

- (void) getACLForUser: (NSString *) theUser
		folder: (GCSFolder *) theFolder
{
  NSArray *allRights, *allKeys;
  NSMutableDictionary *d;
  EOQualifier *qualifier;
  NSDictionary *right;
  NSString *qs;
  id o;

  int i;

  if ([theUser isEqualToString: @"ALL"])
    qualifier = nil;
  else
    {
      qs = [NSString stringWithFormat: @"c_uid = '%@'", theUser];
      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
    }

  allRights = [theFolder fetchAclMatchingQualifier: qualifier];
  d = [NSMutableDictionary dictionary];

  for (i = 0; i < [allRights count]; i++)
    {
      right = [allRights objectAtIndex: i];
      if ((o = [d objectForKey: [right objectForKey: @"c_uid"]]))
	[o addObject: [right objectForKey: @"c_role"]];
      else
	[d setObject: [NSMutableArray arrayWithObject: [right objectForKey: @"c_role"]]
	      forKey: [right objectForKey: @"c_uid"]];	   
    }

  allKeys = [d allKeys];

  for (i = 0; i < [allKeys count]; i++)
    {
      o = [allKeys objectAtIndex: i];
      NSLog(@"Rights for %@ %@", o, [[d objectForKey: o] jsonRepresentation]);
    }
}

- (void) removeACLForUser: (NSString *) theUser
		   folder: (GCSFolder *) theFolder
{
  EOQualifier *qualifier;
  NSString *qs, *path;

  if ([theUser isEqualToString: @"ALL"])
    qs = [NSString stringWithFormat: @"c_uid LIKE '\%'", theUser];
  else
    {
      qs = [NSString stringWithFormat: @"c_uid = '%@'", theUser];
    }

  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
  
  [theFolder deleteAclMatchingQualifier: qualifier];

  // We clear the cache. We first strip /Users/ from our path
  path = [[[[theFolder path] pathComponents] subarrayWithRange: NSMakeRange(2,3)] componentsJoinedByString: @"/"];
  [[SOGoCache sharedCache] setACLs: nil
			   forPath: path];
}

- (BOOL) proceed
{
  NSAutoreleasePool *pool;
  GCSFolderManager *fm;
  GCSFolder *f;

  BOOL rc;

  rc = YES;

  pool = [NSAutoreleasePool new];

  fm = [GCSFolderManager defaultFolderManager];
  f = [fm folderAtPath: [NSString stringWithFormat: @"/Users/%@/%@", owner, folder]];

  if (!f)
    {
      NSLog(@"No folder %@ found for user %@", folder, owner);
      rc = NO;
    }
  else
    {
      if (command == ManageACLGet)
	[self getACLForUser: user  folder: f];
      else if (command == ManageACLRemove)
	[self removeACLForUser: user  folder: f];
      else if (command == ManageACLAdd)
	[self addACLForUser: user  folder: f];
      else
	[self usage];
    }

  [pool release];

  return rc;
}

- (BOOL) run
{
  return ([self parseArguments] && [self proceed]);
}

@end
