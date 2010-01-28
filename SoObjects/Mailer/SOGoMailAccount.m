/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2007-2009 Inverse inc.

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
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoHTTPAuthenticator.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGStreams/NGInternetSocketAddress.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Context.h>
#import <NGImap4/NGSieveClient.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>

#import "SOGoDraftsFolder.h"
#import "SOGoMailFolder.h"
#import "SOGoMailManager.h"
#import "SOGoMailNamespace.h"
#import "SOGoSentFolder.h"
#import "SOGoTrashFolder.h"

#import "SOGoMailAccount.h"

@implementation SOGoMailAccount

static NSString *inboxFolderName = @"INBOX";
static NSString *sieveScriptName = @"sogo";

- (id) init
{
  if ((self = [super init]))
    {
      inboxFolder = nil;
      draftsFolder = nil;
      sentFolder = nil;
      trashFolder = nil;
      accountName = nil;
      imapAclStyle = undefined;
    }

  return self;
}

- (void) dealloc
{
  [inboxFolder release];
  [draftsFolder release];
  [sentFolder release];
  [trashFolder release];
  [accountName release];
  [super dealloc];  
}

- (void) setAccountName: (NSString *) newAccountName
{
  ASSIGN (accountName, newAccountName);
}

/* listing the available folders */

- (BOOL) isInDraftsFolder
{
  return NO;
}

- (void) _appendNamespace: (NSArray *) namespace
                toFolders: (NSMutableArray *) folders
{
  NSString *newFolder;
  NSDictionary *currentPart;
  int count, max;

  max = [namespace count];
  for (count = 0; count < max; count++)
    {
      currentPart = [namespace objectAtIndex: count];
      newFolder
        = [[currentPart objectForKey: @"prefix"] substringFromIndex: 1];
      if ([newFolder length])
        [folders addObject: newFolder];
    }
}

/* namespaces */

- (void) _appendNamespaces: (NSMutableArray *) folders
{
  NSDictionary *namespaceDict;
  NSArray *namespace;
  NGImap4Client *client;

  client = [[self imap4Connection] client];
  namespaceDict = [client namespace];
  namespace = [namespaceDict objectForKey: @"personal"];
  if (namespace)
    [self _appendNamespace: namespace toFolders: folders];
  namespace = [namespaceDict objectForKey: @"other users"];
  if (namespace)
    [self _appendNamespace: namespace toFolders: folders];
  namespace = [namespaceDict objectForKey: @"shared"];
  if (namespace)
    [self _appendNamespace: namespace toFolders: folders];
}

- (NSArray *) _namespacesWithKey: (NSString *) nsKey
{
  NSDictionary *namespaceDict;
  NSArray *namespace;
  NGImap4Client *client;
  NSMutableArray *folders;

  client = [[self imap4Connection] client];
  namespaceDict = [client namespace];
  namespace = [namespaceDict objectForKey: nsKey];
  if (namespace)
    {
      folders = [NSMutableArray array];
      [self _appendNamespace: namespace toFolders: folders];
    }
  else
    folders = nil;

  return folders;
}

- (NSArray *) otherUsersFolderNamespaces
{
  return [self _namespacesWithKey: @"other users"];
}

- (NSArray *) sharedFolderNamespaces
{
  return [self _namespacesWithKey: @"shared"];
}

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *folders;
  NSArray *imapFolders;

  imapFolders = [[self imap4Connection] subfoldersForURL: [self imap4URL]];
  folders = [imapFolders mutableCopy];
  [folders autorelease];
  [folders addObjectUniquely: [self draftsFolderNameInContext: nil]];
  [self _appendNamespaces: folders];

  return [[folders stringsWithFormat: @"folder%@"]
           resultsOfSelector: @selector (asCSSIdentifier)];
}

- (SOGoIMAPAclStyle) imapAclStyle
{
  SOGoDomainDefaults *dd;

  if (imapAclStyle == undefined)
    {
      dd = [[context activeUser] domainDefaults];
      if ([[dd imapAclStyle] isEqualToString: @"rfc2086"])
        imapAclStyle = rfc2086;
      else
        imapAclStyle = rfc4314;
    }

  return imapAclStyle;
}

- (BOOL) imapAclConformsToIMAPExt
{
  SOGoDomainDefaults *dd;

  dd = [[context activeUser] domainDefaults];

  return [dd imapAclConformsToIMAPExt];
}

- (BOOL) supportsQuotas
{
  NGImap4Client *imapClient;
  NSArray *capability;

  imapClient = [[self imap4Connection] client];
  capability = [[imapClient capability] objectForKey: @"capability"];

  return [capability containsObject: @"quota"];
}

