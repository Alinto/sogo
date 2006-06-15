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

#ifndef __Mailer_SOGoSharedMailAccount_H__
#define __Mailer_SOGoSharedMailAccount_H__

#include <SoObjects/Mailer/SOGoMailAccount.h>

/*
  SOGoSharedMailAccount
    Parent object: SOGoMailAccounts
    Child objects: SOGoMailFolder
  
  The SOGoSharedMailAccount represents an IMAP4 mail account which is shared
  by multiple users using the ".-." login trick.
  
  Eg:
    beatrix.b.-.evariste.e@amelie-01.ac.melanie2.i2
  
  The mailbox of 'evariste.e' will be accessed using as user 'beatrix.b'. The
  Cyrus server will deliver a special kind of mailbox hierarchy in this case.
  
  An advantage is that either Cyrus or LDAP seems to know about the ".-."
  separator.
*/

@class NSString;

@interface SOGoSharedMailAccount : SOGoMailAccount
{
}

- (BOOL)isSharedAccount;
- (NSString *)sharedAccountName;

@end

#endif /* __Mailer_SOGoSharedMailAccount_H__ */
