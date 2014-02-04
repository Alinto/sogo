/* SOGoUserSettings.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2013 Inverse inc.
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

#import "SOGoUserProfile.h"

#import "SOGoUserSettings.h"

static Class SOGoUserProfileKlass = Nil;

@implementation SOGoUserSettings

+ (NSString *) userProfileClassName
{
  return @"SOGoSQLUserProfile";
}

+ (void) initialize
{
  if (!SOGoUserProfileKlass)
    SOGoUserProfileKlass = NSClassFromString ([self userProfileClassName]);
}

+ (SOGoUserSettings *) settingsForUser: (NSString *) userId
{
  SOGoUserProfile *up;
  SOGoUserSettings *ud;

  up = [SOGoUserProfileKlass userProfileWithType: SOGoUserProfileTypeSettings
                                          forUID: userId];
  [up fetchProfile];
  ud = [self defaultsSourceWithSource: up andParentSource: nil];

  return ud;
}

- (NSArray *) _subscribedFoldersForModule: (NSString *) module
{
  return [[self dictionaryForKey: module] objectForKey: @"SubscribedFolders"];
}

- (NSArray *) subscribedCalendars
{
  return [self _subscribedFoldersForModule: @"Calendar"];
}

- (NSArray *) subscribedAddressBooks
{
  return [self _subscribedFoldersForModule: @"Contacts"];
}

/* Microsoft Active Sync support */
- (void) setMicrosoftActiveSyncMetadata: (NSDictionary *) theMetadata
                              forDevice: (NSString *) theDeviceID
{
  if (theMetadata && theDeviceID)
    {
      NSMutableDictionary *d;

      d = [NSMutableDictionary dictionaryWithDictionary: [self dictionaryForKey: @"SOGoMicrosoftActiveSyncMetadata"]];
      [d setObject: theMetadata  forKey: theDeviceID];

      [self setObject: d forKey: @"SOGoMicrosoftActiveSyncMetadata"];
    }
}

- (NSMutableDictionary *) microsoftActiveSyncMetadataForDevice: (NSString *) theDevice
{
  NSDictionary *d;
  
  d = [self dictionaryForKey: @"SOGoMicrosoftActiveSyncMetadata"];
  
  return [NSMutableDictionary dictionaryWithDictionary: [d objectForKey: theDevice]];
}

@end
