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

#import <Foundation/NSArray.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoHTTPAuthenticator.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGImap4/NGImap4Connection.h>

#import <SoObjects/SOGo/SOGoUser.h>

#import "SOGoMailFolder.h"
#import "SOGoMailManager.h"
#import "SOGoDraftsFolder.h"

#import "SOGoMailAccount.h"

@implementation SOGoMailAccount

static NSArray *rootFolderNames = nil;
static NSString *inboxFolderName = @"INBOX";
static NSString *draftsFolderName = @"Drafts";
static NSString *sieveFolderName = @"Filters";
static NSString *sentFolderName = nil;
static NSString *trashFolderName = nil;
static NSString *sharedFolderName = @""; // TODO: add English default
static NSString *otherUsersFolderName = @""; // TODO: add English default
static BOOL useAltNamespace = NO;

+ (void) initialize
{
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
  if ([ud boolForKey: @"SOGoEnableSieveFolder"])
    rootFolderNames = [[NSArray alloc] initWithObjects:
				        draftsFolderName, 
				        sieveFolderName, 
				      nil];
  else
    rootFolderNames = [[NSArray alloc] initWithObjects:
				        draftsFolderName, 
				      nil];
}

- (id) init
{
  if ((self = [super init]))
    {
      inboxFolder = nil;
      draftsFolder = nil;
      sentFolder = nil;
      trashFolder = nil;
    }

  return self;
}

- (void) dealloc
{
  [inboxFolder release];
  [draftsFolder release];
  [sentFolder release];
  [trashFolder release];
  [super dealloc];  
}

/* shared accounts */

- (BOOL) isSharedAccount
{
  NSString *s;
  NSRange  r;
  
  s = [self nameInContainer];
  r = [s rangeOfString:@"@"];
  if (r.length == 0) /* regular HTTP logins are never a shared mailbox */
    return NO;
  
  s = [s substringToIndex:r.location];
  return [s rangeOfString:@".-."].length > 0 ? YES : NO;
}

- (NSString *) sharedAccountName
{
  return nil;
}

/* listing the available folders */

- (NSArray *) additionalRootFolderNames
{
  return rootFolderNames;
}

- (BOOL) isInDraftsFolder
{
  return NO;
}

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *folders;
  NSArray *imapFolders, *additionalFolders;

  folders = [NSMutableArray array];

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

/* hierarchy */

