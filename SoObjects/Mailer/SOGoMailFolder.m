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

#include "SOGoMailFolder.h"
#include "SOGoMailObject.h"
#include "SOGoMailAccount.h"
#include "SOGoMailManager.h"
#include <NGImap4/NGImap4MailboxInfo.h>
#include "SOGoMailFolderDataSource.h"
#include "common.h"

@implementation SOGoMailFolder

static BOOL useAltNamespace = NO;

+ (int)version {
  return [super version] + 0 /* v1 */;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  useAltNamespace = [ud boolForKey:@"SOGoSpecialFoldersInRoot"];
}

- (void)dealloc {
  [self->selectInfo release];
  [self->filenames  release];
  [self->folderType release];
  [super dealloc];
}

/* IMAP4 */

- (NSString *)relativeImap4Name {
  return [self nameInContainer];
}

/* listing the available folders */

- (NSArray *)toManyRelationshipKeys {
  return [[self imap4Connection] subfoldersForURL:[self imap4URL]];
}
- (NSArray *)toOneRelationshipKeys {
  NSArray  *uids;
  unsigned count;
  
  if (self->filenames != nil)
    return [self->filenames isNotNull] ? self->filenames : nil;

  uids = [self fetchUIDsMatchingQualifier:nil sortOrdering:@"DATE"];
  if ([uids isKindOfClass:[NSException class]])
    return nil;
  
  if ((count = [uids count]) == 0) {
    self->filenames = [[NSArray alloc] init];
  }
  else {
    NSMutableArray *keys;
    unsigned i;
    
    keys = [[NSMutableArray alloc] initWithCapacity:count];
    for (i = 0; i < count; i++) {
      NSString *k;
      
      k = [[uids objectAtIndex:i] stringValue];
      k = [k stringByAppendingString:@".mail"];
      [keys addObject:k];
    }
    self->filenames = [keys copy];
    [keys release];
  }
  return self->filenames;
}

- (EODataSource *)contentDataSourceInContext:(id)_ctx {
  SOGoMailFolderDataSource *ds;
  
  ds = [[SOGoMailFolderDataSource alloc] initWithImap4URL:[self imap4URL]
					 imap4Password:[self imap4Password]];
  return [ds autorelease];
}

/* mailbox raw ops */

- (NSException *)primaryFetchMailboxInfo {
  /* returns nil if fetch was successful */
  id info;
  
  if (self->selectInfo != nil)
    return nil; /* select info exists, => no error */
  
  info = [[self imap4Connection] infoForMailboxAtURL:[self imap4URL]];
  if ([info isKindOfClass:[NSException class]])
    return info;
  
  self->selectInfo = [info retain];
  return nil; /* no error */
}

/* permissions */

- (void)_loadACLPermissionFlags {
  NSString *rights;
  unsigned i, len;
  
  if (self->somfFlags.didCheckMyRights)
    return;

  rights = [[self imap4Connection] myRightsForMailboxAtURL:[self imap4URL]];
  if ([rights isKindOfClass:[NSException class]]) {
    [self logWithFormat:@"ERROR: could not retrieve ACL: %@", rights];
    return;
  }
  
  // [self logWithFormat:@"GOT PERM: %@", rights];
  
  self->somfFlags.didCheckMyRights = 1;
  
  /* reset flags */
  self->somfFlags.isDeleteAndExpungeAllowed = 0;
  self->somfFlags.isReadAllowed   = 0;
  self->somfFlags.isWriteAllowed  = 0;
  self->somfFlags.isInsertAllowed = 0;
  self->somfFlags.isPostAllowed   = 0;
  self->somfFlags.isCreateAllowed = 0;
  self->somfFlags.hasAdminAccess  = 0;
  
  for (i = 0, len = [rights length]; i < len; i++) {
    switch ([rights characterAtIndex:i]) {
    case 'd': self->somfFlags.isDeleteAndExpungeAllowed = 1; break;
    case 'r': self->somfFlags.isReadAllowed   = 1; break;
    case 'w': self->somfFlags.isWriteAllowed  = 1; break;
    case 'i': self->somfFlags.isInsertAllowed = 1; break;
    case 'p': self->somfFlags.isPostAllowed   = 1; break;
    case 'c': self->somfFlags.isCreateAllowed = 1; break;
    case 'a': self->somfFlags.hasAdminAccess  = 1; break;
    }
  }
}

