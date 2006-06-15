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

#ifndef __Mailer_SOGoMailManager_H__
#define __Mailer_SOGoMailManager_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>
#include <NGImap4/NGImap4ConnectionManager.h>

/*
  NGImap4ConnectionManager(SOGoMailManager)
  
  Legacy methods, the methods were used prior the move to NGImap4.
*/

@class NSString, NSData, NSURL, NSArray, NSMutableDictionary, NSTimer;
@class NSDictionary;
@class NSException;
@class NGImap4Client;

@interface NGImap4ConnectionManager(SOGoMailManager)

/* folder hierarchy */

- (NSArray *)subfoldersForURL:(NSURL *)_url password:(NSString *)_pwd;
- (NSArray *)allFoldersForURL:(NSURL *)_url password:(NSString *)_pwd;

/* messages */

- (NSArray *)fetchUIDsInURL:(NSURL *)_url qualifier:(id)_q
  sortOrdering:(id)_so password:(NSString *)_pwd;
- (NSArray *)fetchUIDs:(NSArray *)_uids inURL:(NSURL *)_url
  parts:(NSArray *)_parts password:(NSString *)_pwd;

- (NSException *)expungeAtURL:(NSURL *)_url password:(NSString *)_pwd;

/* individual message */

- (id)fetchURL:(NSURL *)_url parts:(NSArray *)_parts password:(NSString *)_pwd;

- (NSData *)fetchContentOfBodyPart:(NSString *)_partId
  atURL:(NSURL *)_url password:(NSString *)_pwd;

- (NSException *)addFlags:(id)_f    toURL:(NSURL *)_u password:(NSString *)_p;
- (NSException *)removeFlags:(id)_f toURL:(NSURL *)_u password:(NSString *)_p;
- (NSException *)markURLDeleted:(NSURL *)_u           password:(NSString *)_p;

- (NSException *)postData:(NSData *)_data flags:(id)_flags
  toFolderURL:(NSURL *)_url password:(NSString *)_p;

- (NSException *)copyMailURL:(NSURL *)_srcurl toFolderURL:(NSURL *)_desturl
  password:(NSString *)_pwd;

/* managing folders */

- (BOOL)doesMailboxExistAtURL:(NSURL *)_url password:(NSString *)_pwd;
- (id)infoForMailboxAtURL:(NSURL *)_url     password:(NSString *)_pwd;

- (NSException *)createMailbox:(NSString *)_mailbox atURL:(NSURL *)_url
  password:(NSString *)_pwd;
- (NSException *)deleteMailboxAtURL:(NSURL *)_url password:(NSString *)_pwd;

- (NSException *)moveMailboxAtURL:(NSURL *)_srcurl toURL:(NSURL *)_desturl
  password:(NSString *)_pwd;

- (NSDictionary *)aclForMailboxAtURL:(NSURL *)_url password:(NSString *)_pwd;
- (NSString *)myRightsForMailboxAtURL:(NSURL *)_url password:(NSString *)_pwd;

- (NSException *)addFlags:(id)_f toAllMessagesInURL:(NSURL *)_u
  password:(NSString *)_p;

@end

#endif /* __Mailer_SOGoMailManager_H__ */
