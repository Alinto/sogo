/* SOGoToolRestore.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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
#import <Foundation/NSError.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>

#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SOGo/LDAPUserManager.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "SOGoToolRestore.h"

/* TODO:
   - respond to "--help restore"
   - handle database connectivity errors
   - handle the case where the restored folder has been deleted
   - write methods in GDLContentStore to get/update displayname
     and storing roles */ 

@implementation SOGoToolRestore

+ (NSString *) command
{
  return @"restore";
}

+ (NSString *) description
{
  return @"restore user folders";
}

- (id) init
{
  if ((self = [super init]))
    {
      directory = nil;
      userID = nil;
      restoreFolder = nil;
      destructive = NO;
    }

  return self;
}

- (void) dealloc
{
  [directory release];
  [userID release];
  [restoreFolder release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "restore directory user [-f folder|-p]\n\n"
	   "         folder     the folder where backup files will be stored\n"
	   "         user       the user of whom to save the data\n");
}

- (BOOL) checkDirectory
{
  NSFileManager *fm;
  BOOL exists, isDir, rc;

  fm = [NSFileManager defaultManager];
  exists = [fm fileExistsAtPath: directory isDirectory: &isDir];
  if (exists)
    {
      if (isDir)
        rc = YES;
      else
        {
          rc = NO;
          NSLog (@"specified directory is a regular file");
        }
    }
  else
    {
      rc = NO;
      NSLog (@"specified directory does not exist");
    }

  return rc;
}

- (BOOL) fetchUserID: (NSString *) identifier
{
  BOOL rc;
  LDAPUserManager *lm;
  NSDictionary *infos;

  lm = [LDAPUserManager sharedUserManager];
  infos = [lm contactInfosForUserWithUIDorEmail: identifier];
  ASSIGN (userID, [infos objectForKey: @"c_uid"]);
  if (userID)
    rc = YES;
  else
    {
      rc = NO;
      NSLog (@"user '%@' not found", identifier);
    }

  return rc;
}

- (BOOL) parseModeArguments: (NSArray *) modeArguments
{
  NSString *mode;
  BOOL rc;

  rc = NO;

  mode = [modeArguments objectAtIndex: 0];
  if ([mode isEqualToString: @"-f"])
    {
      rc = YES;
      restoreMode = SOGoToolRestoreFolderMode;
      if ([modeArguments count] == 2)
        {
          restoreFolder = [NSString stringWithFormat: @"/Users/%@/%@",
                                    userID,
                                    [modeArguments objectAtIndex: 1]];
          [restoreFolder retain];
        }
    }
  else if ([mode isEqualToString: @"-p"])
    {
      rc = YES;
      restoreMode = SOGoToolRestorePreferencesMode;
    }
  else
    [self usage];

  return rc;
}

- (BOOL) parseArguments
{
  BOOL rc;
  NSString *identifier;
  NSArray *modeArguments;
  int max;

  max = [arguments count];
  if ([arguments count] > 2)
    {
      ASSIGN (directory, [arguments objectAtIndex: 0]);
      identifier = [arguments objectAtIndex: 1];
      modeArguments
        = [arguments subarrayWithRange: NSMakeRange (2, max - 2)];
      rc = ([self checkDirectory]
            && [self fetchUserID: identifier]
            && [self parseModeArguments: modeArguments]);
    }
  else
    {
      [self usage];
      rc = NO;
    }

  return rc;
}

- (BOOL) restoreDisplayName: (NSString *) newDisplayName
                   ofFolder: (GCSFolder *) gcsFolder
                     withFM: (GCSFolderManager *) fm
{
  BOOL rc;
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql;

  if (newDisplayName)
    {
      rc = YES;

      cm = [fm channelManager];
      folderLocation = [fm folderInfoLocation];
      fc = [cm acquireOpenChannelForURL: folderLocation];
      if (fc)
        {
          sql
            = [NSString stringWithFormat: (@"UPDATE %@"
                                           @" SET c_foldername = '%@'"
                                           @" WHERE c_path = '%@'"),
                        [folderLocation gcsTableName],
                        [newDisplayName stringByReplacingString: @"'"
                                                     withString: @"''"],
                        [gcsFolder path]];
          [fc evaluateExpressionX: sql];
          [cm releaseChannel: fc];
        }
    }
  else
    {
      rc = NO;
      NSLog (@"no display name found (abort)");
    }

  return rc;
}

- (BOOL) restoreACL: (NSDictionary *) acl
           ofFolder: (GCSFolder *) gcsFolder
{
  EOAdaptorChannel *channel;
  NSEnumerator *users, *userRoles;
  NSString *SQL, *folderPath, *aclTableName, *currentUser, *currentRole;
  BOOL rc;

  if (acl)
    {
      aclTableName = [gcsFolder aclTableName];
      folderPath = [[gcsFolder path] substringFromIndex: 6];

      [gcsFolder deleteAclWithSpecification: nil];

      channel = [gcsFolder acquireAclChannel];
      [[channel adaptorContext] beginTransaction];

      users = [[acl allKeys] objectEnumerator];
      while ((currentUser = [users nextObject]))
        {
          userRoles = [[acl objectForKey: currentUser] objectEnumerator];
          while ((currentRole = [userRoles nextObject]))
            {
              SQL = [NSString stringWithFormat: @"INSERT INTO %@"
                              @" (c_object, c_uid, c_role)"
                              @" VALUES ('%@', '%@', '%@')",
                              aclTableName,
                              folderPath, currentUser, currentRole];
              [channel evaluateExpressionX: SQL];
            }
        }

      [[channel adaptorContext] commitTransaction];
      [gcsFolder releaseChannel: channel];

      rc = YES;
    }
  else
    {
      rc = NO;
      NSLog (@"no acl found (abort)");
    }

  return rc;
}

