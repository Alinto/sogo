/*
  Copyright (C) 2009-2014 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

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
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSValue.h>
#import <Foundation/NSTask.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSURL+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSFileManager+Extensions.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import <SaxObjC/XMLNamespaces.h>

#import <EOControl/EOSortOrdering.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>

#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NSString+Imap4.h>

#import <SOGo/DOMNode+SOGo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/SOGoDAVAuthenticator.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/NSString+DAV.h>
#import <SOGo/NSArray+DAV.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/WORequest+SOGo.h>
#import <SOGo/WOResponse+SOGo.h>
#import <SOGo/SOGoMailer.h>

#import "EOQualifier+MailDAV.h"
#import "SOGoMailAccount.h"
#import "SOGoMailAccounts.h"
#import "SOGoTrashFolder.h"
#import "SOGoMailObject+Draft.h"


#define XMLNS_INVERSEDAV @"urn:inverse:params:xml:ns:inverse-dav"

static NSString *defaultUserID =  @"anyone";

static NSComparisonResult
_compareFetchResultsByMODSEQ (id entry1, id entry2, void *data)
{
  static NSNumber *zeroNumber = nil;
  NSNumber *modseq1, *modseq2;

  if (!zeroNumber)
    {
      zeroNumber = [NSNumber numberWithUnsignedLongLong: 0];
      [zeroNumber retain];
    }

  modseq1 = [entry1 objectForKey: @"modseq"];
  if (!modseq1)
    modseq1 = zeroNumber;
  modseq2 = [entry2 objectForKey: @"modseq"];
  if (!modseq2)
    modseq2 = zeroNumber;

  return [modseq1 compare: modseq2];
}

@interface NGImap4Connection (PrivateMethods)

- (NSString *) imap4FolderNameForURL: (NSURL *) url;

@end

@implementation SOGoMailFolder

- (BOOL)   _path: (NSString *) path
  isInNamespaces: (NSArray *) namespaces
{
  int count, max;
  BOOL rc;

  rc = NO;

  max = [namespaces count];
  for (count = 0; !rc && count < max; count++)
    rc = [path hasPrefix: [namespaces objectAtIndex: count]];

  return rc;
}

- (void) _adjustOwner
{
  SOGoMailAccount *mailAccount;
  NSString *path;
  NSArray *names;

  mailAccount = [self mailAccountFolder];
  path = [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]];

  if ([self _path: path
            isInNamespaces: [mailAccount sharedFolderNamespaces]])
    [self setOwner: @"nobody"];
  else if ([self _path: path
                 isInNamespaces: [mailAccount otherUsersFolderNamespaces]])
    {
      names = [path componentsSeparatedByString: @"/"];
      if ([names count] > 1)
        [self setOwner: [names objectAtIndex: 1]];
      else
        [self setOwner: @"nobody"];
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
      prefetchedInfos = nil;
    }

  return self;
}

- (void) dealloc
{
  [filenames release];
  [folderType release];
  [mailboxACL release];
  [prefetchedInfos release];
  [super dealloc];
}

/* IMAP4 */

- (NSString *) relativeImap4Name
{
  return [[nameInContainer substringFromIndex: 6] fromCSSIdentifier];
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
  NSArray *subfolders;

  subfolders = [[self subfolders] resultsOfSelector: @selector (asCSSIdentifier)];

  return [subfolders stringsWithFormat: @"folder%@"];
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

  deepSubfolders = [NSMutableArray array];

  prefix = [self absoluteImap4Name];

  result = [[self mailAccountFolder] allFolderPaths: SOGoMailStandardListing];
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
      if ([self exists])
        {
          uids = [self fetchUIDsMatchingQualifier: nil sortOrdering: @"DATE"];
          if (![uids isKindOfClass: [NSException class]])
            {
              max = [uids count];
              for (count = 0; count < max; count++)
                {
                  filename = [NSString stringWithFormat: @"%@.eml",
                                    [uids objectAtIndex: count]];
                  [filenames addObject: filename];
                }
            }
        }
    }

  return filenames;
}

- (NSException *) renameTo: (NSString *) newName
{
  NSException *error;
  SOGoMailFolder *inbox;
  NSURL *destURL;
  NSString *path;
  NGImap4Client *client;

  if ([newName length] > 0)
    {
      [self imap4URL];

      if ([self imap4Connection])
        {
          client = [imap4 client];

          inbox = [[self mailAccountFolder] inboxFolderInContext: context];
          [client select: [inbox absoluteImap4Name]];

          path = [[imap4URL path] stringByDeletingLastPathComponent];
          if (![path hasSuffix: @"/"])
            path = [path stringByAppendingString: @"/"];

	  // If new name contains the path - dont't need to add
          if ([newName rangeOfString: @"/"].location == NSNotFound)
            destURL = [[NSURL alloc] initWithScheme: [imap4URL scheme]
                                               host: [imap4URL host]
                                               path: [NSString stringWithFormat: @"%@%@",
                                                               path, [newName stringByEncodingImap4FolderName]]];
          else
            destURL = [[NSURL alloc] initWithScheme: [imap4URL scheme]
                                               host: [imap4URL host]
                                               path: [NSString stringWithFormat: @"%@",
                                                               [newName stringByEncodingImap4FolderName]]];
          [destURL autorelease];
          error = [imap4 moveMailboxAtURL: imap4URL
                                    toURL: destURL];
          if (!error)
            {
              // We unsubscribe to the old one, and subscribe back to the new one
              [client subscribe: [destURL path]];
              [client unsubscribe: [imap4URL path]];

              ASSIGN (imap4URL, nil);
              ASSIGN (nameInContainer,
                      ([NSString stringWithFormat: @"folder%@", [newName asCSSIdentifier]]));
            }
        }
      else
        error = [NSException exceptionWithName: @"SOGoMailException"
                                        reason: @"IMAP connection is invalid"
                                      userInfo: nil];
    }
  else
    error = [NSException exceptionWithName: @"SOGoMailException"
                                    reason: @"given name is empty"
                                  userInfo: nil];

  return error;
}

/* messages */
- (void) prefetchCoreInfosForMessageKeys: (NSArray *) keys
{
  NSUInteger count, max, keyLength;
  NSMutableArray *uids;
  NSDictionary *infos;
  NSArray *allValues;
  NSString *key;

  if (!SOGoMailCoreInfoKeys)
    {
      /* ensure SOGoMailCoreInfoKeys is initialized */
      [SOGoMailObject class];
    }

  [prefetchedInfos release];

  max = [keys count];
  if (max > 0)
    {
      uids = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          key = [keys objectAtIndex: count];
          if ([key hasSuffix: @".eml"])
            {
              keyLength = [key length];
              [uids addObject: [key substringToIndex: keyLength - 4]];
            }
          else
            [uids addObject: key];
        }
      infos = (NSDictionary *) [self fetchUIDs: uids parts: SOGoMailCoreInfoKeys];

      prefetchedInfos = [[NSMutableDictionary alloc] initWithCapacity: max];

      // We MUST NOT use setObjects:forKeys here as the fetch's array does NOT
      // necessarily have the same order!
      allValues = [infos objectForKey: @"fetch"];
      max = [allValues count];

      for (count = 0; count < max ; count++)
	{
	  infos = [allValues objectAtIndex: count];
          key = [NSString stringWithFormat: @"%@", [infos objectForKey: @"uid"]];
	  [prefetchedInfos setObject: infos forKey: key];
	}
    }
  else
    prefetchedInfos = nil;
}

