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

#import <Foundation/NSArray.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4ConnectionManager.h>

#import "SOGoMailManager.h"

/*
  Could check read-write state:
    dict = [[self->context client] select:[self absoluteName]];
    self->isReadOnly = 
      [[dict objectForKey:@"access"] isEqualToString:@"READ-WRITE"]
      ? NoNumber : YesNumber;
  
  TODO: to implement copy, use "uid copy" instead of "copy" as used by
        NGImap4Client.
*/

@implementation NGImap4ConnectionManager(SOGoMailManager)

+ (id)defaultMailManager {
  return [self defaultConnectionManager];
}


- (NSException *)errorForMissingEntryAtURL:(NSURL *)_url {
  // TODO: improve
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */
		      reason:@"Did not find mail URL"];
}

/* client object */


/* folder hierarchy */

- (NSArray *)subfoldersForURL:(NSURL *)_url password:(NSString *)_pwd {
  NGImap4Connection *entry;

  /* check connection cache */
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return nil;
  
  return [entry subfoldersForURL:_url];
}

- (NSArray *)allFoldersForURL:(NSURL *)_url password:(NSString *)_pwd {
  NGImap4Connection *entry;
  
  /* check connection cache */
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return nil;
  
  return [entry allFoldersForURL:_url];
}

/* messages */

- (NSArray *)fetchUIDsInURL:(NSURL *)_url qualifier:(id)_qualifier
  sortOrdering:(id)_so password:(NSString *)_pwd
{
  /* 
     sortOrdering can be an NSString, an EOSortOrdering or an array of EOS.
  */
  NGImap4Connection *entry;
  
  /* check connection cache */
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return nil;
  
  return [entry fetchUIDsInURL:_url qualifier:_qualifier sortOrdering:_so];
}

- (NSArray *)fetchUIDs:(NSArray *)_uids inURL:(NSURL *)_url
  parts:(NSArray *)_parts password:(NSString *)_pwd
{
  // currently returns a dict?!
  /*
    Allowed fetch keys:
      UID
      BODY.PEEK[<section>]<<partial>>
      BODY            [this is the bodystructure, supported]
      BODYSTRUCTURE   [not supported yet!]
      ENVELOPE        [this is a parsed header, but does not include type]
      FLAGS
      INTERNALDATE
      RFC822
      RFC822.HEADER
      RFC822.SIZE
      RFC822.TEXT
  */
  NGImap4Connection *entry;
  
  if (_uids == nil)
    return nil;
  if ([_uids count] == 0)
    return nil; // TODO: might break empty folders?! return a dict!
  
  /* check connection cache */
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return nil;
  
  return [entry fetchUIDs:_uids inURL:_url parts:_parts];
}

- (NSException *)expungeAtURL:(NSURL *)_url password:(NSString *)_pwd {
  NGImap4Connection *entry;
  
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return [self errorForMissingEntryAtURL:_url];
  
  return [entry expungeAtURL:_url];
}

- (id)fetchURL:(NSURL *)_url parts:(NSArray *)_parts password:(NSString *)_pwd{
  NGImap4Connection *entry;
  
  if (![_url isNotNull]) return nil;
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return [self errorForMissingEntryAtURL:_url];
  
  return [entry fetchURL:_url parts:_parts];
}

- (NSData *)fetchContentOfBodyPart:(NSString *)_partId
  atURL:(NSURL *)_url password:(NSString *)_pwd
{
  NGImap4Connection *entry;

  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return nil; // TODO: improve?

  return [entry fetchContentOfBodyPart:_partId atURL:_url];
}

- (NSException *)addOrRemove:(BOOL)_flag flags:(id)_f
  toURL:(NSURL *)_url password:(NSString *)_p
{
  NGImap4Connection *entry;

  if ((entry = [self connectionForURL:_url password:_p]) == nil)
    return [self errorForMissingEntryAtURL:_url];

  return [entry addOrRemove:_flag flags:_f toURL:_url];
}
- (NSException *)addFlags:(id)_f toURL:(NSURL *)_u password:(NSString *)_p {
  return [self addOrRemove:YES flags:_f toURL:_u password:_p];
}
- (NSException *)removeFlags:(id)_f toURL:(NSURL *)_u password:(NSString *)_p {
  return [self addOrRemove:NO flags:_f toURL:_u password:_p];
}

- (NSException *)markURLDeleted:(NSURL *)_url password:(NSString *)_p {
  return [self addOrRemove:YES flags:@"Deleted" toURL:_url password:_p];
}