- (SOGoMailAccount *) mailAccountFolder
{
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

- (BOOL) useSSL
{
  return NO;
}

- (NSString *) imap4LoginFromHTTP
{
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

- (id) lookupFolder: (NSString *) _key
       ofClassNamed: (NSString *) _cn
	  inContext: (id) _cx
{
  Class clazz;
  SOGoMailFolder *folder;

  if ((clazz = NSClassFromString(_cn)) == Nil)
    {
      [self logWithFormat:@"ERROR: did not find class '%@' for key: '%@'", 
	    _cn, _key];
      return [NSException exceptionWithHTTPStatus:500 /* server error */
			  reason:@"did not find mail folder class!"];
    }

  folder = [clazz objectWithName: _key inContainer: self];

  return folder;
}

- (id) lookupImap4Folder: (NSString *) _key
	       inContext: (id) _cx
{
  NSString *s;

  s = [_key isEqualToString: [self trashFolderNameInContext:_cx]]
    ? @"SOGoTrashFolder" : @"SOGoMailFolder";
  
  return [self lookupFolder:_key ofClassNamed:s inContext:_cx];
}

- (id) lookupDraftsFolder: (NSString *) _key
		inContext: (id) _ctx
{
  return [self lookupFolder: _key ofClassNamed: @"SOGoDraftsFolder" 
	       inContext: _ctx];
}

- (id) lookupFiltersFolder: (NSString *) _key inContext: (id) _ctx
{
  return [self lookupFolder:_key ofClassNamed:@"SOGoSieveScriptsFolder" 
	       inContext:_ctx];
}

- (id) lookupName: (NSString *) _key
	inContext: (id)_ctx
	  acquire: (BOOL) _flag
{
  id obj;

  if ([_key hasPrefix: @"folder"])
    {
  // TODO: those should be product.plist bindings? (can't be class bindings
  //       though because they are 'per-account')
      if ([_key isEqualToString: [self draftsFolderNameInContext: _ctx]])
	obj = [self lookupDraftsFolder: _key inContext: _ctx];
      else if ([_key isEqualToString: [self sieveFolderNameInContext: _ctx]])
	obj = [self lookupFiltersFolder: _key inContext: _ctx];
      else
	obj = [self lookupImap4Folder: _key inContext: _ctx];
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
  /* cannot be changed in Cyrus ? */
  return [NSString stringWithFormat: @"folder%@", inboxFolderName];
}

- (NSString *) _userFolderNameWithPurpose: (NSString *) purpose
{
  NSUserDefaults *ud;
  NSMutableDictionary *mailSettings;
  NSString *folderName;

  folderName = nil;
  ud = [[context activeUser] userSettings];
  mailSettings = [ud objectForKey: @"Mail"];
  if (mailSettings)
    folderName
      = [mailSettings objectForKey: [NSString stringWithFormat: @"%@Folder",
					      purpose]];

  return folderName;
}

- (NSString *) draftsFolderNameInContext: (id) _ctx
{
  NSString *folderName;

  folderName = [self _userFolderNameWithPurpose: @"Drafts"];
  if (!folderName)
    folderName = draftsFolderName;

  return [NSString stringWithFormat: @"folder%@", folderName];
}

- (NSString *) sieveFolderNameInContext: (id) _ctx
{
  return [NSString stringWithFormat: @"folder%@", sieveFolderName];
}

- (NSString *) sentFolderNameInContext: (id)_ctx
{
  NSString *folderName;

  folderName = [self _userFolderNameWithPurpose: @"Sent"];
  if (!folderName)
    folderName = sentFolderName;

  return [NSString stringWithFormat: @"folder%@", folderName];
}

- (NSString *) trashFolderNameInContext: (id)_ctx
{
  NSString *folderName;

  folderName = [self _userFolderNameWithPurpose: @"Trash"];
  if (!folderName)
    folderName = trashFolderName;

  return [NSString stringWithFormat: @"folder%@", folderName];
}

- (SOGoMailFolder *) inboxFolderInContext: (id) _ctx
{
  // TODO: use some profile to determine real location, use a -traverse lookup
  if (!inboxFolder)
    {
      inboxFolder = [self lookupName: [self inboxFolderNameInContext: _ctx]
			  inContext: _ctx acquire: NO];
      [inboxFolder retain];
    }

  return inboxFolder;
}

- (SOGoDraftsFolder *) draftsFolderInContext: (id) _ctx
{
  SOGoMailFolder *lookupFolder;
  // TODO: use some profile to determine real location, use a -traverse lookup

  if (!draftsFolder)
    {
      lookupFolder = (useAltNamespace
		      ? (id) self
		      : [self inboxFolderInContext:_ctx]);
      if (![lookupFolder isKindOfClass: [NSException class]])
	draftsFolder
	  = [lookupFolder lookupName: [self draftsFolderNameInContext:_ctx]
			  inContext: _ctx acquire: NO];
      if (![draftsFolder isNotNull])
	draftsFolder = [NSException exceptionWithHTTPStatus: 404 /* not found */
				    reason: @"did not find Drafts folder!"];
      [draftsFolder retain];
    }

  return draftsFolder;
}

- (SOGoMailFolder *) sentFolderInContext: (id) _ctx
{
  SOGoMailFolder *lookupFolder;
  // TODO: use some profile to determine real location, use a -traverse lookup

  if (!sentFolder)
    {
      lookupFolder = (useAltNamespace
		      ? (id) self
		      : [self inboxFolderInContext:_ctx]);
      if (![lookupFolder isKindOfClass: [NSException class]])
	sentFolder = [lookupFolder lookupName: [self sentFolderNameInContext:_ctx]
				   inContext: _ctx acquire: NO];
      if (![sentFolder isNotNull])
	sentFolder = [NSException exceptionWithHTTPStatus: 404 /* not found */
				  reason: @"did not find Sent folder!"];
      [sentFolder retain];
    }

  return sentFolder;
}

- (SOGoMailFolder *) trashFolderInContext: (id) _ctx
{
  SOGoMailFolder *lookupFolder;
  // TODO: use some profile to determine real location, use a -traverse lookup

  if (!trashFolder)
    {
      lookupFolder = (useAltNamespace
		      ? (id) self
		      : [self inboxFolderInContext:_ctx]);
      if (![lookupFolder isKindOfClass: [NSException class]])
	trashFolder = [lookupFolder lookupName: [self trashFolderNameInContext: _ctx]
 				    inContext: _ctx acquire: NO];
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