- (NSException *) deleteUIDs: (NSArray *) uids
	      useTrashFolder: (BOOL *) withTrash
		   inContext: (id) localContext
{
  SOGoMailFolder *trashFolder;
  NGImap4Client *client;
  NSString *folderName;
  NSException *error;
  NSString *result;
  BOOL b;

  client = nil;
  trashFolder = nil;
  b = YES;
  if (*withTrash)
    {
      trashFolder = [[self mailAccountFolder] trashFolderInContext: localContext];
      b = NO;
      if ([trashFolder isNotNull])
	{
	  if ([trashFolder isKindOfClass: [NSException class]])
	    error = (NSException *) trashFolder;
	  else
	    {
              if ([self imap4Connection])
                {
                  error = nil;
                  client = [imap4 client];
                  [imap4 selectFolder: [self imap4URL]];
                  folderName = [imap4 imap4FolderNameForURL: [trashFolder imap4URL]];
                  b = YES;
	      
                  // If we are deleting messages within the Trash folder itself, we
                  // do not, of course, try to move messages to the Trash folder.
                  if ([folderName isEqualToString: [imap4 imap4FolderNameForURL: [self imap4URL]]])
                    {
                      *withTrash = NO;
                    }
                  else
                    {
                      // If our Trash folder doesn't exist when we try to copy messages
                      // to it, we create it.
                      b = [self ensureTrashFolder];
		  
                      if (b)
                      {
                        result = [[client copyUids: uids toFolder: folderName]
                                   objectForKey: @"result"];
		  
                        b = [result boolValue];
                      }
                    }
		}
              else
                error = [NSException exceptionWithName: @"SOGoMailException"
                                                reason: @"IMAP connection is invalid"
                                              userInfo: nil];
	    }
	}
      else
        error = [NSException exceptionWithHTTPStatus: 500
 					      reason: @"Did not find Trash folder!"];
    }
  
  if (b)
    {
      if (client == nil)
	{
	  client = [[self imap4Connection] client];
	  [imap4 selectFolder: [self imap4URL]];
	}
      result = [[client storeFlags: [NSArray arrayWithObject: @"Deleted"]
			   forUIDs: uids addOrRemove: YES]
                          objectForKey: @"result"];
      if ([result boolValue])
	{
          if (*withTrash)
            {
              [self markForExpunge];
              if (trashFolder)
                [trashFolder flushMailCaches];
              error = nil;
            }
          else
            {
              // When not using a trash folder, expunge the current folder
              // immediately
              error = [self expunge];
            }
        }
      else
	error
	  = [NSException exceptionWithHTTPStatus:500
					  reason: @"Could not mark UIDs as Deleted"];
    }
  else
    error = [NSException exceptionWithHTTPStatus:500
					  reason: @"Could not copy UIDs"];
  
  return error;
}

- (WOResponse *) archiveUIDs: (NSArray *) uids
              inArchiveNamed: (NSString *) archiveName
                   inContext: (id) localContext
{
  NSException *error;
  NSFileManager *fm;
  NSString *spoolPath, *fileName, *baseName, *extension, *zipPath, *qpFileName;
  NSDictionary *msgs;
  NSArray *messages;
  NSData *content, *zipContent;
  NSTask *zipTask;
  NSMutableArray *zipTaskArguments;
  WOResponse *response;
  int i;

  if (!archiveName)
    archiveName = @"SavedMessages.zip";

  spoolPath = [self userSpoolFolderPath];
  if (![self ensureSpoolFolderPath])
    {
      [self errorWithFormat: @"spool directory '%@' doesn't exist", spoolPath];
      error = [NSException exceptionWithHTTPStatus: 500
                                            reason: @"spool directory does not exist"];
      return (WOResponse *)error;
  }

  zipPath = [[SOGoSystemDefaults sharedSystemDefaults] zipPath];
  fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath: zipPath])
    {
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
                                   parts: [NSArray arrayWithObject: @"BODY.PEEK[]"]];
  messages = [msgs objectForKey: @"fetch"];

  for (i = 0; i < [messages count]; i++)
    {
      content = [[[messages objectAtIndex: i] objectForKey: @"body[]"] objectForKey: @"data"];
      fileName = [NSString stringWithFormat:@"%@/%@.eml", spoolPath, [uids objectAtIndex: i]];;
      [content writeToFile: fileName atomically: YES];
    
      [zipTaskArguments addObject:
                          [NSString stringWithFormat:@"%@.eml", [uids objectAtIndex: i]]];
    }
  
  [zipTask setArguments: zipTaskArguments];
  [zipTask launch];
  [zipTask waitUntilExit];
  
  [zipTask release];
  
  zipContent = [[NSData alloc] initWithContentsOfFile: 
                           [NSString stringWithFormat: @"%@/SavedMessages.zip", spoolPath]];
  
  for (i = 0; i < [zipTaskArguments count]; i++)
    {
      fileName = [zipTaskArguments objectAtIndex: i];
      [fm removeFileAtPath:
            [NSString stringWithFormat: @"%@/%@", spoolPath, fileName] handler: nil];
    }

  response = [context response];
  baseName = [archiveName stringByDeletingPathExtension];
  extension = [archiveName pathExtension];
  if ([extension length] > 0)
    extension = [@"." stringByAppendingString: extension];
  else
    extension = @"";

  qpFileName = [NSString stringWithFormat: @"%@%@",
                         [baseName asQPSubjectString: @"utf-8"],
                         extension];
  [response setHeader: [NSString stringWithFormat: @"application/zip;"
                                 @" name=\"%@\"",
                                 qpFileName]
               forKey: @"content-type"];
  [response setHeader: [NSString stringWithFormat: @"attachment; filename=\"%@\"",
                                 qpFileName]
               forKey: @"Content-Disposition"];
  [response setContent: zipContent];

  [zipContent release];

  return response;
}

- (WOResponse *) archiveAllMessagesInContext: (id) localContext
{
  WOResponse *response;
  NSArray *uids;
  NSString *archiveName;
  EOQualifier *notDeleted;

  if ([self exists])
    {
      notDeleted = [EOQualifier qualifierWithQualifierFormat:
                                  @"(not (flags = %@))", @"deleted"];
      uids = [self fetchUIDsMatchingQualifier: notDeleted
                                 sortOrdering: @"ARRIVAL"];
      archiveName = [NSString stringWithFormat: @"%@.zip", [self relativeImap4Name]];
      response = [self archiveUIDs: uids inArchiveNamed: archiveName
                         inContext: localContext];
    }
  else
    response = (WOResponse *)
      [NSException exceptionWithHTTPStatus: 404
                                    reason: @"Folder does not exist."];

  return response;
}