- (BOOL) updateFilters
{
  NSMutableString *header, *script;
  NGInternetSocketAddress *address;
  NSDictionary *result, *values;
  SOGoUserDefaults *ud;
  SOGoDomainDefaults *dd;
  NGSieveClient *client;
  NSString *v, *password;
  BOOL b;

  dd = [[context activeUser] domainDefaults];
  if (!([dd vacationEnabled] || [dd forwardEnabled]))
    return YES;

  ud = [[context activeUser] userDefaults];
  b = NO;

  header = [NSMutableString stringWithString: @"require ["];
  script = [NSMutableString string];

  // Right now, we handle Sieve filters here and only for vacation
  // and forwards. Traditional filters support (for fileinto, for
  // example) will be added later.
  values = [ud vacationOptions];

  // We handle vacation messages.
  // See http://ietfreport.isoc.org/idref/draft-ietf-sieve-vacation/
  if (values && [[values objectForKey: @"enabled"] boolValue])
    {
      NSArray *addresses;
      NSString *text;
      BOOL ignore;
      int days, i;
            
      days = [[values objectForKey: @"daysBetweenResponse"] intValue];
      addresses = [values objectForKey: @"autoReplyEmailAddresses"];
      ignore = [[values objectForKey: @"ignoreLists"] boolValue];
      text = [values objectForKey: @"autoReplyText"];
      b = YES;

      if (days == 0)
	days = 7;

      [header appendString: @"\"vacation\""];
      
      // Skip mailing lists
      if (ignore)
	[script appendString: @"if allof ( not exists [\"list-help\", \"list-unsubscribe\", \"list-subscribe\", \"list-owner\", \"list-post\", \"list-archive\", \"list-id\", \"Mailing-List\"], not header :comparator \"i;ascii-casemap\" :is \"Precedence\" [\"list\", \"bulk\", \"junk\"], not header :comparator \"i;ascii-casemap\" :matches \"To\" \"Multiple recipients of*\" ) {"];
      
      [script appendFormat: @"vacation :days %d :addresses [", days];

      for (i = 0; i < [addresses count]; i++)
	{
	  [script appendFormat: @"\"%@\"", [addresses objectAtIndex: i]];
	  
	  if (i == [addresses count]-1)
	    [script appendString: @"] "];
	  else
	    [script appendString: @", "];
	}
      
      [script appendFormat: @"text:\r\n%@\r\n.\r\n;\r\n", text];
      
      if (ignore)
	[script appendString: @"}\r\n"];
    }


  // We handle mail forward
  values = [ud forwardOptions];

  if (values && [[values objectForKey: @"enabled"] boolValue])
    {
      b = YES;
      
      v = [values objectForKey: @"forwardAddress"];

      if (v && [v length] > 0)
	[script appendFormat: @"redirect \"%@\";\r\n", v];

      if ([[values objectForKey: @"keepCopy"] boolValue])
	[script appendString: @"keep;\r\n"];
    }
  
  if ([header compare: @"require ["] != NSOrderedSame)
    {
      [header appendString: @"];\r\n"];
      [script insertString: header  atIndex: 0];
    }

  // We connect to our Sieve server and upload the script
  address =  [NGInternetSocketAddress addressWithPort: 2000
				      onHost: [[self imap4URL] host]];

  client = [NGSieveClient clientWithAddress: address];
  
  if (!client) {
    [self errorWithFormat: @"Sieve connection failed on %@", [address description]];
    return NO;
  }
  
  password = [self imap4PasswordRenewed: NO];
  if (!password) {
    [client closeConnection];
    return NO;
  }
  result = [client login: [[self imap4URL] user]  password: password];
  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat: @"failure. Attempting with a renewed password."];
    password = [self imap4PasswordRenewed: NO];
    result = [client login: [[self imap4URL] user]  password: password];
  }
  
  if (![[result valueForKey:@"result"] boolValue]) {
    [self errorWithFormat: @"Could not login '%@' (%@) on Sieve server: %@: %@",
	  [[self imap4URL] user], password, client, result];
    [client closeConnection];
    return NO;
  }

  // We delete the existing Sieve script
  result = [client deleteScript: sieveScriptName];
  
  if (![[result valueForKey:@"result"] boolValue]) {
    [self logWithFormat:@"WARNING: Could not delete Sieve script - continuing...: %@", result];
  }

  // We put and activate the script only if we actually have a script
  // that does something...
  if (b)
    {
      result = [client putScript: sieveScriptName  script: script];
      
      if (![[result valueForKey:@"result"] boolValue]) {
	[self errorWithFormat:@"Could not upload Sieve script: %@", result];
	[client closeConnection];	
	return NO;
      }
      
      result = [client setActiveScript: sieveScriptName];
      if (![[result valueForKey:@"result"] boolValue]) {
	[self errorWithFormat:@"Could not enable Sieve script: %@", result];
	[client closeConnection];
	return NO;
      }
  }

  return YES;
}


