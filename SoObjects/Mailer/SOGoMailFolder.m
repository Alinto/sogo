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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSTask.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSURL+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSFileManager+Extensions.h>

#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>

#import <SoObjects/SOGo/SOGoPermissions.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/NSArray+Utilities.h>

#import "SOGoMailObject.h"
#import "SOGoMailAccount.h"
#import "SOGoMailManager.h"
#import "SOGoMailFolder.h"

static NSString *defaultUserID =  @"anyone";

#warning this could be detected from the capabilities
static SOGoIMAPAclStyle aclStyle = undefined;
static BOOL aclUsernamesAreQuoted = NO;
/* http://www.tools.ietf.org/wg/imapext/draft-ietf-imapext-acl/ */
static BOOL aclConformsToIMAPExt = NO;

static NSString *spoolFolder = nil;

@interface NGImap4Connection (PrivateMethods)

- (NSString *) imap4FolderNameForURL: (NSURL *) url;

@end

@implementation SOGoMailFolder

+ (void) initialize
{
  NSUserDefaults *ud;
  NSString *aclStyleStr;

  if (aclStyle == undefined)
  {
    ud = [NSUserDefaults standardUserDefaults];
    aclStyleStr = [ud stringForKey: @"SOGoIMAPAclStyle"];
    if ([aclStyleStr isEqualToString: @"rfc2086"])
      aclStyle = rfc2086;
    else
      aclStyle = rfc4314;

    aclUsernamesAreQuoted
      = [ud boolForKey: @"SOGoIMAPAclUsernamesAreQuoted"];
    aclConformsToIMAPExt
      = [ud boolForKey: @"SOGoIMAPAclConformsToIMAPExt"];
  }

  if (!spoolFolder)
  {
    spoolFolder = [ud stringForKey:@"SOGoMailSpoolPath"];
    if (![spoolFolder length])
      spoolFolder = @"/tmp/";
    [spoolFolder retain];

    NSLog(@"Note: using SOGo mail spool folder: %@", spoolFolder);
  }
}

+ (SOGoIMAPAclStyle) imapAclStyle
{
  return aclStyle;
}

- (void) _adjustOwner
{
  SOGoMailAccount *mailAccount;
  NSString *path, *folder;
  NSArray *names;

  mailAccount = [self mailAccountFolder];
  path = [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]];

  folder = [mailAccount sharedFolderName];
  if (folder && [path hasPrefix: folder])
    [self setOwner: @"nobody"];
  else
    {
      folder = [mailAccount otherUsersFolderName];
      if (folder && [path hasPrefix: folder])
	{
	  names = [path componentsSeparatedByString: @"/"];
	  if ([names count] > 1)
	    [self setOwner: [names objectAtIndex: 1]];
	  else
	    [self setOwner: @"nobody"];
	}
    }
}

- (id) initWithName: (NSString *) newName
	inContainer: (id) newContainer
{
  if ((self = [super initWithName: newName
		     inContainer: newContainer]))
    {
      [self _adjustOwner];
      mailboxACL = nil;
    }

  return self;
}

- (void) dealloc
{
  [filenames  release];
  [folderType release];
  [mailboxACL release];
  [super dealloc];
}

/* IMAP4 */

- (NSString *) relativeImap4Name
{
  return [nameInContainer substringFromIndex: 6];
}

- (NSString *) absoluteImap4Name
{
  NSString *name;

  name = [[self imap4URL] path];
  if (![name hasSuffix: @"/"])
    name = [name stringByAppendingString: @"/"];

  return name;
}

- (NSMutableString *) imap4URLString
{
  NSMutableString *urlString;

  urlString = [super imap4URLString];
  [urlString appendString: @"/"];

  return urlString;
}

/* listing the available folders */

- (NSArray *) toManyRelationshipKeys
{
  return [self subfolders];
}

- (NSArray *) subfolders
{
  return [[self imap4Connection] subfoldersForURL: [self imap4URL]];
}