- (WOResponse *) copyUIDs: (NSArray *) uids
		 toFolder: (NSString *) destinationFolder
		inContext: (id) localContext
{
  NSArray *folders;
  NSString *currentFolderName, *currentAccountName, *destinationAccountName;
  NSMutableString *imapDestinationFolder;
  NGImap4Client *client;
  id result;
  int count, max;

#warning this code will fail on implementation using something else than '/' as delimiter
  imapDestinationFolder = [NSMutableString string];
  folders = [destinationFolder componentsSeparatedByString: @"/"];
  max = [folders count];
  if (max > 1)
    {
      currentAccountName = [[self mailAccountFolder] nameInContainer];
      client = [[self imap4Connection] client];
      [imap4 selectFolder: [self imap4URL]];
      destinationAccountName = [[folders objectAtIndex: 1] fromCSSIdentifier];

      for (count = 2; count < max; count++)
        {
          currentFolderName = [[[folders objectAtIndex: count] substringFromIndex: 6] fromCSSIdentifier];
          [imapDestinationFolder appendFormat: @"/%@", currentFolderName];
        }

      if (client)
        {
          if ([destinationAccountName isEqualToString: currentAccountName])
            {
              // We make sure the destination IMAP folder exist, if not, we create it.
              result = [[client status: imapDestinationFolder
                                 flags: [NSArray arrayWithObject: @"UIDVALIDITY"]]
                         objectForKey: @"result"];
              if (![result boolValue])
                result = [[self imap4Connection] createMailbox: imapDestinationFolder
                                                         atURL: [[self mailAccountFolder] imap4URL]];
              if (!result || [result boolValue])
                result = [client copyUids: uids toFolder: imapDestinationFolder];

              if ([[result valueForKey: @"result"] boolValue])
                result = nil;
              else
                result = [NSException exceptionWithHTTPStatus: 500
                                                       reason: [[[result objectForKey: @"RawResponse"]
                                                                  objectForKey: @"ResponseResult"]
                                                                 objectForKey: @"description"]];
            }
          else
            {
              // Destination folder is in a different account
              SOGoMailAccounts *accounts;
              SOGoMailAccount *account;
              SOGoUserFolder *userFolder;
              
              userFolder = [[context activeUser] homeFolderInContext: context];
              accounts = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
              account = [accounts lookupName: destinationAccountName inContext: localContext acquire: NO];

              if ([account isKindOfClass: [NSException class]])
                {
                  result = [NSException exceptionWithHTTPStatus: 500
                                                         reason: @"Cannot copy messages to other account."];
                }
              else
                {
                  NSEnumerator *messages;
                  NSDictionary *message;
                  NSData *content;
                  NSArray *flags;

                  // Fetch messages
                  result = [client fetchUids: uids parts: [NSArray arrayWithObjects: @"RFC822", @"FLAGS", nil]];
                  if ([[result objectForKey: @"result"] boolValue])
                    {
                      result = [result valueForKey: @"fetch"];
                      if ([result isKindOfClass: [NSArray class]] && [result count] > 0)
                        {
                          // Copy each message to the other account
                          client = [[account imap4Connection] client];
                          [[account imap4Connection] selectFolder: imapDestinationFolder];
                          messages = [result objectEnumerator];
                          result = nil;
                          while (result == nil && (message = [messages nextObject]))
                            {
                              if ((content = [message valueForKey: @"message"]) != nil)
                                {
                                  flags = [message valueForKey: @"flags"];
                                  result = [client append: content toFolder: imapDestinationFolder withFlags: flags];
                                  if ([[result objectForKey: @"result"] boolValue])
                                    result = nil;
                                  else
                                    [self logWithFormat: @"ERROR: Can't append message: %@", result];
                                }
                            }
                        }
                      else
                        {
                          [self logWithFormat: @"ERROR: unexpected IMAP4 result (missing 'fetch'): %@", result];
                          result = [NSException exceptionWithHTTPStatus: 500
                                                                 reason: @"Unexpected IMAP4 result"];
                        }
                    }
                  else
                    {
                      [self logWithFormat: @"ERROR: Can't fetch messages: %@", result];
                      result = [NSException exceptionWithHTTPStatus: 500
                                                             reason: @"Can't fetch messages"];
                    }
                }
            }
        }
      else
        result = [NSException exceptionWithName: @"SOGoMailException"
                                         reason: @"IMAP connection is invalid"
                                       userInfo: nil];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 500
                                           reason: @"Invalid destination."];

  return result;
}

- (WOResponse *) moveUIDs: (NSArray *) uids
		 toFolder: (NSString *) destinationFolder
		inContext: (id) localContext
{
  id result;
  NGImap4Client *client;

  client = [[self imap4Connection] client];
  if (client)
    {
      result = [self copyUIDs: uids toFolder: destinationFolder inContext: localContext];
      if (![result isNotNull])
        {
          result = [client storeFlags: [NSArray arrayWithObject: @"Deleted"]
                              forUIDs: uids addOrRemove: YES];
          if ([[result valueForKey: @"result"] boolValue])
            {
              [self markForExpunge];
              result = nil;
            }
        }
    }
  else
    result = [NSException exceptionWithName: @"SOGoMailException"
                                     reason: @"IMAP connection is invalid"
                                   userInfo: nil];

  return result;
}

- (WOResponse *) markMessagesAsJunkOrNotJunk: (NSArray *) uids
                                        junk: (BOOL) isJunk
{
  NSDictionary *junkSettings;
  NSString *recipient;
  NSException *error;
  unsigned int limit;

  junkSettings = [[[context activeUser] domainDefaults] mailJunkSettings];
  error = nil;

  if ([[junkSettings objectForKey: @"vendor"] caseInsensitiveCompare: @"generic"] == NSOrderedSame)
    {
      if (isJunk)
        recipient = [junkSettings objectForKey: @"junkEmailAddress"];
      else
        recipient = [junkSettings objectForKey: @"notJunkEmailAddress"];

      limit = [[junkSettings objectForKey: @"limit"] intValue];

      // If no limit is set, we only attach one mail at the time
      // to reports sent by SOGo.
      if (!limit)
        limit = 1;

      if ([recipient length])
        {
          NGMimeMessage *messageToSend;
          SOGoMailObject *mailObject;
          NGMimeBodyPart *bodyPart;
          NGMutableHashMap *map;
          NGMimeFileData *fdata;
          NSArray *identities;
          NSData *data;
          id body;

          int i;

          identities = [[self mailAccountFolder] identities];

          for (i = 0; i < [uids count]; i++)
            {
              // If we are starting or reaching the limit, we create
              // a new mail message
              if ((i%limit) == 0)
                {
                  map = [NGMutableHashMap hashMapWithCapacity: 5];

#warning SOPE is just plain stupid here - if you change the case of keys, it will break the encoding of fields
                  [map setObject: @"multipart/mixed" forKey: @"content-type"];
                  [map setObject: @"1.0" forKey: @"MIME-Version"];
                  [map setObject: [[identities objectAtIndex: 0] objectForKey: @"email"] forKey: @"from"];
                  [map setObject: recipient forKey: @"to"];
                  [map setObject: [[NSCalendarDate date] rfc822DateString]  forKey: @"date"];

                  messageToSend = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];
                  body = [[[NGMimeMultipartBody alloc] initWithPart: messageToSend] autorelease];
                }

              mailObject = [self lookupName: [NSString stringWithFormat: @"%@", [uids objectAtIndex: i]]
                                  inContext: context
                                    acquire: NO];

              // We skip emails that might have disappeared before we were able
              // to perform the action
              if ([mailObject isKindOfClass: [NSException class]])
                continue;

              map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];
              [map setObject: @"message/rfc822" forKey: @"content-type"];
              [map setObject: @"8bit" forKey: @"content-transfer-encoding"];
              [map addObject: [NSString stringWithFormat: @"attachment; filename=\"%@\"", [mailObject filenameForForward]] forKey: @"content-disposition"];
              bodyPart = [[[NGMimeBodyPart alloc] initWithHeader: map] autorelease];

              data = [mailObject content];
              fdata = [[NGMimeFileData alloc] initWithBytes: [data bytes]  length: [data length]];

              [bodyPart setBody: fdata];
              RELEASE(fdata);
              [body addBodyPart: bodyPart];

              // We reached the limit or the end of the array
              if ((i%limit) == 0 || i == [uids count]-1)
                {
                  id <SOGoAuthenticator> authenticator;
                  NGMimeMessageGenerator *generator;

                  [messageToSend setBody: body];

                  generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
                  data = [generator generateMimeFromPart: messageToSend];

                  authenticator = [SOGoDAVAuthenticator sharedSOGoDAVAuthenticator];

                  error = [[SOGoMailer mailerWithDomainDefaults: [[context activeUser] domainDefaults]]
                            sendMailData: data
                            toRecipients: [NSArray arrayWithObject: recipient]
                                  sender: [[identities objectAtIndex: 0] objectForKey: @"email"]
                            withAuthenticator: authenticator
                               inContext: context];

                  if (error)
                    break;
                }
            }
        }
    }

  return (WOResponse *) error;
}

