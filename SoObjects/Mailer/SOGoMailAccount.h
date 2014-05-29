/*
  Copyright (C) 2009-2014 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

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
@class NSMutableArray;
@class NSString;

@class SOGoMailFolder;
@class SOGoDraftsFolder;
@class SOGoSentFolder;
@class SOGoTrashFolder;

typedef enum {
  undefined = -1,
  rfc2086 = 0,
  rfc4314
} SOGoIMAPAclStyle;

@interface SOGoMailAccount : SOGoMailBaseObject
{
  SOGoMailFolder *inboxFolder;
  SOGoDraftsFolder *draftsFolder;
  SOGoSentFolder *sentFolder;
  SOGoTrashFolder *trashFolder;
  SOGoIMAPAclStyle imapAclStyle;
  NSMutableArray *identities;
  NSString *otherUsersFolderName;
  NSString *sharedFoldersName;
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

- (NSArray *) allFolderPaths;
- (NSArray *) allFoldersMetadata;

- (NSDictionary *) imapFolderGUIDs;

- (BOOL) isInDraftsFolder;

/* special folders */
- (NSString *) inboxFolderNameInContext: (id)_ctx;
- (NSString *) draftsFolderNameInContext: (id)_ctx;
- (NSString *) sentFolderNameInContext: (id)_ctx;
- (NSString *) trashFolderNameInContext: (id)_ctx;
- (NSString *) otherUsersFolderNameInContext: (id)_ctx;
- (NSString *) sharedFoldersNameInContext: (id)_ctx;

- (SOGoMailFolder *) inboxFolderInContext: (id)_ctx;
- (SOGoDraftsFolder *) draftsFolderInContext: (id)_ctx;
- (SOGoSentFolder *) sentFolderInContext: (id)_ctx;
- (SOGoTrashFolder *) trashFolderInContext: (id)_ctx;

/* namespaces */

- (NSArray *) otherUsersFolderNamespaces;
- (NSArray *) sharedFolderNamespaces;

/* account delegation */
- (NSArray *) delegates;
- (void) addDelegates: (NSArray *) newDelegates;
- (void) removeDelegates: (NSArray *) oldDelegates;

@end

#endif /* __Mailer_SOGoMailAccount_H__ */