- (BOOL) isSpecialFolder
{
  return NO;
}

- (NSArray *) allFolderPaths
{
  NSMutableArray *deepSubfolders;
  NSEnumerator *folderNames;
  NSArray *result;
  NSString *currentFolderName, *prefix;

  deepSubfolders = [NSMutableArray new];
  [deepSubfolders autorelease];

  prefix = [self absoluteImap4Name];

  result = [[self mailAccountFolder] allFolderPaths];
  folderNames = [result objectEnumerator];
  while ((currentFolderName = [folderNames nextObject]))
    if ([currentFolderName hasPrefix: prefix])
      [deepSubfolders addObject: currentFolderName];
  [deepSubfolders sortUsingSelector: @selector (compare:)];

  return deepSubfolders;
}

- (NSArray *) allFolderURLs
{
  NSURL *selfURL, *currentURL;
  NSMutableArray *subfoldersURL;
  NSEnumerator *subfolders;
  NSString *currentFolder;

  subfoldersURL = [NSMutableArray array];
  selfURL = [self imap4URL];
  subfolders = [[self allFolderPaths] objectEnumerator];
  currentFolder = [subfolders nextObject];
  while (currentFolder)
    {
      currentURL = [[NSURL alloc]
		     initWithScheme: [selfURL scheme]
		     host: [selfURL host]
		     path: currentFolder];
      [currentURL autorelease];
      [subfoldersURL addObject: currentURL];
      currentFolder = [subfolders nextObject];
    }

  return subfoldersURL;
}

- (NSString *) davContentType
{
  return @"httpd/unix-directory";
}

- (NSArray *) toOneRelationshipKeys
{
  NSArray *uids;
  unsigned int count, max;
  NSString *filename;

  if (!filenames)
    {
      filenames = [NSMutableArray new];
      uids = [self fetchUIDsMatchingQualifier: nil sortOrdering: @"DATE"];
      if (![uids isKindOfClass: [NSException class]])
	{
	  max = [uids count];
	  for (count = 0; count < max; count++)
	    {
	      filename = [NSString stringWithFormat: @"%@.mail",
				   [uids objectAtIndex: count]];
	      [filenames addObject: filename];
	    }
	}
    }

  return filenames;
}

/* messages */
- (NSException *) deleteUIDs: (NSArray *) uids
		   inContext: (id) localContext
{
  SOGoMailFolder *trashFolder;
  id result;
  NSException *error;
  NSString *folderName;
  NGImap4Client *client;

  trashFolder = [[self mailAccountFolder] trashFolderInContext: localContext];
  if ([trashFolder isNotNull])
    {
      if ([trashFolder isKindOfClass: [NSException class]])
	error = (NSException *) trashFolder;
      else
	{
	  client = [[self imap4Connection] client];
	  [imap4 selectFolder: [self imap4URL]];
	  folderName = [imap4 imap4FolderNameForURL: [trashFolder imap4URL]];

	  // If our Trash folder doesn't exist when we try to copy messages
	  // to it, we create it.
	  result = [[client status: folderName  flags: [NSArray arrayWithObject: @"UIDVALIDITY"]]
		     objectForKey: @"result"];
	  
	  if (![result boolValue])
	    result = [[self imap4Connection] createMailbox: folderName  atURL: [[self mailAccountFolder] imap4URL]];

	  if (!result || [result boolValue])
	    result = [client copyUids: uids toFolder: folderName];

	  if ([[result valueForKey: @"result"] boolValue])
	    {
	      result = [client storeFlags: [NSArray arrayWithObject: @"Deleted"]
			       forUIDs: uids addOrRemove: YES];
	      if ([[result valueForKey: @"result"] boolValue])
		{
		  [self markForExpunge];
		  [trashFolder flushMailCaches];
		  error = nil;
		}
	      else
		error
		  = [NSException exceptionWithHTTPStatus:500
				 reason: @"Could not mark UIDs as Deleted"];
	    }
	  else
	    error = [NSException exceptionWithHTTPStatus:500
				 reason: @"Could not copy UIDs"];
	}
    }
  else
    error = [NSException exceptionWithHTTPStatus: 500
			 reason: @"Did not find Trash folder!"];

  return error;
}