/* hierarchy */

- (SOGoMailAccount *) mailAccountFolder
{
  return self;
}

- (NSArray *) _allFoldersFromNS: (NSString *) namespace
                 subscribedOnly: (BOOL) subscribedOnly
{
  NSArray *folders;
  NSURL *nsURL;
  NSString *baseURLString, *urlString;

  baseURLString = [[self imap4URL] absoluteString];
  urlString = [NSString stringWithFormat: @"%@%@/", baseURLString, [namespace stringByEscapingURL]];
  nsURL = [NSURL URLWithString: urlString];
  folders = [[self imap4Connection] allFoldersForURL: nsURL
                               onlySubscribedFolders: subscribedOnly];

  return folders;
}

- (NSArray *) allFolderPaths
{
  NSMutableArray *folderPaths, *namespaces;
  NSArray *folders, *mainFolders;
  SOGoUserDefaults *ud;
  BOOL subscribedOnly;
  int count, max;

  ud = [[context activeUser] userDefaults];
  subscribedOnly = [ud mailShowSubscribedFoldersOnly];

  mainFolders = [[NSArray arrayWithObjects:
			    [self inboxFolderNameInContext: context],
			  [self draftsFolderNameInContext: context],
			  [self sentFolderNameInContext: context],
			  [self trashFolderNameInContext: context],
			  nil] stringsWithFormat: @"/%@"];
  folders = [[self imap4Connection] allFoldersForURL: [self imap4URL]
                               onlySubscribedFolders: subscribedOnly];
  folderPaths = [folders mutableCopy];
  [folderPaths autorelease];
  [folderPaths removeObjectsInArray: mainFolders];
  namespaces = [NSMutableArray arrayWithCapacity: 10];
  [self _appendNamespaces: namespaces];
  max = [namespaces count];
  for (count = 0; count < max; count++)
    {
      folders = [self _allFoldersFromNS: [namespaces objectAtIndex: count]
                         subscribedOnly: subscribedOnly];
      if ([folders count])
        {
          [folderPaths removeObjectsInArray: folders];
          [folderPaths addObjectsFromArray: folders];
        }
    }
  [folderPaths
    sortUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
  [folderPaths replaceObjectsInRange: NSMakeRange (0, 0)
	       withObjectsFromArray: mainFolders];

  return folderPaths;
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

- (NSString *) _urlHostString
{
  NSDictionary *mailAccount;
  NSString *username, *escUsername, *hostString;

  mailAccount = [[context activeUser] accountWithName: accountName];
  if (mailAccount)
    {
      username = [mailAccount objectForKey: @"userName"];
      escUsername
	= [[username stringByEscapingURL] stringByReplacingString: @"@"
					  withString: @"%40"];
      hostString = [NSString stringWithFormat: @"%@@%@", escUsername,
                    [mailAccount objectForKey: @"serverName"]];
    }
  else
    hostString = @"localhost";

  return hostString;
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

  host = [self _urlHostString];
  if (![host rangeOfString: @"@"].length)
    [urlString appendFormat: @"%@@", [self imap4LoginFromHTTP]];
  [urlString appendFormat: @"%@/", host];

  return urlString;
}

- (NSMutableString *) traversalFromMailAccount
{
  return [NSMutableString string];
}

- (NSString *) imap4Login
{
  return [[self imap4URL] user];
}

/* name lookup */

- (id) lookupName: (NSString *) _key
	inContext: (id)_ctx
	  acquire: (BOOL) _flag
{
  NSString *folderName;
  NSMutableArray *namespaces;
  Class klazz;
  id obj;

  [[[self imap4Connection] client] namespace];

  if ([_key hasPrefix: @"folder"])
    {
      folderName = [[_key substringFromIndex: 6] fromCSSIdentifier];

      namespaces = [NSMutableArray array];
      [self _appendNamespaces: namespaces];
      if ([namespaces containsObject: folderName])
        klazz = [SOGoMailNamespace class];
      else if ([folderName
                 isEqualToString: [self sentFolderNameInContext: _ctx]])
	klazz = [SOGoSentFolder class];
      else if ([folderName
		 isEqualToString: [self draftsFolderNameInContext: _ctx]])
	klazz = [SOGoDraftsFolder class];
      else if ([folderName
		 isEqualToString: [self trashFolderNameInContext: _ctx]])
	klazz = [SOGoTrashFolder class];
      else
	klazz = [SOGoMailFolder class];

      obj = [klazz objectWithName: _key inContainer: self];
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
  return inboxFolderName;
}

- (BOOL) _migrateFolderWithPurpose: (NSString *) purpose
                          withName: (NSString *) folderName
{
  SOGoUserDefaults *ud;
  NSString *methodName;
  SEL methodSel;
  BOOL rc;

  ud = [[context activeUser] userDefaults];
  methodName = [NSString stringWithFormat: @"set%@FolderName:", purpose];
  methodSel = NSSelectorFromString (methodName);
  if ([ud respondsToSelector: methodSel])
    {
      [ud performSelector: methodSel withObject: folderName];
      [ud synchronize];
      rc = YES;
    }
  else
    {
      [self errorWithFormat: @"method '%@' not available with user defaults"
            @" object, folder migration fails", methodName];
      rc = NO;
    }

  return rc;
}

- (NSString *) _userFolderNameWithPurpose: (NSString *) purpose
{
  SOGoUser *user;
  SOGoUserSettings *us;
  SOGoUserDefaults *ud;
  NSMutableDictionary *mailSettings;
  NSString *folderName, *key, *methodName;
  SEL methodSel;

  folderName = nil;

  user = [context activeUser];
  /* migration part: */
  us = [user userSettings];
  mailSettings = [us objectForKey: @"Mail"];
  if (mailSettings)
    {
      key = [NSString stringWithFormat: @"%@Folder", purpose];
      folderName = [mailSettings objectForKey: key];
      if ([folderName length]
          && [self _migrateFolderWithPurpose: purpose withName: folderName])
        {
          [mailSettings removeObjectForKey: key];
          [us synchronize];
          folderName = nil;
        }
    }
  else
    folderName = nil;

  if (!folderName)
    {
      ud = [[context activeUser] userDefaults];
      methodName = [NSString stringWithFormat: @"%@FolderName",
                             [purpose lowercaseString]];
      methodSel = NSSelectorFromString (methodName);
      folderName = [ud performSelector: methodSel];
    }

  return folderName;
}

- (NSString *) draftsFolderNameInContext: (id) _ctx
{
  return [self _userFolderNameWithPurpose: @"Drafts"];
}

- (NSString *) sentFolderNameInContext: (id)_ctx
{
  return [self _userFolderNameWithPurpose: @"Sent"];
}

- (NSString *) trashFolderNameInContext: (id)_ctx
{
  return [self _userFolderNameWithPurpose: @"Trash"];
}

- (id) folderWithTraversal: (NSString *) traversal
	      andClassName: (NSString *) className
{
  NSArray *paths;
  NSString *currentName;
  id currentContainer;
  unsigned int count, max;
  Class clazz;

  currentContainer = self;
  paths = [traversal componentsSeparatedByString: @"/"];

  if (!className)
    clazz = [SOGoMailFolder class];
  else
    clazz = NSClassFromString (className);

  max = [paths count];
  for (count = 0; count < max - 1; count++)
    {
      currentName = [NSString stringWithFormat: @"folder%@",
			      [paths objectAtIndex: count]];
      currentContainer = [SOGoMailFolder objectWithName: currentName
					 inContainer: currentContainer];
    }
  currentName = [NSString stringWithFormat: @"folder%@",
			  [paths objectAtIndex: max - 1]];

  return [clazz objectWithName: currentName inContainer: currentContainer];
}

- (SOGoMailFolder *) inboxFolderInContext: (id) _ctx
{
  // TODO: use some profile to determine real location, use a -traverse lookup
  if (!inboxFolder)
    {
      inboxFolder
	= [self folderWithTraversal: [self inboxFolderNameInContext: _ctx]
		andClassName: nil];
      [inboxFolder retain];
    }

  return inboxFolder;
}

- (SOGoDraftsFolder *) draftsFolderInContext: (id) _ctx
{
  // TODO: use some profile to determine real location, use a -traverse lookup

  if (!draftsFolder)
    {
      draftsFolder
	= [self folderWithTraversal: [self draftsFolderNameInContext: _ctx]
		andClassName: @"SOGoDraftsFolder"];
      [draftsFolder retain];
    }

  return draftsFolder;
}

- (SOGoSentFolder *) sentFolderInContext: (id) _ctx
{
  // TODO: use some profile to determine real location, use a -traverse lookup

  if (!sentFolder)
    {
      sentFolder
	= [self folderWithTraversal: [self sentFolderNameInContext: _ctx]
		andClassName: @"SOGoSentFolder"];
      [sentFolder retain];
    }

  return sentFolder;
}

- (SOGoTrashFolder *) trashFolderInContext: (id) _ctx
{
  if (!trashFolder)
    {
      trashFolder
	= [self folderWithTraversal: [self trashFolderNameInContext: _ctx]
		andClassName: @"SOGoTrashFolder"];
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
  NSString *login, *host;
  NSRange r;

  r = [accountName rangeOfString:@"@"];
  if (r.length > 0)
    {
      login = [accountName substringToIndex:r.location];
      host  = [accountName substringFromIndex:(r.location + r.length)];
    }
  else
    {
      login = nil;
      host  = accountName;
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

@end /* SOGoMailAccount */
