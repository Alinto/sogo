/*
  Copyright (C) 2007-2020 Inverse inc.

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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NSString+Imap4.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoAuthenticator.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoSieveManager.h>

#import "SOGoDraftsFolder.h"
#import "SOGoMailNamespace.h"
#import "SOGoSentFolder.h"
#import "SOGoTrashFolder.h"
#import "SOGoJunkFolder.h"
#import "SOGoUser+Mailer.h"

#import "SOGoMailAccount.h"
#import <Foundation/NSProcessInfo.h>


#define XMLNS_INVERSEDAV @"urn:inverse:params:xml:ns:inverse-dav"

@implementation SOGoMailAccount

static NSString *inboxFolderName = @"INBOX";

- (id) init
{
  if ((self = [super init]))
    {
      NSString *sieveFolderEncoding = [[SOGoSystemDefaults sharedSystemDefaults] sieveFolderEncoding];
      inboxFolder = nil;
      draftsFolder = nil;
      sentFolder = nil;
      trashFolder = nil;
      junkFolder = nil;
      imapAclStyle = undefined;
      identities = nil;
      otherUsersFolderName = nil;
      sharedFoldersName = nil;
      subscribedFolders = nil;
      sieveFolderUTF8Encoding = [sieveFolderEncoding isEqualToString: @"UTF-8"];
    }

  return self;
}

- (void) dealloc
{
  [inboxFolder release];
  [draftsFolder release];
  [sentFolder release];
  [trashFolder release];
  [junkFolder release];
  [identities release];
  [otherUsersFolderName release];
  [sharedFoldersName release];
  [subscribedFolders release];
  [super dealloc];  
}

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

  return [[folders resultsOfSelector: @selector (asCSSIdentifier)]
           stringsWithFormat: @"folder%@"];
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
                                         [NSNumber numberWithLong: [[inboxQuota objectForKey: @"usedSpace"] longLongValue]], @"usedSpace",
				     nil];
	}
    }

  return inboxQuota;
}

- (NSException *) updateFiltersAndForceActivation: (BOOL) forceActivation
{
  return [self updateFiltersWithUsername: nil
                             andPassword: nil
                         forceActivation: forceActivation];
}

- (NSException *) updateFilters
{
  return [self updateFiltersWithUsername: nil
                             andPassword: nil
                         forceActivation: NO];
}

- (NSException *) updateFiltersWithUsername: (NSString *) theUsername
                       andPassword: (NSString *) thePassword
                   forceActivation: (BOOL) forceActivation
{
  SOGoSieveManager *manager;

  manager = [SOGoSieveManager sieveManagerForUser: [context activeUser]];

  return [manager updateFiltersForAccount: self
                             withUsername: theUsername
                              andPassword: thePassword
                          forceActivation: forceActivation];
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

  baseURLString = [self imap4URLString];
  urlString = [NSString stringWithFormat: @"%@%@/", baseURLString, [namespace stringByEscapingURL]];
  nsURL = [NSURL URLWithString: urlString];
  folders = [[self imap4Connection] allFoldersForURL: nsURL
                               onlySubscribedFolders: subscribedOnly];

  return folders;
}

//
//
//
- (NSArray *) allFolderPaths: (SOGoMailListingMode) theListingMode
{
  NSMutableArray *folderPaths, *namespaces;
  NSArray *folders, *mainFolders;
  NSString *namespace;

  BOOL subscribedOnly;
  int count, max;

  if (theListingMode == SOGoMailStandardListing)
      subscribedOnly = [[[context activeUser] userDefaults] mailShowSubscribedFoldersOnly];
  else
    {
      subscribedOnly = NO;
      DESTROY(subscribedFolders);
      subscribedFolders = [[NSMutableDictionary alloc] init];
      folders = [[self imap4Connection] allFoldersForURL: [self imap4URL]
				   onlySubscribedFolders: YES];
      max = [folders count];
      for (count = 0; count < max; count++)
	{
	  [subscribedFolders setObject: [NSNull null]
				forKey: [folders objectAtIndex: count]];
	}
      [[self imap4Connection] flushFolderHierarchyCache];
    }

  mainFolders = [[NSArray arrayWithObjects:
			    [self inboxFolderNameInContext: context],
			  [self draftsFolderNameInContext: context],
			  [self sentFolderNameInContext: context],
			  [self trashFolderNameInContext: context],
			  [self junkFolderNameInContext: context],
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
      namespace = [namespaces objectAtIndex: count];
      folders = [self _allFoldersFromNS: namespace
                         subscribedOnly: subscribedOnly];
      if ([folders count])
        {
          [folderPaths removeObjectsInArray: folders];
          [folderPaths addObjectsFromArray: folders];

          // We make sure our "shared" / "public" namespace is always defined. Cyrus does NOT
          // return them in LIST while Dovecot does.
          namespace = [NSString stringWithFormat: @"/%@", namespace];
          [folderPaths removeObject: namespace];
          [folderPaths addObject: namespace];
        }
    }
  [folderPaths
    sortUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
  [folderPaths replaceObjectsInRange: NSMakeRange (0, 0)
	       withObjectsFromArray: mainFolders];

  return folderPaths;
}

//
//
//
- (NSString *) _folderType: (NSString *) folderName
                     flags: (NSMutableArray *) flags
{
  NSString *folderType, *key;
  NSDictionary *metadata;
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  metadata = [[[self imap4Connection] allFoldersMetadataForURL: [self imap4URL]
                                         onlySubscribedFolders: [ud mailShowSubscribedFoldersOnly]]
               objectForKey: @"list"];

  key = [NSString stringWithFormat: @"/%@", folderName];
  [flags addObjectsFromArray: [metadata objectForKey: key]];

  // RFC6154 (https://tools.ietf.org/html/rfc6154) describes special uses for IMAP mailboxes.
  // We do honor them, as long as your SOGo{Drafts,Trash,Sent,Junk}FolderName are properly configured
  // See http://wiki.dovecot.org/MailboxSettings for a Dovecot example.
  if ([folderName isEqualToString: inboxFolderName])
    folderType = @"inbox";
  else if ([flags containsObject: [self draftsFolderNameInContext: context]] ||
           [folderName isEqualToString: [self draftsFolderNameInContext: context]])
    folderType = @"draft";
  else if ([flags containsObject: [self sentFolderNameInContext: context]] ||
           [folderName isEqualToString: [self sentFolderNameInContext: context]])
    folderType = @"sent";
  else if ([flags containsObject: [self trashFolderNameInContext: context]] ||
           [folderName isEqualToString: [self trashFolderNameInContext: context]])
    folderType = @"trash";
  else if ([flags containsObject: [self junkFolderNameInContext: context]] ||
           [folderName isEqualToString: [self junkFolderNameInContext: context]])
    folderType = @"junk";
  else if ([folderName isEqualToString: otherUsersFolderName])
    folderType = @"otherUsers";
  else if ([folderName isEqualToString: sharedFoldersName])
    folderType = @"shared";
  else
    folderType = @"folder";

  return folderType;
}

//
//
//
- (NSMutableDictionary *) _insertFolder: (NSString *) folderPath
                            foldersList: (NSMutableArray *) theFolders
{
  NSArray *pathComponents;
  NSMutableArray *folders, *flags;
  NSMutableDictionary *currentFolder, *parentFolder, *folder;
  NSString *currentFolderName, *currentPath, *sievePath, *fullName, *folderType;
  SOGoUserManager *userManager;

  BOOL last, isOtherUsersFolder, parentIsOtherUsersFolder, isSubscribed;
  int i, j, count;

  parentFolder = nil;
  parentIsOtherUsersFolder = NO;
  pathComponents = [folderPath pathComponents];
  count = [pathComponents count];

  // Make sure all ancestors exist.
  // The variable folderPath is something like '/INBOX/Junk' so pathComponents becomes ('/', 'INBOX', 'Junk').
  // That's why we always ignore the first element
  for (i = 1; i < count; i++)
    {
      last = ((count - i) == 1);
      folder = nil;
      currentPath = [[[pathComponents subarrayWithRange: NSMakeRange(0,i+1)] componentsJoinedByString: @"/"] substringFromIndex: 2];

      // Search for the current path in the children of the parent folder.
      // For the first iteration, take the parent folder passed as argument.
      if (parentFolder)
	folders = [parentFolder objectForKey: @"children"];
      else
	folders = theFolders;

      for (j = 0; j < [folders count]; j++)
        {
          currentFolder = [folders objectAtIndex: j];
          if ([currentPath isEqualToString: [currentFolder objectForKey: @"path"]])
            {
              folder = currentFolder;
              // Make sure all branches are ready to receive children
              if (!last && ![folder objectForKey: @"children"])
                  [folder setObject: [NSMutableArray array] forKey: @"children"];

	      break;
            }
        }

      // Check if the current folder is the "Other users" folder (shared mailboxes)
      currentFolderName = [[pathComponents objectAtIndex: i] stringByDecodingImap4FolderName];
      if (otherUsersFolderName
          && [currentFolderName caseInsensitiveCompare: otherUsersFolderName] == NSOrderedSame)
	isOtherUsersFolder = YES;
      else
	isOtherUsersFolder = NO;

      if (folder == nil)
        {
          // Folder was not found; create it and add it to the folders list
          if (parentIsOtherUsersFolder)
            {
              // Parent folder is the "Other users" folder; translate the user's mailbox name
              // to the full name of the person
              userManager = [SOGoUserManager sharedUserManager];
              if ((fullName = [userManager getCNForUID: currentFolderName]) && [fullName length])
                currentFolderName = fullName;
	      else if ((fullName = [userManager getEmailForUID: currentFolderName]) && [fullName length])
		currentFolderName = fullName;
            }
          else if (isOtherUsersFolder)
	    currentFolderName = [self labelForKey: @"OtherUsersFolderName"];
          else if (sharedFoldersName
                   && [currentFolderName caseInsensitiveCompare: sharedFoldersName] == NSOrderedSame)
	    currentFolderName = [self labelForKey: @"SharedFoldersName"];

          flags = [NSMutableArray array];;

          if (last)
            folderType = [self _folderType: currentPath
                                     flags: flags];
          else
            folderType = @"additional";

	  if ([subscribedFolders objectForKey: folderPath])
	    isSubscribed = YES;
	  else
	    isSubscribed = NO;

          folder = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          currentPath, @"path",
                                          folderType, @"type",
                                          currentFolderName, @"name",
                                          [NSMutableArray array], @"children",
					  flags, @"flags",
					  [NSNumber numberWithBool: isSubscribed], @"subscribed",
					  nil];

          if (sieveFolderUTF8Encoding)
            sievePath = [currentPath stringByDecodingImap4FolderName];
          else
            sievePath = currentPath;
          [folder setObject: sievePath forKey: @"sievePath"];

          // Either add this new folder to its parent or the list of root folders
          [folders addObject: folder];
        }

      parentFolder = folder;
      parentIsOtherUsersFolder = isOtherUsersFolder;
    }

  return parentFolder;
}

//
// Return a tree representation of the mailboxes
//
- (NSArray *) allFoldersMetadata: (SOGoMailListingMode) theListingMode
{
  NSString *currentFolder;
  NSMutableArray *folders;
  NSEnumerator *rawFolders;
  NSAutoreleasePool *pool;
  NSArray *allFolderPaths;

  allFolderPaths = [self allFolderPaths: theListingMode];
  rawFolders = [allFolderPaths objectEnumerator];
  folders = [NSMutableArray array];

  while ((currentFolder = [rawFolders nextObject]))
    {
      // Using a local pool to avoid using too many file descriptors. This could
      // happen with tons of mailboxes under "Other Users" as LDAP connections
      // are never reused and "autoreleased" at the end. This loop would consume
      // lots of LDAP connections during its execution.
      pool = [[NSAutoreleasePool alloc] init];

      // Insert folder into folders tree
      [self _insertFolder: currentFolder
              foldersList: folders];

      [pool release];
    }

  return folders;
}

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

- (NSDictionary *) defaultIdentity
{
  NSDictionary *defaultIdentity, *currentIdentity;
  unsigned int count, max;

  defaultIdentity = nil;
  [self identities];

  max = [identities count];
  for (count = 0; count < max; count++)
    {
      currentIdentity = [identities objectAtIndex: count];
      if ([[currentIdentity objectForKey: @"isDefault"] boolValue])
        {
          defaultIdentity = currentIdentity;
          break;
        }
    }

  return defaultIdentity; // can be nil
}

- (NSString *) signature
{
  NSDictionary *identity;
  NSString *signature;

  identity = [self defaultIdentity];

  if (identity)
    signature = [identity objectForKey: @"signature"];
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


- (NSDictionary *) imapFolderGUIDs
{
  NSDictionary *result, *nresult;
  NSMutableDictionary *folders;
  NGImap4Client *client;
  SOGoUserDefaults *ud;
  NSArray *folderList;
  NSEnumerator *e;
  NSString *guid;
  id currentFolder;
  
  BOOL hasAnnotatemore;

  ud = [[context activeUser] userDefaults];

  // We skip the Junk folder here, as EAS doesn't know about this
  if ([ud synchronizeOnlyDefaultMailFolders])
    folderList = [[NSArray arrayWithObjects:
                             [self inboxFolderNameInContext: context],
                           [self draftsFolderNameInContext: context],
                           [self sentFolderNameInContext: context],
                           [self trashFolderNameInContext: context],
                     nil] stringsWithFormat: @"/%@"];
  else
    folderList = [self allFolderPaths: SOGoMailStandardListing];

  folders = [NSMutableDictionary dictionary];

  client = [[self imap4Connection] client];
  hasAnnotatemore = [self hasCapability: @"annotatemore"];

  if (hasAnnotatemore)
    result = [client annotation: @"*"  entryName: @"/comment" attributeName: @"value.priv"];
  else
    result = [client lstatus: @"*" flags: [NSArray arrayWithObjects: @"x-guid", nil]];
  
  e = [folderList objectEnumerator];

  while ((currentFolder = [[e nextObject] substringFromIndex: 1]))
    {
      if (hasAnnotatemore)
        guid = [[[[result objectForKey: @"FolderList"] objectForKey: currentFolder] objectForKey: @"/comment"] objectForKey: @"value.priv"];
      else
        guid = [[[result objectForKey: @"status"] objectForKey: currentFolder] objectForKey: @"x-guid"];
      
      if (!guid || ![guid isNotNull])
        {
          // Don't generate a GUID for "Other users" and "Shared" namespace folders - user foldername instead
          if ((otherUsersFolderName && [currentFolder isEqualToString: otherUsersFolderName]) ||
              (sharedFoldersName && [currentFolder isEqualToString: sharedFoldersName]))
             guid = [NSString stringWithFormat: @"%@", currentFolder];
          // If Dovecot is used with mail_shared_explicit_inbox = yes we have to generate a guid for "shared/user".
          // * LIST (\NonExistent \HasChildren) "/" shared
          // * LIST (\NonExistent \HasChildren) "/" shared/jdoe@example.com
          // * LIST (\HasNoChildren) "/" shared/jdoe@example.com/INBOX
          else if (!hasAnnotatemore &&
		   ([[[result objectForKey: @"list"] objectForKey: currentFolder] indexOfObject: @"nonexistent"] != NSNotFound &&
		    [[[result objectForKey: @"list"] objectForKey: currentFolder] indexOfObject: @"haschildren"] != NSNotFound))
            guid = [NSString stringWithFormat: @"%@", currentFolder];
          else
            {
              // If folder doesn't exists - ignore it. 
              nresult = [client status: currentFolder
                                 flags: [NSArray arrayWithObject: @"UIDVALIDITY"]];
              if (![[nresult valueForKey: @"result"] boolValue])
                continue;
              else if (hasAnnotatemore)
                 {
                   guid = [[NSProcessInfo processInfo] globallyUniqueString];
                   nresult = [client annotation: currentFolder entryName: @"/comment" attributeName: @"value.priv" attributeValue: guid];
                 }

             // setannotation failed or annotatemore is not available
             if ((hasAnnotatemore && ![[nresult objectForKey: @"result"] boolValue]) || !hasAnnotatemore)
               guid = [NSString stringWithFormat: @"%@", currentFolder];
            }
        }
      
      [folders setObject: [NSString stringWithFormat: @"folder%@", guid] forKey: [NSString stringWithFormat: @"folder%@", currentFolder]];
    }
  
  return folders;
}


/* name lookup */