- (BOOL)isDeleteAndExpungeAllowed {
  [self _loadACLPermissionFlags];
  return self->somfFlags.isDeleteAndExpungeAllowed ? YES : NO;
}
- (BOOL)isReadAllowed {
  [self _loadACLPermissionFlags];
  return self->somfFlags.isReadAllowed ? YES : NO;
}
- (BOOL)isWriteAllowed {
  [self _loadACLPermissionFlags];
  return self->somfFlags.isWriteAllowed ? YES : NO;
}
- (BOOL)isInsertAllowed {
  [self _loadACLPermissionFlags];
  return self->somfFlags.isInsertAllowed ? YES : NO;
}
- (BOOL)isPostAllowed {
  [self _loadACLPermissionFlags];
  return self->somfFlags.isPostAllowed ? YES : NO;
}

- (BOOL)isCreateAllowedInACL {
  /* we call this directly from UIxMailAccountView */
  [self _loadACLPermissionFlags];
  return self->somfFlags.isCreateAllowed ? YES : NO;
}
- (BOOL)isCreateAllowed {
  if (useAltNamespace) {
    /* with altnamespace, Cyrus doesn't allow mailboxes under INBOX */
    if ([[self outlookFolderClass] isEqualToString:@"IPF.Inbox"])
      return NO;
  }
  return [self isCreateAllowedInACL];
}

- (BOOL)hasAdminAccess {
  [self _loadACLPermissionFlags];
  return self->somfFlags.hasAdminAccess ? YES : NO;
}

/* messages */

- (NSArray *)fetchUIDsMatchingQualifier:(id)_q sortOrdering:(id)_so {
  /* seems to return an NSArray of NSNumber's */
  return [[self imap4Connection] fetchUIDsInURL:[self imap4URL]
				 qualifier:_q sortOrdering:_so];
}

- (NSArray *)fetchUIDs:(NSArray *)_uids parts:(NSArray *)_parts {
  return [[self imap4Connection] fetchUIDs:_uids inURL:[self imap4URL]
				 parts:_parts];
}

- (NSException *)postData:(NSData *)_data flags:(id)_flags {
  return [[self imap4Connection] postData:_data flags:_flags
				 toFolderURL:[self imap4URL]];
}

- (NSException *)expunge {
  return [[self imap4Connection] expungeAtURL:[self imap4URL]];
}

/* flags */

- (NSException *)addFlagsToAllMessages:(id)_f {
  return [[self imap4Connection] addFlags:_f 
				 toAllMessagesInURL:[self imap4URL]];
}

/* name lookup */

- (BOOL)isMessageKey:(NSString *)_key inContext:(id)_ctx {
  /*
    Every key starting with a digit is consider an IMAP4 message key. This is
    not entirely correct since folders could also start with a number.
    
    If we want to support folders beginning with numbers, we would need to
    scan the folder list for the _key, which would make everything quite a bit
    slower.
    TODO: support this mode using a default.
  */
  if ([_key length] == 0)
    return NO;
  
  if (isdigit([_key characterAtIndex:0]))
    return YES;
  
  return NO;
}

- (id)lookupImap4Folder:(NSString *)_key inContext:(id)_ctx {
  // TODO: we might want to check for existence prior controller creation
  NSURL *sf;

  /* check whether URL exists */
  
  sf = [self imap4URL];
  sf = [NSURL URLWithString:[[sf path] stringByAppendingPathComponent:_key]
	      relativeToURL:sf];
  
  if (![[self imap4Connection] doesMailboxExistAtURL:sf]) {
    /* 
       We may not return 404, confuses path traversal - but we still do in the
       calling method. Probably the traversal process should be fixed to
       support 404 exceptions (as stop traversal _and_ acquisition).
    */
    return nil;
  }
  
  /* create object */
  
  return [[[SOGoMailFolder alloc] initWithName:_key 
				  inContainer:self] autorelease];
}