- (WOResponse *) archiveUIDs: (NSArray *) uids
  inContext: (id) localContext
{
  NSException *error;
  NSFileManager *fm;
  NSString *spoolPath, *fileName, *zipPath;
  NSDictionary *msgs;
  NSArray *messages;
  NSData *content, *zipContent;
  NSTask *zipTask;
  NSMutableArray *zipTaskArguments;
  WOResponse *response;
  int i;
  
  spoolPath = [self userSpoolFolderPath];
  if ( ![self ensureSpoolFolderPath] ) {
    error = [NSException exceptionWithHTTPStatus: 500 
      reason: @"spoolFolderPath doesn't exist"];
    return (WOResponse *)error;
  }
  
  zipPath = [[NSUserDefaults standardUserDefaults] stringForKey: @"SOGoZipPath"];
  if (![zipPath length])
    zipPath = [NSString stringWithString: @"/usr/bin/zip"];

  fm = [NSFileManager defaultManager];
  if ( ![fm fileExistsAtPath: zipPath] ) {
    error = [NSException exceptionWithHTTPStatus: 500 
      reason: @"zip not available"];
    return (WOResponse *)error;
  }
  
  zipTask = [[NSTask alloc] init];
  [zipTask setCurrentDirectoryPath: spoolPath];
  [zipTask setLaunchPath: zipPath];
  
  zipTaskArguments = [NSMutableArray arrayWithObjects: nil];
  [zipTaskArguments addObject: @"SavedMessages.zip"];

  msgs = (NSDictionary *)[self fetchUIDs: uids  
    parts: [NSArray arrayWithObject: @"RFC822"]];
  messages = [msgs objectForKey: @"fetch"];

  for (i = 0; i < [messages count]; i++) {
    content = [[messages objectAtIndex: i] objectForKey: @"message"];

    [content writeToFile: 
      [NSString stringWithFormat:@"%@/%d.eml", spoolPath, [uids objectAtIndex: i]] 
      atomically: YES];
    
    [zipTaskArguments addObject: 
      [NSString stringWithFormat:@"%d.eml", [uids objectAtIndex: i]]];
  }
  
  [zipTask setArguments: zipTaskArguments];
  [zipTask launch];
  [zipTask waitUntilExit];
  
  [zipTask release];
  
  zipContent = [[NSData alloc] initWithContentsOfFile: 
    [NSString stringWithFormat: @"%@/SavedMessages.zip", spoolPath]];
  
  for(i = 0; i < [zipTaskArguments count]; i++) {
    fileName = [zipTaskArguments objectAtIndex: i];
    [fm removeFileAtPath: 
      [NSString stringWithFormat: @"%@/%@", spoolPath, fileName] handler: nil];
  }
  
  response = [[WOResponse alloc] init];
  [response autorelease];
  [response setHeader: @"application/zip" forKey:@"content-type"];
  [response setHeader: @"attachment;filename=SavedMessages.zip" forKey: @"Content-Disposition"];
  [response setContent: zipContent];
  
  [zipContent release];
  
  return response;
}

