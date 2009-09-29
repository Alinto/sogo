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

/* listing the available mailboxes */

// - (BOOL) isInHomeFolderBranchOfLoggedInAccount: (NSString *) userLogin
// {
//   return [[container nameInContainer] isEqualToString: userLogin];
// }

- (id) init
{
  if ((self = [super init]))
    {
      accountKeys = nil;
    }

  return self;
}

- (void) dealloc
{
  [accountKeys release];
  [super dealloc];
}

- (void) _initAccountKeys
{
  NSArray *accounts;
  NSString *currentName;
  int count, max;

  if (!accountKeys)
    {
      accountKeys = [NSMutableDictionary new];

      accounts = [[context activeUser] mailAccounts];
      max = [accounts count];
      for (count = 0; count < max; count++)
        {
          currentName = [[accounts objectAtIndex: count] objectForKey: @"name"];
          [accountKeys setObject: currentName
                          forKey: [currentName asCSSIdentifier]];
        }
    }
}

- (NSDictionary *) accountKeys
{
  [self _initAccountKeys];

  return accountKeys;
}

- (NSArray *) toManyRelationshipKeys
{
  [self _initAccountKeys];

  return [accountKeys allKeys];
}

/* name lookup */

// - (id) mailAccountWithName: (NSString *) _key
// 		 inContext: (id) _ctx
// {
//   static Class ctClass = Nil;
//   id ct;
  
//   if (ctClass == Nil)
//     ctClass = NSClassFromString(@"SOGoMailAccount");
//   if (ctClass == Nil) {
//     [self errorWithFormat:@"missing SOGoMailAccount class!"];
//     return nil;
//   }
  
//   ct = [[ctClass alloc] initWithName:_key inContainer:self];

//   return [ct autorelease];
// }

- (id) lookupName: (NSString *) _key
        inContext: (id) _ctx
          acquire: (BOOL) _flag
{
  id obj;
  NSString *accountName;
//   NSString *userLogin;

//   userLogin = [[context activeUser] login];
  
//   if (![self isInHomeFolderBranchOfLoggedInAccount: userLogin]) {
//     [self warnWithFormat:@ "User %@ tried to access mail hierarchy of %@",
// 	  userLogin, [container nameInContainer]];
    
//     return [NSException exceptionWithHTTPStatus:403 /* Forbidden */
// 			reason:@"Tried to access the mail of another user"];
//   }

  /* first check attributes directly bound to the application */
  obj = [super lookupName:_key inContext:_ctx acquire:NO];
  if (!obj)
    {
      [self _initAccountKeys];
      accountName = [accountKeys objectForKey: _key];
      if ([accountName length])
        {
          obj = [SOGoMailAccount objectWithName: _key inContainer: self];
          [obj setAccountName: accountName];
        }
      else
        obj = [NSException exceptionWithHTTPStatus: 404 /* Not Found */];
    }

  return obj;
}

@end /* SOGoMailAccounts */
