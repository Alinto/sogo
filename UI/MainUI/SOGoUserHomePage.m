/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <NGObjWeb/SoComponent.h>

@interface SOGoUserHomePage : SoComponent
{
  id item;
}

- (NSString *)ownPath;
- (NSString *)userFolderPath;
- (NSString *)relativePathToUserFolderSubPath:(NSString *)_sub;

- (NSString *)relativeCalendarPath;
- (NSString *)relativeContactsPath;
- (NSString *)relativeMailPath;
  
@end

#include <SOGo/AgenorUserManager.h>
#include <SOGo/WOContext+Agenor.h>
#include <SOGo/SOGoUser.h>
#include "common.h"

@implementation SOGoUserHomePage

static NSArray *internetAccessStates = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if (didInit) return;
  didInit = YES;
  
  internetAccessStates = [[NSArray alloc] initWithObjects:@"0", @"1", nil];
}

- (void)dealloc {
  [self->item release];
  [super dealloc];
}

/* lookup */

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  // Note: we do no acquisition
  id obj;
  
  /* first check attributes directly bound to the object */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  return nil;
}

/* accessors */

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (NSArray *)internetAccessStates {
  return internetAccessStates;
}

- (NSString *)internetAccessState {
  NSUserDefaults *ud;
  NSNumber       *value;

  ud    = [[[self context] activeUser] userDefaults];
  value = [ud objectForKey:@"allowinternet"];
  return [NSString stringWithFormat:@"%d", [value boolValue]];
}
- (void)setInternetAccessState:(NSString *)_internetAccessState {
  NSUserDefaults *ud;
  
  ud = [[[self context] activeUser] userDefaults];
  [ud setObject:_internetAccessState forKey:@"allowinternet"];
  [ud synchronize];
}

- (NSString *)itemInternetAccessStateText {
  NSString *key;
  
  key = [NSString stringWithFormat:@"internetAccessState_%@", self->item];
  return key;
}

/* paths */

- (NSString *)ownPath {
  NSString *uri;
  NSRange  r;
  
  uri = [[[self context] request] uri];
  
  /* first: cut off query parameters */
  
  r = [uri rangeOfString:@"?" options:NSBackwardsSearch];
  if (r.length > 0)
    uri = [uri substringToIndex:r.location];
  return uri;
}

- (NSString *)userFolderPath {
  WOContext *ctx;
  NSArray   *traversalObjects;
  NSString  *url;
  
  ctx = [self context];
  traversalObjects = [ctx objectTraversalStack];
  url = [[traversalObjects objectAtIndex:1]
                           baseURLInContext:ctx];
  return [[NSURL URLWithString:url] path];
}

- (NSString *)relativePathToUserFolderSubPath:(NSString *)_sub {
  NSString *dst, *rel;
  
  dst = [[self userFolderPath] stringByAppendingPathComponent:_sub];
  rel = [dst urlPathRelativeToPath:[self ownPath]];
  return rel;
}

- (NSString *)relativeCalendarPath {
  return [self relativePathToUserFolderSubPath:@"Calendar/"];
}

- (NSString *)relativeContactsPath {
  return [self relativePathToUserFolderSubPath:@"Contacts/"];
}

- (NSString *)relativeMailPath {
  return [NSString stringWithFormat: @"%@%@/view",
		   [self relativePathToUserFolderSubPath:@"Mail/"],
		   [self emailForUser]];
}

/* objects */

- (id)calendarFolder {
  return [[self clientObject] lookupName:@"Calendar"
                              inContext:[self context]
                              acquire:NO];
}

/* checking access */

- (BOOL)canAccess {
  WOContext *ctx;
  NSString  *owner;

  ctx   = [self context];
  owner = [[self clientObject] ownerInContext:ctx];
  return [owner isEqualToString:[[ctx activeUser] login]];
}

- (BOOL)isNotAllowedToChangeInternetAccess {
  // TODO: should be a SOGoUser method
  AgenorUserManager *um;
  WOContext         *ctx;
  NSString          *uid;

  ctx = [self context];
  /* do not allow changes when access is from Internet */
  if (![ctx isAccessFromIntranet])
    return YES;
  um  = [AgenorUserManager sharedUserManager];
  uid = [[ctx activeUser] login];
  return [um isUserAllowedToChangeSOGoInternetAccess:uid] ? NO : YES;
}

- (BOOL)isVacationMessageEnabledForInternet {
  // TODO: should be a SOGoUser method
  AgenorUserManager *um;
  NSString          *uid;

  um  = [AgenorUserManager sharedUserManager];
  uid = [[[self context] activeUser] login];
  return [um isInternetAutoresponderEnabledForUser:uid];
}

- (BOOL)isVacationMessageEnabledForIntranet {
  // TODO: should be a SOGoUser method
  AgenorUserManager *um;
  NSString          *uid;
  
  um  = [AgenorUserManager sharedUserManager];
  uid = [[[self context] activeUser] login];
  return [um isIntranetAutoresponderEnabledForUser:uid];
}

/* actions */

#if 0
- (id)defaultAction {
  return [self redirectToLocation:[self relativeCalendarPath]];
}
#endif

/* this is triggered by an XMLHTTPRequest */
- (id)saveInternetAccessStateAction {
  NSString *state;
  
  if ([self isNotAllowedToChangeInternetAccess])
    return [NSException exceptionWithHTTPStatus:403 /* Forbidden */];

  state = [[[self context] request] formValueForKey:@"allowinternet"];
  [self setInternetAccessState:state];
  return [NSException exceptionWithHTTPStatus:200 /* OK */];
}

@end /* SOGoUserHomePage */