- (NSDictionary *) statusForFlags: (NSArray *) flags
{
  NGImap4Client *client;
  NSString *folderName;
  NSDictionary *result, *status;

  client = [[self imap4Connection] client];
  folderName = [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]];
  result = [client status: folderName flags: flags];
  if ([[result objectForKey: @"result"] boolValue])
    status = [[[result objectForKey: @"RawResponse"] objectForKey: @"status"]
               objectForKey: @"flags"];
  else
    status = nil;

  return status;
}

- (unsigned int) unseenCount
{
  NSDictionary *imapResult;
  NGImap4Connection *connection;
  NGImap4Client *client;
  EOQualifier *searchQualifier;
  NSArray *searchResult;
  unsigned int unseen;

  connection = [self imap4Connection];
  client = [connection client];

  if ([connection selectFolder: [self imap4URL]])
    {
      searchQualifier
        = [EOQualifier qualifierWithQualifierFormat: @"flags = %@ AND not flags = %@",
                       @"unseen", @"deleted"];
      imapResult = [client searchWithQualifier: searchQualifier];
      searchResult = [[imapResult objectForKey: @"RawResponse"] objectForKey: @"search"];
      unseen = [searchResult count];
    }
  else
    unseen = 0;

  return unseen;
}

- (NSArray *) fetchUIDsMatchingQualifier: (id) _q
			    sortOrdering: (id) _so
{
  return [self fetchUIDsMatchingQualifier: _q
                             sortOrdering: _so
                                 threaded: NO];
}

- (NSArray *) fetchUIDsMatchingQualifier: (id) _q
			    sortOrdering: (id) _so
                                threaded: (BOOL) _threaded
{
  if (_threaded)
    {
      return [[self imap4Connection] fetchThreadedUIDsInURL: [self imap4URL]
                                                  qualifier: _q
                                               sortOrdering: _so];
    }
  else
    {
      return [[self imap4Connection] fetchUIDsInURL: [self imap4URL]
                                          qualifier: _q
                                       sortOrdering: _so];      
    }
}

- (NSArray *) fetchUIDs: (NSArray *) _uids
		  parts: (NSArray *) _parts
{
  return [[self imap4Connection] fetchUIDs: _uids
                                     inURL: [self imap4URL]
                                     parts: _parts];
}

- (NSArray *) fetchUIDsOfVanishedItems: (uint64_t) modseq
{
  NGImap4Client *client;
  NSDictionary *result;

  client = [[self imap4Connection] client];
  result = [client fetchVanished: modseq];

  return [result objectForKey: @"vanished"];
}

- (NSException *) postData: (NSData *) _data
		     flags: (id) _flags
{
  // We check for the existence of the IMAP folder (likely to be the
  // Sent mailbox) prior to appending messages to it.
  if ([self exists]
      || ![[self imap4Connection] createMailbox: [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]]
                                          atURL: [[self mailAccountFolder] imap4URL]])
    return [[self imap4Connection] postData: _data flags: _flags
                                toFolderURL: [self imap4URL]];
  
  return [NSException exceptionWithHTTPStatus: 502 /* Bad Gateway */
                                       reason: [NSString stringWithFormat: @"%@ is not an IMAP4 folder", [self relativeImap4Name]]];
}

- (NSException *) expunge
{
  NSException *error;

  if ([self imap4Connection])
    error = [imap4 expungeAtURL: [self imap4URL]];
  else
    error = [NSException exceptionWithName: @"SOGoMailException"
                                    reason: @"IMAP connection is invalid"
                                  userInfo: nil];
  return error;
}

- (void) markForExpunge
{
  SOGoUserSettings *us;
  NSMutableDictionary *mailSettings;
  NSString *urlString;

  us = [[context activeUser] userSettings];
  mailSettings = [us objectForKey: @"Mail"];
  if (!mailSettings)
    {
      mailSettings = [NSMutableDictionary dictionaryWithCapacity: 1];
      [us setObject: mailSettings forKey: @"Mail"];
    }

  urlString = [self imap4URLString];
  if (![[mailSettings objectForKey: @"folderForExpunge"]
	 isEqualToString: urlString])
    {
      [mailSettings setObject: [self imap4URLString]
                       forKey: @"folderForExpunge"];
      [us synchronize];
    }
}

- (void) expungeLastMarkedFolder
{
  SOGoUserSettings *us;
  NSMutableDictionary *mailSettings;
  NSString *expungeURL;
  NSURL *folderURL;

  us = [[context activeUser] userSettings];
  mailSettings = [us objectForKey: @"Mail"];
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
	      [us synchronize];
	    }
	}
    }
}

/* flags */

- (NSException *) addFlagsToAllMessages: (id) _f
{
  NSException *error;

  if ([self imap4Connection])
    error = [imap4 addFlags:_f 
                   toAllMessagesInURL: [self imap4URL]];
  else
    error = [NSException exceptionWithName: @"SOGoMailException"
                                    reason: @"IMAP connection is invalid"
                                  userInfo: nil];

  return error;
}

/* name lookup */