- (WOResponse *) copyUIDs: (NSArray *) uids
		 toFolder: (NSString *) destinationFolder
		inContext: (id) localContext
{
  NSEnumerator *folders;
  NSString *currentFolderName;
  NSMutableString *imapDestinationFolder;
  NGImap4Client *client;
  id result;
  
  imapDestinationFolder = [NSMutableString string];
  folders = [[destinationFolder componentsSeparatedByString: @"/"] objectEnumerator];
  currentFolderName = [folders nextObject];
  while (currentFolderName)
  {
    if ([currentFolderName hasPrefix: @"folder"])
    {
      [imapDestinationFolder appendString: @"/"];
      [imapDestinationFolder appendString: [currentFolderName substringFromIndex: 6]];
    }
    currentFolderName = [folders nextObject];
  }

  client = [[self imap4Connection] client];
  [imap4 selectFolder: [self imap4URL]];
  
  // We make sure the destination IMAP folder exist, if not, we create it.
  result = [[client status: imapDestinationFolder  flags: [NSArray arrayWithObject: @"UIDVALIDITY"]]
	     objectForKey: @"result"];
  
  if (![result boolValue])
    result = [[self imap4Connection] createMailbox: imapDestinationFolder  atURL: [[self mailAccountFolder] imap4URL]];

  if (!result || [result boolValue])
    result = [client copyUids: uids toFolder: imapDestinationFolder];

  if ([[result valueForKey: @"result"] boolValue])
    result = nil;
  else
    result = [NSException exceptionWithHTTPStatus: 500 reason: @"Couldn't copy UIDs."];
  
  return result;
}

- (WOResponse *) moveUIDs: (NSArray *) uids
		 toFolder: (NSString *) destinationFolder
		inContext: (id) localContext
{
  id result;
  NGImap4Client *client;

	client = [[self imap4Connection] client];
  
  result = [self copyUIDs: uids toFolder: destinationFolder inContext: localContext];
  
  if ( ![result isNotNull] ) {
    result = [client storeFlags: [NSArray arrayWithObject: @"Deleted"]
	       forUIDs: uids addOrRemove: YES];
	  if ([[result valueForKey: @"result"] boolValue])
		{
		  [self markForExpunge];
      result = nil;
    }
  }

  return result;
}

- (NSArray *) fetchUIDsMatchingQualifier: (id) _q
			    sortOrdering: (id) _so
{
  /* seems to return an NSArray of NSNumber's */
  return [[self imap4Connection] fetchUIDsInURL: [self imap4URL]
				 qualifier: _q sortOrdering: _so];
}

- (NSArray *) fetchUIDs: (NSArray *) _uids
		  parts: (NSArray *) _parts
{
  return [[self imap4Connection] fetchUIDs: _uids inURL: [self imap4URL]
				 parts: _parts];
}

- (NSException *) postData: (NSData *) _data
		     flags: (id) _flags
{
  // We check for the existence of the IMAP folder (likely to be the
  // Sent mailbox) prior to appending messages to it.
  if ([[self imap4Connection] doesMailboxExistAtURL: [self imap4URL]] ||
      ![[self imap4Connection] createMailbox: [self relativeImap4Name]  atURL: [[self mailAccountFolder] imap4URL]])
    return [[self imap4Connection] postData: _data flags: _flags
				   toFolderURL: [self imap4URL]];
  
  return [NSException exceptionWithHTTPStatus: 502 /* Bad Gateway */
		      reason: [NSString stringWithFormat: @"%@ is not an IMAP4 folder", [self relativeImap4Name]]];
}

- (NSException *) expunge
{
  return [[self imap4Connection] expungeAtURL: [self imap4URL]];
}

- (void) markForExpunge
{
  NSUserDefaults *ud;
  NSMutableDictionary *mailSettings;
  NSString *urlString;

  ud = [[context activeUser] userSettings];
  mailSettings = [ud objectForKey: @"Mail"];
  if (!mailSettings)
    {
      mailSettings = [NSMutableDictionary dictionaryWithCapacity: 1];
      [ud setObject: mailSettings forKey: @"Mail"];
    }

  urlString = [self imap4URLString];
  if (![[mailSettings objectForKey: @"folderForExpunge"]
	 isEqualToString: urlString])
    {
      [mailSettings setObject: [self imap4URLString]
		    forKey: @"folderForExpunge"];
      [ud synchronize];
    }
}

