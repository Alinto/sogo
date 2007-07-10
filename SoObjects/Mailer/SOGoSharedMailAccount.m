/*
  Copyright (C) 2005 SKYRIX Software AG

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

#include "SOGoSharedMailAccount.h"
#include "common.h"

@interface SOGoMailAccount(UsedPrivates)

- (NSString *)imap4URLString;

- (id)lookupFolder:(NSString *)_key ofClassNamed:(NSString *)_cn
  inContext:(id)_cx;

@end

@implementation SOGoSharedMailAccount

static NSString *otherUsersFolderName = @""; // TODO: add English default

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  otherUsersFolderName = [ud stringForKey:@"SOGoOtherUsersFolderName"];
  NSLog(@"Note: using other-users-folders name: '%@'", otherUsersFolderName);
}

/* shared accounts */

- (BOOL)isSharedAccount {
  return YES;
}

- (NSString *)sharedAccountName {
  NSString *s;
  NSRange  r;
  
  s = [self nameInContainer];
  r = [s rangeOfString:@"@"];
  if (r.length == 0) /* regular HTTP logins are never a shared mailbox */
    return nil;
  
  s = [s substringToIndex:r.location];
  r = [s rangeOfString:@".-."];
  if (r.length == 0) /* no shared mailbox marker */
    return nil;

  return [s substringFromIndex:(r.location + r.length)];
}

/* listing the available folders */

- (NSArray *)additionalRootFolderNames {
  /* do not show Drafts folder in shared mailboxes (#1452) */
  /* Note: this also disables the Sieve folder */
  return nil;
}

- (NSArray *)toManyRelationshipKeys {
  NSMutableArray *m;
  NSArray *b;
  
  m = [NSMutableArray arrayWithCapacity:16];
  
  [m addObject:@"INBOX"]; /* special for shared, see -lookupInboxFolder:.. */
  
  if ((b = [[self imap4Connection] subfoldersForURL:[self imap4URL]]) != nil)
    [m addObjectsFromArray:b];
  
  if ((b = [self additionalRootFolderNames]) != nil)
    [m addObjectsFromArray:b];
  return m;
}

/* IMAP4 locator */

- (NSString *)imap4URLString {
  /* we jump in the hierarchy directly to the shared user folder */
  NSString *s;
  
  s = [super imap4URLString];
  s = [s stringByAppendingString:otherUsersFolderName];
  s = [s stringByAppendingString:@"/"];
  s = [s stringByAppendingString:[self sharedAccountName]];
  return s;
}

/* lookup */

- (id)lookupInboxFolder:(NSString *)_key inContext:(id)_ctx {
  /*
    Note: We have a choice: Cyrus does both, it gives the user an own
          INBOX folder, but it also provides access to the mailbox INBOX
	  folder.
	  However the mailbox INBOX folder is NOT returned as an "INBOX"
	  subcollection as usual, but is the primary mailbox name.
    Eg:
      2 list "*" "*"
      * LIST (\Noinferiors) "/" "INBOX"
      * LIST (\HasChildren) "/" "Boite partag&AOk-e/alienor.a"
    
    The first INBOX is auto-assigned for the user by Cyrus, the second entry
    is actually the INBOX of the mailbox itself (alienor.a).
  */
  return [self lookupFolder:_key ofClassNamed:@"SOGoSharedInboxFolder"
	       inContext:_ctx];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  if ([_key isEqualToString:@"INBOX"])
    return [self lookupInboxFolder:_key inContext:_ctx];
  
  return [super lookupName:_key inContext:_ctx acquire:_flag];
}

@end /* SOGoSharedMailAccount */