- (id) lookupName: (NSString *) _key
	inContext: (id)_ctx
	  acquire: (BOOL) _acquire
{
  NSString *folderName, *fullFolderName, *className;
  SOGoMailAccount *mailAccount;
  id obj;

  obj = [super lookupName: _key inContext: _ctx acquire: NO];
  if (!obj)
    {
      if ([_key hasPrefix: @"folder"])
        {
          mailAccount = [self mailAccountFolder];
          folderName = [[_key substringFromIndex: 6] fromCSSIdentifier];
          fullFolderName = [NSString stringWithFormat: @"%@/%@",
                                     [self traversalFromMailAccount], folderName];
          if ([fullFolderName
                     isEqualToString:
                       [mailAccount draftsFolderNameInContext: _ctx]])
            className = @"SOGoDraftsFolder";
          else if ([fullFolderName
                    isEqualToString:
                  [mailAccount sentFolderNameInContext: _ctx]])
            className = @"SOGoSentFolder";
          else if ([fullFolderName
                     isEqualToString:
                       [mailAccount trashFolderNameInContext: _ctx]])
            className = @"SOGoTrashFolder";
          /*       else if ([folderName isEqualToString:
                   [mailAccount sieveFolderNameInContext: _ctx]])
                   obj = [self lookupFiltersFolder: _key inContext: _ctx]; */
          else
            className = @"SOGoMailFolder";

          obj = [NSClassFromString (className) objectWithName: _key
                                                  inContainer: self];
        }
      else if (isdigit ([_key characterAtIndex: 0])
               && [self exists])
        {
          obj = [SOGoMailObject objectWithName: _key inContainer: self];
          if ([_key hasSuffix: @".eml"])
            _key = [_key substringToIndex: [_key length] - 4];
          [obj setCoreInfos: [prefetchedInfos objectForKey: _key]];
        }
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
  NSException *error;

  if ([self imap4Connection])
    error = [imap4 createMailbox:_name atURL:[self imap4URL]];
  else
    error = [NSException exceptionWithName: @"SOGoMailException"
                                    reason: @"IMAP connection is invalid"
                                  userInfo: nil];

  return error;
}

- (BOOL) exists
{
  return [[self imap4Connection] doesMailboxExistAtURL: [self imap4URL]];
}

- (BOOL) create
{
  NSException *error;
  BOOL rc;

  if ([self imap4Connection])
    {
      error = [imap4 createMailbox: [[self relativeImap4Name] stringByEncodingImap4FolderName]
                             atURL: [container imap4URL]];
      if (error)
        rc = NO;
      else
        {
          [[imap4 client] subscribe: [self absoluteImap4Name]];
          rc = YES;
        }
    }
  else
    rc = NO;

  return rc;
}

- (BOOL) ensureTrashFolder
{
  SOGoMailFolder *trashFolder;
  BOOL rc;

  trashFolder = [[self mailAccountFolder] trashFolderInContext: context];
  rc = NO;
  if (![trashFolder isKindOfClass: [NSException class]])
  {
    rc = [trashFolder exists];
    if (!rc)
      rc = [trashFolder create];
  }
  if (!rc)
    [self errorWithFormat: @"Cannot create Trash Mailbox"];
  return rc;
}

- (NSException *) delete
{
  NSException *error;

  if ([self imap4Connection])
    {
      error = [imap4 deleteMailboxAtURL: [self imap4URL]];
      if (!error)
        [[imap4 client] unsubscribe: [[self imap4URL] path]];
    }
  else
    error = [NSException exceptionWithName: @"SOGoMailException"
                                    reason: @"IMAP connection is invalid"
                                  userInfo: nil];

  return error;
}

- (NSException *) davMoveToTargetObject: (id) _target
				newName: (NSString *) _name
			      inContext: (id)_ctx
{
  NSException *error;
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

  if ([self imap4Connection])
    error = [imap4 moveMailboxAtURL: [self imap4URL] 
                              toURL: destImapURL];
  else
    error = [NSException exceptionWithName: @"SOGoMailException"
                                    reason: @"IMAP connection is invalid"
                                  userInfo: nil];

  return error;
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

- (NSString *) _sogoACLsToIMAPACLs: (NSArray *) sogoAcls
{
  NSMutableString *imapAcls;
  NSEnumerator *acls;
  NSString *currentAcl;
  char character;
  SOGoIMAPAclStyle aclStyle;

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
          aclStyle = [[self mailAccountFolder] imapAclStyle];
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

- (NSString *) _sogoACLUIDToIMAPUID: (NSString *) uid
{
  if ([uid hasPrefix: @"@"])
    return [[[[context activeUser] domainDefaults] imapAclGroupIdPrefix]
             stringByAppendingString: [uid substringFromIndex: 1]];
  else if ([[[context activeUser] domainDefaults] forceExternalLoginWithEmail])
    {
      return [[[SOGoUser userWithLogin: uid] primaryIdentity] objectForKey: @"email"];
    }
  else
    return uid;
}

- (void) _removeIMAPExtUsernames
{
  NSMutableDictionary *newIMAPAcls;
  NSEnumerator *usernames;
  NSString *username;

  if ([mailboxACL isKindOfClass: [NSException class]])
    return;

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

- (void) _convertIMAPGroupnames
{
  NSMutableDictionary *newIMAPAcls;
  NSEnumerator *usernames;
  NSString *username;
  NSString *newUsername;
  NSString *imapPrefix;

  if ([mailboxACL isKindOfClass: [NSException class]])
    return;
  
  imapPrefix = [[[context activeUser] domainDefaults] imapAclGroupIdPrefix];
  
  newIMAPAcls = [[NSMutableDictionary alloc] init];
  
  usernames = [[mailboxACL allKeys] objectEnumerator];
  while ((username = [usernames nextObject]))
    {
      if ([username hasPrefix: imapPrefix])
        newUsername = [@"@" stringByAppendingString: [username substringFromIndex: [imapPrefix length]]];
      else
        newUsername = username;
      [newIMAPAcls setObject: [mailboxACL objectForKey: username]
		   forKey: newUsername];
    }
  [mailboxACL release];
  mailboxACL = newIMAPAcls;
}

- (void) _readMailboxACL
{
  [mailboxACL release];

  mailboxACL = [[self imap4Connection] aclForMailboxAtURL: [self imap4URL]];

  // If the mailbox doesn't exist, we create it. That could happen if
  // a special mailbox (Drafts, Sent, Trash) is deleted from SOGo's web GUI
  // or if any other mailbox is deleted behind SOGo's back.
  if ([mailboxACL isKindOfClass: [NSException class]])
    {
      [[self imap4Connection] createMailbox: [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]]
				      atURL: [[self mailAccountFolder] imap4URL]];
      mailboxACL = [[self imap4Connection] aclForMailboxAtURL: [self imap4URL]];
    }

  [mailboxACL retain];

  [self _convertIMAPGroupnames];
  if ([[self mailAccountFolder] imapAclConformsToIMAPExt])
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
  NSString *path;

  acls = [NSMutableArray array];

  mailAccount = [self mailAccountFolder];
  path = [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]];

  if ([self         _path: path
           isInNamespaces: [mailAccount otherUsersFolderNamespaces]] ||
      [self         _path: path
           isInNamespaces: [mailAccount sharedFolderNamespaces]])
    [acls addObject: SOGoRole_ObjectViewer];
  else
    // Inside user's namespace, automatically owner
    [acls addObject: SoRole_Owner];

  return acls;
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSMutableArray *acls;
  NSString *userAcls, *userLogin;

  userLogin = [[context activeUser] login];
  if ([uid isEqualToString: userLogin])
    // Login user wants her ACLs
    acls = [self _sharesACLs];
  else
    // Login user wants the ACLs of another user
    acls = [NSMutableArray array];

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
    [client deleteACL: folderName uid: [self _sogoACLUIDToIMAPUID: currentUID]];
  [mailboxACL release];
  mailboxACL = nil;
}

- (void) setRoles: (NSArray *) roles
	  forUser: (NSString *) uid
{
  NSString *acls, *folderName;

  acls = [self _sogoACLsToIMAPACLs: roles];
  folderName = [[self imap4Connection] imap4FolderNameForURL: [self imap4URL]];
  [[imap4 client] setACL: folderName rights: acls uid: [self _sogoACLUIDToIMAPUID: uid]];

  [mailboxACL release];
  mailboxACL = nil;
}

- (NSString *) defaultUserID
{
  return defaultUserID;
}

- (NSString *) otherUsersPathToFolder
{
  NSString *userPath, *selfPath, *otherUsers;
  SOGoMailAccount *account;
  NSArray *otherUsersFolderNamespaces;

#warning this method should be checked
  account = [self mailAccountFolder];
  otherUsersFolderNamespaces = [account otherUsersFolderNamespaces];

  selfPath = [[self imap4URL] path];
  if ([self _path: selfPath isInNamespaces: otherUsersFolderNamespaces]
      || [self _path: selfPath
               isInNamespaces: [account sharedFolderNamespaces]])
    userPath = selfPath;
  else
    {
      if ([otherUsersFolderNamespaces count])
        {
          /* can we really have more than one "other users" namespace? */
          otherUsers = [[otherUsersFolderNamespaces objectAtIndex: 0]
                         stringByEscapingURL];
          userPath = [NSString stringWithFormat: @"/%@/%@%@",
                               otherUsers, owner, selfPath];
        }
      else
	userPath = nil;
    }

  return userPath;
}

- (NSString *) httpURLForAdvisoryToUser: (NSString *) uid
{
  NSString *otherUsersPath, *url;

  otherUsersPath = [self otherUsersPathToFolder];
  if (otherUsersPath)
    {
      url = [NSString stringWithFormat: @"%@/0%@",
		      [self soURLToBaseContainerForUser: uid],
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
  NSString *login, *mailSpoolPath;
  SOGoUser *currentUser;

  currentUser = [context activeUser];
  login = [currentUser login];
  mailSpoolPath = [[currentUser domainDefaults] mailSpoolPath];

  return [NSString stringWithFormat: @"%@/%@",
		   mailSpoolPath, login];
}

- (BOOL) ensureSpoolFolderPath
{
  NSFileManager *fm;

  fm = [NSFileManager defaultManager];
  
  return ([fm createDirectoriesAtPath: [self userSpoolFolderPath]
                           attributes: nil]);
}

- (NSString *) displayName
{
  return [[self relativeImap4Name] stringByDecodingImap4FolderName];
}

- (NSDictionary *) davIMAPFieldsTable
{
  static NSMutableDictionary *davIMAPFieldsTable = nil;

  if (!davIMAPFieldsTable)
    {
      davIMAPFieldsTable = [NSMutableDictionary new];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (DATE)]"
                             forKey: @"{urn:schemas:httpmail:}date"];
      [davIMAPFieldsTable setObject: @""
                             forKey: @"{urn:schemas:httpmail:}hasattachment"];
      [davIMAPFieldsTable setObject: @""
                             forKey: @"{urn:schemas:httpmail:}read"];
      [davIMAPFieldsTable setObject: @"BODY"
                             forKey: @"{urn:schemas:httpmail:}textdescription"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (CC)]"
                             forKey: @"{urn:schemas:mailheader:}cc"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (DATE)]"
                             forKey: @"{urn:schemas:mailheader:}date"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (FROM)]"
                             forKey: @"{urn:schemas:mailheader:}from"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (INREPLYTO)]"
                             forKey: @"{urn:schemas:mailheader:}in-reply-to"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (MESSAGEID)]"
                             forKey: @"{urn:schemas:mailheader:}message-id"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (RECEIVED)]"
                             forKey: @"{urn:schemas:mailheader:}received"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (REFERENCES)]"
                             forKey: @"{urn:schemas:mailheader:}references"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (SUBJECT)]"
                             forKey: @"{DAV:}displayname"];
      [davIMAPFieldsTable setObject: @"BODY[HEADER.FIELDS (TO)]"
                             forKey: @"{urn:schemas:mailheader:}to"];
    }

  return davIMAPFieldsTable;
}

