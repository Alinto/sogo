/*
  Copyright (C) 2023 Alinto

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import "SOGoAdmin.h"

#import <GDLContentStore/GCSFolderManager.h>

#import "NSString+Utilities.h"
#import "SOGoCache.h"

static const NSString *kCacheMotdKey = @"admin-motd";

@implementation SOGoAdmin

+ (id)sharedInstance
{
    static id admin = nil;

    if (!admin)
      admin = [self new];

    return admin;
}

- (id)init {
  if (self = [super init]) {
      
  }
  return self;
}

- (void)dealloc {
  
}

- (BOOL) isConfigured
{
  return nil != [[GCSFolderManager defaultFolderManager] adminFolder];
}

- (NSString *)getMotd
{
  NSString *cache;
  NSString *value;
  
  cache = [[SOGoCache sharedCache] valueForKey:kCacheMotdKey];
  if (!cache) {
    value = [[[GCSFolderManager defaultFolderManager] adminFolder] getMotd];
    if (value) {
      [[SOGoCache sharedCache] setValue:[[[GCSFolderManager defaultFolderManager] adminFolder] getMotd] forKey:kCacheMotdKey];
      cache = value;
    } else {
      cache = @" "; // Empty string won't set cache
      [[SOGoCache sharedCache] setValue:cache forKey:kCacheMotdKey];
    }
  }
  
  return cache;
}

- (NSException *)deleteMotd
{
  NSException *error;

  error = [[[GCSFolderManager defaultFolderManager] adminFolder] deleteMotd];
  if (!error) {
    [[SOGoCache sharedCache] removeValueForKey:kCacheMotdKey];
  }

  return error;
}

- (NSException *)saveMotd:(NSString *)motd
{
  NSException *error;
  NSString *safeMotd;

  safeMotd = [motd stringWithoutHTMLInjection: NO];
  error = [[[GCSFolderManager defaultFolderManager] adminFolder] writeMotd: safeMotd];
  if (!error) {
    [[SOGoCache sharedCache] setValue:safeMotd forKey:kCacheMotdKey];
  }
  return error;
}


@end /* SOGoAdmin */
