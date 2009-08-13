/* SOGoToolBackup.m - this file is part of SOGo
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

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SOGo/LDAPUserManager.h>
#import <SOGo/LDAPSource.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>

#import "NSDictionary+SOGoTool.h"
#import "SOGoToolBackup.h"

@implementation SOGoToolBackup

+ (NSString *) command
{
  return @"backup";
}

+ (NSString *) description
{
  return @"backup user folders";
}

- (id) init
{
  if ((self = [super init]))
    {
      directory = nil;
      userIDs = nil;
    }

  return self;
}

- (void) dealloc
{
  [directory release];
  [userIDs release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "backup folder user|ALL\n\n"
	   "         folder     the folder where backup files will be stored\n"
	   "         user       the user of whom to save the data\n");
}

- (BOOL) checkDirectory
{
  NSFileManager *fm;
  BOOL exists, isDir, rc;
  NSError *createError;

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
      rc = [fm createDirectoryAtPath: directory
               withIntermediateDirectories: YES
                          attributes: nil
                               error: &createError];
      if (!rc)
        NSLog (@"an error occured during directory creation: %@",
               createError);
    }

  return rc;
}

- (BOOL) fetchUserIDs: (NSString *) identifier
{
  BOOL rc;
  LDAPUserManager *lm;
  NSDictionary *infos;
  NSString *userID;
  NSArray *allUsers;

  lm = [LDAPUserManager sharedUserManager];
  if ([identifier isEqualToString: @"ALL"])
    {
      rc = YES;
      allUsers = [lm fetchUsersMatching: @"."];
      ASSIGN (userIDs, [allUsers objectsForKey: @"c_uid"
                                notFoundMarker: nil]);
    }
  else
    {
      infos = [lm contactInfosForUserWithUIDorEmail: identifier];
      userID = [infos objectForKey: @"c_uid"];
      if (userID)
        {
          rc = YES;
          ASSIGN (userIDs, [NSArray arrayWithObject: userID]);
        }
      else
        {
          rc = NO;
          NSLog (@"user '%@' not found", identifier);
        }
    }

  return rc;
}

- (BOOL) parseArguments
{
  BOOL rc;
  NSString *identifier;

  if ([arguments count] == 2)
    {
      ASSIGN (directory, [arguments objectAtIndex: 0]);
      identifier = [arguments objectAtIndex: 1];
      rc = ([self checkDirectory] && [self fetchUserIDs: identifier]);
    }
  else
    {
      [self usage];
      rc = NO;
    }

  return rc;
}

- (NSString *) fetchFolderDisplayName: (NSString *) folder
                               withFM: (GCSFolderManager *) fm
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql, *displayName;
  NSArray *attrs;
  NSDictionary *row;

  displayName = nil;

  cm = [fm channelManager];
  folderLocation = [fm folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if (fc)
    {
      sql
	= [NSString stringWithFormat: (@"SELECT c_foldername FROM %@"
				       @" WHERE c_path = '%@'"),
		    [folderLocation gcsTableName], folder];
      [fc evaluateExpressionX: sql];
      attrs = [fc describeResults: NO];
      row = [fc fetchAttributes: attrs withZone: NULL];
      displayName = [row objectForKey: @"c_foldername"];
      [fc cancelFetch];
      [cm releaseChannel: fc];
    }

  if (!displayName)
    displayName = @"";

  return displayName;
}

- (NSDictionary *) fetchFolderACL: (GCSFolder *) gcsFolder
{
  NSMutableDictionary *acl;
  NSEnumerator *aclRecords;
  NSDictionary *currentRecord;
  NSMutableArray *userRoles;
  NSString *user, *folderPath;

  acl = [NSMutableDictionary dictionary];

  folderPath = [gcsFolder path];
  aclRecords = [[gcsFolder fetchAclMatchingQualifier: nil] objectEnumerator];
  while ((currentRecord = [aclRecords nextObject]))
    {
      user = [currentRecord objectForKey: @"c_uid"];
      if ([folderPath hasSuffix: [currentRecord objectForKey: @"c_object"]])
        {
          userRoles = [acl objectForKey: user];
          if (!userRoles)
            {
              userRoles = [NSMutableArray array];
              [acl setObject: userRoles forKey: user];
            }
          [userRoles addObject: [currentRecord objectForKey: @"c_role"]];
        }
    }

  return acl;
}

- (BOOL) extractFolder: (NSString *) folder
                withFM: (GCSFolderManager *) fm
            intoRecord: (NSMutableDictionary *) folderRecord
{
  GCSFolder *gcsFolder;
  NSArray *records;
  static NSArray *fields = nil;
  NSMutableDictionary *tableRecord;

  if (!fields)
    {
      fields = [NSArray arrayWithObjects: @"c_name", @"c_content", nil];
      [fields retain];
    }

  gcsFolder = [fm folderAtPath: folder];

  tableRecord = [NSMutableDictionary dictionary];
  // [tableRecord setObject: 
  //                  forKey: @"displayname"];
  records = [gcsFolder fetchFields: fields
                fetchSpecification: nil];
  [tableRecord setObject: records forKey: @"records"];
  [tableRecord setObject: [self fetchFolderDisplayName: folder
                                                withFM: fm]
                  forKey: @"displayname"];
  [tableRecord setObject: [self fetchFolderACL: gcsFolder]
                  forKey: @"acl"];
  [folderRecord setObject: tableRecord forKey: folder];

  return YES;
}

- (BOOL) extractUserFolders: (NSString *) uid
                 intoRecord: (NSMutableDictionary *) userRecord
{
  GCSFolderManager *fm;
  NSArray *folders;
  NSMutableDictionary *tables;
  int count, max;
  NSString *basePath, *folder;

  fm = [GCSFolderManager defaultFolderManager];
  basePath = [NSString stringWithFormat: @"/Users/%@", uid];
  folders = [fm listSubFoldersAtPath: basePath recursive: YES];
  max = [folders count];
  tables = [NSMutableDictionary dictionaryWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      folder = [NSString stringWithFormat: @"%@/%@",
                         basePath, [folders objectAtIndex: count]];
      NSLog (@"folder %d: %@", count, folder);
      [self extractFolder: folder withFM: fm
               intoRecord: tables];
    }
  [userRecord setObject: tables forKey: @"tables"];

  return YES;
}

- (BOOL) extractUserLDIFRecord: (NSString *) uid
                    intoRecord: (NSMutableDictionary *) userRecord
{
  NSEnumerator *ldapSources;
  NSString *sourceID;
  LDAPSource *currentSource;
  LDAPUserManager *lm;
  NSDictionary *userEntry;
  BOOL done;

  lm = [LDAPUserManager sharedUserManager];

  done = NO;
  ldapSources = [[lm authenticationSourceIDs] objectEnumerator];
  while (!done && (sourceID = [ldapSources nextObject]))
    {
      currentSource = [lm sourceWithID: sourceID];
      userEntry = [currentSource lookupContactEntry: uid];
      if (userEntry)
	{
          [userRecord setObject: [userEntry userRecordAsLDIFEntry]
                         forKey: @"ldif_record"];
          done = YES;
	}
    }

  return YES;
}

- (BOOL) extractUserPreferences: (NSString *) uid
                     intoRecord: (NSMutableDictionary *) userRecord
{
  SOGoUser *sogoUser;
  NSArray *preferences;

  sogoUser = [SOGoUser userWithLogin: uid roles: nil];
  preferences = [NSArray arrayWithObjects:
                           [sogoUser userDefaults],
                         [sogoUser userSettings], nil];
  [userRecord setObject: preferences forKey: @"preferences"];

  return YES;
}

- (BOOL) exportUser: (NSString *) uid
{
  NSMutableDictionary *userRecord;
  NSString *exportPath;

  userRecord = [NSMutableDictionary dictionary];
  exportPath = [directory stringByAppendingPathComponent: uid];

  return ([self extractUserFolders: uid
                        intoRecord: userRecord]
          && [self extractUserLDIFRecord: uid
                              intoRecord: userRecord]
          && [self extractUserPreferences: uid
                               intoRecord: userRecord]
          && [userRecord writeToFile: exportPath
                          atomically: NO]);
}

- (BOOL) proceed
{
  int count, max;
  BOOL rc;

  rc = YES;

  max = [userIDs count];
  for (count = 0; rc && count < max; count++)
    rc = [self exportUser: [userIDs objectAtIndex: count]];

  return rc;
}

- (BOOL) run
{
  return ([self parseArguments] && [self proceed]);
}

@end
