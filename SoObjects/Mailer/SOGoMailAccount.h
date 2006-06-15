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

#ifndef __Mailer_SOGoMailAccount_H__
#define __Mailer_SOGoMailAccount_H__

#include <SoObjects/Mailer/SOGoMailBaseObject.h>

/*
  SOGoMailAccount
    Parent object: SOGoMailAccounts
    Child objects: SOGoMailFolder
  
  The SOGoMailAccount represents a single IMAP4 mail account (host, login,
  password, etc)
*/

@class NSString, NSArray;
@class SOGoMailFolder, SOGoMailIdentity;

@interface SOGoMailAccount : SOGoMailBaseObject
{
  SOGoMailFolder *inboxFolder;
  SOGoMailFolder *sentFolder;
  SOGoMailFolder *trashFolder;
}

/* folder pathes */

- (NSArray *)allFolderPathes;
- (NSArray *)additionalRootFolderNames; /* stuff like filters and drafts */

/* shared accounts */

- (BOOL)isSharedAccount;
- (NSString *)sharedAccountName;

/* identity */

- (SOGoMailIdentity *)preferredIdentity;

/* special folders */

- (NSString *)inboxFolderNameInContext:(id)_ctx;
- (NSString *)draftsFolderNameInContext:(id)_ctx;
- (NSString *)sieveFolderNameInContext:(id)_ctx;
- (NSString *)sentFolderNameInContext:(id)_ctx;
- (NSString *)trashFolderNameInContext:(id)_ctx;

- (SOGoMailFolder *)inboxFolderInContext:(id)_ctx;
- (SOGoMailFolder *)sentFolderInContext:(id)_ctx;
- (SOGoMailFolder *)trashFolderInContext:(id)_ctx;

@end

#endif /* __Mailer_SOGoMailAccount_H__ */