- (id)lookupImap4Message:(NSString *)_key inContext:(id)_ctx {
  // TODO: we might want to check for existence prior controller creation
  return [[[SOGoMailObject alloc] initWithName:_key 
				  inContainer:self] autorelease];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_acquire {
  id obj;
  
  if ([self isMessageKey:_key inContext:_ctx]) {
    /* 
       We assume here that _key is a number and methods are not and this is
       moved above the super lookup since the super checks the
       -toOneRelationshipKeys which in turn loads the message ids.
    */
    return [self lookupImap4Message:_key inContext:_ctx];
  }
  
  /* check attributes directly bound to the app */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
    return obj;
  
  obj = [self lookupImap4Folder:_key  inContext:_ctx];
  if (obj != nil)
    return obj;
  
  /* return 404 to stop acquisition */
  return _acquire
    ? [NSException exceptionWithHTTPStatus:404 /* Not Found */]
    : nil; /* hack to work with WebDAV move */
}

/* WebDAV */

- (BOOL)davIsCollection {
  return YES;
}

- (NSException *)davCreateCollection:(NSString *)_name inContext:(id)_ctx {
  return [[self imap4Connection] createMailbox:_name atURL:[self imap4URL]];
}

- (NSException *)delete {
  /* Note: overrides SOGoObject -delete */
  return [[self imap4Connection] deleteMailboxAtURL:[self imap4URL]];
}

- (NSException *)davMoveToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx
{
  NSURL *destImapURL;
  
  if ([_name length] == 0) { /* target already exists! */
    // TODO: check the overwrite request field (should be done by dispatcher)
    return [NSException exceptionWithHTTPStatus:412 /* Precondition Failed */
			reason:@"target already exists"];
  }
  if (![_target respondsToSelector:@selector(imap4URL)]) {
    return [NSException exceptionWithHTTPStatus:502 /* Bad Gateway */
			reason:@"target is not an IMAP4 folder"];
  }
  
  /* build IMAP4 URL for target */
  
  destImapURL = [_target imap4URL];
  destImapURL = [NSURL URLWithString:[[destImapURL path] 
				       stringByAppendingPathComponent:_name]
		       relativeToURL:destImapURL];
  
  [self logWithFormat:@"TODO: should move collection as '%@' to: %@",
	[[self imap4URL] absoluteString], 
	[destImapURL absoluteString]];
  
  return [[self imap4Connection] moveMailboxAtURL:[self imap4URL] 
				 toURL:destImapURL];
}
- (NSException *)davCopyToTargetObject:(id)_target newName:(NSString *)_name
  inContext:(id)_ctx
{
  [self logWithFormat:@"TODO: should copy collection as '%@' to: %@",
	_name, _target];
  return [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
		      reason:@"not implemented"];
}

/* folder type */

- (NSString *)outlookFolderClass {
  // TODO: detect Trash/Sent/Drafts folders
  SOGoMailAccount *account;
  NSString *n;

  if (self->folderType != nil)
    return self->folderType;
  
  account = [self mailAccountFolder];
  n       = [self nameInContainer];
  
  if ([n isEqualToString:[account trashFolderNameInContext:nil]])
    self->folderType = @"IPF.Trash";
  else if ([n isEqualToString:[account inboxFolderNameInContext:nil]])
    self->folderType = @"IPF.Inbox";
  else if ([n isEqualToString:[account sentFolderNameInContext:nil]])
    self->folderType = @"IPF.Sent";
  else
    self->folderType = @"IPF.Folder";
  
  return self->folderType;
}

@end /* SOGoMailFolder */
