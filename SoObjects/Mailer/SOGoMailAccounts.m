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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "../SOGo/NSArray+Utilities.h"
#import "../SOGo/NSString+Utilities.h"
#import "../SOGo/SOGoUser.h"
#import "SOGoMailAccount.h"

#import "SOGoMailAccounts.h"

@implementation SOGoMailAccounts

- (NSArray *) mailAccounts
{
  SOGoUser *user;
  
  user = [SOGoUser userWithLogin: [self ownerInContext: nil]];

  return [user mailAccounts];
}

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *keys;
  NSArray *accounts;
  int count, max;
  SOGoUser *user;
  
  user = [SOGoUser userWithLogin: [self ownerInContext: nil]];
  accounts = [user mailAccounts];
  max = [accounts count];

  keys = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    [keys addObject: [NSString stringWithFormat: @"%d", count]];

  return keys;
}

/* name lookup */

- (id) lookupName: (NSString *) _key
        inContext: (id) _ctx
          acquire: (BOOL) _flag
{
  id obj;
  NSArray *accounts;
  SOGoUser *user;
  int keyCount;
  
  /* first check attributes directly bound to the application */
  obj = [super lookupName:_key inContext:_ctx acquire:NO];
  if (!obj)
    {
      user = [SOGoUser userWithLogin: [self ownerInContext: nil]];
      accounts = [user mailAccounts];

      keyCount = [_key intValue];
      if ([_key isEqualToString: [NSString stringWithFormat: @"%d", keyCount]]
          && keyCount > -1 && keyCount < [accounts count])
        obj = [SOGoMailAccount objectWithName: _key inContainer: self];
      else
        obj = [NSException exceptionWithHTTPStatus: 404 /* Not Found */];
    }

  return obj;
}

@end /* SOGoMailAccounts */
