/* SOGoToolBackup.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSError.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SOGo/SOGoUserManager.h>
#import <SOGo/LDAPSource.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserProfile.h>
#import <SOGo/SOGoUserSettings.h>
#import <Contacts/NSDictionary+LDIF.h>

#import "SOGoTool.h"

/* TODO:
   - handle database connectivity errors
   - respond to "--help backup"
   - allow more than one user specifier on the command-line
*/

@interface SOGoToolBackup : SOGoTool
{
  NSString *directory;
  NSArray *userIDs;
}

@end

@implementation SOGoToolBackup

+ (void) initialize
{
  [[SOGoProductLoader productLoader]
    loadProducts: [NSArray arrayWithObject: @"Contacts.SOGo"]];
}

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
  fprintf (stderr, "backup directory ALL|user1 [user2] ...\n\n"
	   "           directory  the target directory where backup files will be stored\n"
	   "           user       the user of whom to save the data or ALL for everybody\n\n"
	   "Example:   sogo-tool backup /tmp/foo ALL\n");
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
      rc = [fm createDirectoryAtPath: directory
                          attributes: nil];
      if (!rc)
        NSLog (@"an error occured during directory creation");
    }

  return rc;
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
  pool = [[NSAutoreleasePool alloc] init];

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
	  sql
	    = [NSString stringWithFormat: @"SELECT DISTINCT c_path2 FROM %@",
			[folderLocation gcsTableName]];
	  [fc evaluateExpressionX: sql];
	  attrs = [fc describeResults: NO];
	  while ((infos = [fc fetchAttributes: attrs withZone: NULL]))
	    {
	      user = [infos objectForKey: @"c_path2"];
	      if (user)
		[allSqlUsers addObject: user];
	    }
	  [cm releaseChannel: fc];

	  users = allSqlUsers;
	  max = [users count];
	}
    }

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
	NSLog (@"user '%@' unknown", user);
    }
  [allUsers autorelease];
  
  ASSIGN (userIDs, [allUsers objectsForKey: @"c_uid" notFoundMarker: nil]);
  DESTROY(pool);

  return ([userIDs count] > 0);
}

- (BOOL) parseArguments
{
  BOOL rc;
  NSRange rest;
  int max;

  max = [arguments count];
  if (max > 1)
    {
      ASSIGN (directory, [arguments objectAtIndex: 0]);
      rest = NSMakeRange (1, max - 1);
      rc = ([self checkDirectory]
            && [self fetchUserIDs: [arguments subarrayWithRange: rest]]);
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
  BOOL rc;

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
  if (records)
    { 
      [tableRecord setObject: records forKey: @"records"];
      [tableRecord setObject: [self fetchFolderDisplayName: folder
                                                    withFM: fm]
                      forKey: @"displayname"];
      [tableRecord setObject: [self fetchFolderACL: gcsFolder]
                      forKey: @"acl"];
      [folderRecord setObject: tableRecord forKey: folder];
      rc = YES;
   }
  else
    {
      NSLog(@"Unable to extract records for folder %@", folder);
      rc = NO;
    }

  return rc;
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
      // NSLog (@"folder %d: %@", count, folder);
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
  NSObject <SOGoSource> *currentSource;
  SOGoUserManager *lm;
  NSDictionary *userEntry;
  BOOL done;

  lm = [SOGoUserManager sharedUserManager];

  done = NO;
  ldapSources = [[lm authenticationSourceIDsInDomain: nil] objectEnumerator];
  while (!done && (sourceID = [ldapSources nextObject]))
    {
      currentSource = [lm sourceWithID: sourceID];
      userEntry = [currentSource lookupContactEntry: uid];
      if (userEntry)
	{
          [userRecord setObject: [userEntry ldifRecordAsString]
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
  SOGoUserProfile *defaultsSource, *profileSource;

  sogoUser = [SOGoUser userWithLogin: uid roles: nil];
  defaultsSource = [[sogoUser userDefaults] source];
  profileSource = [[sogoUser userSettings] source];
  preferences = [NSArray arrayWithObjects:
                           [defaultsSource values], [profileSource values],
                         nil];
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
  NSAutoreleasePool *pool;
  int count, max;
  BOOL rc;

  rc = YES;

  pool = [NSAutoreleasePool new];

  max = [userIDs count];
  for (count = 0; rc && count < max; count++)
    {
      rc = [self exportUser: [userIDs objectAtIndex: count]];
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