- (NSDictionary *) fetchExistingRecordsFromFolder: (GCSFolder *) gcsFolder
{
  NSArray *records;
  int count, max;
  NSDictionary *row;
  NSMutableDictionary *existingRecords;

  records = [gcsFolder fetchFields: [NSArray arrayWithObject: @"c_name"]
                fetchSpecification: nil];
  max = [records count];
  existingRecords = [NSMutableDictionary dictionaryWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      row = [records objectAtIndex: count];
      [existingRecords setObject: @""
                          forKey: [row objectForKey: @"c_name"]];
    }

  return existingRecords;
}

- (BOOL) restoreRecords: (NSArray *) records
               ofFolder: (GCSFolder *) gcsFolder
{
  BOOL rc;
  NSDictionary *existingRecords, *currentRecord;
  NSString *cName, *cContent;
  NSException *ex;
  int count, max;

  if (records)
    {
      rc = YES;
      existingRecords = [self fetchExistingRecordsFromFolder: gcsFolder];
      max = [records count];
      for (count = 0; count < max; count++)
        {
          currentRecord = [records objectAtIndex: count];
          cName = [currentRecord objectForKey: @"c_name"];
          if (![existingRecords objectForKey: cName])
            {
              NSLog (@"restoring record '%@'", cName);
              cContent = [currentRecord objectForKey: @"c_content"];
              ex = [gcsFolder writeContent: cContent toName: cName
                               baseVersion: 0];
            }
        }
    }
  else
    {
      rc = NO;
      NSLog (@"no records found (abort)");
    }

  return rc;
}

- (BOOL) restoreFolder: (NSString *) folder
           withContent: (NSDictionary *) content
{
  GCSFolderManager *fm;
  GCSFolder *gcsFolder;

  fm = [GCSFolderManager defaultFolderManager];
  gcsFolder = [fm folderAtPath: folder];

  return ([self restoreDisplayName: [content objectForKey: @"displayname"]
                          ofFolder: gcsFolder
                            withFM: fm]
          && [self restoreACL: [content objectForKey: @"acl"]
                     ofFolder: gcsFolder]
          && [self restoreRecords: [content objectForKey: @"records"]
                         ofFolder: gcsFolder]);
}

- (BOOL)
 restoreSpecifiedUserFolderFromUserRecord: (NSDictionary *) userRecord
{
  NSDictionary *tables, *content;
  NSArray *restoreFolders;
  NSString *currentFolder;
  int count, max;
  BOOL rc;

  rc = YES;

  tables = [userRecord objectForKey: @"tables"];
  if (tables)
    {
      if (restoreFolder)
        restoreFolders = [NSArray arrayWithObject: restoreFolder];
      else
        restoreFolders = [tables allKeys];
      max = [restoreFolders count];
      for (count = 0; count < max; count++)
        {
          currentFolder = [restoreFolders objectAtIndex: count];
          content = [tables objectForKey: currentFolder];
          if (content)
            rc &= [self restoreFolder: currentFolder
                          withContent: content];
          else
            {
              rc = NO;
              NSLog (@"no user table with that name");
            }
        }
    }
  else
    {
      rc = NO;
      NSLog (@"no table information found in backup file");
    }

  return rc;
}

- (BOOL) restoreUserPreferencesFromUserRecord: (NSDictionary *) userRecord
{
  SOGoUser *sogoUser;
  NSUserDefaults *storedPreferences;
  NSArray *preferences;
  BOOL rc;

  preferences = [userRecord objectForKey: @"preferences"];
  if (preferences)
    {
      rc = YES;
      sogoUser = [SOGoUser userWithLogin: userID roles: nil];

      storedPreferences = [sogoUser userDefaults];
      [storedPreferences setValues: [preferences objectAtIndex: 0]];
      [storedPreferences synchronize];

      storedPreferences = [sogoUser userSettings];
      [storedPreferences setValues: [preferences objectAtIndex: 1]];
      [storedPreferences synchronize];
    }
  else
    {
      rc = NO;
      NSLog (@"no preferences found (abort)");
    }

  return rc;
}

- (BOOL) proceed
{
  NSDictionary *userRecord;
  NSString *importPath;
  BOOL rc;

  importPath = [directory stringByAppendingPathComponent: userID];
  userRecord = [NSDictionary dictionaryWithContentsOfFile: importPath];
  if (userRecord)
    {
      if (restoreMode == SOGoToolRestoreFolderMode)
        rc = [self restoreSpecifiedUserFolderFromUserRecord: userRecord];
      else
        rc = [self restoreUserPreferencesFromUserRecord: userRecord];
    }
  else
    {
      rc = NO;
      NSLog (@"user backup file could not be loaded");
    }

  return rc;
}

- (BOOL) run
{
  return ([self parseArguments] && [self proceed]);
}

@end
