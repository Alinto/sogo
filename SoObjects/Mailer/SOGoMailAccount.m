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

#include "SOGoMailAccount.h"
#include "SOGoMailFolder.h"
#include "SOGoMailManager.h"
#include "SOGoDraftsFolder.h"
#include "SOGoUser+Mail.h"
#include <NGObjWeb/SoHTTPAuthenticator.h>
#include "common.h"

@implementation SOGoMailAccount

static NSArray  *rootFolderNames      = nil;
static NSString *inboxFolderName      = @"INBOX";
static NSString *draftsFolderName     = @"Drafts";
static NSString *sieveFolderName      = @"Filters";
static NSString *sentFolderName = nil;
static NSString *trashFolderName = nil;
static NSString *sharedFolderName     = @""; // TODO: add English default
static NSString *otherUsersFolderName = @""; // TODO: add English default
static BOOL     useAltNamespace       = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *cfgDraftsFolderName;

  useAltNamespace = [ud boolForKey:@"SOGoSpecialFoldersInRoot"];
  
  sharedFolderName = [ud stringForKey:@"SOGoSharedFolderName"];
  otherUsersFolderName = [ud stringForKey:@"SOGoOtherUsersFolderName"];
  cfgDraftsFolderName = [ud stringForKey:@"SOGoDraftsFolderName"];
  if (!sentFolderName)
    {
      sentFolderName = [ud stringForKey: @"SOGoSentFolderName"];
      if (!sentFolderName)
	sentFolderName = @"Sent";
      [sentFolderName retain];
    }
  if (!trashFolderName)
    {
      trashFolderName = [ud stringForKey: @"SOGoTrashFolderName"];
      if (!trashFolderName)
	trashFolderName = @"Trash";
      [trashFolderName retain];
    }
  if ([cfgDraftsFolderName length] > 0)
    {
      ASSIGN (draftsFolderName, cfgDraftsFolderName);
      NSLog(@"Note: using drafts folder named:      '%@'", draftsFolderName);
    }

  NSLog(@"Note: using shared-folders name:      '%@'", sharedFolderName);
  NSLog(@"Note: using other-users-folders name: '%@'", otherUsersFolderName);
  if ([ud boolForKey:@"SOGoEnableSieveFolder"]) {
    rootFolderNames = [[NSArray alloc] initWithObjects:
				        draftsFolderName, 
				        sieveFolderName, 
				      nil];
  }
  else {
    rootFolderNames = [[NSArray alloc] initWithObjects:
				        draftsFolderName, 
				      nil];
  }
}

/* shared accounts */

- (BOOL)isSharedAccount {
  NSString *s;
  NSRange  r;
  
  s = [self nameInContainer];
  r = [s rangeOfString:@"@"];
  if (r.length == 0) /* regular HTTP logins are never a shared mailbox */
    return NO;
  
  s = [s substringToIndex:r.location];
  return [s rangeOfString:@".-."].length > 0 ? YES : NO;
}

- (NSString *)sharedAccountName {
  return nil;
}

/* listing the available folders */

- (NSArray *)additionalRootFolderNames {
  return rootFolderNames;
}

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *folders;
  NSArray *imapFolders, *additionalFolders;

  folders = [NSMutableArray new];
  [folders autorelease];

  imapFolders = [[self imap4Connection] subfoldersForURL: [self imap4URL]];
  additionalFolders = [self additionalRootFolderNames];
  if ([imapFolders count] > 0)
    [folders addObjectsFromArray: imapFolders];
  if ([additionalFolders count] > 0)
    {
      [folders removeObjectsInArray: additionalFolders];
      [folders addObjectsFromArray: additionalFolders];
    }

  return folders;
}

/* identity */

- (SOGoMailIdentity *)preferredIdentity {
  return [[context activeUser] primaryMailIdentityForAccount:
				 [self nameInContainer]];
}

/* hierarchy */

- (SOGoMailAccount *)mailAccountFolder {
  return self;
}