- (void) expungeLastMarkedFolder
{
  NSUserDefaults *ud;
  NSMutableDictionary *mailSettings;
  NSString *expungeURL;
  NSURL *folderURL;

  ud = [[context activeUser] userSettings];
  mailSettings = [ud objectForKey: @"Mail"];
  if (mailSettings)
    {
      expungeURL = [mailSettings objectForKey: @"folderForExpunge"];
      if (expungeURL
	  && ![expungeURL isEqualToString: [self imap4URLString]])
	{
	  folderURL = [NSURL URLWithString: expungeURL];
	  if (![[self imap4Connection] expungeAtURL: folderURL])
	    {
	      [mailSettings removeObjectForKey: @"folderForExpunge"];
	      [ud synchronize];
	    }
	}
    }
}

/* flags */

- (NSException *) addFlagsToAllMessages: (id) _f
{
  return [[self imap4Connection] addFlags:_f 
				 toAllMessagesInURL: [self imap4URL]];
}

/* name lookup */

- (id) lookupName: (NSString *) _key
	inContext: (id)_ctx
	  acquire: (BOOL) _acquire
{
  NSString *folderName, *className;
  SOGoMailAccount *mailAccount;
  id obj;

  if ([_key hasPrefix: @"folder"])
    {
      mailAccount = [self mailAccountFolder];
      folderName = [NSString stringWithFormat: @"%@/%@",
			     [self traversalFromMailAccount],
			     [_key substringFromIndex: 6]];
      if ([folderName
	    isEqualToString: [mailAccount sentFolderNameInContext: _ctx]])
	className = @"SOGoSentFolder";
      else if ([folderName isEqualToString:
			     [mailAccount draftsFolderNameInContext: _ctx]])
	className = @"SOGoDraftsFolder";
      else if ([folderName isEqualToString:
			     [mailAccount trashFolderNameInContext: _ctx]])
	className = @"SOGoTrashFolder";
/*       else if ([folderName isEqualToString:
	 [mailAccount sieveFolderNameInContext: _ctx]])
	 obj = [self lookupFiltersFolder: _key inContext: _ctx]; */
      else
	className = @"SOGoMailFolder";

      obj = [NSClassFromString (className)
			       objectWithName: _key inContainer: self];
    }
  else
    {
      // We automatically create mailboxes that don't exist but that we're
      // trying to open. This shouldn't happen unless a mailbox has been
      // deleted "behind our back" or if we're trying to open a special
      // mailbox that doesn't yet exist.
      if ([[self imap4Connection] doesMailboxExistAtURL: [self imap4URL]] ||
	  ![[self imap4Connection] createMailbox: [self relativeImap4Name]  atURL: [[self mailAccountFolder] imap4URL]])
	{
	  if (isdigit ([_key characterAtIndex: 0]))
	    obj = [SOGoMailObject objectWithName: _key inContainer: self];
	  else
	    obj = [super lookupName: _key inContext: _ctx acquire: NO];
	}
      else
	obj = nil;
    }

  if (!obj && _acquire)
    obj = [NSException exceptionWithHTTPStatus: 404 /* Not Found */];

  return obj;
}

/* WebDAV */

- (BOOL) davIsCollection
{
  return YES;
}

- (NSException *) davCreateCollection: (NSString *) _name
			    inContext: (id) _ctx
{
  return [[self imap4Connection] createMailbox:_name atURL:[self imap4URL]];
}

- (NSException *) delete
{
  /* Note: overrides SOGoObject -delete */
  return [[self imap4Connection] deleteMailboxAtURL:[self imap4URL]];
}