- (id) lookupNameByPaths: (NSArray *) _paths
               inContext: (id)_ctx
                 acquire: (BOOL) _flag
{
  NSString *folderName;
  NSUInteger count, max;
  SOGoMailBaseObject *folder;

  max = [_paths count];
  folder = self;
  for (count = 0; folder && count < max; count++)
    {
      folderName = [_paths objectAtIndex: count];
      folder = [folder lookupName: folderName inContext: _ctx acquire: _flag];
    }

  return folder;
}

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
      else if ([folderName
		 isEqualToString: [self junkFolderNameInContext: _ctx]])
	klazz = [SOGoJunkFolder class];
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
  folderName = [[account objectForKey: @"specialMailboxes"]
                 objectForKey: purpose];
  if (!folderName && accountIdx > 0)
    {
      account = [accounts objectAtIndex: 0];
      folderName = [[account objectForKey: @"specialMailboxes"]
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

- (NSString *) junkFolderNameInContext: (id)_ctx
{
  return [self _userFolderNameWithPurpose: @"Junk"];
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

- (SOGoJunkFolder *) junkFolderInContext: (id) _ctx
{
  if (!junkFolder)
    {
      junkFolder
	= [self folderWithTraversal: [self junkFolderNameInContext: _ctx]
                       andClassName: @"SOGoJunkFolder"];
      [trashFolder retain];
    }

  return junkFolder;
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
  NSMutableDictionary *mailSettings;
  SOGoUser *ownerUser;
  SOGoUserSettings *settings;

  ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
  settings = [ownerUser userSettings];
  mailSettings = [settings objectForKey: @"Mail"];
  if (!mailSettings)
    {
      mailSettings = [NSMutableDictionary dictionaryWithCapacity: 1];
      [settings setObject: mailSettings forKey: @"Mail"];
    }
  [mailSettings setObject: newDelegates
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
          currentDelegate = [newDelegates objectAtIndex: count];
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
          currentDelegate = [oldDelegates objectAtIndex: count];
          delegateUser = [SOGoUser userWithLogin: currentDelegate];
          [delegates removeObject: currentDelegate];
          if (delegateUser)
            [delegateUser removeMailDelegator: owner];
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

- (NSData *) certificate
{
  NSData *mailCertificate;
  SOGoUserDefaults *ud;

  mailCertificate = nil;
  ud = [[context activeUser] userDefaults];

  if ([nameInContainer isEqualToString: @"0"])
    {
      mailCertificate = [[ud stringForKey: @"SOGoMailCertificate"] dataByDecodingBase64];
    }
  else
    {
      int accountIdx;
      NSArray* accounts;
      NSDictionary *account, *security;

      accountIdx = [nameInContainer intValue] - 1;
      accounts = [ud auxiliaryMailAccounts];
      if ([accounts count] > accountIdx)
        {
          account = [accounts objectAtIndex: accountIdx];
          security = [account objectForKey: @"security"];
          if (security && [[security objectForKey: @"certificate"] length])
            {
              mailCertificate = [[security objectForKey: @"certificate"] dataByDecodingBase64];
            }
        }
    }

  return mailCertificate;
}

- (void) setCertificate: (NSData *) theData
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  if ([nameInContainer isEqualToString: @"0"])
    {
      if ([theData length])
        [ud setObject: [theData stringByEncodingBase64]  forKey: @"SOGoMailCertificate"];
      else
        [ud removeObjectForKey: @"SOGoMailCertificate"];
    }
  else
    {
      int accountIdx;
      NSArray* accounts;
      NSMutableDictionary *account, *security;

      accountIdx = [nameInContainer intValue] - 1;
      accounts = [ud auxiliaryMailAccounts];
      if ([accounts count] > accountIdx)
        {
          account = [accounts objectAtIndex: accountIdx];
          security = [account objectForKey: @"security"];
          if (!security)
            {
              security = [NSMutableDictionary dictionary];
              [account setObject: security forKey: @"security"];
            }
          if ([theData length])
            [security setObject: [theData stringByEncodingBase64] forKey: @"certificate"];
          else
            [security removeObjectForKey: @"certificate"];
          [ud setAuxiliaryMailAccounts: accounts];
        }
    }

  [ud synchronize];
}


@end /* SOGoMailAccount */
