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

#import <SOGo/SOGoUserManager.h>
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

#import <NGExtensions/NGBundleManager.h>

@implementation SOGoToolRestore

+ (void) initialize
{
  NGBundleManager *bm;

  /* we need to load the SOGo bundles here because OGoContentStore make use of
     certain categories found therein */
  bm = [NGBundleManager defaultBundleManager];
  [bm setBundleSearchPaths: [NSArray arrayWithObject: SOGO_LIBDIR]];
  [[bm bundleWithName: @"Appointments" type: @"SOGo"] load];
  [[bm bundleWithName: @"Contacts" type: @"SOGo"] load];
}

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
  fprintf (stderr, "restore [-l|-f/-F folder/ALL|-p] directory user\n\n"
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
  SOGoUserManager *lm;
  NSDictionary *infos;

  lm = [SOGoUserManager sharedUserManager];
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

- (int) parseModeArguments
{
  NSString *mode;
  int count, max;

  max = [arguments count];
  if (max > 0)
    {
      mode = [arguments objectAtIndex: 0];
      count = 1;
      if ([mode isEqualToString: @"-f"]
          || [mode isEqualToString: @"-F"])
        {
          if ([mode hasSuffix: @"f"])
            restoreMode = SOGoToolRestoreFolderMode;
          else
            restoreMode = SOGoToolRestoreFolderDestructiveMode;
          if (max > 1)
            {
              count++;
              ASSIGN (restoreFolder, [arguments objectAtIndex: 1]);
            }
          else
            {
              count = 0;
              NSLog (@"missing 'folder' parameter");
            }
        }
      else if ([mode isEqualToString: @"-l"])
        restoreMode = SOGoToolRestoreListFoldersMode;
      else if ([mode isEqualToString: @"-p"])
        restoreMode = SOGoToolRestorePreferencesMode;
      else
        {
          count = 0;
          if ([mode hasPrefix: @"-"])
            NSLog (@"specified mode is invalid");
          else
            NSLog (@"missing 'mode' parameter");
        }
    }
  else
    count = 0;

  return count;
}

- (BOOL) parseArguments
{
  BOOL rc;
  NSString *identifier;
  NSArray *newArguments;
  int count, max;

  count = [self parseModeArguments];
  max = [arguments count] - count;
  if (max == 2)
    {
      newArguments
        = [arguments subarrayWithRange: NSMakeRange (count, max)];
      ASSIGN (directory, [newArguments objectAtIndex: 0]);
      identifier = [newArguments objectAtIndex: 1];
      rc = ([self checkDirectory]
            && [self fetchUserID: identifier]);
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

- (BOOL) createFolder: (NSString *) folder
               withFM: (GCSFolderManager *) fm
{
  NSArray *pathElements;
  NSException *error;
  NSString *folderType;
  BOOL rc;

  pathElements = [folder componentsSeparatedByString: @"/"];
  if ([[pathElements objectAtIndex: 3] isEqualToString: @"Contacts"])
    folderType = @"Contact";
  else
    folderType = @"Appointment";

  error = [fm createFolderOfType: folderType
                        withName: [pathElements objectAtIndex: 4]
                          atPath: folder];
  if (error)
    {
      rc = NO;
      NSLog (@"an error occured during folder creation: %@", error);
    }
  else
    rc = YES;

  return rc;
}

- (BOOL) restoreFolder: (NSString *) folder
           withContent: (NSDictionary *) content
           destructive: (BOOL) isDestructive
{
  GCSFolderManager *fm;
  GCSFolder *gcsFolder;
  NSException *error;
  BOOL rc;

  rc = YES;

  fm = [GCSFolderManager defaultFolderManager];
  gcsFolder = [fm folderAtPath: folder];
  if (gcsFolder && isDestructive)
    {
      error = [fm deleteFolderAtPath: folder];
      if (error)
        {
          rc = NO;
          NSLog (@"an error occured during folder deletion: %@", error);
        }
      else
        gcsFolder = nil;
    }
  if (rc)
    {
      if (!gcsFolder)
        {
          rc = [self createFolder: folder withFM: fm];
          if (rc)
            {
              gcsFolder = [fm folderAtPath: folder];
              if (!gcsFolder)
                {
                  rc = NO;
                  NSLog (@"missing folder '%@' could not be recreated",
                         folder);
                }
            }
        }

      rc &= ([self restoreDisplayName: [content objectForKey: @"displayname"]
                             ofFolder: gcsFolder
                               withFM: fm]
             && [self restoreACL: [content objectForKey: @"acl"]
                        ofFolder: gcsFolder]
             && [self restoreRecords: [content objectForKey: @"records"]
                            ofFolder: gcsFolder]);
    }

  return rc;
}

- (BOOL) restoreUserFolderFromUserRecord: (NSDictionary *) userRecord
                             destructive: (BOOL) isDestructive
{
  NSDictionary *tables, *content;
  NSArray *restoreFolders;
  NSString *currentFolder, *folderPath;
  int count, max;
  BOOL rc;

  rc = YES;

  tables = [userRecord objectForKey: @"tables"];
  if (tables)
    {
      if ([restoreFolder isEqualToString: @"ALL"])
        restoreFolders = [tables allKeys];
      else
        {
          folderPath = [NSString stringWithFormat: @"/Users/%@/%@",
                                 userID, restoreFolder];
          restoreFolders = [NSArray arrayWithObject: folderPath];
        }
      max = [restoreFolders count];
      for (count = 0; count < max; count++)
        {
          currentFolder = [restoreFolders objectAtIndex: count];
          content = [tables objectForKey: currentFolder];
          if (content)
            rc &= [self restoreFolder: currentFolder
                          withContent: content
                          destructive: isDestructive];
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

- (BOOL) listRestorableFolders: (NSDictionary *) userRecord
{
  BOOL rc;
  NSDictionary *tables, *currentFolder;
  NSEnumerator *tableKeys;
  NSString *key, *folderKey;
  int folderPrefixLen;

  tables = [userRecord objectForKey: @"tables"];
  if (tables)
    {
      NSLog (@"Restorable folders:");
      folderPrefixLen = 8 + [userID length];
      tableKeys = [[tables allKeys] objectEnumerator];
      while ((key = [tableKeys nextObject]))
        {
          currentFolder = [tables objectForKey: key];
          folderKey = [key substringFromIndex: folderPrefixLen];
          NSLog (@"  '%@': %@",
                 [currentFolder objectForKey: @"displayname"], folderKey);
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
        rc = [self restoreUserFolderFromUserRecord: userRecord
                                       destructive: NO];
      else if (restoreMode == SOGoToolRestoreFolderDestructiveMode)
        rc = [self restoreUserFolderFromUserRecord: userRecord
                                       destructive: YES];
      else if (restoreMode == SOGoToolRestoreListFoldersMode)
        rc = [self listRestorableFolders: userRecord];
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