- (NSException *) davMoveToTargetObject: (id) _target
				newName: (NSString *) _name
			      inContext: (id)_ctx
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
// -  destImapURL = [NSURL URLWithString:[[destImapURL path] 
// -				       stringByAppendingPathComponent:_name]
// -		       relativeToURL:destImapURL];
  destImapURL = [NSURL URLWithString: _name
		       relativeToURL: destImapURL];
  
  [self logWithFormat:@"TODO: should move collection as '%@' to: %@",
	[[self imap4URL] absoluteString], 
	[destImapURL absoluteString]];
  
  return [[self imap4Connection] moveMailboxAtURL:[self imap4URL] 
				 toURL:destImapURL];
}

- (NSException *) davCopyToTargetObject: (id) _target
				newName: (NSString *) _name
			      inContext: (id) _ctx
{
  [self logWithFormat:@"TODO: should copy collection as '%@' to: %@",
	_name, _target];
  return [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
		      reason:@"not implemented"];
}

/* folder type */
- (NSString *) folderType
{
  return @"Mail";
}

- (NSString *) outlookFolderClass
{
  // TODO: detect Trash/Sent/Drafts folders
  SOGoMailAccount *account;
  NSString *name;

  if (!folderType)
    {
      account = [self mailAccountFolder];
      name = [self traversalFromMailAccount];

      if ([name isEqualToString: [account trashFolderNameInContext: nil]])
	folderType = @"IPF.Trash";
      else if ([name
		 isEqualToString: [account inboxFolderNameInContext: nil]])
	folderType = @"IPF.Inbox";
      else if ([name
		 isEqualToString: [account sentFolderNameInContext: nil]])
	folderType = @"IPF.Sent";
      else
	folderType = @"IPF.Folder";
    }
  
  return folderType;
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
	case 'r':
	  [SOGoAcls addObjectUniquely: SOGoRole_ObjectViewer];
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
	case 'c':
	case 'k':
	  [SOGoAcls addObjectUniquely: SOGoRole_FolderCreator];
	  break;
	case 'x':
	  [SOGoAcls addObjectUniquely: SOGoRole_FolderEraser];
	  break;
	case 'd':
	case 't':
	  [SOGoAcls addObjectUniquely: SOGoRole_ObjectEraser];
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

- (char) _rfc2086StyleRight: (NSString *) sogoRight
{
  char character;

  if ([sogoRight isEqualToString: SOGoRole_FolderCreator])
    character = 'c';
  else if ([sogoRight isEqualToString: SOGoRole_ObjectEraser])
    character = 'd';
  else
    character = 0;

  return character;
}

- (char) _rfc4314StyleRight: (NSString *) sogoRight
{
  char character;

  if ([sogoRight isEqualToString: SOGoRole_FolderCreator])
    character = 'k';
  else if ([sogoRight isEqualToString: SOGoRole_FolderEraser])
    character = 'x';
  else if ([sogoRight isEqualToString: SOGoRole_ObjectEraser])
    character = 't';
  else if ([sogoRight isEqualToString: SOGoMailRole_Expunger])
    character = 'e';
  else
    character = 0;

  return character;
}

- (NSString *) _sogoAclsToImapAcls: (NSArray *) sogoAcls
{
  NSMutableString *imapAcls;
  NSEnumerator *acls;
  NSString *currentAcl;
  char character;

  imapAcls = [NSMutableString string];
  acls = [sogoAcls objectEnumerator];
  while ((currentAcl = [acls nextObject]))
    {
      if ([currentAcl isEqualToString: SOGoRole_ObjectViewer])
	{
	  [imapAcls appendFormat: @"lr"];
	  character = 0;
	}
      else if ([currentAcl isEqualToString: SOGoMailRole_SeenKeeper])
	character = 's';
      else if ([currentAcl isEqualToString: SOGoMailRole_Writer])
	character = 'w';
      else if ([currentAcl isEqualToString: SOGoRole_ObjectCreator])
	character = 'i';
      else if ([currentAcl isEqualToString: SOGoMailRole_Poster])
	character = 'p';
      else if ([currentAcl isEqualToString: SOGoMailRole_Administrator])
	character = 'a';
      else
	{
	  if (aclStyle == rfc2086)
	    character = [self _rfc2086StyleRight: currentAcl];
	  else if (aclStyle == rfc4314)
	    character = [self _rfc4314StyleRight: currentAcl];
	  else
	    character = 0;
	}

      if (character)
	[imapAcls appendFormat: @"%c", character];
    }

  return imapAcls;
}

- (void) _unquoteACLUsernames
{
  NSMutableDictionary *newIMAPAcls;
  NSEnumerator *usernames;
  NSString *username, *unquoted;

  newIMAPAcls = [NSMutableDictionary new];

  usernames = [[mailboxACL allKeys] objectEnumerator];
  while ((username = [usernames nextObject]))
    {
      unquoted = [username substringFromRange:
			     NSMakeRange(1, [username length] - 2)];
      [newIMAPAcls setObject: [mailboxACL objectForKey: username]
		   forKey: unquoted];
    }
  [mailboxACL release];
  mailboxACL = newIMAPAcls;
}

- (void) _removeIMAPExtUsernames
{
  NSMutableDictionary *newIMAPAcls;
  NSEnumerator *usernames;
  NSString *username;

  newIMAPAcls = [NSMutableDictionary new];

  usernames = [[mailboxACL allKeys] objectEnumerator];
  while ((username = [usernames nextObject]))
    if (!([username isEqualToString: @"administrators"]
	  || [username isEqualToString: @"owner"]
	  || [username isEqualToString: @"anonymous"]
	  || [username isEqualToString: @"authuser"]))
      [newIMAPAcls setObject: [mailboxACL objectForKey: username]
		   forKey: username];
  [mailboxACL release];
  mailboxACL = newIMAPAcls;
}

- (void) _readMailboxACL
{
  [mailboxACL release];

  mailboxACL = [[self imap4Connection] aclForMailboxAtURL: [self imap4URL]];
  [mailboxACL retain];

  if (aclUsernamesAreQuoted)
    [self _unquoteACLUsernames];
  if (aclConformsToIMAPExt)
    [self _removeIMAPExtUsernames];
}

- (NSArray *) subscriptionRoles
{
  return [NSArray arrayWithObjects: SOGoRole_ObjectViewer,
		  SOGoMailRole_SeenKeeper, SOGoMailRole_Writer,
		  SOGoRole_ObjectCreator, SOGoMailRole_Poster,
		  SOGoRole_FolderCreator, SOGoRole_FolderEraser,
		  SOGoRole_ObjectEraser, SOGoMailRole_Expunger,
		  SOGoMailRole_Administrator, nil];
}

- (NSArray *) aclUsers
{
  NSArray *users;

  if (!mailboxACL)
    [self _readMailboxACL];

  if ([mailboxACL isKindOfClass: [NSDictionary class]])
    users = [mailboxACL allKeys];
  else
    users = nil;

  return users;
}

- (NSMutableArray *) _sharesACLs
{
  NSMutableArray *acls;
  SOGoMailAccount *mailAccount;
  NSString *path, *folder;
//   NSArray *names;
//   unsigned int count;

  acls = [NSMutableArray array];

  mailAccount = [self mailAccountFolder];
  path = [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]];
//   names = [path componentsSeparatedByString: @"/"];
//   count = [names count];

  folder = [mailAccount sharedFolderName];
  if (folder && [path hasPrefix: folder])
    [acls addObject: SOGoRole_ObjectViewer];
  else
    {
      folder = [mailAccount otherUsersFolderName];
      if (folder && [path hasPrefix: folder])
	[acls addObject: SOGoRole_ObjectViewer];
      else
	[acls addObject: SoRole_Owner];
    }

  return acls;
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSMutableArray *acls;
  NSString *userAcls;

  acls = [self _sharesACLs];

  if (!mailboxACL)
    [self _readMailboxACL];

  if ([mailboxACL isKindOfClass: [NSDictionary class]])
    {
      userAcls = [mailboxACL objectForKey: uid];
      if (!([userAcls length] || [uid isEqualToString: defaultUserID]))
	userAcls = [mailboxACL objectForKey: defaultUserID];
      if ([userAcls length])
	[acls addObjectsFromArray: [self _imapAclsToSOGoAcls: userAcls]];
    }

  return acls;
}

