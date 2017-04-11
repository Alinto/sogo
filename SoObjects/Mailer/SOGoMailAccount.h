/*
  Copyright (C) 2009-2016 Inverse inc.

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

#ifndef __Mailer_SOGoMailAccount_H__
#define __Mailer_SOGoMailAccount_H__

#import <Mailer/SOGoMailBaseObject.h>

/*
  SOGoMailAccount
    Parent object: SOGoMailAccounts
    Child objects: SOGoMailFolder
  
  The SOGoMailAccount represents a single IMAP4 mail account (host, login,
  password, etc)
*/

@class NSArray;
@class NSMutableDictionary;
@class NSMutableArray;
@class NSString;

@class SOGoMailFolder;
@class SOGoDraftsFolder;
@class SOGoSentFolder;
@class SOGoTrashFolder;
@class SOGoJunkFolder;

typedef enum {
  undefined = -1,
  rfc2086 = 0,
  rfc4314
} SOGoIMAPAclStyle;

typedef enum {
  SOGoMailStandardListing = 0,
  SOGoMailSubscriptionsManagementListing = 1
} SOGoMailListingMode;

@interface SOGoMailAccount : SOGoMailBaseObject
{
  SOGoMailFolder *inboxFolder;
  SOGoDraftsFolder *draftsFolder;
  SOGoSentFolder *sentFolder;
  SOGoTrashFolder *trashFolder;
  SOGoJunkFolder *junkFolder;
  SOGoIMAPAclStyle imapAclStyle;
  NSMutableArray *identities;
  NSString *otherUsersFolderName;
  NSString *sharedFoldersName;
  NSMutableDictionary *subscribedFolders;
  BOOL sieveFolderUTF8Encoding;
}

- (SOGoIMAPAclStyle) imapAclStyle;
- (BOOL) imapAclConformsToIMAPExt;

/* capabilities */
- (BOOL) hasCapability: (NSString *) capability;
- (BOOL) supportsQuotas;
- (BOOL) supportsQResync;

- (id) getInboxQuota;
- (BOOL) updateFilters;
- (BOOL) updateFiltersWithUsername: (NSString *) theUsername
                       andPassword: (NSString *) thePassword;

- (NSArray *) identities;
- (NSString *) signature;
- (NSString *) encryption;

/* folder pathes */
- (NSArray *) toManyRelationshipKeysWithNamespaces: (BOOL) withNSs;

- (NSArray *) allFolderPaths: (SOGoMailListingMode) theListingMode;
- (NSArray *) allFoldersMetadata: (SOGoMailListingMode) theListingMode;

- (NSDictionary *) imapFolderGUIDs;

- (BOOL) isInDraftsFolder;

- (id) lookupNameByPaths: (NSArray *) _paths
               inContext: (id)_ctx
                 acquire: (BOOL) _flag;

  /* special folders */
- (NSString *) inboxFolderNameInContext: (id)_ctx;
- (NSString *) draftsFolderNameInContext: (id)_ctx;
- (NSString *) sentFolderNameInContext: (id)_ctx;
- (NSString *) trashFolderNameInContext: (id)_ctx;
- (NSString *) otherUsersFolderNameInContext: (id)_ctx;
- (NSString *) sharedFoldersNameInContext: (id)_ctx;
- (NSString *) junkFolderNameInContext: (id)_ctx;

- (SOGoMailFolder *) inboxFolderInContext: (id)_ctx;
- (SOGoDraftsFolder *) draftsFolderInContext: (id)_ctx;
- (SOGoSentFolder *) sentFolderInContext: (id)_ctx;
- (SOGoTrashFolder *) trashFolderInContext: (id)_ctx;
- (SOGoJunkFolder *) junkFolderInContext: (id)_ctx;

/* namespaces */

- (NSArray *) otherUsersFolderNamespaces;
- (NSArray *) sharedFolderNamespaces;

/* account delegation */
- (NSArray *) delegates;
- (void) addDelegates: (NSArray *) newDelegates;
- (void) removeDelegates: (NSArray *) oldDelegates;

@end

#endif /* __Mailer_SOGoMailAccount_H__ */