- (NSArray *) allFolderPaths
{
  NSMutableArray *newFolders;
  NSArray *rawFolders, *mainFolders;

  rawFolders = [[self imap4Connection]
		 allFoldersForURL: [self imap4URL]];

  mainFolders = [NSArray arrayWithObjects: inboxFolderName, draftsFolderName,
			 sentFolder, trashFolder, nil];
  newFolders = [NSMutableArray arrayWithArray: rawFolders];
  [newFolders removeObjectsInArray: mainFolders];
  [newFolders sortUsingSelector: @selector (caseInsensitiveCompare:)];
  [newFolders replaceObjectsInRange: NSMakeRange (0, 0)
	      withObjectsFromArray: mainFolders];

  return newFolders;
}

/* IMAP4 */

- (BOOL)useSSL {
  return NO;
}

- (NSString *)imap4LoginFromHTTP {
  WORequest *rq;
  NSString  *s;
  NSArray   *creds;
  
  rq = [context request];
  
  s = [rq headerForKey:@"x-webobjects-remote-user"];
  if ([s length] > 0)
    return s;
  
  if ((s = [rq headerForKey:@"authorization"]) == nil) {
    /* no basic auth */
    return nil;
  }
  
  creds = [SoHTTPAuthenticator parseCredentials:s];
  if ([creds count] < 2)
    /* somehow invalid */
    return nil;
  
  return [creds objectAtIndex:0]; /* the user */
}

- (NSMutableString *) imap4URLString
{
  /* private, overridden by SOGoSharedMailAccount */
  NSMutableString *urlString;
  NSString *host;

  urlString = [NSMutableString string];

  if ([self useSSL])
    [urlString appendString: @"imaps://"];
  else
    [urlString appendString: @"imap://"];

  host = [self nameInContainer];
  if (![host rangeOfString: @"@"].length)
    [urlString appendFormat: @"%@@", [self imap4LoginFromHTTP]];
  [urlString appendFormat: @"%@/", host];

  return urlString;
}

- (NSString *) imap4Login
{
  return [[self imap4URL] user];
}

/* name lookup */

- (id)lookupFolder:(NSString *)_key ofClassNamed:(NSString *)_cn
  inContext:(id)_cx
{
  Class clazz;

  if ((clazz = NSClassFromString(_cn)) == Nil) {
    [self logWithFormat:@"ERROR: did not find class '%@' for key: '%@'", 
	    _cn, _key];
    return [NSException exceptionWithHTTPStatus:500 /* server error */
			reason:@"did not find mail folder class!"];
  }
  return [[[clazz alloc] initWithName:_key inContainer:self] autorelease];
}

- (id)lookupImap4Folder:(NSString *)_key inContext:(id)_cx {
  NSString *s;

  s = [_key isEqualToString:[self trashFolderNameInContext:_cx]]
    ? @"SOGoTrashFolder" : @"SOGoMailFolder";
  
  return [self lookupFolder:_key ofClassNamed:s inContext:_cx];
}

- (id)lookupDraftsFolder:(NSString *)_key inContext:(id)_ctx {
  return [self lookupFolder:_key ofClassNamed:@"SOGoDraftsFolder" 
	       inContext:_ctx];
}
- (id)lookupFiltersFolder:(NSString *)_key inContext:(id)_ctx {
  return [self lookupFolder:_key ofClassNamed:@"SOGoSieveScriptsFolder" 
	       inContext:_ctx];
}

- (id) lookupName: (NSString *) _key
	inContext: (id)_ctx
	  acquire: (BOOL) _flag
{
  NSString *folderName;
  id obj;

  if ([_key hasPrefix: @"folder"])
    {
      folderName = [_key substringFromIndex: 6];
      
  // TODO: those should be product.plist bindings? (can't be class bindings
  //       though because they are 'per-account')
      if ([folderName isEqualToString: draftsFolderName])
	obj = [self lookupDraftsFolder: folderName inContext: _ctx];
      else if ([folderName isEqualToString: sieveFolderName])
	obj = [self lookupFiltersFolder: folderName inContext: _ctx];
      else
	obj = [self lookupImap4Folder: folderName inContext: _ctx];
    }
  else
    obj = [super lookupName: _key inContext: _ctx acquire: NO];
  
  /* return 404 to stop acquisition */
  if (!obj)
    obj = [NSException exceptionWithHTTPStatus: 404 /* Not Found */];

  return obj;
}

/* special folders */

