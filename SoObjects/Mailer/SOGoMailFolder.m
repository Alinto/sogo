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

#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSURL+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4MailboxInfo.h>
#import <NGImap4/NGImap4Client.h>

#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>

#import "SOGoMailObject.h"
#import "SOGoMailAccount.h"
#import "SOGoMailManager.h"
#import "SOGoMailFolderDataSource.h"
#import "SOGoMailFolder.h"

static NSString *defaultUserID =  @"anyone";

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

  obj = [self lookupImap4Folder:_key  inContext:_ctx];
  if (obj != nil)
    return obj;
  
  /* check attributes directly bound to the app */
  if ((obj = [super lookupName:_key inContext:_ctx acquire:NO]))
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

/* acls */

- (NSArray *) _imapAclsToSOGoAcls: (NSString *) imapAcls
{
  unsigned int count, max;
  NSMutableArray *SOGoAcls;

  SOGoAcls = [NSMutableArray array];
  max = [imapAcls length];
  for (count = 0; count < max; count++)
    {
      switch ([imapAcls characterAtIndex: count])
	{
	case 'l':
	  [SOGoAcls addObjectUniquely: SOGoRole_ObjectViewer];
	  break;
	case 'r':
	  [SOGoAcls addObjectUniquely: SOGoRole_ObjectReader];
	  break;
	case 's':
	  [SOGoAcls addObjectUniquely: SOGoMailRole_SeenKeeper];
	  break;
	case 'w':
	  [SOGoAcls addObjectUniquely: SOGoMailRole_Writer];
	  break;
	case 'i':
	  [SOGoAcls addObjectUniquely: SOGoRole_ObjectCreator];
	  break;
	case 'p':
	  [SOGoAcls addObjectUniquely: SOGoMailRole_Poster];
	  break;
	case 'k':
	  [SOGoAcls addObjectUniquely: SOGoRole_FolderCreator];
	  break;
	case 'x':
	  [SOGoAcls addObjectUniquely: SOGoRole_ObjectEraser];
	  break;
	case 't':
	  [SOGoAcls addObjectUniquely: SOGoMailRole_MessageEraser];
	  break;
	case 'e':
	  [SOGoAcls addObjectUniquely: SOGoMailRole_Expunger];
	  break;
	case 'a':
	  [SOGoAcls addObjectUniquely: SOGoMailRole_Administrator];
	  break;
	}
    }

  return SOGoAcls;
}

- (NSString *) _sogoAclsToImapAcls: (NSArray *) sogoAcls
{
  NSMutableString *imapAcls;
  NSEnumerator *acls;
  NSString *currentAcl;
  char character;

  imapAcls = [NSMutableString string];
  acls = [sogoAcls objectEnumerator];
  currentAcl = [acls nextObject];
  while (currentAcl)
    {
      if ([currentAcl isEqualToString: SOGoRole_ObjectViewer])
	character = 'l';
      else if ([currentAcl isEqualToString: SOGoRole_ObjectReader])
	character = 'r';
      else if ([currentAcl isEqualToString: SOGoMailRole_SeenKeeper])
	character = 's';
      else if ([currentAcl isEqualToString: SOGoMailRole_Writer])
	character = 'w';
      else if ([currentAcl isEqualToString: SOGoRole_ObjectCreator])
	character = 'i';
      else if ([currentAcl isEqualToString: SOGoMailRole_Poster])
	character = 'p';
      else if ([currentAcl isEqualToString: SOGoRole_FolderCreator])
	character = 'k';
      else if ([currentAcl isEqualToString: SOGoRole_ObjectEraser])
	character = 'x';
      else if ([currentAcl isEqualToString: SOGoMailRole_MessageEraser])
	character = 't';
      else if ([currentAcl isEqualToString: SOGoMailRole_Expunger])
	character = 'e';
      else if ([currentAcl isEqualToString: SOGoMailRole_Administrator])
	character = 'a';
      else
	character = 0;

      if (character)
	[imapAcls appendFormat: @"%c", character];

      currentAcl = [acls nextObject];
    }

  return imapAcls;
}

- (NSArray *) aclUsers
{
  NSDictionary *imapAcls;

  imapAcls = [imap4 aclForMailboxAtURL: [self imap4URL]];

  return [imapAcls allKeys];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSDictionary *imapAcls;
  NSArray *userAcls;

  imapAcls = [imap4 aclForMailboxAtURL: [self imap4URL]];
  userAcls = [imapAcls objectForKey: uid];
  if (!([userAcls count] || [uid isEqualToString: defaultUserID]))
    userAcls = [imapAcls objectForKey: defaultUserID];

  return [self _imapAclsToSOGoAcls: userAcls];
}

- (void) removeAclsForUsers: (NSArray *) users
{
  NSEnumerator *uids;
  NSString *currentUID;
  NSString *folderName;
  NGImap4Client *client;

  folderName = [imap4 imap4FolderNameForURL: [self imap4URL]];
  client = [imap4 client];

  uids = [users objectEnumerator];
  currentUID = [uids nextObject];
  while (currentUID)
    {
      [client deleteACL: folderName uid: currentUID];
      currentUID = [uids nextObject];
    }
}

- (void) setRoles: (NSArray *) roles
	  forUser: (NSString *) uid
{
  NSString *acls, *folderName;

  acls = [self _sogoAclsToImapAcls: roles];
  folderName = [imap4 imap4FolderNameForURL: [self imap4URL]];
  [[imap4 client] setACL: folderName rights: acls uid: uid];
}

- (NSString *) defaultUserID
{
  return defaultUserID;
}

- (BOOL) hasSupportForDefaultRoles
{
  return YES;
}

@end /* SOGoMailFolder */
