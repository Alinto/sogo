/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2007-2011 Inverse inc.

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
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoHTTPAuthenticator.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Context.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoAuthenticator.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoSieveManager.h>

#import "SOGoDraftsFolder.h"
#import "SOGoMailFolder.h"
#import "SOGoMailManager.h"
#import "SOGoMailNamespace.h"
#import "SOGoSentFolder.h"
#import "SOGoTrashFolder.h"
#import "SOGoUser+Mailer.h"

#import "SOGoMailAccount.h"

@implementation SOGoMailAccount

static NSString *inboxFolderName = @"INBOX";

- (id) init
{
  if ((self = [super init]))
    {
      inboxFolder = nil;
      draftsFolder = nil;
      sentFolder = nil;
      trashFolder = nil;
      imapAclStyle = undefined;
      identities = nil;
      otherUsersFolderName = nil;
      sharedFoldersName = nil;
    }

  return self;
}

- (void) dealloc
{
  [inboxFolder release];
  [draftsFolder release];
  [sentFolder release];
  [trashFolder release];
  [identities release];
  [otherUsersFolderName release];
  [sharedFoldersName release];
  [super dealloc];  
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
        [folders addObjectUniquely: newFolder];
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
    {
      [self _appendNamespace: namespace toFolders: folders];
      ASSIGN(otherUsersFolderName, [folders lastObject]);     
    }

  namespace = [namespaceDict objectForKey: @"shared"];
  if (namespace)
    {
      [self _appendNamespace: namespace toFolders: folders];
      ASSIGN(sharedFoldersName, [folders lastObject]);
    }
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

- (NSArray *) toManyRelationshipKeysWithNamespaces: (BOOL) withNSs
{
  NSMutableArray *folders;
  NSArray *imapFolders, *nss;

  imapFolders = [[self imap4Connection] subfoldersForURL: [self imap4URL]];
  folders = [imapFolders mutableCopy];
  [folders autorelease];
  if (withNSs)
    [self _appendNamespaces: folders];
  else
    { /* some implementation insist on returning NSs in the list of
         folders... */
      nss = [self otherUsersFolderNamespaces];
      if (nss)
          [folders removeObjectsInArray: nss];
      nss = [self sharedFolderNamespaces];
      if (nss)
        [folders removeObjectsInArray: nss];
    }

  return [[folders stringsWithFormat: @"folder%@"]
           resultsOfSelector: @selector (asCSSIdentifier)];
}

- (NSArray *) toManyRelationshipKeys
{
  return [self toManyRelationshipKeysWithNamespaces: YES];
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

/* see http://tools.ietf.org/id/draft-ietf-imapext-acl */
- (BOOL) imapAclConformsToIMAPExt
{
  NGImap4Client *imapClient;
  NSArray *capability;
  int count, max;
  BOOL conforms;

  conforms = NO;

  imapClient = [[self imap4Connection] client];
  capability = [[imapClient capability] objectForKey: @"capability"];
  max = [capability count];
  for (count = 0; !conforms && count < max; count++)
    {
      if ([[capability objectAtIndex: count] hasPrefix: @"acl2"])
	conforms = YES;
    }

  return conforms;
}

/* capabilities */
- (BOOL) hasCapability: (NSString *) capability
{
  NGImap4Client *imapClient;
  NSArray *capabilities;

  imapClient = [[self imap4Connection] client];
  capabilities = [[imapClient capability] objectForKey: @"capability"];

  return [capabilities containsObject: capability];
}

- (BOOL) supportsQuotas
{
  return [self hasCapability: @"quota"];
}

- (BOOL) supportsQResync
{
  return [self hasCapability: @"qresync"];
}

- (id) getInboxQuota
{
  SOGoMailFolder *inbox;
  NGImap4Client *client;
  NSString *inboxName;
  SOGoDomainDefaults *dd;
  id inboxQuota, infos;
  float quota;
  
  inboxQuota = nil;
  if ([self supportsQuotas])
    {
      dd = [[context activeUser] domainDefaults];
      quota = [dd softQuotaRatio];
      inbox = [self inboxFolderInContext: context];
      inboxName = [NSString stringWithFormat: @"/%@", [inbox relativeImap4Name]];
      client = [[inbox imap4Connection] client];
      infos = [[client getQuotaRoot: [inbox relativeImap4Name]] objectForKey: @"quotas"];
      inboxQuota = [infos objectForKey: inboxName];
      if (quota != 0 && inboxQuota != nil)
	{
	  // A soft quota ratio is imposed for all users
	  quota = quota * [(NSNumber*)[inboxQuota objectForKey: @"maxQuota"] intValue];
	  inboxQuota = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithLong: (long)(quota+0.5)], @"maxQuota",
					[inboxQuota objectForKey: @"usedSpace"], @"usedSpace",
				     nil];
	}
    }

  return inboxQuota;
}