- (NSString *) inboxFolderNameInContext: (id)_ctx
{
  return inboxFolderName; /* cannot be changed in Cyrus ? */
}

- (NSString *) draftsFolderNameInContext: (id) _ctx
{
  return draftsFolderName; /* SOGo managed folder */
}

- (NSString *) sieveFolderNameInContext: (id) _ctx
{
  return sieveFolderName;  /* SOGo managed folder */
}

- (NSString *) sentFolderNameInContext:(id)_ctx
{
  return sentFolderName;
}

- (NSString *) trashFolderNameInContext:(id)_ctx
{
  return trashFolderName;
}

- (SOGoMailFolder *) inboxFolderInContext: (id) _ctx
{
  NSString *folderName;

  // TODO: use some profile to determine real location, use a -traverse lookup
  if (!inboxFolder)
    {
      folderName = [NSString stringWithFormat: @"folder%@",
			     [self inboxFolderNameInContext: _ctx]];
      inboxFolder = [self lookupName: folderName inContext: _ctx acquire: NO];
      [inboxFolder retain];
    }

  return inboxFolder;
}

- (SOGoMailFolder *) sentFolderInContext: (id) _ctx
{
  NSString *folderName;
  SOGoMailFolder *lookupFolder;
  // TODO: use some profile to determine real location, use a -traverse lookup

  if (!sentFolder)
    {
      lookupFolder = (useAltNamespace
		      ? (id) self
		      : [self inboxFolderInContext:_ctx]);
      if (![lookupFolder isKindOfClass: [NSException class]])
	{
	  folderName = [NSString stringWithFormat: @"folder%@",
				 [self sentFolderNameInContext:_ctx]];
	  sentFolder = [lookupFolder lookupName: folderName
				     inContext: _ctx acquire: NO];
	}
      if (![sentFolder isNotNull])
	sentFolder = [NSException exceptionWithHTTPStatus: 404 /* not found */
				  reason: @"did not find Sent folder!"];
      [sentFolder retain];
    }

  return sentFolder;
}

- (SOGoMailFolder *) trashFolderInContext: (id) _ctx
{
  NSString *folderName;
  SOGoMailFolder *lookupFolder;
  // TODO: use some profile to determine real location, use a -traverse lookup

  if (!trashFolder)
    {
      lookupFolder = (useAltNamespace
		      ? (id) self
		      : [self inboxFolderInContext:_ctx]);
      if (![lookupFolder isKindOfClass: [NSException class]])
	{
	  folderName = [NSString stringWithFormat: @"folder%@",
				 [self trashFolderNameInContext:_ctx]];
	  trashFolder = [lookupFolder lookupName: folderName
				      inContext: _ctx acquire: NO];
	}
      if (![trashFolder isNotNull])
	trashFolder = [NSException exceptionWithHTTPStatus: 404 /* not found */
				  reason: @"did not find Trash folder!"];
      [trashFolder retain];
    }

  return trashFolder;
}

/* WebDAV */

- (NSString *) davContentType
{
  return @"httpd/unix-directory";
}

- (BOOL) davIsCollection
{
  return YES;
}

- (NSException *) davCreateCollection: (NSString *) _name
			    inContext: (id) _ctx
{
  return [[self imap4Connection] createMailbox:_name atURL:[self imap4URL]];
}

- (NSString *) shortTitle
{
  NSString *s, *login, *host;
  NSRange r;

  s = [self nameInContainer];
  
  r = [s rangeOfString:@"@"];
  if (r.length > 0) {
    login = [s substringToIndex:r.location];
    host  = [s substringFromIndex:(r.location + r.length)];
  }
  else {
    login = nil;
    host  = s;
  }
  
  r = [host rangeOfString:@"."];
  if (r.length > 0)
    host = [host substringToIndex:r.location];
  
  if ([login length] == 0)
    return host;
  
  r = [login rangeOfString:@"."];
  if (r.length > 0)
    login = [login substringToIndex:r.location];
  
  return [NSString stringWithFormat:@"%@@%@", login, host];
}

- (NSString *) davDisplayName
{
  return [self shortTitle];
}

- (NSString *) sharedFolderName
{
  return sharedFolderName;
}

- (NSString *) otherUsersFolderName
{
  return otherUsersFolderName;
}

@end /* SOGoMailAccount */
