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

#include "SOGoUser+Mail.h"
#include "SOGoMailIdentity.h"
#include "common.h"

@implementation SOGoUser(Mail)

- (NSString *)agenorSentFolderName {
  /* Note: specialty: the Sent folder is called the same in all accounts */
  static NSString *s = nil;
  if (s == nil) {
    NSUserDefaults *ud;
    
    ud = [NSUserDefaults standardUserDefaults];
    s = [[ud stringForKey:@"SOGoSentFolderName"] copy];
    if (![s isNotEmpty]) s = @"Sent";
    [self logWithFormat:@"Note: using SOGoSentFolderName: '%@'", s];
  }
  return s;
}

- (NSString *)agenorSentFolderForAccount:(NSString *)_account {
  // TODO: support different locations for shares!
  NSString *p;
  
  if (![_account isNotEmpty]) 
    return nil;
  
  // if ([_account rangeOfString:@".-."].length == 0)
  // TODO: check whether we need special handling for shares!
  p = [_account stringByAppendingString:@"/"];
  p = [p stringByAppendingString:[self agenorSentFolderName]];
  return p;
}

- (SOGoMailIdentity *)primaryMailIdentity {
  SOGoMailIdentity *identity;
  NSString *account;

  account = [self valueForKey:@"primaryIMAP4AccountString"];
  
  identity = [[[SOGoMailIdentity alloc] init] autorelease];
  [identity setName:[self cn]];
  [identity setEmail:[self email]];
  [identity setSentFolderName:[self agenorSentFolderForAccount:account]];
  return identity;
}

- (SOGoMailIdentity *)mailIdentityForAccount:(NSString *)_account
  emitter:(NSString *)_em
{
  SOGoMailIdentity *identity;
  
  identity = [[[SOGoMailIdentity alloc] init] autorelease];
  [identity setName:[self cn]]; // TODO: should we use something else?
  if ([_em isNotEmpty]) [identity setEmail:_em];
  [identity setSentFolderName:[self agenorSentFolderForAccount:_account]];
  return identity;
}

- (NSArray *)fetchAllMailIdentitiesWithOnlyEmitterAccess:(BOOL)_onlyGC {
  NSMutableArray *identities;
  NSEnumerator *accounts;
  NSDictionary *shares;
  NSString  *account;
  id        identity;
  
  identity = [self primaryMailIdentity];
  shares = [self valueForKey:@"additionalIMAP4AccountsAndEMails"];
  if ([shares count] == 0)
    return [NSArray arrayWithObject: identity];
  
  identities = [NSMutableArray arrayWithCapacity:[shares count] + 1];
  if (identity != nil) [identities addObject:identity];
  
  accounts = [shares keyEnumerator];
  while ((account = [accounts nextObject]) != nil) {
    NSString *emitter;
    
    emitter = [shares objectForKey:account];
    if (_onlyGC && ![emitter isNotNull]) continue;
    
    identity = [self mailIdentityForAccount:account emitter:emitter];
    if (identity != nil)
      [identities addObject:identity];
  }
  
  return identities;
}

- (SOGoMailIdentity *)primaryMailIdentityForAccount:(NSString *)_account {
  NSEnumerator *accounts;
  NSDictionary *shares;
  NSString  *account;
  id        identity;
  
  identity = [self primaryMailIdentity];
  shares = [self valueForKey:@"additionalIMAP4AccountsAndEMails"];
  if ([shares count] == 0)
    return identity;
  
  /* scan shares for ID */
  accounts = [shares keyEnumerator];
  while ((account = [accounts nextObject]) != nil) {
    NSString *emitter;
    
    if (![account isEqualToString:_account])
      continue;
    
    emitter  = [shares objectForKey:account];
    identity = [self mailIdentityForAccount:_account emitter:emitter];
    if ([identity isNotNull])
      return identity;
  }
  
  return identity;
}

@end /* SOGoUser(Mail) */