- (BOOL) updateFilters
{
  SOGoSieveManager *manager;

  manager = [SOGoSieveManager sieveManagerForUser: [context activeUser]];

  return [manager updateFiltersForLogin: [[self imap4URL] user]
                               authname: [[self imap4URL] user]
                               password: [self imap4PasswordRenewed: NO]
                                account: self];
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

- (NSDictionary *) _mailAccount
{
  NSDictionary *mailAccount;
  NSArray *accounts;
  SOGoUser *user;

  user = [SOGoUser userWithLogin: [self ownerInContext: nil]];
  accounts = [user mailAccounts];
  mailAccount = [accounts objectAtIndex: [nameInContainer intValue]];

  return mailAccount;
}

- (void) _appendDelegatorIdentities
{
  NSArray *delegators;
  SOGoUser *delegatorUser;
  NSDictionary *delegatorAccount;
  NSInteger count, max;

  delegators = [[SOGoUser userWithLogin: owner] mailDelegators];
  max = [delegators count];
  for (count = 0; count < max; count++)
    {
      delegatorUser = [SOGoUser
                        userWithLogin: [delegators objectAtIndex: count]];
      if (delegatorUser)
        {
          delegatorAccount = [[delegatorUser mailAccounts]
                                       objectAtIndex: 0];
          [identities addObjectsFromArray:
                        [delegatorAccount objectForKey: @"identities"]];
        }
    }
}

- (NSArray *) identities
{
  if (!identities)
    {
      identities = [[[self _mailAccount] objectForKey: @"identities"]
                     mutableCopy];
      if ([nameInContainer isEqualToString: @"0"])
        [self _appendDelegatorIdentities];
    }

  return identities;
}

- (NSString *) signature
{
  NSString *signature;

  [self identities];
  if ([identities count] > 0)
    signature = [[identities objectAtIndex: 0] objectForKey: @"signature"];
  else
    signature = nil;

  return signature;
}

- (NSString *) encryption
{
  NSString *encryption;

  encryption = [[self _mailAccount] objectForKey: @"encryption"];
  if (![encryption length])
    encryption = @"none";

  return encryption;
}

- (NSMutableString *) imap4URLString
{
  NSMutableString *imap4URLString;
  NSDictionary *mailAccount;
  NSString *encryption, *protocol, *username, *escUsername;
  int defaultPort, port;

  mailAccount = [self _mailAccount];
  encryption = [mailAccount objectForKey: @"encryption"];
  defaultPort = 143;
  protocol = @"imap";

  if ([encryption isEqualToString: @"ssl"])
    {
      protocol = @"imaps";
      defaultPort = 993;
    }
  else if ([encryption isEqualToString: @"tls"])
    {
      protocol = @"imaps";
    }

  username = [mailAccount objectForKey: @"userName"];
  escUsername
    = [[username stringByEscapingURL] stringByReplacingString: @"@"
                                                   withString: @"%40"];
  imap4URLString = [NSMutableString stringWithFormat: @"%@://%@@%@",
                                    protocol, escUsername,
                           [mailAccount objectForKey: @"serverName"]];
  port = [[mailAccount objectForKey: @"port"] intValue];
  if (port && port != defaultPort)
    [imap4URLString appendFormat: @":%d", port];

  [imap4URLString appendString: @"/"];

  return imap4URLString;
}

- (NSMutableString *) traversalFromMailAccount
{
  return [NSMutableString string];
}

//
// Extract password from basic authentication.
//
- (NSString *) imap4PasswordRenewed: (BOOL) renewed
{
  NSString *password;
  NSURL *imapURL;

  // Default account - ie., the account that is provided with a default
  // SOGo installation. User-added IMAP accounts will have name >= 1.
  if ([nameInContainer isEqualToString: @"0"])
    {
      imapURL = [self imap4URL];

      password = [[self authenticatorInContext: context]
                   imapPasswordInContext: context
		                  forURL: imapURL
                              forceRenew: renewed];
      if (!password)
        [self errorWithFormat: @"no IMAP4 password available"];
    }
  else
    {
      password = [[self _mailAccount] objectForKey: @"password"];
      if (!password)
        password = @"";
    }

  return password;
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
		 isEqualToString: [self draftsFolderNameInContext: _ctx]])
	klazz = [SOGoDraftsFolder class];
      else if ([folderName
                 isEqualToString: [self sentFolderNameInContext: _ctx]])
	klazz = [SOGoSentFolder class];
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

