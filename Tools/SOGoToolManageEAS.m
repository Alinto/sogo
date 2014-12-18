/* SOGoToolManageEAS.m - this file is part of SOGo
 *
 * Copyright (C) 2014 Inverse inc.
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
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOApplication.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoProductLoader.h>
#import "SOGo/SOGoCredentialsFile.h"
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailAccount.h>

#import <SOGo/SOGoCacheGCSObject.h>


#import "SOGoTool.h"

typedef enum
{
  ManageEASUnknown = -1,
  ManageEASListDevices = 0,
  ManageEASListFolders = 2,
  ManageEASResetDevice = 3,
  ManageEASRestFolder = 4,
} SOGoManageEASCommand;

@interface SOGoToolManageEAS : SOGoTool
@end

@implementation SOGoToolManageEAS

+ (void) initialize
{
}

+ (NSString *) command
{
  return @"manage-eas";
}

+ (NSString *) description
{
  return @"manage EAS folders";
}

- (void) usage
{
  fprintf (stderr, "manage-eas listdevices|resetdevice|resetfolder user <devinceId | folderId> \n\n"
           "     user              the user of whom to reset the whole device or a single folder\n"
           "  Examples:\n"
           "       sogo-tool manage-eas listdevices janedoe\n"
           "       sogo-tool manage-eas listfolders janedoe androidc316986417\n"
           "       sogo-tool manage-eas resetdevice janedoe androidc316986417\n"
           "       sogo-tool manage-eas resetfolder janedow androidc316986417+folderlala-dada-sasa_7a13_1a2386e0_e\n") ;
}


- (SOGoManageEASCommand) _cmdFromString: (NSString *) theString
{
  if ([theString length] > 2)
    {
      if ([theString caseInsensitiveCompare: @"listdevices"] == NSOrderedSame)
        return ManageEASListDevices;
      else if ([theString caseInsensitiveCompare: @"listfolders"] == NSOrderedSame)
        return ManageEASListFolders;
      else if  ([theString caseInsensitiveCompare: @"resetdevice"] == NSOrderedSame)
        return ManageEASResetDevice;
      else if ([theString caseInsensitiveCompare: @"resetfolder"] == NSOrderedSame)
        return ManageEASRestFolder;
    }

  return ManageEASUnknown;
}

- (BOOL) run
{
  NSString *urlString, *deviceId, *userId;
  NSMutableString *ocFSTableName;
  SOGoCacheGCSObject *oc, *foc;
  NSURL *folderTableURL;
  NSMutableArray *parts;
  NSArray *entries;
  id cacheEntry;

  SOGoManageEASCommand cmd;
  int i, max;
  BOOL rc;
  
  max = [sanitizedArguments count];
  rc = NO;

  if (max > 1)
    {
      SOGoUser *user;

      cmd = [self _cmdFromString: [sanitizedArguments objectAtIndex: 0]];

      userId = [sanitizedArguments objectAtIndex: 1];

      user = [SOGoUser userWithLogin: userId];

      if (![user loginInDomain])
        return NO;

      urlString = [[user domainDefaults] folderInfoURL];
      parts = [[urlString componentsSeparatedByString: @"/"]
                mutableCopy];
      [parts autorelease];
      if ([parts count] == 5)
        {
          /* If "OCSFolderInfoURL" is properly configured, we must have 5
             parts in this url. We strip the '-' character in case we have
             this in the domain part - like foo@bar-zot.com */
          ocFSTableName = [NSMutableString stringWithFormat: @"sogo_cache_folder_%@",
                                           [[user loginInDomain] asCSSIdentifier]];
          [ocFSTableName replaceOccurrencesOfString: @"-"
                                         withString: @"_"
                                            options: 0
                                              range: NSMakeRange(0, [ocFSTableName length])];
          [parts replaceObjectAtIndex: 4 withObject: ocFSTableName];
          folderTableURL
            = [NSURL URLWithString: [parts componentsJoinedByString: @"/"]];
          [folderTableURL retain];
        }

      switch (cmd)
        {
        case ManageEASListDevices:
          oc = [SOGoCacheGCSObject objectWithName: @"0" inContainer: nil];
          [oc setObjectType: ActiveSyncGlobalCacheObject];

          [oc setTableUrl: folderTableURL];
          entries = [oc cacheEntriesForDeviceId: nil newerThanVersion: -1];

          for (i = 0; i < [entries count]; i++)
            {
              cacheEntry = [entries objectAtIndex: i];
              fprintf(stdout,"%s\n", [[cacheEntry substringFromIndex: 1] UTF8String]);
            }

          rc = YES;
          break;

        case ManageEASListFolders:
          if (max > 2)
            {
              /* value specified on command line */
              deviceId = [sanitizedArguments objectAtIndex: 2];

              oc = [SOGoCacheGCSObject objectWithName: @"0" inContainer: nil];
              [oc setObjectType: ActiveSyncFolderCacheObject];

              [oc setTableUrl: folderTableURL];
              entries = [oc cacheEntriesForDeviceId: deviceId newerThanVersion: -1];

              for (i = 0; i < [entries count]; i++)
                {
                  cacheEntry = [entries objectAtIndex: i];
                  fprintf(stdout,"Folder Key: %s\n", [[cacheEntry substringFromIndex: 1] UTF8String]);

                  foc = [SOGoCacheGCSObject objectWithName: [cacheEntry substringFromIndex: 1] inContainer: nil];
                  [foc setObjectType: ActiveSyncFolderCacheObject];
                  [foc setTableUrl: folderTableURL];

                  [foc reloadIfNeeded];

                  fprintf(stdout, "   Folder Name: %s\n\n", [[[foc properties] objectForKey: @"displayName"] UTF8String]);

                  if (verbose)
                    fprintf(stdout, "   metadata Name: %s\n\n", [[[foc properties] description] UTF8String]);
              }

              rc = YES;
            }
          else
            {
              fprintf(stderr, "\nERROR: deviceId not specified\n\n");
            }

          break;


        case ManageEASResetDevice:
          if (max > 2)
            {
              /* value specified on command line */
              deviceId = [sanitizedArguments objectAtIndex: 2];
              oc = [SOGoCacheGCSObject objectWithName: deviceId inContainer: nil];
              [oc setObjectType: ActiveSyncGlobalCacheObject];
              [oc setTableUrl: folderTableURL];

              [oc reloadIfNeeded];
              if ([oc isNew]) {
                fprintf(stderr, "ERROR: Device with ID '%s' not found\n", [deviceId UTF8String]);
                return rc;
              }

              NSMutableString *sql;

              sql = [NSMutableString stringWithFormat: @"DELETE FROM %@" @" WHERE c_path like '/%@%'", [oc tableName], deviceId];

              [oc performBatchSQLQueries: [NSArray arrayWithObject: sql]];
              rc = YES;
            }
          else
            {
              fprintf(stderr, "\nERROR: deviceId not specified\n\n");
            }

          break;

        case ManageEASRestFolder:
          if (max > 2)
            {
              /* value specified on command line */
              deviceId = [sanitizedArguments objectAtIndex: 2];

              //if ([deviceId rangeOfString: @"+"].location == NSNotFound) {
              //   fprintf(stderr, "ERROR: Deviceid invalid folder \"%@\" not found\n", deviceId);
              //   return rc;
              //}

              oc = [SOGoCacheGCSObject objectWithName: deviceId inContainer: nil];
              [oc setObjectType: ActiveSyncFolderCacheObject];
              [oc setTableUrl: folderTableURL];

              [oc reloadIfNeeded];

              if ([oc isNew]) {
                fprintf(stderr, "ERROR: Folder with ID \"%s\" not found\n", [deviceId UTF8String]);
                return rc;
              }
              [[oc properties] removeObjectForKey: @"SyncKey"];
              [[oc properties] removeObjectForKey: @"SyncCache"];
              [[oc properties] removeObjectForKey: @"DateCache"];
              [[oc properties] removeObjectForKey: @"MoreAvailable"];

              [oc save];
              rc = YES;

            }
          else
            {
              fprintf(stderr, "\nERROR: folderId not specified\n\n");
            }

          break;

        case ManageEASUnknown:
          break;
        }
    }

  if (!rc)
    {
      [self usage];
    }

  return rc;
}

@end
