/* SOGoToolRenameUser.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2020 Inverse inc
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
#import <Foundation/NSException.h>

#import <EOControl/EOQualifier.h>
#import <GDLAccess/EOAdaptorContext.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSSpecialQueries.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserSettings.h>

#import "SOGoTool.h"

@interface SOGoToolRenameUser : SOGoTool
{
  NSString *oldUserID;
  NSString *newUserID;
}

@end

@implementation SOGoToolRenameUser

+ (NSString *) command
{
  return @"rename-user";
}

+ (NSString *) description
{
  return @"update records pertaining to a user after a change of user id";
}

- (id) init
{
  if ((self = [super init]))
    {
      oldUserID = nil;
      newUserID = nil;
    }

  return self;
}

- (void) dealloc
{
  [oldUserID release];
  [newUserID release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "rename-user fromuserid touserid\n\n"
	   "           fromuserid  the previous user id\n"
	   "           touserid    the new user id\n\n"
	   "Example:   sogo-tool rename-user jane_doe janedoe\n");
}

- (BOOL) parseArguments
{
  BOOL rc = NO;
  int max;

  max = [arguments count];
  if (max == 2)
    {
      ASSIGN (oldUserID, [arguments objectAtIndex: 0]);
      ASSIGN (newUserID, [arguments objectAtIndex: 1]);
      rc = YES;
    }
  else
    [self usage];

  return rc;
}

- (BOOL) _updateSOGoFolderInfoFromUser: (NSString *) fromUserID
                                toUser: (NSString *) toUserID
{
  BOOL rc = NO;
  GCSFolderManager *fm;
  GCSChannelManager *cm;
  GCSSpecialQueries *specialQueries;
  NSURL *folderLocation;
  EOAdaptorContext *ac;
  EOAdaptorChannel *fc;
  NSString *sql;
  NSString *sqlFromUserID, *sqlToUserID;
  NSException *sqlError;

  fm = [GCSFolderManager defaultFolderManager];
  cm = [fm channelManager];
  folderLocation = [fm folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  ac = [fc adaptorContext];
  specialQueries = [fc specialQueries];
  sqlFromUserID = [fromUserID asSafeSQLString];
  sqlToUserID = [toUserID asSafeSQLString];
      
  [ac beginTransaction];

  sql = [NSString stringWithFormat: @"UPDATE %@ SET c_path2 = '%@'"
                  @" WHERE c_path2 = '%@'",
                  [folderLocation gcsTableName], sqlToUserID, sqlFromUserID];
  sqlError = [fc evaluateExpressionX: sql];
  if (!sqlError)
    {
      sql
        = [specialQueries updateCPathInFolderInfo: [folderLocation gcsTableName]
                                       withCPath2: sqlToUserID];
      sqlError = [fc evaluateExpressionX: sql];
    }
  
  if (sqlError)
    {
      [ac rollbackTransaction];
      NSLog(@"%@", [sqlError reason]);
    }
  else
    rc = [ac commitTransaction];
  
  [cm releaseChannel: fc  immediately: YES];

  return rc;
}

- (BOOL) _updateSOGoFolderInfo
{
  return [self _updateSOGoFolderInfoFromUser: oldUserID toUser: newUserID];
}

- (void) _rollbackSOGoFolderInfo
{
  [self _updateSOGoFolderInfoFromUser: newUserID toUser: oldUserID];
}

- (BOOL) _updateSOGoUserProfileFromUser: (NSString *) fromUserID
                                 toUser: (NSString *) toUserID
{
  BOOL rc = NO;
  GCSFolderManager *fm;
  GCSChannelManager *cm;
  NSURL *profileLocation;
  EOAdaptorContext *ac;
  EOAdaptorChannel *fc;
  NSString *profileURL, *sql, *sqlFromUserID, *sqlToUserID;
  NSString *old_c_default, *old_c_settings, *new_c_default, *new_c_settings;
  NSArray *attrs;
  NSDictionary *row;
  NSException *sqlError;
  SOGoSystemDefaults *sd;

  fm = [GCSFolderManager defaultFolderManager];
  cm = [fm channelManager];
  sd = [SOGoSystemDefaults sharedSystemDefaults];
  profileURL = [sd profileURL];
  profileLocation = [[NSURL alloc] initWithString: profileURL];
  [profileLocation autorelease];
  fc = [cm acquireOpenChannelForURL: profileLocation];
  ac = [fc adaptorContext];
  sqlFromUserID = [fromUserID asSafeSQLString];
  sqlToUserID = [toUserID asSafeSQLString];

  [ac beginTransaction];

  sql = [NSString stringWithFormat: @"SELECT c_defaults, c_settings FROM %@"
                  @" WHERE c_uid = '%@'",
                  [profileLocation gcsTableName], sqlFromUserID];
  sqlError = [fc evaluateExpressionX: sql];
  attrs = [fc describeResults: NO];
  while ((row = [fc fetchAttributes: attrs withZone: NULL]))
  {
    old_c_default = [row objectForKey: @"c_defaults"];
    old_c_settings = [row objectForKey: @"c_settings"];
    new_c_default = [old_c_default stringByReplacingOccurrencesOfString:fromUserID withString:toUserID];
    new_c_settings = [old_c_settings stringByReplacingOccurrencesOfString:fromUserID withString:toUserID];
  }

  sql = [NSString stringWithFormat: @"UPDATE %@ SET c_uid = '%@', c_defaults = '%@', "
                  @"c_settings = '%@' WHERE c_uid = '%@'",
                  [profileLocation gcsTableName], sqlToUserID, new_c_default, new_c_settings, sqlFromUserID];
  sqlError = [fc evaluateExpressionX: sql];
  if (sqlError)
    {
      [ac rollbackTransaction];
      NSLog(@"%@", [sqlError reason]);
    }
  else
    rc = [ac commitTransaction];
  
  [cm releaseChannel: fc  immediately: YES];

  return rc;
}

- (BOOL) _updateSOGoUserProfile
{
  return [self _updateSOGoUserProfileFromUser: oldUserID toUser: newUserID];
}

- (void) _rollbackSOGoUserProfile
{
  [self _updateSOGoUserProfileFromUser: newUserID toUser: oldUserID];
}

- (NSArray *) _fetchSubcribersForUser: (NSString *) fromUserID
{
  NSMutableArray *subscribers;
  GCSFolderManager *fm;
  GCSChannelManager *cm;
  NSURL *profileLocation;
  EOAdaptorChannel *fc;
  NSString *profileURL, *sql, *sqlFromUserID;
  SOGoSystemDefaults *sd;
  NSArray *attrs;
  NSDictionary *row;

  subscribers = [NSMutableArray array];

  fm = [GCSFolderManager defaultFolderManager];
  cm = [fm channelManager];
  sd = [SOGoSystemDefaults sharedSystemDefaults];
  profileURL = [sd profileURL];
  profileLocation = [[NSURL alloc] initWithString: profileURL];
  [profileLocation autorelease];
  fc = [cm acquireOpenChannelForURL: profileLocation];
  sqlFromUserID = [fromUserID asSafeSQLString];
  sql = [NSString stringWithFormat:
                    @"SELECT c_uid FROM %@ WHERE c_settings LIKE '%%\"%@:%%'",
                  [profileLocation gcsTableName], sqlFromUserID];
  [fc evaluateExpressionX: sql];
  attrs = [fc describeResults: NO];
  while ((row = [fc fetchAttributes: attrs withZone: NULL]))
    [subscribers addObject: [row objectForKey: @"c_uid"]];
  [fc cancelFetch];
  [cm releaseChannel: fc  immediately: YES];

  return subscribers;
}

- (NSArray *) _updateSubscriptionsForConfig: (NSArray *) subscriptions
                                   fromUser: (NSString *) fromUserID
                                     toUser: (NSString *) toUserID
{
  NSMutableArray *newSubscriptions;
  BOOL modified = NO;
  NSString *oldPrefix, *oldSubscription, *newPrefix, *rest;
  NSUInteger count, max;

  newSubscriptions = [subscriptions mutableCopy];
  [newSubscriptions autorelease];
  oldPrefix = [NSString stringWithFormat: @"%@:", fromUserID];
  newPrefix = [NSString stringWithFormat: @"%@:", toUserID];
  max = [subscriptions count];
  for (count = 0; count < max; count++)
    {
      oldSubscription = [subscriptions objectAtIndex: count];
      if ([oldSubscription hasPrefix: oldPrefix])
        {
          modified = YES;
          rest = [oldSubscription substringFromIndex: [oldPrefix length]];
          [newSubscriptions replaceObjectAtIndex: count
                                      withObject: [NSString stringWithFormat: @"%@%@", newPrefix, rest]];
        }
    }

  if (!modified)
    newSubscriptions = nil;

  return newSubscriptions;
}

- (NSDictionary *) _updatedValuesForConfig: (NSDictionary *) config
                                  fromUser: (NSString *) fromUserID
                                    toUser: (NSString *) toUserID
{
  NSMutableDictionary *newConfig;
  BOOL modified = NO;
  NSString *oldPrefix, *oldKey, *newPrefix, *rest;
  NSArray *keys;
  NSUInteger count, max;

  newConfig = [config mutableCopy];
  [newConfig autorelease];
  oldPrefix = [NSString stringWithFormat: @"%@:", fromUserID];
  newPrefix = [NSString stringWithFormat: @"%@:", toUserID];
  keys = [newConfig allKeys];
  max = [keys count];
  for (count = 0; count < max; count++)
    {
      oldKey = [keys objectAtIndex: count];
      if ([oldKey hasPrefix: oldPrefix])
        {
          modified = YES;
          rest = [oldKey substringFromIndex: [oldPrefix length]];
          [newConfig setObject: [newConfig objectForKey: oldKey]
                        forKey: [NSString stringWithFormat: @"%@%@", newPrefix, rest]];
          [newConfig removeObjectForKey: oldKey];
        }
    }

  if (!modified)
    newConfig = nil;

  return newConfig;
}

- (BOOL) _updateSettings: (SOGoUserSettings *) settings
               forModule: (NSString *) moduleName
                fromUser: (NSString *) fromUserID
                  toUser: (NSString *) toUserID
{
  static NSString *contactsKeys[] = { @"FolderDisplayNames", nil };
  static NSString *calendarKeys[] = { @"FolderDisplayNames", @"FolderColors",
                                      @"FolderShowAlarms", @"FolderShowTasks",
                                      @"FolderSyncTags", @"FolderSynchronize",
                                      @"FreeBusyExclusions", nil };
  BOOL modified = NO;
  NSMutableDictionary *config;
  NSDictionary *modifiedValues;
  NSArray *modifiedSubscriptions;
  NSString **keys, **key;

  config = [[settings objectForKey: moduleName] mutableCopy];
  if (config)
    {
      if ([moduleName isEqualToString: @"Contacts"])
        keys = contactsKeys;
      else if ([moduleName isEqualToString: @"Calendar"])
        keys = calendarKeys;
      else
        keys = NULL;
      key = keys;

      if (key)
        {
          while (*key)
            {
              modifiedValues
                = [self _updatedValuesForConfig: [config objectForKey: *key]
                                       fromUser: fromUserID toUser: toUserID];
              if (modifiedValues)
                {
                  [config setObject: modifiedValues forKey: *key];
                  modified = YES;
                }
              key++;
            }
        }
      
      modifiedSubscriptions
        = [self
            _updateSubscriptionsForConfig: [config objectForKey: @"SubscribedFolders"]
                                 fromUser: fromUserID
                                   toUser: toUserID];
      if (modifiedSubscriptions)
        {
          modified = YES;
          [config setObject: modifiedSubscriptions forKey: @"SubscribedFolders"];
        }

      if (modified)
        [settings setObject: config forKey: moduleName];
    }

  return modified;
}

- (void) _updateForeignSubscriptionsFromUser: (NSString *) fromUserID
                                      toUser: (NSString *) toUserID
                               forSubscriber: (NSString *) subscriber
{
  SOGoUserSettings *settings;
  BOOL modified;

  settings = [SOGoUserSettings settingsForUser: subscriber];
  modified = ([self _updateSettings: settings forModule: @"Calendar"
                           fromUser: fromUserID toUser: toUserID]
              || [self _updateSettings: settings forModule: @"Contacts"
                              fromUser: fromUserID toUser: toUserID]);
  if (modified)
    [settings synchronize];
}

- (void) _updateForeignSubscriptionsFromUser: (NSString *) fromUserID
                                      toUser: (NSString *) toUserID
{
  NSArray *subscribers;
  NSString *subscriber;
  NSUInteger count, max;

  subscribers = [self _fetchSubcribersForUser: fromUserID];
  max = [subscribers count];
  for (count = 0; count < max; count++)
    {
      subscriber = [subscribers objectAtIndex: count];
      [self _updateForeignSubscriptionsFromUser: fromUserID
                                         toUser: toUserID
                                  forSubscriber: subscriber];
    }
}

- (void) _updateLocalACLsForPath: (NSString *) path
                     andFolderID: (NSString *) folderID
                     fromSQLUser: (NSString *) sqlFromUserID
                       toSQLUser: (NSString *) sqlToUserID
{
  GCSFolderManager *fm;
  GCSFolder *folder;
  GCSChannelManager *cm;
  EOAdaptorChannel *ac;
  NSAutoreleasePool *pool;
  NSArray *acls;
  NSString *sql, *qs, *oldObjectPath, *newObjectPath, *rest;
  NSURL *location;
  EOQualifier *qualifier;

  pool = [NSAutoreleasePool new];

  fm = [GCSFolderManager defaultFolderManager];
  cm = [fm channelManager];
  folder = [fm folderAtPath: path];
  qs = [NSString stringWithFormat: @"c_object LIKE '/%@/%%'", sqlFromUserID];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];

  acls = [folder fetchAclMatchingQualifier: qualifier];
  if ([acls count] > 0)
    {
      oldObjectPath = [[acls objectAtIndex: 0] objectForKey: @"c_object"];
      rest = [oldObjectPath substringFromIndex: [sqlFromUserID length] + 1];
      newObjectPath = [NSString stringWithFormat: @"/%@%@",
                                sqlToUserID, rest];
      location = [folder aclLocation];
      ac = [cm acquireOpenChannelForURL: location];
      if ([GCSFolderManager singleStoreMode])
        sql = [NSString stringWithFormat: @"UPDATE %@ SET c_object = '%@' WHERE c_folder_id = %@",
                        [location gcsTableName], newObjectPath, folderID];
      else
        sql = [NSString stringWithFormat: @"UPDATE %@ SET c_object = '%@'",
                        [location gcsTableName], newObjectPath];
      [ac evaluateExpressionX: sql];
      [cm releaseChannel: ac  immediately: YES];
    }

  [pool release];
}

- (void) _updateLocalACLsFromUser: (NSString *) fromUserID
                           toUser: (NSString *) toUserID
{
  GCSFolderManager *fm;
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSArray *attrs;
  NSDictionary *row;
  NSString *sql, *sqlFromUserID, *sqlToUserID;
  NSURL *folderLocation;

  fm = [GCSFolderManager defaultFolderManager];
  cm = [fm channelManager];
  folderLocation = [fm folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  sqlFromUserID = [fromUserID asSafeSQLString];
  sqlToUserID = [toUserID asSafeSQLString];

  sql = [NSString stringWithFormat: @"SELECT c_path, c_folder_id FROM %@"
                  @" WHERE c_path2 = '%@'",
                  [folderLocation gcsTableName], sqlToUserID];
  [fc evaluateExpressionX: sql];
  attrs = [fc describeResults: NO];
  while ((row = [fc fetchAttributes: attrs withZone: NULL]))
    [self _updateLocalACLsForPath: [row objectForKey: @"c_path"]
                      andFolderID: [row objectForKey: @"c_folder_id"]
                      fromSQLUser: sqlFromUserID
                        toSQLUser: sqlToUserID];
  [fc cancelFetch];
  [cm releaseChannel: fc  immediately: YES];
}

- (void) _updateForeignACLsForPath: (NSString *) path
                       andFolderID: (NSString *) folderID
                       fromSQLUser: (NSString *) sqlFromUserID
                         toSQLUser: (NSString *) sqlToUserID
{
  GCSChannelManager *cm;
  GCSFolder *folder;
  GCSFolderManager *fm;
  EOAdaptorChannel *tc;
  NSAutoreleasePool *pool;
  NSString *sql;
  NSURL *location;

  pool = [NSAutoreleasePool new];

  fm = [GCSFolderManager defaultFolderManager];
  cm = [fm channelManager];
  folder = [fm folderAtPath: path];
  location = [folder aclLocation];

  tc = [cm acquireOpenChannelForURL: location];
  if ([GCSFolderManager singleStoreMode])
    sql = [NSString stringWithFormat: @"UPDATE %@ SET c_uid = '%@'"
                     @" WHERE c_uid = '%@'",
                     [location gcsTableName],
                     sqlToUserID, sqlFromUserID];
  else
    sql = [NSString stringWithFormat: @"UPDATE %@ SET c_uid = '%@'"
                     @" WHERE c_uid = '%@'",
                     [location gcsTableName],
                     sqlToUserID, sqlFromUserID];
  [tc evaluateExpressionX: sql];
  [cm releaseChannel: tc  immediately: YES];
  [pool release];
}

- (void) _updateForeignACLsFromUser: (NSString *) fromUserID
                             toUser: (NSString *) toUserID
{
  GCSFolderManager *fm;
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSArray *attrs;
  NSDictionary *row;
  NSString *sql, *sqlFromUserID, *sqlToUserID;
  NSURL *folderLocation;

  fm = [GCSFolderManager defaultFolderManager];
  cm = [fm channelManager];
  folderLocation = [fm folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  sqlFromUserID = [fromUserID asSafeSQLString];
  sqlToUserID = [toUserID asSafeSQLString];

  sql = [NSString stringWithFormat: @"SELECT c_path, c_folder_id FROM %@"
                  @" WHERE c_path2 != '%@'",
                  [folderLocation gcsTableName], sqlToUserID];
  [fc evaluateExpressionX: sql];
  attrs = [fc describeResults: NO];
  while ((row = [fc fetchAttributes: attrs withZone: NULL]))
    [self _updateForeignACLsForPath: [row objectForKey: @"c_path"]
                        andFolderID: [row objectForKey: @"c_folder_id"]
                        fromSQLUser: sqlFromUserID
                          toSQLUser: sqlToUserID];
  [fc cancelFetch];
  [cm releaseChannel: fc  immediately: YES];
}

- (BOOL) proceed
{
  BOOL rc = NO;

  if ([self _updateSOGoFolderInfo])
    {
      if ([self _updateSOGoUserProfile])
        {
          [self _updateForeignSubscriptionsFromUser: oldUserID toUser: newUserID];
          [self _updateLocalACLsFromUser: oldUserID toUser: newUserID];
          [self _updateForeignACLsFromUser: oldUserID toUser: newUserID];
          [self _updateOldUserIDDefaultAndSettings: oldUserID toUser: newUserID];
          rc = YES;
        }

      if (!rc)
        [self _rollbackSOGoFolderInfo];
    }

  return rc;
}

- (BOOL) run
{
  return ([self parseArguments] && [self proceed]);
}

@end