- (void) removeAclsForUsers: (NSArray *) users
{
  NSEnumerator *uids;
  NSString *currentUID, *folderName;
  NGImap4Client *client;

  folderName = [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]];
  client = [imap4 client];

  uids = [users objectEnumerator];
  while ((currentUID = [uids nextObject]))
    [client deleteACL: folderName uid: currentUID];
  [mailboxACL release];
  mailboxACL = nil;
}

- (void) setRoles: (NSArray *) roles
	  forUser: (NSString *) uid
{
  NSString *acls, *folderName;

  acls = [self _sogoAclsToImapAcls: roles];
  folderName = [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]];
  [[imap4 client] setACL: folderName rights: acls uid: uid];

  [mailboxACL release];
  mailboxACL = nil;
}

- (NSString *) defaultUserID
{
  return defaultUserID;
}

- (NSString *) otherUsersPathToFolder
{
  NSString *userPath, *selfPath, *otherUsers, *sharedFolders;
  SOGoMailAccount *account;

  account = [self mailAccountFolder];
  otherUsers = [account otherUsersFolderName];
  sharedFolders = [account sharedFolderName];

  selfPath = [[self imap4URL] path];
  if ((otherUsers
       && [selfPath hasPrefix:
		      [NSString stringWithFormat: @"/%@", otherUsers]])
      || (sharedFolders
	  && [selfPath hasPrefix:
			 [NSString stringWithFormat: @"/%@", sharedFolders]]))
    userPath = selfPath;
  else
    {
      if (otherUsers)
	userPath = [NSString stringWithFormat: @"/%@/%@%@",
			     [otherUsers stringByEscapingURL],
			     owner, selfPath];
      else
	userPath = nil;
    }

  return userPath;
}