- (BOOL) _sortElementIsAscending: (NGDOMNodeWithChildren <DOMElement> *) sortElement
{
  NSString *davReverseAttr;
  BOOL orderIsAscending;

  orderIsAscending = YES;

  davReverseAttr = [sortElement attribute: @"order"];
  if ([davReverseAttr isEqualToString: @"descending"])
    orderIsAscending = NO;
  else if ([davReverseAttr length]
           && ![davReverseAttr isEqualToString: @"ascending"])
    [self errorWithFormat: @"unrecognized sort order: '%@'",
          davReverseAttr];

  return orderIsAscending;
}

- (NSArray *) _sortOrderingsFromSortElement: (NGDOMNodeWithChildren *) sortElement
{
  static NSMutableDictionary *criteriasMap = nil;
  NSArray *davSortCriterias;
  NSMutableArray *sortOrderings;
  SEL sortOrderingOrder;
  NSString *davSortVerb, *imapSortVerb;
  EOSortOrdering *currentOrdering;
  int count, max;

  if (!criteriasMap)
    {
      criteriasMap = [NSMutableDictionary new];
      [criteriasMap setObject: @"ARRIVAL"
                       forKey: @"{urn:schemas:mailheader:}received"];
      [criteriasMap setObject: @"DATE"
                       forKey: @"{urn:schemas:mailheader:}date"];
      [criteriasMap setObject: @"FROM"
                       forKey: @"{urn:schemas:mailheader:}from"];
      [criteriasMap setObject: @"TO"
                       forKey: @"{urn:schemas:mailheader:}to"];
      [criteriasMap setObject: @"CC"
                       forKey: @"{urn:schemas:mailheader:}cc"];
      [criteriasMap setObject: @"SUBJECT"
                       forKey: @"{DAV:}displayname"];
      [criteriasMap setObject: @"SUBJECT"
                       forKey: @"{urn:schemas:mailheader:}subject"];
      [criteriasMap setObject: @"SIZE"
                       forKey: @"{DAV:}getcontentlength"];
    }

  sortOrderings = [NSMutableArray array];

  if ([self _sortElementIsAscending: (NGDOMNodeWithChildren <DOMElement> *)sortElement])
    sortOrderingOrder = EOCompareAscending;
  else
    sortOrderingOrder = EOCompareDescending;

  davSortCriterias = [sortElement flatPropertyNameOfSubElements];
  max = [davSortCriterias count];
  for (count = 0; count < max; count++)
    {
      davSortVerb = [davSortCriterias objectAtIndex : count];
      imapSortVerb = [criteriasMap objectForKey: davSortVerb];
      if (imapSortVerb)
        {
          currentOrdering
            = [EOSortOrdering sortOrderingWithKey: imapSortVerb
                                         selector: sortOrderingOrder];
          [sortOrderings addObject: currentOrdering];
        }
      else
        [self errorWithFormat: @"unrecognized sort key: '%@'", davSortVerb];
    }

  return sortOrderings;
}

- (NSArray *) _fetchMessageProperties: (NSArray *) properties
                    matchingQualifier: (EOQualifier *) searchQualifier
                     andSortOrderings: (NSArray *) sortOrderings
{
  NGImap4Client *client;
  NSDictionary *response;
  NSArray *messages, *values = nil;
  NSString *resultKey;

  client = [[self imap4Connection] client];
  [imap4 selectFolder: [self imap4URL]];

  if ([sortOrderings count])
    {
      response = [client sort: sortOrderings qualifier: searchQualifier
                     encoding: @"UTF-8"];
      resultKey = @"sort";
    }
  else
    {
      response = [client searchWithQualifier: searchQualifier];
      resultKey = @"search";
    }

   if ([[response objectForKey: @"result"] boolValue])
     {
       messages = [response objectForKey: resultKey];
       if ([messages count] > 0)
         {
           response = [client fetchUids: messages parts: properties];
           values = [response objectForKey: @"fetch"];
         }
     }

  return values;
}

