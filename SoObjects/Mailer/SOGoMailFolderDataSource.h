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

#ifndef __Mailer_SOGoMailFolderDataSource_H__
#define __Mailer_SOGoMailFolderDataSource_H__

#include <EOControl/EODataSource.h>

/*
  SOGoMailFolderDataSource

  This is used as the contentDataSource in the SOGoMailFolder, that is, as the
  object to retrieve WebDAV listings of an IMAP4 folder.
*/

@class NSString, NSURL, NSArray;
@class EOFetchSpecification;

@interface SOGoMailFolderDataSource : EODataSource
{
  EOFetchSpecification *fetchSpecification;
  NSURL    *imap4URL;
  NSString *imap4Password;
}

- (id)initWithImap4URL:(NSURL *)_imap4URL imap4Password:(NSString *)_pwd;

/* accessors */

- (void)setFetchSpecification:(EOFetchSpecification *)_fetchSpec;
- (EOFetchSpecification *)fetchSpecification;

- (NSURL *)imap4URL;

/* operations */

- (NSArray *)fetchObjects;

@end

#endif /* SOGoMailFolderDataSource */