- (NSException *)postData:(NSData *)_data flags:(id)_f
  toFolderURL:(NSURL *)_url password:(NSString *)_p
{
  NGImap4Connection *entry;

  if (![_url isNotNull]) return nil;
  
  if ((entry = [self connectionForURL:_url password:_p]) == nil)
    return [self errorForMissingEntryAtURL:_url];
  
  return [entry postData:_data flags:_f toFolderURL:_url];
}

- (NSException *)copyMailURL:(NSURL *)_srcurl toFolderURL:(NSURL *)_desturl
  password:(NSString *)_pwd
{
  NGImap4Connection *entry;
  
  /* check connection cache */
  
  if ((entry = [self connectionForURL:_srcurl password:_pwd]) == nil)
    return [self errorForMissingEntryAtURL:_srcurl];
  
  /* check whether URLs are on different servers */
  
  if ([self connectionForURL:_desturl password:_pwd] != entry) {
    // TODO: find a better error code
    return [NSException exceptionWithHTTPStatus:502 /* Bad Gateway */
			reason:@"source and destination on different servers"];
  }  
  
  return [entry copyMailURL:_srcurl toFolderURL:_desturl];
}

/* managing folders */

- (BOOL)isPermissionDeniedResult:(id)_result {
  if ([[_result valueForKey:@"result"] intValue] != 0)
    return NO;
  
  return [[_result valueForKey:@"reason"] 
	           isEqualToString:@"Permission denied"];
}

- (BOOL)doesMailboxExistAtURL:(NSURL *)_url password:(NSString *)_pwd {
  NGImap4Connection *entry;
  
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return NO;
  
  return [entry doesMailboxExistAtURL:_url];
}

- (id)infoForMailboxAtURL:(NSURL *)_url password:(NSString *)_pwd {
  NGImap4Connection *entry;
  
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return [self errorForMissingEntryAtURL:_url];
  
  return [entry infoForMailboxAtURL:_url];
}

- (NSException *)createMailbox:(NSString *)_mailbox atURL:(NSURL *)_url
  password:(NSString *)_pwd
{
  NGImap4Connection *entry;
  
  /* check connection cache */
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return [self errorForMissingEntryAtURL:_url];

  return [entry createMailbox:_mailbox atURL:_url];
}

- (NSException *)deleteMailboxAtURL:(NSURL *)_url password:(NSString *)_pwd {
  NGImap4Connection *entry;
  
  /* check connection cache */
  
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return [self errorForMissingEntryAtURL:_url];
  
  return [entry deleteMailboxAtURL:_url];
}

- (NSException *)moveMailboxAtURL:(NSURL *)_srcurl toURL:(NSURL *)_desturl
  password:(NSString *)_pwd
{
  NGImap4Connection *entry;
  
  /* check connection cache */
  
  if ((entry = [self connectionForURL:_srcurl password:_pwd]) == nil)
    return [self errorForMissingEntryAtURL:_srcurl];
  
  /* check whether URLs are on different servers */
  
  if ([self connectionForURL:_desturl password:_pwd] != entry) {
    // TODO: find a better error code
    return [NSException exceptionWithHTTPStatus:502 /* Bad Gateway */
			reason:@"source and destination on different servers"];
  }  
  
  return [entry moveMailboxAtURL:_srcurl toURL:_desturl];
}

- (NSDictionary *)aclForMailboxAtURL:(NSURL *)_url password:(NSString *)_pwd {
  /*
    Returns a mapping of uid => permission strings, eg:
      guizmo.g = lrs;
      root     = lrswipcda;
  */
  NGImap4Connection *entry;
  
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return (id)[self errorForMissingEntryAtURL:_url];
  
  return [entry aclForMailboxAtURL:_url];
}

- (NSString *)myRightsForMailboxAtURL:(NSURL *)_url password:(NSString *)_pwd {
  NGImap4Connection *entry;
  
  if ((entry = [self connectionForURL:_url password:_pwd]) == nil)
    return (id)[self errorForMissingEntryAtURL:_url];

  return [entry myRightsForMailboxAtURL:_url];
}

/* bulk flag adding (eg used for empty/trash) */

- (NSException *)addFlags:(id)_f toAllMessagesInURL:(NSURL *)_url
  password:(NSString *)_p
{
  NGImap4Connection *entry;
  
  if (![_url isNotNull]) return nil;
  if (![_f   isNotNull]) return nil;
  
  if ((entry = [self connectionForURL:_url password:_p]) == nil)
    return [self errorForMissingEntryAtURL:_url];
  
  return [entry addFlags:_f toAllMessagesInURL:_url];
}

@end /* NGImap4ConnectionManager(SOGoMailManager) */