- (NSArray *) _davPropstatsWithProperties: (NSArray *) davProperties
                       andMethodSelectors: (SEL *) selectors
                              fromMessage: (NSString *) messageId
{
  SOGoMailObject *message;
  unsigned int count, max;
  NSMutableArray *properties200, *properties404, *propstats;
  NSDictionary *propContent;
  NSString *messageUrl;
  id result;

  propstats = [NSMutableArray arrayWithCapacity: 2];

  max = [davProperties count];
  properties200 = [NSMutableArray arrayWithCapacity: max];
  properties404 = [NSMutableArray arrayWithCapacity: max];

  message = [self lookupName: messageId
                   inContext: context
                     acquire: NO];
  for (count = 0; count < max; count++)
    {
      if (selectors[count]
          && [message respondsToSelector: selectors[count]])
        result = [message performSelector: selectors[count]];
      else
        result = nil;

      if (result)
        {
          propContent = [[davProperties objectAtIndex: count]
                             asWebDAVTupleWithContent: result];
          [properties200 addObject: propContent];
        }
      else
        {
          propContent = [[davProperties objectAtIndex: count]
                          asWebDAVTuple];
          [properties404 addObject: propContent];
        }
    }

  messageUrl = [NSString stringWithFormat: @"%@%@.eml", 
                         [self davURL], messageId];
  [propstats addObject: davElementWithContent (@"href", XMLNS_WEBDAV, 
                                               messageUrl)];

  if ([properties200 count])
    [propstats addObject: [properties200
                            asDAVPropstatWithStatus: @"HTTP/1.1 200 OK"]];
  if ([properties404 count])
    [propstats addObject: [properties404
                            asDAVPropstatWithStatus: @"HTTP/1.1 404 Not Found"]];

  return propstats;
}

- (void) _appendProperties: (NSArray *) properties
              fromMessages: (NSArray *) messages
                toResponse: (WOResponse *) response
{
  NSDictionary *davElement;
  NSArray *propstats;
  NSMutableArray *all;
  NSString *message, *davString;
  SEL *selectors;
  int max, count;

  max = [properties count];
  selectors = NSZoneMalloc (NULL, sizeof (max * sizeof (SEL)));

  for (count = 0; count < max; count++)
    selectors[count]
      = SOGoSelectorForPropertyGetter ([properties objectAtIndex: count]);

  max = [messages count];
  all = [NSMutableArray array];
  for (count = 0; count < max; count++)
    {
      message = [[messages objectAtIndex: count] stringValue];
      propstats = [self _davPropstatsWithProperties: properties
                                 andMethodSelectors: selectors
                                         fromMessage: message];
      davElement = davElementWithContent (@"response", XMLNS_WEBDAV, 
                                          propstats);

      [all addObject: davElement];
    }

  davString = [davElementWithContent (@"multistatus", XMLNS_WEBDAV, all)
                asWebDavStringWithNamespaces: nil];
  [response appendContentString: davString];
  NSZoneFree (NULL, selectors);
}

- (NSDictionary *) _davIMAPFieldsForProperties: (NSArray *) properties
{
  NSMutableDictionary *davIMAPFields;
  NSDictionary *davIMAPFieldsTable;
  NSString *imapField, *property;
  unsigned int count, max;

  davIMAPFieldsTable = [self davIMAPFieldsTable];

  max = [properties count];
  davIMAPFields = [NSMutableDictionary dictionaryWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      property = [properties objectAtIndex: count];
      imapField = [davIMAPFieldsTable objectForKey: property];
      if (imapField)
        [davIMAPFields setObject: imapField forKey: property];
      else
        [self errorWithFormat: @"DAV property '%@' has no matching IMAP field,"
          @" response could be incomplete", property];
    }

  return davIMAPFields;
}

- (NSDictionary *) parseDAVRequestedProperties: (NGDOMNodeWithChildren *) propElement
{
  NSArray *properties;
  NSDictionary *imapFieldsTable;

  properties = [propElement flatPropertyNameOfSubElements];
  imapFieldsTable = [self _davIMAPFieldsForProperties: properties];

  return imapFieldsTable;
}

/* TODO:
   - populate only required keys in returned SOGoMailObject rather that
     fetching the whole envelope and stuff
   - use EOSortOrdering rather than an NSString
 */
- (id) davMailQuery: (id) queryContext
{
  WOResponse *r;
  id <DOMDocument> document;
  id <DOMElement> filterElement;
  NGDOMNodeWithChildren *documentElement, *propElement, *sortElement;
  NSDictionary *properties;
  NSArray *messages, *sortOrderings;
  EOQualifier *searchQualifier;

  r = [context response];
  [r prepareDAVResponse];

  document = [[context request] contentAsDOMDocument];
  documentElement = [document documentElement];

  propElement = (NGDOMNodeWithChildren *) [documentElement
                                            firstElementWithTag: @"prop"
                                                    inNamespace: XMLNS_WEBDAV];
  properties = [self parseDAVRequestedProperties: propElement];
  filterElement = [documentElement firstElementWithTag: @"mail-filters"
                                           inNamespace: XMLNS_INVERSEDAV];
  searchQualifier = [EOQualifier
                      qualifierFromMailDAVMailFilters: filterElement];
  sortElement = (NGDOMNodeWithChildren *) [documentElement
                                            firstElementWithTag: @"sort"
                                                    inNamespace: XMLNS_INVERSEDAV];
  sortOrderings = [self _sortOrderingsFromSortElement: sortElement];

  messages = [self _fetchMessageProperties: [properties allKeys]
                         matchingQualifier: searchQualifier
                          andSortOrderings: sortOrderings];
  [self _appendProperties: [properties allKeys]
             fromMessages: messages
               toResponse: r];

  return r;
}

- (NSException *) _appendMessageData: (NSData *) data
                             usingId: (int *) imap4id;
{
  NGImap4Client *client;
  NSString *folderName;
  NSException *error;
  id result;

  error = nil;
  client = [imap4 client];

  folderName = [imap4 imap4FolderNameForURL: [self imap4URL]];
  result = [client append: data toFolder: folderName withFlags: nil];

  if ([[result objectForKey: @"result"] boolValue])
    {
      if (imap4id)
        *imap4id = [self IMAP4IDFromAppendResult: result];
    }
  else
    error = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
                                          reason: @"Failed to store message"];

  return error;
}

- (id) appendMessage: (NSData *) message
             usingId: (int *) imap4id
{
  NSException *error;
  WOResponse *response;
  NSString *location;

  error = [self _appendMessageData: message
                           usingId: imap4id];
  if (error)
    response = (WOResponse *) error;
  else
    {
      response = [context response];
      [response setStatus: 201];
      location = [NSString stringWithFormat: @"%@%d.eml",
                           [self davURL], *imap4id];
      [response setHeader: location forKey: @"location"];
    }

  return response;
}

- (NSString *) className
{
  return NSStringFromClass([self class]);
}

- (id) PUTAction: (WOContext *) _ctx
{
  WORequest *rq;
  NSException *error;
  WOResponse *response;
  int imap4id;

  error = [self matchesRequestConditionInContext: _ctx];
  if (error)
    response = (WOResponse *) error;
  else
    {
      rq = [_ctx request];
      response = [self appendMessage: [rq content]
                             usingId: &imap4id];
    }

  return response;
}

- (NSCalendarDate *) mostRecentMessageDate
{
  NSArray *values;
  NSCalendarDate *date = nil;

  values = [self _fetchMessageProperties: [NSArray arrayWithObject: @"ENVELOPE"]
                       matchingQualifier: nil
                        andSortOrderings: [NSArray arrayWithObject: @"REVERSE DATE"]];
  if ([values count] > 0)
    date = [[[values objectAtIndex: 0] objectForKey: @"envelope"] date];

  return date;
}

- (NSString *) davCollectionTagFromId: (NSString *) theId
{
  NSString *tag;

  tag = @"-1";

  if ([self imap4Connection])
    {
      NSDictionary *result;
      unsigned int modseq, uid;

      uid = [theId intValue];
      result = [[imap4 client] fetchModseqForUid: uid];
      modseq = [[[[result objectForKey: @"RawResponse"]  objectForKey: @"fetch"] objectForKey: @"modseq"] intValue];
      
      if (modseq < 1)
        modseq = 1;

      tag = [NSString stringWithFormat: @"%d-%d", uid, modseq];
    }

  return tag;
}

