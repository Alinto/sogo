/* MAPIApplication.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSTimeZone.h>
#import <WEExtensions/WEResourceManager.h>

#import <SOGo/SOGoProductLoader.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <Appointments/iCalEntityObject+SOGo.h>

#import "MAPIStoreUserContext.h"
#import "MAPIStoreTypes.h"

#import "MAPIApplication.h"

MAPIApplication *MAPIApp = nil;

@implementation MAPIApplication

+ (BOOL) isCachingEnabled;
{
  return NO;
}

- (NSString *) name
{
  return @"SOGo";
}

- (id) init
{
  if (!MAPIApp)
    {
      WEResourceManager *rm;

      // TODO publish
      [iCalEntityObject initializeSOGoExtensions];

      MAPIApp = [super init];
      [MAPIApp retain];

      rm = [[WEResourceManager alloc] init];
      [self setResourceManager:rm];
      [rm release];

      utcTZ = [NSTimeZone timeZoneWithName: @"UTC"];
      [utcTZ retain];
    }

  return MAPIApp;
}

- (BOOL) shouldSetupSignalHandlers
{
  return NO;
}

- (void) setUserContext: (MAPIStoreUserContext *) newContext
{
  /* user contexts must not be retained here ad their holder (mapistore)
     contexts must be active when any operation occurs. */
  userContext = newContext;
}

- (id) authenticatorInContext: (id) context
{
  return [userContext authenticator];
}

@end