- (NSString *) _userFolderNameWithPurpose: (NSString *) purpose
{
  SOGoUser *user;
  NSArray *accounts;
  int accountIdx;
  NSDictionary *account;
  NSString *folderName;

  folderName = nil;

  user = [SOGoUser userWithLogin: [self ownerInContext: nil]];
  accounts = [user mailAccounts];
  accountIdx = [nameInContainer intValue];
  account = [accounts objectAtIndex: accountIdx];
  folderName = [[account objectForKey: @"mailboxes"]
                 objectForKey: purpose];
  if (!folderName && accountIdx > 0)
    {
      account = [accounts objectAtIndex: 0];
      folderName = [[account objectForKey: @"mailboxes"]
                     objectForKey: purpose];
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

- (NSString *) otherUsersFolderNameInContext: (id)_ctx
{
  return otherUsersFolderName;
}

- (NSString *) sharedFoldersNameInContext: (id)_ctx
{
  return sharedFoldersName;
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

/* account delegation */
- (NSArray *) delegates
{
  NSDictionary *mailSettings;
  SOGoUser *ownerUser;
  NSArray *delegates;

  if ([nameInContainer isEqualToString: @"0"])
    {
      ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
      mailSettings = [[ownerUser userSettings] objectForKey: @"Mail"];
      delegates = [mailSettings objectForKey: @"DelegateTo"];
      if (!delegates)
        delegates = [NSArray array];
    }
  else
    delegates = nil;

  return delegates;
}

- (void) _setDelegates: (NSArray *) newDelegates
{
  SOGoUser *ownerUser;
  SOGoUserSettings *settings;

  ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
  settings = [ownerUser userSettings];
  [[settings objectForKey: @"Mail"] setObject: newDelegates
                                       forKey: @"DelegateTo"];
  [settings synchronize];
}

- (void) addDelegates: (NSArray *) newDelegates
{
  NSMutableArray *delegates;
  NSInteger count, max;
  NSString *currentDelegate;
  SOGoUser *delegateUser;

  if ([nameInContainer isEqualToString: @"0"])
    {
      delegates = [[self delegates] mutableCopy];
      [delegates autorelease];
      max = [newDelegates count];
      for (count = 0; count < max; count++)
        {
          currentDelegate = [newDelegates objectAtIndex: 0];
          delegateUser = [SOGoUser userWithLogin: currentDelegate];
          if (delegateUser)
            {
              [delegates addObjectUniquely: currentDelegate];
              [delegateUser addMailDelegator: owner];
            }
        }

      [self _setDelegates: delegates];
    }
}

- (void) removeDelegates: (NSArray *) oldDelegates
{
  NSMutableArray *delegates;
  NSInteger count, max;
  NSString *currentDelegate;
  SOGoUser *delegateUser;

  if ([nameInContainer isEqualToString: @"0"])
    {
      delegates = [[self delegates] mutableCopy];
      [delegates autorelease];
      max = [oldDelegates count];
      for (count = 0; count < max; count++)
        {
          currentDelegate = [oldDelegates objectAtIndex: 0];
          delegateUser = [SOGoUser userWithLogin: currentDelegate];
          if (delegateUser)
            {
              [delegates removeObject: currentDelegate];
              [delegateUser removeMailDelegator: owner];
            }
        }
      
      [self _setDelegates: delegates];
    }
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

- (NSString *) davDisplayName
{
  return [[self _mailAccount] objectForKey: @"name"];
}

@end /* SOGoMailAccount */