- (NSString *) davCollectionTag
{
  NSString *tag;

  tag = @"-1";

  if ([self imap4Connection])
    {
      NSString *folderName;
      NSDictionary *result;

      folderName = [imap4 imap4FolderNameForURL: [self imap4URL]];

      [[imap4 client] unselect];
      
      result = [[imap4 client] select: folderName];

      tag = [NSString stringWithFormat: @"%@-%@", [result objectForKey: @"uidnext"], [result objectForKey: @"highestmodseq"]];
    }

  return tag;
}

//
// FIXME - see below for code refactoring with MAPIStoreMailFolder.
//
- (EOQualifier *) _nonDeletedQualifier
{
  static EOQualifier *nonDeletedQualifier = nil;
  EOQualifier *deletedQualifier;

  if (!nonDeletedQualifier)
    {
      deletedQualifier
        = [[EOKeyValueQualifier alloc] 
                 initWithKey: @"FLAGS"
            operatorSelector: EOQualifierOperatorContains
                       value: [NSArray arrayWithObject: @"Deleted"]];
      nonDeletedQualifier = [[EONotQualifier alloc]
                              initWithQualifier: deletedQualifier];
      [deletedQualifier release];
    }

  return nonDeletedQualifier;
}



//
// Check updated items
//
// . UID FETCH 1:* (UID) (CHANGEDSINCE 1)
// * 1 FETCH (UID 542 MODSEQ (7))
// * 2 FETCH (UID 553 MODSEQ (14))
// * 3 FETCH (UID 554 MODSEQ (16))
// * 4 FETCH (UID 555 MODSEQ (15))
// * 5 FETCH (UID 559 MODSEQ (17))
// * 6 FETCH (UID 560 MODSEQ (18))
// * 7 FETCH (UID 561 MODSEQ (19))
//
// SORT + MODSEQ:  http://www.watersprings.org/pub/id/draft-melnikov-condstore-sort-00.txt
// With date, not modseq
// . UID SORT (DATE) UTF-8 (NOT DELETED) (SINCE "15-Mar-2014")
// * SORT 553 542 555 554 601 559 560 561 565 602 603 605 611 610 612 613 614 615 616 617 618 621 619 620 622 623
//
// . UID SORT (DATE) UTF-8 ((MODSEQ 64) (NOT DELETED)) (SINCE "15-Mar-2014")
// * SORT 623 624 (MODSEQ 65)
// . OK Completed (2 msgs in 0.000 secs)
//
// ".. the server MUST also append (to the end of the untagged SORT response) the highest mod-sequence for all messages being returned."
//                                                    
// To get the modseq of a specific message:
//
// . UID FETCH 124569:124569 (UID MODSEQ)
// * 4900 FETCH (UID 124569 MODSEQ (2))
//
//
// To get deleted messages
//
// . UID FETCH 1:* (UID) (CHANGEDSINCE 1 VANISHED)
// * VANISHED (EARLIER) 1:541,543:552,556:558,562:564,566:600,604,606:609
// * 1 FETCH (UID 542 MODSEQ (7))
// * 2 FETCH (UID 553 MODSEQ (14))
// * 3 FETCH (UID 554 MODSEQ (16))
// * 4 FETCH (UID 555 MODSEQ (15))
// * 5 FETCH (UID 559 MODSEQ (17))
// * 6 FETCH (UID 560 MODSEQ (18))
// * 7 FETCH (UID 561 MODSEQ (19))
//
//
// fetchUIDsOfVanishedItems ..
//
// . uid fetch 1:* (FLAGS) (changedsince 176 vanished)
// * VANISHED (EARLIER) 36
//
// 
// FIXME: refactor MAPIStoreMailFolder.m - synchroniseCache to use this method
//
- (NSArray *) syncTokenFieldsWithProperties: (NSDictionary *) theProperties
                          matchingSyncToken: (NSString *) theSyncToken
                                   fromDate: (NSCalendarDate *) theStartDate
                                initialLoad: (BOOL) initialLoadInProgress
{
  EOQualifier *searchQualifier;
  NSMutableArray *allTokens;
  NSArray *a, *uids;
  NSDictionary *d;
  id fetchResults;

  int highestmodseq = 0, i;

  allTokens = [NSMutableArray array];

  if (![theSyncToken isEqualToString: @"-1"])
    {
      a = [theSyncToken componentsSeparatedByString: @"-"];
      highestmodseq = [[a objectAtIndex: 1] intValue];
    }
  
  // We first make sure QRESYNC is enabled
  [[self imap4Connection] enableExtensions: [NSArray arrayWithObject: @"QRESYNC"]];
   

  // We fetch new messages and modified messages
  if (highestmodseq)
    {    
      EOKeyValueQualifier *kvQualifier;
      NSNumber *nextModseq;

      nextModseq = [NSNumber numberWithUnsignedLongLong: highestmodseq];
      kvQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"modseq"
                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                      value: nextModseq];
      searchQualifier = [[EOAndQualifier alloc]
                          initWithQualifiers:
                            kvQualifier, nil];
      [kvQualifier release];
      [searchQualifier autorelease];
    }
  else
    {
      searchQualifier = nil;
    }

  if (theStartDate)
    {
      EOQualifier *sinceDateQualifier;
      
      sinceDateQualifier = [EOQualifier qualifierWithQualifierFormat:
                                          @"(DATE >= %@)", theStartDate];
      searchQualifier = [[EOAndQualifier alloc] initWithQualifiers: sinceDateQualifier, searchQualifier,
                                                nil];
      [searchQualifier autorelease];
    }
  

  // we fetch modified or added uids
  uids = [self fetchUIDsMatchingQualifier: searchQualifier
                             sortOrdering: nil];

  fetchResults = [(NSDictionary *)[self fetchUIDs: uids
                                            parts: [NSArray arrayWithObjects: @"modseq", @"flags", nil]]
                     objectForKey: @"fetch"];
  
  /* NOTE: we sort items manually because Cyrus does not properly sort
     entries with a MODSEQ of 0 */
  fetchResults
    = [fetchResults sortedArrayUsingFunction: _compareFetchResultsByMODSEQ
                                     context: NULL];

  for (i = 0; i < [fetchResults count]; i++)
    { 
      if ([[[fetchResults objectAtIndex: i] objectForKey: @"flags"] containsObject: @"deleted"] && initialLoadInProgress)
        continue;

      d = [NSDictionary dictionaryWithObject: ([[[fetchResults objectAtIndex: i] objectForKey: @"flags"] containsObject: @"deleted"]) ? [NSNull null] : [[fetchResults objectAtIndex: i] objectForKey: @"modseq"]
                                      forKey: [[[fetchResults objectAtIndex: i] objectForKey: @"uid"] stringValue]];
      [allTokens addObject: d];
    }
  

  // We fetch deleted ones
  if (highestmodseq == 0)
    highestmodseq = 1;

  if (highestmodseq > 0 && !initialLoadInProgress)
    {
      id uid;

      uids = [self fetchUIDsOfVanishedItems: highestmodseq];
      
      for (i = 0; i < [uids count]; i++)
        {
          uid = [[uids objectAtIndex: i] stringValue];
          d = [NSDictionary dictionaryWithObject: [NSNull null]  forKey: uid];
          [allTokens addObject: d];
        }
    }

  return allTokens;
}

@end /* SOGoMailFolder */

@implementation SOGoSpecialMailFolder

- (BOOL) isSpecialFolder
{
  return YES;
}

@end
