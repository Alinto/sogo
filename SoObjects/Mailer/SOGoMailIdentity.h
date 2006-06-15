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

#ifndef __Mailer_SOGoMailIdentity_H__
#define __Mailer_SOGoMailIdentity_H__

#import <Foundation/NSObject.h>

/*
  SOGoMailIdentity
  
  A user identity bound to an account.
  
  Note: currently this is not a SoObject. This might change later on.
  
  
  In Thunderbird you have a set of accounts which in turn have a set of
  identities. There is one default identity.
  
  The identities then have:
  - settings
    - a name
    - a from-email
    - a reply-to
    - an organization
    - a signature
    - a vcard (to be attached)
  - folder settings
    - Sent-Folder and bcc
    - Drafts + Templates
  - composition
    - whether to use HTML
    - whether to quote the source message (reply below, above the quote or
      select the quote)
*/

@class NSString;

@interface SOGoMailIdentity : NSObject
{
  NSString *name;
  NSString *email;
  NSString *replyTo;
  NSString *organization;
  NSString *signature;
  NSString *vCard;
  NSString *sentFolderName;
  NSString *sentBCC;
  NSString *draftsFolderName;
  NSString *templatesFolderName;
  struct {
    int composeHTML:1;
    int reserved:31;
  } idFlags;
}

/* accessors */

- (void)setName:(NSString *)_value;
- (NSString *)name;

- (void)setEmail:(NSString *)_value;
- (NSString *)email;

- (void)setReplyTo:(NSString *)_value;
- (NSString *)replyTo;

- (void)setOrganization:(NSString *)_value;
- (NSString *)organization;

- (void)setSignature:(NSString *)_value;
- (NSString *)signature;
- (BOOL)hasSignature;

- (void)setVCard:(NSString *)_value;
- (NSString *)vCard;
- (BOOL)hasVCard;

- (void)setSentFolderName:(NSString *)_value;
- (NSString *)sentFolderName;

- (void)setSentBCC:(NSString *)_value;
- (NSString *)sentBCC;

- (void)setDraftsFolderName:(NSString *)_value;
- (NSString *)draftsFolderName;

- (void)setTemplatesFolderName:(NSString *)_value;
- (NSString *)templatesFolderName;

@end

#endif /* __Mailer_SOGoMailIdentity_H__ */
