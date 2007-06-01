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

#include "SOGoMailAccounts.h"
#include "SOGoUser+Mail.h"
#include "common.h"
#include <NGObjWeb/SoObject+SoDAV.h>
#include <SOGo/WOContext+Agenor.h>

@implementation SOGoMailAccounts

static NSString *AgenorShareLoginMarker  = @".-.";

/* detect webmail being accessed from the outside */

- (BOOL)isInternetRequest {
  return ([context isAccessFromIntranet] ? NO : YES);
}

/* listing the available mailboxes */

- (BOOL) isInHomeFolderBranchOfLoggedInAccount: (NSString *) userLogin
{
  return [[[self container] nameInContainer] isEqualToString: userLogin];
}

- (NSArray *)toManyRelationshipKeys {
  SOGoUser *user;
  id        account;
  NSArray   *shares;
  NSString *userLogin;
  
  /*
    Note: this is not strictly correct. The accounts being retrieved should be
          the accounts based on the container object of this folder. Given
	  sufficient rights (eg delegation rights!), this would allow you to
	  browse the hierarchies of other users.
	  
	  But then, the home-folder would need to know about mail
          functionality which isn't perfect either.
	  => TODO
  */
  user = [context activeUser];
  userLogin = [user login];
  
  /* for now: return nothing if the home-folder does not belong to the login */
  if (![self isInHomeFolderBranchOfLoggedInAccount: userLogin]) {
    [self warnWithFormat:@"User %@ tried to access mail hierarchy of %@",
	  [user login], [[self container] nameInContainer]];
    return nil;
  }
  
  account = [user primaryIMAP4AccountString];
  if ([account isNotNull]) account = [NSArray arrayWithObject:account];
  
  if ([self isInternetRequest]) /* only show primary mailbox in Internet */
    return account;
  
  shares  = [user valueForKey:@"additionalIMAP4AccountStrings"];
  return ([shares count] == 0)
    ? account
    : [account arrayByAddingObjectsFromArray:shares];
}

- (NSArray *) fetchIdentitiesWithOnlyEmitterAccess: (BOOL) _flag
{
  NSString *accountString;

  accountString = [[context activeUser] primaryIMAP4AccountString];

  return [NSArray arrayWithObject: accountString];
}

- (NSArray *)fetchAllIdentities {
  return [self fetchIdentitiesWithOnlyEmitterAccess:NO];
}

- (NSArray *)fetchIdentitiesWithEmitterPermissions {
  return [self fetchIdentitiesWithOnlyEmitterAccess:YES];
}

/* name lookup */

- (BOOL)isValidMailAccountName:(NSString *)_key {
  if ([_key length] == 0)
    return NO;
  
  return YES;
}

- (id)mailAccountWithName:(NSString *)_key inContext:(id)_ctx {
  static Class ctClass = Nil;
  id ct;
  
  if (ctClass == Nil)
    ctClass = NSClassFromString(@"SOGoMailAccount");
  if (ctClass == Nil) {
    [self errorWithFormat:@"missing SOGoMailAccount class!"];
    return nil;
  }
  
  ct = [[ctClass alloc] initWithName:_key inContainer:self];
  return [ct autorelease];
}

- (id)sharedMailAccountWithName:(NSString *)_key inContext:(id)_ctx {
  static Class ctClass = Nil;
  id ct;
  
  if (ctClass == Nil)
    ctClass = NSClassFromString(@"SOGoSharedMailAccount");
  if (ctClass == Nil) {
    [self errorWithFormat:@"missing SOGoSharedMailAccount class!"];
    return nil;
  }
  
  ct = [[ctClass alloc] initWithName:_key inContainer:self];
  return [ct autorelease];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag
{
  id obj;
  NSString *userLogin;

  userLogin = [[context activeUser] login];
  
  /* first check attributes directly bound to the application */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  if (![self isInHomeFolderBranchOfLoggedInAccount: userLogin]) {
    [self warnWithFormat:@"User %@ tried to access mail hierarchy of %@",
	  userLogin, [[self container] nameInContainer]];
    
    return [NSException exceptionWithHTTPStatus:403 /* Forbidden */
			reason:@"Tried to access the mail of another user"];
  }
  
  if ([self isValidMailAccountName:_key]) {
    /* forbid shares for requests coming from the Internet */
    BOOL isSharedKey;
    
    isSharedKey = [_key rangeOfString:AgenorShareLoginMarker].length > 0;
    
    if ([self isInternetRequest]) {
      if (isSharedKey) {
	return [NSException exceptionWithHTTPStatus:403 /* Forbidden */
			    reason:
			      @"Access to shares forbidden from the Internet"];
      }
    }
    
    return isSharedKey
      ? [self sharedMailAccountWithName:_key inContext:_ctx]
      : [self mailAccountWithName:_key inContext:_ctx];
  }

  /* return 404 to stop acquisition */
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */];
}

/* WebDAV */

- (BOOL) davIsCollection
{
  return YES;
}

- (NSString *) davContentType
{
  return @"httpd/unix-directory";
}

/* acls */

- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}


@end /* SOGoMailAccounts */
