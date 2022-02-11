/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2009-2017 Inverse inc.

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
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __Mailer_SOGoMailBaseObject_H__
#define __Mailer_SOGoMailBaseObject_H__

#include <SOGo/SOGoObject.h>

/*
  SOGoMailBaseObject
  
  Common base class for mailer SoObjects.

  Subclasses:
    SOGoDraftObject
    SOGoDraftsFolder
    SOGoMailAccount
    SOGoMailBodyPart
    SOGoMailFolder
    SOGoMailObject
*/

@class NSString, NSArray, NSURL;
@class NGImap4ConnectionManager, NGImap4Connection;
@class SOGoMailAccount, SOGoMailAccounts;

@interface SOGoMailBaseObject : SOGoObject
{
  NSURL             *imap4URL;
  NGImap4Connection *imap4;
  BOOL              imap4ExceptionsEnabled;
}

- (BOOL) isFolderish;

- (id) init;

- (id) initWithImap4URL: (NSURL *) _url
	    inContainer: (id) _container;

/* hierarchy */

- (SOGoMailAccount *) mailAccountFolder;
- (SOGoMailAccounts *) mailAccountsFolder;
- (BOOL) isInDraftsFolder;
- (BOOL) isInTemplatesFolder;

/* IMAP4 */

- (NGImap4Connection *) imap4Connection;
- (NGImap4ConnectionManager *) mailManager;

- (NSString *) relativeImap4Name;
- (NSMutableString *) imap4URLString;
- (NSMutableString *) traversalFromMailAccount;

- (NSURL *) imap4URL;
- (NSString *) imap4PasswordRenewed: (BOOL) renew;

- (void) flushMailCaches;

/* IMAP4 names */

- (BOOL) isBodyPartKey: (NSString *) key;

- (int) IMAP4IDFromAppendResult: (NSDictionary *) result;

@end

#endif /* __Mailer_SOGoMailBaseObject_H__ */
