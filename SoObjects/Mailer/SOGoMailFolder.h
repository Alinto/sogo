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

#ifndef __Mailer_SOGoMailFolder_H__
#define __Mailer_SOGoMailFolder_H__

#include <SoObjects/Mailer/SOGoMailBaseObject.h>
#import <Foundation/NSRange.h>

/*
  SOGoMailFolder
    Parent object: the SOGoMailAccount
    Child objects: SOGoMailObject or SOGoMailFolder
    
  The SOGoMailFolder maps to an IMAP4 folder from NGImap4.
*/

@class NSData, NSArray, NSException, NSMutableArray;
@class NGImap4MailboxInfo;

@interface SOGoMailFolder : SOGoMailBaseObject
{
  NSMutableArray *filenames;
  NSString *folderType;
}

/* messages */

- (NSArray *)fetchUIDsMatchingQualifier:(id)_q sortOrdering:(id)_so;
- (NSArray *)fetchUIDs:(NSArray *)_uids parts:(NSArray *)_parts;

- (NSException *)postData:(NSData *)_data flags:(id)_flags;

- (NSException *)expunge;

/* flags */

- (NSException *)addFlagsToAllMessages:(id)_f;

/* folder type */

- (NSString *)outlookFolderClass;

- (NSArray *) subfolders;
- (NSArray *) subfoldersURL;

@end

#endif /* __Mailer_SOGoMailFolder_H__ */