- (NSString *) httpURLForAdvisoryToUser: (NSString *) uid
{
  SOGoUser *user;
  NSString *otherUsersPath, *url;
  SOGoMailAccount *thisAccount;
  NSDictionary *mailAccount;

  user = [SOGoUser userWithLogin: uid roles: nil];
  otherUsersPath = [self otherUsersPathToFolder];
  if (otherUsersPath)
    {
      thisAccount = [self mailAccountFolder];
      mailAccount = [[user mailAccounts] objectAtIndex: 0];
      url = [NSString stringWithFormat: @"%@/%@%@",
		      [self soURLToBaseContainerForUser: uid],
		      [mailAccount objectForKey: @"name"],
		      otherUsersPath];
    }
  else
    url = nil;

  return url;
}

- (NSString *) resourceURLForAdvisoryToUser: (NSString *) uid
{
  NSURL *selfURL, *userURL;

  selfURL = [self imap4URL];
  userURL = [[NSURL alloc] initWithScheme: [selfURL scheme]
			   host: [selfURL host]
			   path: [self otherUsersPathToFolder]];
  [userURL autorelease];

  return [userURL absoluteString];
}

- (NSString *) userSpoolFolderPath
{
  NSString *login;

  login = [[context activeUser] login];

  return [NSString stringWithFormat: @"%@/%@",
		   spoolFolder, login];
}

- (BOOL) ensureSpoolFolderPath
{
  NSFileManager *fm;

  fm = [NSFileManager defaultManager];
  
  return ([fm createDirectoriesAtPath: [self userSpoolFolderPath] attributes:nil]);
}

@end /* SOGoMailFolder */

@implementation SOGoSpecialMailFolder

- (BOOL) isSpecialFolder
{
  return YES;
}

@end
