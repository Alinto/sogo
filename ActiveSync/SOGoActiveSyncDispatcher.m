/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#include "SOGoActiveSyncDispatcher.h"

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOCoreApplication.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <NGExtensions/NGBase64Coding.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSString+Encoding.h>

#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NSString+Imap4.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>
#import <NGMime/NGMimeType.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGConcreteMimeType.h>
#import <NGMail/NGMimeMessageParser.h>
#import <NGMail/NGMimeMessageGenerator.h>

#import <DOM/DOMElement.h>
#import <DOM/DOMSaxBuilder.h>

#import <SOGo/NSArray+DAV.h>
#import <SOGo/NSDictionary+DAV.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoCacheGCSObject.h>
#import <SOGo/SOGoDAVAuthenticator.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/GCSSpecialQueries+SOGoCacheObject.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/WORequest+SOGo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoPermissions.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoAppointmentObject.h>

#import <Contacts/SOGoContactGCSFolder.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactSourceFolder.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailBodyPart.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject+Draft.h>
#import <Mailer/SOGoSentFolder.h>
#import <Mailer/NSString+Mail.h>
#import <Mailer/SOGoSentFolder.h>

#import <Foundation/NSString.h>

#include "iCalEvent+ActiveSync.h"
#include "iCalToDo+ActiveSync.h"
#include "NGMimeMessage+ActiveSync.h"
#include "NGVCard+ActiveSync.h"
#include "NSCalendarDate+ActiveSync.h"
#include "NSData+ActiveSync.h"
#include "NSDate+ActiveSync.h"
#include "NSString+ActiveSync.h"
#include "SOGoMailObject+ActiveSync.h"

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>

#include <signal.h>
#include <unistd.h>

#ifdef HAVE_OPENSSL
#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/x509.h>
#endif

void handle_eas_terminate(int signum)
{
  NSLog(@"Forcing termination of EAS loop.");
  easShouldTerminate = YES;
  [[WOCoreApplication application] terminateAfterTimeInterval: 1];
}

@interface SOGoActiveSyncDispatcher (Sync)

- (NSMutableDictionary *) _folderMetadataForKey: (NSString *) theFolderKey;
- (void) _setFolderMetadata: (NSDictionary *) theFolderMetadata forKey: (NSString *) theFolderKey;
- (void) _setOrUnsetSyncRequest: (BOOL) set
                       collections: (NSArray *) collections;
- (NSString *) _getNameInCache: (id) theCollection withType: (SOGoMicrosoftActiveSyncFolderType) theFolderType;

@end

@implementation SOGoActiveSyncDispatcher

- (id) init
{
  [super init];

  debugOn = [[SOGoSystemDefaults sharedSystemDefaults] easDebugEnabled];
  folderTableURL = nil;
  imapFolderGUIDS = nil;
  syncRequest = nil;

  easShouldTerminate = NO;
  signal(SIGTERM, handle_eas_terminate);

  return self;
}

- (void) dealloc
{
  RELEASE(folderTableURL);
  RELEASE(imapFolderGUIDS);
  RELEASE(syncRequest);
  [super dealloc];
}

- (void) _ensureFolder: (SOGoMailFolder *) mailFolder
{
  BOOL rc;

  if (![mailFolder isKindOfClass: [NSException class]])
  {
    rc = [mailFolder exists];
    if (!rc)
      rc = [mailFolder create];
  }
}

- (void) _setFolderSyncKey: (NSString *) theSyncKey
{
  SOGoCacheGCSObject *o;

  o = [SOGoCacheGCSObject objectWithName: [context objectForKey: @"DeviceId"]  inContainer: nil];
  [o setObjectType: ActiveSyncGlobalCacheObject];
  [o setTableUrl: [self folderTableURL]];
  [o reloadIfNeeded];
  
  [[o properties] setObject: theSyncKey
                     forKey: @"FolderSyncKey"];
  [o save];
}

- (NSMutableDictionary *) globalMetadataForDevice
{
  SOGoCacheGCSObject *o;

  o = [SOGoCacheGCSObject objectWithName: [context objectForKey: @"DeviceId"]  inContainer: nil  useCache: NO];
  [o setObjectType: ActiveSyncGlobalCacheObject];
  [o setTableUrl: [self folderTableURL]];
  [o reloadIfNeeded];
  
  return [o properties];
}

- (unsigned int) _softDeleteCountWithFilter: (NSCalendarDate *) theFilter
                               collectionId: (NSString *) theCollectionId
{
  NSMutableDictionary *dateCache;
  NSMutableArray *sdUids;
  SOGoCacheGCSObject *o;
  NSArray *allKeys;
  NSString *key;

  int i;

  sdUids = [NSMutableArray array];
  
  if (theFilter)
    {
      o = [SOGoCacheGCSObject objectWithName: [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], theCollectionId] inContainer: nil];
      [o setObjectType: ActiveSyncFolderCacheObject];
      [o setTableUrl: [self folderTableURL]];
      [o reloadIfNeeded];

      dateCache = [[o properties] objectForKey: @"DateCache"];
      allKeys = [dateCache allKeys];

      for (i = 0; i < [allKeys count]; i++)
        {
          key = [allKeys objectAtIndex: i];
          
          if ([[dateCache objectForKey:key] compare: theFilter ] == NSOrderedAscending)
            [sdUids addObject: [dateCache objectForKey:key]];
        }
    }
  
  return [sdUids count];
}

- (id) globallyUniqueIDToIMAPFolderName: (NSString *) theIdToTranslate
                                   type: (SOGoMicrosoftActiveSyncFolderType) theFolderType
{
  if (theFolderType == ActiveSyncMailFolder)
    {
      SOGoMailAccounts *accountsFolder;
      SOGoMailAccount *accountFolder;
      SOGoUserFolder *userFolder;

      if (!imapFolderGUIDS)
        {
          userFolder = [[context activeUser] homeFolderInContext: context];
          accountsFolder = [userFolder lookupName: @"Mail" inContext: context acquire: NO];
          accountFolder = [accountsFolder lookupName: @"0" inContext: context acquire: NO];

          // Get the GUID of the IMAP folder
          imapFolderGUIDS = [accountFolder imapFolderGUIDs];
          [imapFolderGUIDS retain];

        }

        return [[[imapFolderGUIDS allKeysForObject:  [NSString stringWithFormat: @"folder%@", theIdToTranslate]] objectAtIndex: 0] substringFromIndex: 6] ;
    }
  
  return theIdToTranslate;
}

//
//
//
- (SOGoAppointmentObject *) _eventObjectWithUID: (NSString *) uid
{
  SOGoAppointmentFolder *folder;
  SOGoAppointmentObject *eventObject;
  NSArray *folders;
  NSEnumerator *e;
  NSString *cname;

  eventObject = nil;

  folders = [[[context activeUser] calendarsFolderInContext: context] subFolders];
  e = [folders objectEnumerator];
  while (eventObject == nil && (folder = [e nextObject]))
    {
      cname = [folder resourceNameForEventUID: uid];
      if (cname)
        {
          eventObject = [folder lookupName: cname inContext: context
                                   acquire: NO];
          if ([eventObject isKindOfClass: [NSException class]])
            eventObject = nil;
        }
    }

  if (eventObject)
    return eventObject;
  else
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */];
}

//
//
//
- (id) collectionFromId: (NSString *) theCollectionId
                   type: (SOGoMicrosoftActiveSyncFolderType) theFolderType
{
  id collection;

  collection = nil;

  switch (theFolderType)
    {
    case ActiveSyncContactFolder:
      {
        collection = [[[[context activeUser] homeFolderInContext: context] lookupName: @"Contacts" inContext: context acquire: NO] lookupName: theCollectionId inContext: context acquire: NO];
        if (!collection || ([collection isKindOfClass: [NSException class]]))
           collection = nil;

      }
      break;
    case ActiveSyncEventFolder:
    case ActiveSyncTaskFolder:
      {
        collection = [[[[context activeUser] homeFolderInContext: context] lookupName: @"Calendar" inContext: context acquire: NO] lookupName: theCollectionId inContext: context acquire: NO];
        if (!collection || ([collection isKindOfClass: [NSException class]]))
           collection = nil;
      }
      break;
    case ActiveSyncMailFolder:
    default:
      {
        SOGoMailAccounts *accountsFolder;
        SOGoMailFolder *currentFolder;
        SOGoUserFolder *userFolder;
        
        userFolder = [[context activeUser] homeFolderInContext: context];
        accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
        currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];
                
        collection = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", theCollectionId]
                                     inContext: context
                                       acquire: NO];
        if (![(SOGoMailFolder *)collection exists]) 
           collection = nil;
      }
    }

  return collection;
}

//
//
//
- (void) processFolderCreate: (id <DOMElement>) theDocumentElement
                  inResponse: (WOResponse *) theResponse
{
  NSString *parentId, *displayName, *nameInContainer, *syncKey;
  SOGoUserFolder *userFolder;
  NSMutableString *s;
  NSData *d;

  int type;

  parentId = [[(id)[theDocumentElement getElementsByTagName: @"ParentId"] lastObject] textValue];
  displayName = [[(id)[theDocumentElement getElementsByTagName: @"DisplayName"] lastObject] textValue];
  type = [[[(id)[theDocumentElement getElementsByTagName: @"Type"] lastObject] textValue] intValue];
  userFolder = [[context activeUser] homeFolderInContext: context];

  // See 2.2.3.170.2 Type (FolderCreate) - http://msdn.microsoft.com/en-us/library/gg675445(v=exchg.80).aspx
  // We support the following types:
  //
  // 12 User-created mail folder
  // 13 User-created Calendar folder
  // 14 User-created Contacts folder
  // 15 User-created Tasks folder
  //
  switch (type)
    {
    case 12:
      {
        SOGoMailAccounts *accountsFolder;
        SOGoMailFolder *newFolder;
        id currentFolder;
        
        accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
        currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];

        // If the parrent is 0 -> ok ; otherwise need to build the foldername based on parentId + displayName
        if ([parentId isEqualToString: @"0"])
          newFolder = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", [displayName stringByEncodingImap4FolderName]]
                                      inContext: context
                                        acquire: NO];
        else
          {
            parentId = [self globallyUniqueIDToIMAPFolderName: [[parentId stringByUnescapingURL] substringFromIndex: 5]  type: ActiveSyncMailFolder];
            newFolder = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@/%@", [parentId stringByEncodingImap4FolderName],
                                                             [displayName stringByEncodingImap4FolderName]]
                                        inContext: context
                                          acquire: NO];
          }
        
        // FIXME
        // handle exists (status == 2)
        // handle right synckey
        if ([newFolder create])
          {
            SOGoMailAccount *accountFolder;
            NSDictionary *imapGUIDs;
            SOGoCacheGCSObject *o;
            NSString *key;

            nameInContainer = [newFolder nameInContainer];

            accountFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];
            imapGUIDs = [accountFolder imapFolderGUIDs];
            nameInContainer =[imapGUIDs objectForKey: nameInContainer];

            key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], nameInContainer ];
            o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
            [o setObjectType: ActiveSyncFolderCacheObject];
            [o setTableUrl: [self folderTableURL]];
            [o reloadIfNeeded];
            [[o properties ]  setObject: [[newFolder nameInContainer] substringFromIndex: 6] forKey: @"displayName"];
            [o save];

            nameInContainer = [NSString stringWithFormat: @"mail/%@", [nameInContainer  substringFromIndex: 6]];
          }
        else
          {
            [theResponse setStatus: 500];
            [theResponse appendContentString: @"Unable to create folder."];
            return;
          }
      }
      break;
    case 13:
    case 15:
      {
        SOGoAppointmentFolders *appointmentFolders;
        SOGoCacheGCSObject *o;
        NSString *key;
        id newFolder;
        
        nameInContainer = nil;
        
        appointmentFolders = [userFolder privateCalendars: @"Calendar" inContext: context];
        [appointmentFolders newFolderWithName: displayName
                              nameInContainer: &nameInContainer];

        newFolder = [appointmentFolders lookupName: nameInContainer
                                         inContext: context
                                           acquire: NO];
        [newFolder setSynchronize: YES];

        if (type == 13)
          nameInContainer = [NSString stringWithFormat: @"vevent/%@", nameInContainer];
        else
          nameInContainer = [NSString stringWithFormat: @"vtodo/%@", nameInContainer];

        key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], nameInContainer ];
        o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
        [o setObjectType: ActiveSyncFolderCacheObject];
        [o setTableUrl: [self folderTableURL]];
        [o reloadIfNeeded];
        [[o properties ]  setObject: displayName forKey: @"displayName"];
        [o save];
      }
      break;
    case 14:
      {
        SOGoContactFolders *contactFolders;
        SOGoCacheGCSObject *o;
        NSString *key;
        id newFolder;
        
        nameInContainer = nil;
        
        contactFolders = [userFolder privateContacts: @"Contacts" inContext: context];
        [contactFolders newFolderWithName: displayName
                          nameInContainer: &nameInContainer];

        newFolder = [contactFolders lookupName: nameInContainer
                                     inContext: context
                                       acquire: NO];
        [newFolder setSynchronize: YES];

        nameInContainer = [NSString stringWithFormat: @"vcard/%@", nameInContainer];
        
        key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], nameInContainer ];
        o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
        [o setObjectType: ActiveSyncFolderCacheObject];
        [o setTableUrl: [self folderTableURL]];
        [o reloadIfNeeded];
        [[o properties ]  setObject: displayName forKey: @"displayName"];
        [o save];
      }
      break;
    default:
      {
        [theResponse setStatus: 500];
        [theResponse appendContentString: @"Unsupported folder type during creation."];
        return;
      }
    } // switch (type) ...

  //
  // We update the FolderSync's synckey
  // 
  syncKey = [[NSProcessInfo processInfo] globallyUniqueString];

  [self _setFolderSyncKey: syncKey];

  // All good, we send our response. The format is documented here:
  // 6.7 FolderCreate Response Schema - http://msdn.microsoft.com/en-us/library/dn338950(v=exchg.80).aspx  
  //
  s = [NSMutableString string];
  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<FolderCreate xmlns=\"FolderHierarchy:\">"];
  [s appendFormat: @"<Status>%d</Status>", 1];
  [s appendFormat: @"<SyncKey>%@</SyncKey>", syncKey];
  [s appendFormat: @"<ServerId>%@</ServerId>", [nameInContainer stringByEscapingURL]];
  [s appendString: @"</FolderCreate>"];
  
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
}

//
//
//
- (void) processFolderDelete: (id <DOMElement>) theDocumentElement
                  inResponse: (WOResponse *) theResponse
{
  SOGoMailAccounts *accountsFolder;
  SOGoUserFolder *userFolder;
  id currentFolder, folderToDelete;
  NSString *serverId, *nameInCache, *key, *syncKey;
  SOGoCacheGCSObject *o;
  NSMutableString *s;
  NSData *d;
  
  SOGoMicrosoftActiveSyncFolderType folderType;

  serverId = [[[(id)[theDocumentElement getElementsByTagName: @"ServerId"] lastObject] textValue] realCollectionIdWithFolderType: &folderType];
  nameInCache = serverId;
  serverId = [self globallyUniqueIDToIMAPFolderName: serverId  type: folderType];
  userFolder = [[context activeUser] homeFolderInContext: context];
  
  switch (folderType)
    {
    case ActiveSyncMailFolder:
      {
        nameInCache = [NSString stringWithFormat: @"folder%@", nameInCache];
        accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
        currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];
        
        folderToDelete = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", serverId]
                                         inContext: context
                                           acquire: NO];
      }
      break;
    case ActiveSyncEventFolder:
    case ActiveSyncTaskFolder:
      {
        SOGoAppointmentFolders *appointmentFolders;

        if (folderType == ActiveSyncEventFolder)
          nameInCache = [NSString stringWithFormat: @"vevent/%@", serverId];
        else
          nameInCache = [NSString stringWithFormat: @"vtodo/%@", serverId];
        
        appointmentFolders = [userFolder privateCalendars: @"Calendar" inContext: context];
        
        folderToDelete = [appointmentFolders lookupName: [NSString stringWithFormat: @"%@", serverId]
                                              inContext: context
                                                acquire: NO];
      }
      break;
    default:
      {
        [theResponse setStatus: 500];
        [theResponse appendContentString: @"Unsupported folder type during creation."];
        return;
      }
    }
  
  // FIXME: we should handle exception here
  [folderToDelete delete];
  
  //
  // We destroy the cache object
  //
  key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], nameInCache];
  o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
  [o setTableUrl: [self folderTableURL]];
  [o destroy];
  
  
  //
  // We update the FolderSync's synckey
  //
  syncKey = [[NSProcessInfo processInfo] globallyUniqueString]; 
  
  [self _setFolderSyncKey: syncKey];
  
  s = [NSMutableString string];
  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<FolderDelete xmlns=\"FolderHierarchy:\">"];
  [s appendFormat: @"<Status>%d</Status>", 1];
  [s appendFormat: @"<SyncKey>%@</SyncKey>", syncKey];
  [s appendString: @"</FolderDelete>"];
  
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  [theResponse setContent: d];
}

//
//
//
- (void) processFolderUpdate: (id <DOMElement>) theDocumentElement
                  inResponse: (WOResponse *) theResponse
{
  NSString *serverId, *parentId, *displayName, *newName, *nameInCache, *syncKey, *key;
  SOGoUserFolder *userFolder;
  SOGoCacheGCSObject *o;
  NSMutableString *s;
  id currentFolder;
  NSData *d;
      
  SOGoMicrosoftActiveSyncFolderType folderType;
  
  serverId = [[[(id)[theDocumentElement getElementsByTagName: @"ServerId"] lastObject] textValue] realCollectionIdWithFolderType: &folderType];

  nameInCache = [NSString stringWithFormat: @"folder%@", serverId];

  serverId = [self globallyUniqueIDToIMAPFolderName: serverId  type: folderType];
  parentId = [[(id)[theDocumentElement getElementsByTagName: @"ParentId"] lastObject] textValue];
  displayName = [[(id)[theDocumentElement getElementsByTagName: @"DisplayName"] lastObject] textValue];

  userFolder = [[context activeUser] homeFolderInContext: context];


  switch (folderType)
    {
    case ActiveSyncMailFolder:
      {
        SOGoMailAccounts *accountsFolder;
        SOGoMailFolder *folderToUpdate;

        accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
        currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];
  
        folderToUpdate = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", serverId]
                                         inContext: context
                                           acquire: NO];

        // If parent is 0 or displayname is not changed it is either a rename of a folder in 0 or a move to 0
        if ([parentId isEqualToString: @"0"] ||
            ([serverId hasSuffix: [NSString stringWithFormat: @"/%@", displayName]] && [parentId isEqualToString: @"0"]))
          {
            newName = [NSString stringWithFormat: @"%@", [displayName stringByEncodingImap4FolderName]];

            // FIXME: handle exception here
            [folderToUpdate renameTo: [NSString stringWithFormat: @"/%@", [displayName stringByEncodingImap4FolderName]]];
          }
        else
          {
            parentId = [self globallyUniqueIDToIMAPFolderName: [[parentId stringByUnescapingURL] substringFromIndex: 5]  type: folderType];
            newName = [NSString stringWithFormat: @"%@/%@", [parentId stringByEncodingImap4FolderName], [displayName stringByEncodingImap4FolderName]];

            // FIXME: handle exception here
            [folderToUpdate renameTo: newName];
          }

      
        //
        // We update our cache
        //
        key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], nameInCache];
        o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
        [o setObjectType: ActiveSyncFolderCacheObject];
        [o setTableUrl: [self folderTableURL]];
        [o reloadIfNeeded];
        [[o properties ]  setObject: newName  forKey: @"displayName"];
        [o save];
      }
      break;
    case ActiveSyncEventFolder:
    case ActiveSyncTaskFolder:
      {
        SOGoAppointmentFolders *appointmentFolders;
        SOGoAppointmentFolder *folderToUpdate;
	NSString *nameInCache;

        appointmentFolders = [userFolder privateCalendars: @"Calendar" inContext: context];

        folderToUpdate = [appointmentFolders lookupName: [NSString stringWithFormat: @"%@", serverId]
                                              inContext: context
                                                acquire: NO];

        // update the cache anyway regardless of any error; if the rename fails next folderSync will to the cleanup 
        [folderToUpdate renameTo: [NSString stringWithFormat: @"%@", [displayName stringByEncodingImap4FolderName]]];

        if (folderType == ActiveSyncEventFolder)
          nameInCache = [NSString stringWithFormat: @"vevent/%@", serverId];
        else
          nameInCache = [NSString stringWithFormat: @"vtodo/%@",serverId];

        key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], nameInCache ];
        o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
        [o setObjectType: ActiveSyncFolderCacheObject];
        [o setTableUrl: [self folderTableURL]];
        [o reloadIfNeeded];
        [[o properties ]  setObject: displayName forKey: @"displayName"];
        [o save];
      }
      break;
    default:
      {
        [theResponse setStatus: 500];
        [theResponse appendContentString: @"Unsupported folder type during creation."];
        return;
      }
    }

    //
    // We update the FolderSync's synckey
    // 
    syncKey = [[NSProcessInfo processInfo] globallyUniqueString];

    [self _setFolderSyncKey: syncKey];

    s = [NSMutableString string];
    [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
    [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
    [s appendString: @"<FolderUpdate xmlns=\"FolderHierarchy:\">"];
    [s appendFormat: @"<Status>%d</Status>", 1];
    [s appendFormat: @"<SyncKey>%@</SyncKey>", syncKey];
    [s appendString: @"</FolderUpdate>"];
     
    d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
      
    [theResponse setContent: d];
}


- (void) _flattenFolders: (NSArray *) theFolders
                    into: (NSMutableArray *) theTarget
                  parent: (NSDictionary *) theParent
          existingParent: (NSString *) theExistingParent
{
  NSArray *o;
  int i;

  [theTarget addObjectsFromArray: theFolders];

  for (i = 0; i < [theFolders count]; i++)
    {
      if ([theParent objectForKey: @"path"] && ![[theParent objectForKey: @"type"] isEqualToString: @"additional"])
        {
          [[theFolders objectAtIndex: i] setObject: [theParent objectForKey: @"path"]  forKey: @"parent"];
          theExistingParent = [theParent objectForKey: @"path"];
        }
      else if (theExistingParent)
        {
          [[theFolders objectAtIndex: i] setObject: theExistingParent forKey: @"parent"];
          [[theFolders objectAtIndex: i] setObject:
                 [[[[[theFolders objectAtIndex: i] objectForKey: @"path"] substringFromIndex: [theExistingParent length]+1]stringByReplacingOccurrencesOfString:@"/" withString:@"."] stringByDecodingImap4FolderName]
             forKey: @"name"];
        }
      else if (![[[theFolders objectAtIndex: i] objectForKey: @"type"] isEqualToString: @"otherUsers"] &&
               ![[[theFolders objectAtIndex: i] objectForKey: @"type"] isEqualToString: @"shared"])
        {
          [[theFolders objectAtIndex: i] setObject:
                 [[[[theFolders objectAtIndex: i] objectForKey: @"path"] stringByReplacingOccurrencesOfString:@"/" withString:@"."] stringByDecodingImap4FolderName]
             forKey: @"name"];
        }

      o = [[theFolders objectAtIndex: i] objectForKey: @"children"];

      if (o)
        [self _flattenFolders: o  into: theTarget  parent: [theFolders objectAtIndex: i] existingParent: theExistingParent];
    }
}

//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <FolderSync xmlns="FolderHierarchy:">
//  <SyncKey>0</SyncKey>
// </FolderSync>
//
- (void) processFolderSync: (id <DOMElement>) theDocumentElement
                inResponse: (WOResponse *) theResponse
{
  NSString *key, *cKey, *nkey, *name, *serverId, *parentId, *nameInCache, *personalFolderName, *syncKey, *folderType, *operation;
  NSMutableArray *folders, *processedFolders, *allFoldersMetadata;
  NSMutableDictionary *cachedGUIDs, *metadata;
  NSDictionary *folderMetadata, *imapGUIDs;
  SOGoMailAccounts *accountsFolder;
  SOGoMailAccount *accountFolder;
  NSMutableString *s, *commands;
  SOGoUserFolder *userFolder;
  NSArray *allKeys, *roles;
  SOGoCacheGCSObject *o;
  id currentFolder;
  NSData *d;

  int status, command_count, i, type, fi, count;
  BOOL first_sync;

  metadata = [self globalMetadataForDevice];
  syncKey = [[(id)[theDocumentElement getElementsByTagName: @"SyncKey"] lastObject] textValue];
  s = [NSMutableString string];
  personalFolderName = [[[context activeUser] personalCalendarFolderInContext: context] nameInContainer];

  first_sync = NO;
  status = 1;
  command_count = 0;
  commands = [NSMutableString string];

  processedFolders = [NSMutableArray array];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];

  if ([syncKey isEqualToString: @"0"])
    {
      first_sync = YES;
      syncKey = @"1";
    }
  else if (![metadata objectForKey: @"FolderSyncKey"])
    {
      // Synchronization key mismatch or invalid synchronization key
      //NSLog(@"FolderSync syncKey mismatch %@ <> %@", syncKey, metadata);
      [s appendFormat: @"<FolderSync xmlns=\"FolderHierarchy:\"><Status>9</Status></FolderSync>"];

      d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
      [theResponse setContent: d];
      return;
    }

  userFolder = [[context activeUser] homeFolderInContext: context];
  accountsFolder = [userFolder lookupName: @"Mail" inContext: context acquire: NO];
  accountFolder = [accountsFolder lookupName: @"0" inContext: context acquire: NO];

  if (first_sync)
    {
      [self _ensureFolder: (SOGoMailFolder *)[accountFolder draftsFolderInContext: context]];
      [self _ensureFolder: [accountFolder sentFolderInContext: context]];
      [self _ensureFolder: (SOGoMailFolder *)[accountFolder trashFolderInContext: context]];
    }

  allFoldersMetadata = [NSMutableArray array];
  [self _flattenFolders: [accountFolder allFoldersMetadata: SOGoMailStandardListing]  into: allFoldersMetadata  parent: nil existingParent: nil];
  
  // Get GUIDs of folder (IMAP)
  // e.g. {folderINBOX = folder6b93c528176f1151c7260000aef6df92}
  imapGUIDs = [accountFolder imapFolderGUIDs];

  cachedGUIDs = [NSMutableDictionary dictionary];
     
  // No need to read cached folder infos during first sync. Otherwise, pull it from the database.
  // e.g. {folder6b93c528176f1151c7260000aef6df92 = folderINBOX} - guid = foldername for easy reverse lookup with imapGUIDs
  if (!first_sync)
    {
      NSArray *foldersInCache;
           
      o = [SOGoCacheGCSObject objectWithName: @"0" inContainer: nil];
      [o setObjectType: ActiveSyncFolderCacheObject];
      [o setTableUrl: folderTableURL];

      foldersInCache = [o cacheEntriesForDeviceId: [context objectForKey: @"DeviceId"] newerThanVersion: -1];

      // get guids of folders stored in cache
      for (i = 0; i < [foldersInCache count]; i++)
       {
         key = [[foldersInCache objectAtIndex: i] substringFromIndex: 1];
         o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
         [o setObjectType: ActiveSyncFolderCacheObject];
         [o setTableUrl: [self folderTableURL]];
         [o reloadIfNeeded];
         
         // When the GUID entry exists the name of the entry has to be changed to new name
         if ([[o properties] objectForKey: @"GUID"])
           {
             //NSLog(@"Old cacheEntry: %@ displayName: %@ GUID: %@", key, [[o properties] objectForKey: @"displayName"], [[o properties] objectForKey: @"GUID"]);
             key = [NSString stringWithFormat: @"%@+folder%@", [context objectForKey: @"DeviceId"], [[o properties] objectForKey: @"GUID"]];
             //NSLog(@"New cacheEntry: %@", key);
             [[o properties] removeObjectForKey: @"GUID"];
             [[o properties ] setObject: @"updateMe" forKey: @"displayName"];
             [o save];
             [o changePathTo: [NSString stringWithFormat: @"%@", key]];
           }

         // no dispalay Name
         if (![[o properties] objectForKey: @"displayName"])
           continue;

         if ([key rangeOfString: @"+folder" options: NSCaseInsensitiveSearch].location != NSNotFound) 
           [cachedGUIDs setObject: [NSString stringWithFormat: @"folder%@", [[o properties] objectForKey: @"displayName"]] //  e.g. CDB648DDBC5040F8AC90792383DBBBAA+folderINBOX
                           forKey: [key substringFromIndex: [key rangeOfString: @"+"].location+1]];
         else
           [cachedGUIDs setObject: [key substringFromIndex: [key rangeOfString: @"+"].location+1]   //  e.g. CDB648DDBC5040F8AC90792383DBBBAA+vcard/personal
                           forKey: [key substringFromIndex: [key rangeOfString: @"+"].location+1]];
       }
    }
      
  // Handle folders that have been deleted on server
  allKeys = [cachedGUIDs allKeys];

  for (i = 0; i < [allKeys count]; i++)
   {
     cKey = [allKeys objectAtIndex: i];

     // if a cache entry is not found in imapGUIDs its either an imap which has been deleted or its an other folder type which can be checked via lookupName.
     if (![imapGUIDs allKeysForObject: cKey])
       {
         // Destroy folders cache content to avoid stale data if a new folder gets created with the same name
         key =  [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"],  cKey];
         o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
         [o setObjectType: ActiveSyncFolderCacheObject];
         [o setTableUrl: [self folderTableURL]];
         [o reloadIfNeeded];

         if ([cKey hasPrefix: @"folder"] || [cKey isEqualToString:@"(null)"])
           {
             [commands appendFormat: @"<Delete><ServerId>%@</ServerId></Delete>", [[NSString stringWithFormat: @"mail/%@", [cKey substringFromIndex: 6]] stringByEscapingURL]] ;
             command_count++;

             [o destroy];
           }
         else
           {
             if ([cKey rangeOfString: @"vevent" options: NSCaseInsensitiveSearch].location != NSNotFound ||
                 [cKey rangeOfString: @"vtodo" options: NSCaseInsensitiveSearch].location != NSNotFound)
               folderType = @"Calendar";
             else
               folderType = @"Contacts";

	     currentFolder = nil;

             if ([cKey rangeOfString: @"/"].location != NSNotFound) 
               currentFolder = [[[[context activeUser] homeFolderInContext: context] lookupName: folderType inContext: context acquire: NO]
                                                            lookupName: [cKey substringFromIndex: [cKey rangeOfString: @"/"].location+1]  inContext: context acquire: NO];
             else
               currentFolder = nil;

             // We skip personal GCS folders - we always want to synchronize these
             if ([currentFolder isKindOfClass: [SOGoGCSFolder class]] &&
                 [[currentFolder nameInContainer] isEqualToString: @"personal"])
               continue;

             // We remove the folder from device but keep the cache entry,
             // otherwise the user would see duplication objects, one in personal folder and one in the merged folder.
             //    MergedFolder=1 - Folder need to be removed from device.
             //    MergedFolder=2 - Folder has been removed from device; i.e. <Delete> has been sent already.
             if ([[[o properties] objectForKey: @"MergedFolder"] isEqualToString: @"1"])
               {
		 [commands appendFormat: @"<Delete><ServerId>%@</ServerId></Delete>", [cKey stringByEscapingURL] ];
		 command_count++;
		 [[o properties] setObject: @"2" forKey: @"MergedFolder"];
		 [o save];
	       }

             // Remove the folder from device if it doesn't exist, or don't want to sync it.
             if (!currentFolder || !([currentFolder synchronize]))
               {
                 // Don't send a delete when MergedFoler is set, we have done it above.
                 // Windows Phones don't like when a <Delete>-folder is sent twice.
                 if (![[[o properties] objectForKey: @"MergedFolder"] isEqualToString: @"2"])
                   {
                     [commands appendFormat: @"<Delete><ServerId>%@</ServerId></Delete>", [cKey stringByEscapingURL] ];
                     command_count++;
                   }
                 [o destroy];
                 continue;
               }

             // Remove the folder from device if it is a contact folder and we have no SOGoRole_ObjectViewer.
             if ([currentFolder isKindOfClass: [SOGoContactGCSFolder class]] && ![[currentFolder ownerInContext: context] isEqualToString: [[context activeUser] login]])
               {
                 roles = [currentFolder aclsForUser: [[context activeUser] login]];
                 if (![roles containsObject: SOGoRole_ObjectViewer])
                   {
                     // Don't send a delete when MergedFoler is set, we have done it above.
                     // Windows Phones don't like when a <Delete>-folder is sent twice.
                     if (![[[o properties] objectForKey: @"MergedFolder"] isEqualToString: @"2"])
                       {
                         [commands appendFormat: @"<Delete><ServerId>%@</ServerId></Delete>", [cKey stringByEscapingURL] ];
                         command_count++;
                       }
                     [o destroy];
                   }
               }
           }
       }
   }

  // Handle addition and changes
  for (i = 0; i < [allFoldersMetadata count]; i++)
   {
     folderMetadata = [allFoldersMetadata objectAtIndex: i];

     // In v3, the "path" value does not have a '/' at the beginning
     nameInCache = [NSString stringWithFormat: @"folder%@",  [folderMetadata objectForKey: @"path"]];

     // we have no guid - ignore the folder
     if (![imapGUIDs objectForKey: nameInCache])
       continue;

     serverId = [NSString stringWithFormat: @"mail/%@",  [[imapGUIDs objectForKey: nameInCache] substringFromIndex: 6]];

     // In v3, we use "name" while in v2, it was "displayName"
     name = [folderMetadata objectForKey: @"name"];

     // avoid duplicate folders if folder is returned by different imap namespaces
     if ([processedFolders indexOfObject: serverId] == NSNotFound)
       [processedFolders addObject: serverId];
     else
       continue;

     if ([name hasPrefix: @"/"])
       name = [name substringFromIndex: 1];
          
     if ([name hasSuffix: @"/"])
       name = [name substringToIndex: [name length]-1];
          
     type = [[folderMetadata objectForKey: @"type"] activeSyncFolderType];
     parentId = @"0";
         
     if ([folderMetadata objectForKey: @"parent"])
       {
         // make sure that parent of main-folders is always 0
         if (type == 12)
            parentId = [NSString stringWithFormat: @"mail/%@", [[imapGUIDs objectForKey: [NSString stringWithFormat: @"folder%@",  [folderMetadata objectForKey: @"parent"]]] substringFromIndex: 6]];

         name = [[name pathComponents] lastObject];
       }
          
     // Decide between add and change
     if ([cachedGUIDs objectForKey: [imapGUIDs objectForKey: nameInCache]])
       {
         // Search GUID to check name change in cache (diff between IMAP and cache)
         key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], [cachedGUIDs objectForKey: [imapGUIDs objectForKey: nameInCache ]]];
         nkey = [NSString stringWithFormat: @"%@+folder%@", [context objectForKey: @"DeviceId"], [folderMetadata objectForKey: @"path"]];
                   
         if (![key isEqualToString: nkey])
           {
             [commands appendFormat: @"<Update><ServerId>%@</ServerId><ParentId>%@</ParentId><DisplayName>%@</DisplayName><Type>%d</Type></Update>",
                           [serverId stringByEscapingURL],
                           [parentId stringByEscapingURL],
                           [name activeSyncRepresentationInContext: context], type];
                      
             // Change path in cache
             o = [SOGoCacheGCSObject objectWithName: [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"],  [imapGUIDs objectForKey: nameInCache ]]  inContainer: nil];
             [o setObjectType: ActiveSyncFolderCacheObject];
             [o setTableUrl: [self folderTableURL]];
             [o reloadIfNeeded];

             [[o properties ]  setObject: [folderMetadata objectForKey: @"path"] forKey: @"displayName"];
             [o save];

             command_count++;
           }
       }
     else
       {
         [commands appendFormat: @"<Add><ServerId>%@</ServerId><ParentId>%@</ParentId><DisplayName>%@</DisplayName><Type>%d</Type></Add>",
                        [serverId stringByEscapingURL],
                        [parentId stringByEscapingURL],
                        [name activeSyncRepresentationInContext: context], type];
              
         // Store folder's displayName in cache
         key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], [imapGUIDs objectForKey: nameInCache ]];
         o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
         [o setObjectType: ActiveSyncFolderCacheObject];
         [o setTableUrl: [self folderTableURL]];
         [o reloadIfNeeded];
              
         [[o properties ]  setObject: [folderMetadata objectForKey: @"path"] forKey: @"displayName"];

         // clean cache content to avoid stale data
         [[o properties] removeObjectForKey: @"SyncKey"];
         [[o properties] removeObjectForKey: @"SyncCache"];
         [[o properties] removeObjectForKey: @"DateCache"];
         [[o properties] removeObjectForKey: @"UidCache"];
         [[o properties] removeObjectForKey: @"MoreAvailable"];
         [[o properties] removeObjectForKey: @"BodyPreferenceType"];
         [[o properties] removeObjectForKey: @"SupportedElements"];
         [[o properties] removeObjectForKey: @"SuccessfulMoveItemsOps"];
         [[o properties] removeObjectForKey: @"InitialLoadSequence"];
         [[o properties] removeObjectForKey: @"FirstIdInCache"];
         [[o properties] removeObjectForKey: @"LastIdInCache"];
         [[o properties] removeObjectForKey: @"MergedFoldersSyncKeys"];
         [[o properties] removeObjectForKey: @"MergedFolder"];
         [[o properties] removeObjectForKey: @"CleanoutDate"];

         [o save];
              
         command_count++;
       }
   }

  // We get the list of subscribed calendars
  folders = [[[[[context activeUser] homeFolderInContext: context] lookupName: @"Calendar" inContext: context acquire: NO] subFolders] mutableCopy];
  [folders autorelease];

  // We get the list of subscribed address books
  [folders addObjectsFromArray: [[[[context activeUser] homeFolderInContext: context] lookupName: @"Contacts" inContext: context acquire: NO] subFolders]];

    // We remove all the folders that aren't GCS-ones, that we don't want to synchronize and
    // contact folder without SOGoRole_ObjectViewer.
    count = [folders count]-1;
    for (; count >= 0; count--)
     {
       currentFolder = [folders objectAtIndex: count];

       // We skip personal GCS folders - we always want to synchronize these
       if ([currentFolder isKindOfClass: [SOGoGCSFolder class]] &&
           [[currentFolder nameInContainer] isEqualToString: @"personal"])
         continue;

       if (![currentFolder isKindOfClass: [SOGoGCSFolder class]] ||
           ![currentFolder synchronize])
         {
           [folders removeObjectAtIndex: count];
           continue;
         }

       // Remove the folder from the device if it is a contact folder and we have no SOGoRole_ObjectViewer access right.
       if ([currentFolder isKindOfClass: [SOGoContactGCSFolder class]] && ![[currentFolder ownerInContext: context] isEqualToString: [[context activeUser] login]])
         {
           roles = [currentFolder aclsForUser: [[context activeUser] login]];
           if (![roles containsObject: SOGoRole_ObjectViewer])
             [folders removeObjectAtIndex: count];
         }
     }

    count = [folders count]-1;

    for (fi = 0; fi <= count ; fi++)
     {
       if ([[folders objectAtIndex: fi] isKindOfClass: [SOGoAppointmentFolder class]])
         name = [NSString stringWithFormat: @"vevent/%@", [[folders objectAtIndex: fi] nameInContainer]];
       else
         name = [NSString stringWithFormat: @"vcard/%@", [[folders objectAtIndex: fi] nameInContainer]];
          
       key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], name];
       o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
       [o setObjectType: ActiveSyncFolderCacheObject];
       [o setTableUrl: [self folderTableURL]];
       [o reloadIfNeeded];

       // Decide between add and change
       if (![[o properties ] objectForKey: @"displayName"] || first_sync)
         operation = @"Add";
       else if (![[[o properties ] objectForKey: @"displayName"] isEqualToString: [[folders objectAtIndex:fi] displayName]])
         operation = @"Update";
       else
         operation = nil;
          
       if (operation)
         {
           if ([[folders objectAtIndex:fi] isKindOfClass: [SOGoAppointmentFolder class]])
             {
               type = ([[[folders objectAtIndex:fi] nameInContainer] isEqualToString: personalFolderName] ? 8 : 13);
               [commands appendFormat: @"<%@><ServerId>%@</ServerId><ParentId>%@</ParentId><DisplayName>%@</DisplayName><Type>%d</Type></%@>", operation,
                   [name stringByEscapingURL], @"0", [[[folders objectAtIndex:fi] displayName] activeSyncRepresentationInContext: context], type, operation];

               command_count++;

               [[o properties ] setObject: [[folders objectAtIndex:fi] displayName]  forKey: @"displayName"];
               [o save];

               name = [NSString stringWithFormat: @"vtodo/%@", [[folders objectAtIndex:fi] nameInContainer]];
               type = ([[[folders objectAtIndex:fi] nameInContainer] isEqualToString: personalFolderName] ? 7 : 15);

               // We always sync the "Default Tasks folder" (7). For "User-created Tasks folder" (15), we check if we include it in
               // the sync process by checking if "Show tasks" is enabled. If not, we skip the folder entirely.
               if (type == 7 ||
                   (type == 15 && [[folders objectAtIndex: fi] showCalendarTasks]))
                 {
                   [commands appendFormat: @"<%@><ServerId>%@</ServerId><ParentId>%@</ParentId><DisplayName>%@</DisplayName><Type>%d</Type></%@>", operation,
                             [name stringByEscapingURL], @"0", [[[folders objectAtIndex:fi] displayName] activeSyncRepresentationInContext: context], type, operation];

                   command_count++;

                   key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], name];
                   o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
                   [o setObjectType: ActiveSyncFolderCacheObject];
                   [o setTableUrl: [self folderTableURL]];
                   [o reloadIfNeeded];
                   [[o properties ]  setObject:  [[folders objectAtIndex:fi] displayName]  forKey: @"displayName"];

                   if ([operation isEqualToString: @"Add"])
                     {
                       // clean cache content to avoid stale data
                       [[o properties] removeObjectForKey: @"SyncKey"];
                       [[o properties] removeObjectForKey: @"SyncCache"];
                       [[o properties] removeObjectForKey: @"DateCache"];
                       [[o properties] removeObjectForKey: @"UidCache"];
                       [[o properties] removeObjectForKey: @"MoreAvailable"];
                       [[o properties] removeObjectForKey: @"BodyPreferenceType"];
                       [[o properties] removeObjectForKey: @"SupportedElements"];
                       [[o properties] removeObjectForKey: @"SuccessfulMoveItemsOps"];
                       [[o properties] removeObjectForKey: @"InitialLoadSequence"];
                       [[o properties] removeObjectForKey: @"FirstIdInCache"];
                       [[o properties] removeObjectForKey: @"LastIdInCache"];
                       [[o properties] removeObjectForKey: @"MergedFoldersSyncKeys"];
                       [[o properties] removeObjectForKey: @"MergedFolder"];
                       [[o properties] removeObjectForKey: @"CleanoutDate"];
                     }

                   [o save];
                 }
             } 
           else if ([[folders objectAtIndex:fi] isKindOfClass: [SOGoContactGCSFolder class]])
             {
               type = ([[[folders objectAtIndex:fi] nameInContainer] isEqualToString: personalFolderName] ? 9 : 14);
               [commands appendFormat: @"<%@><ServerId>%@</ServerId><ParentId>%@</ParentId><DisplayName>%@</DisplayName><Type>%d</Type></%@>", operation,
                   [name stringByEscapingURL], @"0", [[[folders objectAtIndex:fi] displayName] activeSyncRepresentationInContext: context], type, operation];

               command_count++;

               [[o properties ]  setObject:  [[folders objectAtIndex:fi] displayName]  forKey: @"displayName"];

               if ([operation isEqualToString: @"Add"])
                 {
                   // clean cache content to avoid stale data
                   [[o properties] removeObjectForKey: @"SyncKey"];
                   [[o properties] removeObjectForKey: @"SyncCache"];
                   [[o properties] removeObjectForKey: @"DateCache"];
                   [[o properties] removeObjectForKey: @"UidCache"];
                   [[o properties] removeObjectForKey: @"MoreAvailable"];
                   [[o properties] removeObjectForKey: @"BodyPreferenceType"];
                   [[o properties] removeObjectForKey: @"SupportedElements"];
                   [[o properties] removeObjectForKey: @"SuccessfulMoveItemsOps"];
                   [[o properties] removeObjectForKey: @"InitialLoadSequence"];
                   [[o properties] removeObjectForKey: @"FirstIdInCache"];
                   [[o properties] removeObjectForKey: @"LastIdInCache"];
                   [[o properties] removeObjectForKey: @"MergedFoldersSyncKeys"];
                   [[o properties] removeObjectForKey: @"MergedFolder"];
                   [[o properties] removeObjectForKey: @"CleanoutDate"];
                 }

               [o save];
             }
         } // if (operation)
     } // for (fi = 0; fi <= count ; fi++)

  
  // set a new syncKey if there are folder changes
  if (command_count > 0)
    {
      syncKey = [[NSProcessInfo processInfo] globallyUniqueString];
      [self _setFolderSyncKey: syncKey];
    }

 
  [s appendFormat: @"<FolderSync xmlns=\"FolderHierarchy:\"><Status>%d</Status>", status];
  [s appendFormat: @"<SyncKey>%@</SyncKey><Changes><Count>%d</Count>%@</Changes></FolderSync>", syncKey, command_count, commands];
  
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
} 

//
// From: http://msdn.microsoft.com/en-us/library/ee157980(v=exchg.80).aspx :
//
// <2> Section 2.2.2.6: The GetAttachment command is not supported when the MS-ASProtocolVersion header is set to 14.0 or 14.1
// in the GetAttachment command request. Use the Fetch element of the ItemOperations command instead. For more information about
// the MS-ASProtocolVersion header, see [MS-ASHTTP] section 2.2.1.1.2.4.
//
- (void) processGetAttachment: (id <DOMElement>) theDocumentElement
                   inResponse: (WOResponse *) theResponse
{
  NSString *fileReference, *realCollectionId;

  SOGoMicrosoftActiveSyncFolderType folderType;

  fileReference = [context objectForKey: @"AttachmentName"];

  realCollectionId = [fileReference realCollectionIdWithFolderType: &folderType];

  if (folderType == ActiveSyncMailFolder)
    {
      id currentFolder, currentCollection, currentBodyPart;
      NSString *folderName, *messageName, *pathToPart;
      SOGoMailAccounts *accountsFolder;
      SOGoUserFolder *userFolder;
      SOGoMailObject *mailObject;
      NSMutableArray *a;
      NSArray *partKeys;
      int p;


      a = [[realCollectionId  componentsSeparatedByString: @"/"] mutableCopy];
      [a autorelease];
      pathToPart = [a lastObject];
      [a removeLastObject];
      messageName = [a lastObject];
      [a removeLastObject];
      folderName = [a componentsJoinedByString: @"/"];

      userFolder = [[context activeUser] homeFolderInContext: context];
      accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
      currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];

      currentCollection = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", folderName]
                                          inContext: context
                                            acquire: NO];

      mailObject = [currentCollection lookupName: messageName  inContext: context  acquire: NO];

      partKeys = [pathToPart componentsSeparatedByString: @"."];

      currentBodyPart = [mailObject lookupImap4BodyPartKey: [partKeys objectAtIndex:0]  inContext: context];
      for (p = 1; p < [partKeys count]; p++)
        {
          currentBodyPart = [currentBodyPart lookupImap4BodyPartKey: [partKeys objectAtIndex:p]  inContext: context];
        }

      [theResponse setHeader: [NSString stringWithFormat: @"%@/%@", [[currentBodyPart partInfo] objectForKey: @"type"], [[currentBodyPart partInfo] objectForKey: @"subtype"]]
                 forKey: @"Content-Type"];

      [theResponse setContent: [currentBodyPart fetchBLOBWithPeek: YES] ];
    }
  else
    {
      [theResponse setStatus: 500];
    }
}

//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <GetItemEstimate xmlns="GetItemEstimate:">
//  <Collections>
//   <Collection>
//    <SyncKey xmlns="AirSync:">1</SyncKey>
//    <CollectionId>folderINBOX</CollectionId>
//    <Options xmlns="AirSync:">
//     <FilterType>3</FilterType>
//    </Options>
//   </Collection>
//  </Collections>
// </GetItemEstimate>
//
- (void) processGetItemEstimate: (id <DOMElement>) theDocumentElement
                     inResponse: (WOResponse *) theResponse
{
  NSString *collectionId, *realCollectionId, *nameInCache;
  id currentCollection;
  NSMutableString *s;
  NSData *d;
  NSArray *allCollections;
  int j;

  SOGoMicrosoftActiveSyncFolderType folderType;
  int status, count;

  s = [NSMutableString string];
  status = 1;
  count = 0;

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<GetItemEstimate xmlns=\"GetItemEstimate:\">"];

  allCollections = (id)[theDocumentElement getElementsByTagName: @"Collection"];

  for (j = 0; j < [allCollections count]; j++)
     {
       collectionId = [[(id)[[allCollections objectAtIndex: j] getElementsByTagName: @"CollectionId"] lastObject] textValue];
       realCollectionId = [collectionId realCollectionIdWithFolderType: &folderType];
       
       if (folderType == ActiveSyncMailFolder)
         nameInCache = [NSString stringWithFormat: @"folder%@", realCollectionId];
       else
         nameInCache = collectionId;

       realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];

       currentCollection = [self collectionFromId: realCollectionId  type: folderType];
  
       //
       // For IMAP, we simply build a request like this:
       //
       // . UID SORT (SUBJECT) UTF-8 SINCE 1-Jan-2014 NOT DELETED
       // * SORT 124576 124577 124579 124578
       // . OK Completed (4 msgs in 0.000 secs)
       //
       if (folderType == ActiveSyncMailFolder)
         {
           NSCalendarDate *filter;
           NSString *syncKey;
           NSArray *allMessages;

           filter = [NSCalendarDate dateFromFilterType: [[(id)[[allCollections objectAtIndex: j] getElementsByTagName: @"FilterType"] lastObject] textValue]];
           syncKey = [[(id)[[allCollections objectAtIndex: j] getElementsByTagName: @"SyncKey"] lastObject] textValue];
      
           allMessages = [currentCollection syncTokenFieldsWithProperties: nil  matchingSyncToken: syncKey  fromDate: filter initialLoad: NO];

           count = [allMessages count];
      
           // Add the number of UIDs expected to "soft delete"
           count += [self _softDeleteCountWithFilter: filter collectionId: nameInCache];
         }
       else
         {
           count = [[currentCollection toOneRelationshipKeys] count];
         }
      

       [s appendString: @"<Response>"];
       [s appendFormat: @"<Status>%d</Status><Collection>", status];

       if (folderType == ActiveSyncMailFolder)
         [s appendString: @"<Class>Email</Class>"];
       else if (folderType == ActiveSyncContactFolder)
         [s appendString: @"<Class>Contacts</Class>"];
       else if (folderType == ActiveSyncEventFolder)
         [s appendString: @"<Class>Calendar</Class>"];
       else if (folderType == ActiveSyncTaskFolder)
         [s appendString: @"<Class>Tasks</Class>"];

       [s appendFormat: @"<CollectionId>%@</CollectionId>",collectionId];
       [s appendFormat: @"<Estimate>%d</Estimate></Collection></Response>", count];
     }
  
  [s appendString: @"</GetItemEstimate>"];

  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
}

//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <ItemOperations xmlns="ItemOperations:">
//  <Fetch>
//   <Store>Mailbox</Store>                                      -- http://msdn.microsoft.com/en-us/library/gg663522(v=exchg.80).aspx
//   <FileReference xmlns="AirSyncBase:">2</FileReference>       -- 
//   <Options/>
//  </Fetch>
// </ItemOperations>
//
- (void) processItemOperations: (id <DOMElement>) theDocumentElement
                    inResponse: (WOResponse *) theResponse
{
  NSString *fileReference, *realCollectionId, *serverId, *bodyPreferenceType, *mimeSupport, *collectionId;
  NSArray *fetchRequests;
  NSMutableString *s;
  NSData *d;
  id aFetch;

  SOGoMicrosoftActiveSyncFolderType folderType;
  int i;

  s = [NSMutableString string];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<ItemOperations xmlns=\"ItemOperations:\">"];

  fetchRequests = (id)[theDocumentElement getElementsByTagName: @"Fetch"];
  
  if ([fetchRequests count])
    {
      NSMutableData *bytes, *parts;
      NSMutableArray *partLength;

      bytes = [NSMutableData data];
      parts = [NSMutableData data];
      partLength = [NSMutableArray array];

      [s appendString: @"<Status>1</Status>"];
      [s appendString: @"<Response>"];

      for (i = 0; i < [fetchRequests count]; i++)
        {
          aFetch = [fetchRequests objectAtIndex: i];
          fileReference = [[[(id)[aFetch getElementsByTagName: @"FileReference"] lastObject] textValue] stringByUnescapingURL];
          collectionId = [[(id)[theDocumentElement getElementsByTagName: @"CollectionId"] lastObject] textValue];
	  serverId = nil;

	  // We might not have a CollectionId in our request if the ItemOperation (Fetch) is for getting
	  // Search results with a LongId. Apple iOS does that.
	  if (!collectionId)
	    {
	      NSString *longId;
	      NSRange r;

	      longId = [[(id)[theDocumentElement getElementsByTagName: @"LongId"] lastObject] textValue];
	      r = [longId rangeOfString: @"+"  options: NSBackwardsSearch];
	      collectionId = [longId substringToIndex: r.location];
	      serverId = [longId substringFromIndex: r.location+1];
	    }

          // its either a itemOperation to fetch an attachment or an email
          if ([fileReference length])
             realCollectionId = [fileReference realCollectionIdWithFolderType: &folderType];
          else
             realCollectionId = [collectionId realCollectionIdWithFolderType: &folderType];

          if (folderType == ActiveSyncMailFolder)
            {
              id currentFolder, currentCollection, currentBodyPart;
              NSString *folderName, *messageName, *pathToPart;
              SOGoMailAccounts *accountsFolder;
              SOGoUserFolder *userFolder;
              SOGoMailObject *mailObject;
              NSMutableArray *a;

              if ([fileReference length])
                {
                  // fetch attachment
                  NSArray *partKeys;
                  int p;

                  a = [[realCollectionId  componentsSeparatedByString: @"/"] mutableCopy];
                  [a autorelease];
                  pathToPart = [a lastObject];
                  [a removeLastObject];
                  messageName = [a lastObject];
                  [a removeLastObject];
                  folderName = [a componentsJoinedByString: @"/"]; 

                  userFolder = [[context activeUser] homeFolderInContext: context];
                  accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
                  currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];

                  currentCollection = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", folderName]
                                                      inContext: context
                                                        acquire: NO];

                  mailObject = [currentCollection lookupName: messageName  inContext: context  acquire: NO];

                  partKeys = [pathToPart componentsSeparatedByString: @"."];

                  currentBodyPart = [mailObject lookupImap4BodyPartKey: [partKeys objectAtIndex:0]  inContext: context];
                  for (p = 1; p < [partKeys count]; p++)
                    {
                      currentBodyPart = [currentBodyPart lookupImap4BodyPartKey: [partKeys objectAtIndex:p]  inContext: context];
                    }
                  
                  [s appendString: @"<Fetch>"];
                  [s appendString: @"<Status>1</Status>"];
                  [s appendFormat: @"<FileReference xmlns=\"AirSyncBase:\">mail/%@/%@/%@</FileReference>", [folderName stringByEscapingURL], messageName, pathToPart];
                  [s appendString: @"<Properties>"];

                  [s appendFormat: @"<ContentType xmlns=\"AirSyncBase:\">%@/%@</ContentType>", [[currentBodyPart partInfo] objectForKey: @"type"], [[currentBodyPart partInfo] objectForKey: @"subtype"]];

                  if ([[theResponse headerForKey: @"Content-Type"] isEqualToString:@"application/vnd.ms-sync.multipart"])
                    {
                      NSData *d;

                      d = [currentBodyPart fetchBLOBWithPeek: YES];

                      [s appendFormat: @"<Part>%d</Part>", i+1];
                      [partLength addObject: [NSNumber numberWithInteger: [d length]]];
                      [parts appendData: d];
                    }
                  else
                    {
                      NSString *a;

                      a = [[currentBodyPart fetchBLOBWithPeek: YES] activeSyncRepresentationInContext: context];

                      // Don't send Range when not included in the request. Sending it will cause issue on iOS 10
		      // when downloading attachments. iOS 10 will first report an error upon the first download
		      // and then, it'll work. This makes it work the first time the attachment is downlaoded.
                      if  ([[[(id)[aFetch getElementsByTagName: @"Range"] lastObject] textValue] length])
			[s appendFormat: @"<Range>0-%d</Range>", [a length]-1];

                      [s appendFormat: @"<Data>%@</Data>", a];
                    }
                }
              else
                {
                  // fetch mail
                  realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];

		  // ServerId might have been set if LongId was defined in the initial request. If not, it is
		  // a normal ItemOperations (Fetch) to get a complete email
		  if (!serverId)
		    serverId = [[(id)[theDocumentElement getElementsByTagName: @"ServerId"] lastObject] textValue];

                  bodyPreferenceType = [[(id)[[(id)[theDocumentElement getElementsByTagName: @"BodyPreference"] lastObject] getElementsByTagName: @"Type"] lastObject] textValue];
                  [context setObject: bodyPreferenceType  forKey: @"BodyPreferenceType"];
                  mimeSupport = [[(id)[theDocumentElement getElementsByTagName: @"MIMESupport"] lastObject] textValue];
                  [context setObject: mimeSupport  forKey: @"MIMESupport"];

                  // https://msdn.microsoft.com/en-us/library/gg675490%28v=exchg.80%29.aspx
                  // The fetch element is used to request the application data of an item that was truncated in a synchronization response from the server.
                  // The complete item is then returned to the client in a server response.
                  [context setObject: @"8" forKey: @"MIMETruncation"];

                  currentCollection = [self collectionFromId: realCollectionId  type: folderType];

                  mailObject = [currentCollection lookupName: serverId  inContext: context  acquire: NO];
                  [s appendString: @"<Fetch>"];
                  [s appendString: @"<Status>1</Status>"];

                  if ([[[(id)[theDocumentElement getElementsByTagName: @"LongId"] lastObject] textValue] length])
                    {
                      [s appendString: @"<Class xmlns=\"AirSync:\">Email</Class>"];
                      [s appendFormat: @"<LongId xmlns=\"Search:\">%@</LongId>", [[(id)[theDocumentElement getElementsByTagName: @"LongId"] lastObject] textValue]];
                    }
                  else
                    {
                      [s appendFormat: @"<CollectionId xmlns=\"AirSyncBase:\">%@</CollectionId>", collectionId];
                      [s appendFormat: @"<ServerId xmlns=\"AirSyncBase:\">%@</ServerId>", serverId];
                    }

                  [s appendString: @"<Properties>"];

                  if ([[theResponse headerForKey: @"Content-Type"] isEqualToString:@"application/vnd.ms-sync.multipart"])
                    {
                      [context setObject: parts  forKey: @"MultiParts"];
                      [context setObject: partLength  forKey: @"MultiPartsLen"];
                    }

                  [s appendString: [mailObject activeSyncRepresentationInContext: context]];
                }

              [s appendString: @"</Properties>"];
              [s appendString: @"</Fetch>"];
            }
          else
            {
              [theResponse setStatus: 500];
              return;
            }
        }

      [s appendString: @"</Response>"];
      [s appendString: @"</ItemOperations>"];

      d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

      if ([[theResponse headerForKey: @"Content-Type"] isEqualToString:@"application/vnd.ms-sync.multipart"])
        {
          uint32_t PartCount;
          uint32_t Offset;
          uint32_t Len;

          // 2.2.2.9.1.1 - MultiPartResponse -- http://msdn.microsoft.com/en-us/library/jj663270%28v=exchg.80%29.aspx
          PartCount = [partLength count] + 1;
          Offset = ((PartCount) * 2) * 4 + 4;
          Len = [d length];

          [bytes appendBytes: &PartCount  length: 4];
          [bytes appendBytes: &Offset  length: 4];
          [bytes appendBytes: &Len  length: 4];

          // 2.2.2.9.1.1.1 - PartMetaData -- http://msdn.microsoft.com/en-us/library/jj663267%28v=exchg.80%29.aspx
          for (i = 0; i < [fetchRequests count]; i++)
            {
              Offset = Offset + Len;
              Len = [[partLength objectAtIndex:i] intValue];
              [bytes appendBytes: &Offset  length: 4];
              [bytes appendBytes: &Len  length: 4];
            }

          // First part - webxml
          [bytes appendData: d];

          // Subsequent parts - requested data
          [bytes appendData: parts];

          [theResponse setContent: bytes];
        }
      else
        {
          [theResponse setContent: d];
        }
    } 
  else if ([theDocumentElement getElementsByTagName: @"EmptyFolderContents"])
    {
      NGImap4Connection *connection;
      NSEnumerator *subfolders;
      NSException *error;
      NSURL *currentURL;
      id co; 

      collectionId = [[(id)[theDocumentElement getElementsByTagName: @"CollectionId"] lastObject] textValue];
      realCollectionId = [collectionId realCollectionIdWithFolderType: &folderType];
      realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];

      if (folderType == ActiveSyncMailFolder)
        {
          co = [self collectionFromId: realCollectionId  type: folderType];
          error = [co addFlagsToAllMessages: @"deleted"];

          if (!error)
            error = [(SOGoMailFolder *)co expunge];

          if (!error)
            {
              [co flushMailCaches];

              if ([theDocumentElement getElementsByTagName: @"DeleteSubFolders"])
                {
                  // Delete sub-folders 
                  connection = [co imap4Connection];
                  subfolders = [[co allFolderURLs] objectEnumerator];

                  while ((currentURL = [subfolders nextObject]))
                    {
                      [[connection client] unsubscribe: [currentURL path]];
                      [connection deleteMailboxAtURL: currentURL];
                    }
                }

              [s appendString: @"<Status>1</Status>"];
              [s appendString: @"</ItemOperations>"];
            }

          if (error)
            {
              [s appendString: @"<Status>3</Status>"];
              [s appendString: @"</ItemOperations>"];
            }

          d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
          [theResponse setContent: d];
        }
      else
        {
          [theResponse setStatus: 500];
          return;
        }
    }
}


//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <MeetingResponse xmlns="MeetingResponse:">
//  <Request>
//   <UserResponse>1</UserResponse>
//   <CollectionId>mail%2FINBOX</CollectionId>
//   <RequestId>283</RequestId>
//  </Request>
// </MeetingResponse>
//
- (void) processMeetingResponse: (id <DOMElement>) theDocumentElement
                     inResponse: (WOResponse *) theResponse
{
  NSString *realCollectionId, *requestId, *easRequestId, *participationStatus, *calendarId;
  SOGoAppointmentObject *appointmentObject;
  SOGoMailObject *mailObject;
  NSMutableDictionary *uidCache, *folderMetadata;
  NSMutableString *s, *nameInCache;
  NSData *d;

  id collection;

  SOGoMicrosoftActiveSyncFolderType folderType;  
  int userResponse;
  int status;
  
  s = [NSMutableString string];
  status = 1;

  realCollectionId = [[[(id)[theDocumentElement getElementsByTagName: @"CollectionId"] lastObject] textValue] realCollectionIdWithFolderType: &folderType];
  realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];
  userResponse = [[[(id)[theDocumentElement getElementsByTagName: @"UserResponse"] lastObject] textValue] intValue];
  easRequestId = [[(id)[theDocumentElement getElementsByTagName: @"RequestId"] lastObject] textValue];
  appointmentObject = nil;
  calendarId = nil;

  // Outlook 2013 calls MeetingResponse on the calendar folder! We have
  // no way of handling as we can't retrieve the email (using the id found
  // in requestId) in any mail folder! If that happens, let's simply
  // assume it comes from the INBOX. This should be generally safe as people
  // will answer email invitations as they receive them on their INBOX.
  // Note that the mail should also still be there as MeetingResponse is
  // called *before* MoveItems.
  //
  // Apple iOS will also call MeetingResponse on the calendar folder when the
  // user accepts/declines the meeting from the Calendar application. Before
  // falling back on INBOX, we first check if we can find the event in the 
  // personal calendar.
  if (folderType == ActiveSyncEventFolder)
    {
      collection = [[context activeUser] personalCalendarFolderInContext: context];

      nameInCache = [NSString stringWithFormat: @"vevent/%@", [collection nameInContainer]];
      folderMetadata = [self _folderMetadataForKey: nameInCache];

      uidCache = [folderMetadata objectForKey: @"UidCache"];
      if (uidCache)
        {
          requestId = [[uidCache allKeysForObject: easRequestId] objectAtIndex: 0];

          if (requestId)
            {
              if (debugOn)
                [self logWithFormat: @"EAS - Found requestId: %@ for easRequestId: %@", requestId, easRequestId];
            }
          else
            {
              if (debugOn)
                [self logWithFormat: @"EAS - Use original requestId: %@", easRequestId];

              requestId = easRequestId;
            }
        }
      else
        requestId = easRequestId;

      appointmentObject = [collection lookupName: [requestId sanitizedServerIdWithType: ActiveSyncEventFolder]
                                       inContext: context
                                         acquire: NO];
      calendarId = easRequestId;
      
      // Object not found, let's fallback on the INBOX folder
      if ([appointmentObject isKindOfClass: [NSException class]])
        {
          folderType = ActiveSyncMailFolder;
          realCollectionId = @"INBOX";
          appointmentObject = nil;
        }
    }
  
  // Fetch the appointment object from the mail message
  if (!appointmentObject)
    {
      collection = [self collectionFromId: realCollectionId  type: folderType];
      
      //
      // We fetch the calendar information based on the email (requestId) in the user's INBOX (or elsewhere)
      //
      // FIXME: that won't work too well for external invitations...
      mailObject = [collection lookupName: easRequestId
                                inContext: context
                                  acquire: 0];
      
      if (![mailObject isKindOfClass: [NSException class]])
        {
          iCalCalendar *calendar;
          iCalEvent *event;

          calendar = [mailObject calendarFromIMIPMessage];
          event = [[calendar events] lastObject];
          calendarId = [event uid];

          // Fetch the SOGoAppointmentObject
          collection = [[context activeUser] personalCalendarFolderInContext: context];
          nameInCache = [NSString stringWithFormat: @"vevent/%@", [collection nameInContainer]];

          [self _setOrUnsetSyncRequest: YES  collections: [NSArray arrayWithObject: nameInCache]];
          folderMetadata = [self _folderMetadataForKey: nameInCache];
          uidCache = [folderMetadata objectForKey: @"UidCache"];

          appointmentObject = [collection lookupName: [NSString stringWithFormat: @"%@.ics", [event uid]]
                                           inContext: context
                                             acquire: NO];

          if ([appointmentObject isKindOfClass: [NSException class]])
            appointmentObject = [self _eventObjectWithUID:[event uid]];

          // Create the appointment if it is not added to calendar yet
          if ([appointmentObject isKindOfClass: [NSException class]])
            {
              appointmentObject = [[SOGoAppointmentObject alloc] initWithName: [NSString stringWithFormat: @"%@.ics", [event uid]]
                                                                  inContainer: collection];
              [appointmentObject saveComponent: event force: YES];
           }

          if (uidCache && [calendarId length] > 64)
            {
              calendarId  = [uidCache objectForKey: [event uid]];

              if (![calendarId length])
                {
                  calendarId = [collection globallyUniqueObjectId];
                  [uidCache setObject: calendarId forKey: [event uid]];

                  [self _setFolderMetadata: folderMetadata forKey: nameInCache];

                  if (debugOn)
                    [self logWithFormat: @"EAS - Generated new calendarId: %@ for serverId: %@", calendarId, [event uid]];
                }
              else
                {
                  if (debugOn)
                    [self logWithFormat: @"EAS - Reuse calendarId: %@ for serverId: %@", calendarId, [event uid]];
                }
            }
        }
    }
     
  if (appointmentObject && 
      calendarId &&
      (![appointmentObject isKindOfClass: [NSException class]]))
    {
      // 1 -> accepted, 2 -> tentative, 3 -> declined
      if (userResponse == 1)
        participationStatus = @"ACCEPTED";
      else if (userResponse == 2)
        participationStatus = @"TENTATIVE";
      else
        participationStatus = @"DECLINED";
      
      [appointmentObject changeParticipationStatus: participationStatus
                                      withDelegate: nil
                                             alarm: nil];

      [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
      [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
      [s appendString: @"<MeetingResponse xmlns=\"MeetingResponse:\">"];
      [s appendString: @"<Result>"];
      [s appendFormat: @"<RequestId>%@</RequestId>", easRequestId];
      [s appendFormat: @"<CalendarId>%@</CalendarId>", calendarId];
      [s appendFormat: @"<Status>%d</Status>", status];
      [s appendString: @"</Result>"];
      [s appendString: @"</MeetingResponse>"];
      
      d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
      
      [theResponse setContent: d];
    }
  else
    {
      [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
      [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
      [s appendString: @"<MeetingResponse xmlns=\"MeetingResponse:\">"];
      [s appendString: @"<Result>"];
      [s appendFormat: @"<RequestId>%@</RequestId>", easRequestId];
      [s appendFormat: @"<Status>%d</Status>", 2];
      [s appendString: @"</Result>"];
      [s appendString: @"</MeetingResponse>"];
      d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

      [theResponse setContent: d];
    }
}


//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <MoveItems xmlns="Move:">
//  <Move>
//   <SrcMsgId>85</SrcMsgId>
//   <SrcFldId>mail/INBOX</SrcFldId>
//   <DstFldId>mail/toto</DstFldId>
//  </Move>
// </MoveItems>
//
- (void) processMoveItems: (id <DOMElement>) theDocumentElement
               inResponse: (WOResponse *) theResponse
{
  NSString *srcMessageId, *srcFolderId, *dstFolderId, *dstMessageId, *srcNameInCache, *dstNameInCache, *currentSrcFolder, *currentDstFolder;
  NSMutableDictionary *srcFolderMetadata, *dstFolderMetadata, *prevSuccessfulMoveItemsOps, *newSuccessfulMoveItemsOps;
  SOGoMicrosoftActiveSyncFolderType srcFolderType, dstFolderType;
  id <DOMElement> aMoveOperation;
  NSArray *moveOperations;
  NSMutableString *s;
  NSData *d; 
  int i;

  currentSrcFolder = nil;
  currentDstFolder = nil;

  moveOperations = (id)[theDocumentElement getElementsByTagName: @"Move"];

  newSuccessfulMoveItemsOps = [NSMutableDictionary dictionary];
  prevSuccessfulMoveItemsOps = nil;
  srcFolderMetadata = nil;
  dstFolderMetadata = nil;
  currentSrcFolder = nil;
  currentDstFolder = nil;

  s = [NSMutableString string];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<MoveItems xmlns=\"Move:\">"];

  for (i = 0; i < [moveOperations count]; i++)
    {
      aMoveOperation = [moveOperations objectAtIndex: i];
      
      srcMessageId = [[(id)[aMoveOperation getElementsByTagName: @"SrcMsgId"] lastObject] textValue];
      srcFolderId = [[[(id)[aMoveOperation getElementsByTagName: @"SrcFldId"] lastObject] textValue] realCollectionIdWithFolderType: &srcFolderType];
      dstFolderId = [[[(id)[aMoveOperation getElementsByTagName: @"DstFldId"] lastObject] textValue] realCollectionIdWithFolderType: &dstFolderType];

      [self _setOrUnsetSyncRequest: YES  collections: [NSArray arrayWithObjects:
                             [[[(id)[aMoveOperation getElementsByTagName: @"SrcFldId"] lastObject] textValue] stringByUnescapingURL],
                             [[[(id)[aMoveOperation getElementsByTagName: @"DstFldId"] lastObject] textValue] stringByUnescapingURL], nil ]];

      if (srcFolderType == ActiveSyncMailFolder)
        srcNameInCache = [NSString stringWithFormat: @"folder%@", [[[[(id)[aMoveOperation getElementsByTagName: @"SrcFldId"] lastObject] textValue] stringByUnescapingURL] substringFromIndex: 5]];
      else
        srcNameInCache = [[[(id)[aMoveOperation getElementsByTagName: @"SrcFldId"] lastObject] textValue] stringByUnescapingURL];
      
      if (![srcNameInCache isEqualToString: currentSrcFolder])
        {
          srcFolderMetadata = [self _folderMetadataForKey: srcNameInCache];
          prevSuccessfulMoveItemsOps = [srcFolderMetadata objectForKey: @"SuccessfulMoveItemsOps"];
          currentSrcFolder = srcNameInCache;
        }

      if (dstFolderType == ActiveSyncMailFolder)
        dstNameInCache = [NSString stringWithFormat: @"folder%@", [[[[(id)[aMoveOperation getElementsByTagName: @"DstFldId"] lastObject] textValue] stringByUnescapingURL] substringFromIndex: 5]];
      else
        dstNameInCache = [[[(id)[aMoveOperation getElementsByTagName: @"DstFldId"] lastObject] textValue] stringByUnescapingURL];

      if (![dstNameInCache isEqualToString: currentDstFolder])
        {
          dstFolderMetadata = [self _folderMetadataForKey: dstNameInCache];
          currentDstFolder = dstNameInCache;
        }

      [s appendString: @"<Response>"];

      if (srcFolderType == ActiveSyncMailFolder && dstFolderType == ActiveSyncMailFolder)
        {
          NGImap4Client *client;
          id currentCollection;
          
          NSDictionary *response;
          NSString *v;
          
          srcFolderId = [self globallyUniqueIDToIMAPFolderName: srcFolderId  type: srcFolderType];
          dstFolderId = [self globallyUniqueIDToIMAPFolderName: dstFolderId  type: dstFolderType];

          currentCollection = [self collectionFromId: srcFolderId  type: srcFolderType];
          
          client = [[currentCollection imap4Connection] client];
          [client select: srcFolderId];
          response = [client copyUid: [srcMessageId intValue]
                            toFolder: [NSString stringWithFormat: @"/%@", dstFolderId]];
          
          // We extract the destionation message id
          dstMessageId = nil;
          
          if ([[response objectForKey: @"result"] boolValue]
              && (v = [[[response objectForKey: @"RawResponse"] objectForKey: @"ResponseResult"] objectForKey: @"flag"])
              && [v hasPrefix: @"COPYUID "])
            {
              dstMessageId = [[v componentsSeparatedByString: @" "] lastObject];
              
              // We mark the original message as deleted
              response = [client storeFlags: [NSArray arrayWithObject: @"Deleted"]
                                    forUIDs: [NSArray arrayWithObject: srcMessageId]
                                addOrRemove: YES];
              
              if ([[response valueForKey: @"result"] boolValue])
                [(SOGoMailFolder *)currentCollection expunge];
              
            }
          
          if (!dstMessageId)
            {
              // Our destination message ID doesn't exist OR even our source message ID doesn't.
              // This can happen if you Move items from your EAS client and immediately closes it
              // before the server had the time to receive or process the query. Then, if that message
              // is moved away by an other client behing the EAS' client back, it obvisouly won't find it.
              // The issue the "result" will still be a success, but in fact, it's a failure. Cyrus generates
              // this kind of query/response for an 'unkknown' message UID (696969) when trying to copy it
              // over to the folder "Trash".
              //
              // 3 uid copy 696969 "Trash"
              // 3 OK Completed
              //
              // See http://msdn.microsoft.com/en-us/library/gg651088(v=exchg.80).aspx for Status response codes.
              //
              [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
              if ([prevSuccessfulMoveItemsOps objectForKey: srcMessageId])
                {
                  // Previous move failed operation but we can recover the dstMessageId from previous request
                  [s appendFormat: @"<DstMsgId>%@</DstMsgId>", [prevSuccessfulMoveItemsOps objectForKey: srcMessageId]];
                  [s appendFormat: @"<Status>%d</Status>", 3];
                  [newSuccessfulMoveItemsOps setObject: [prevSuccessfulMoveItemsOps objectForKey: srcMessageId]  forKey: srcMessageId];
                }
              else
                {
                  [s appendFormat: @"<Status>%d</Status>", 1];
                }
            }
          else
            { 
              //
              // If the MoveItems operation is initiated by an Outlook client, we save the "deviceType+dstMessageId" to use it later in order to
              // modify the Sync command from "add" to "change" (see SOGoActiveSyncDispatcher+Sync.m: -processSyncGetChanges: ...).
              // This is to avoid Outlook creating dupes when moving messages across folfers.
              //
              if ([[context objectForKey: @"DeviceType"] isEqualToString: @"WindowsOutlook15"])
                {
                  NSString *key;
                  
                  // The key must be pretty verbose. We use the <uid>+<DeviceType>+<target folder>+<DstMsgId>
                  key = [NSString stringWithFormat: @"%@+%@+%@+%@",
                                  [[context activeUser] login],
                             [context objectForKey: @"DeviceType"],
                                  dstFolderId,
                                  dstMessageId];
                  
                  
                  [[SOGoCache sharedCache] setValue: @"MovedItem"
                                             forKey: key];
                }
              
              // Everything is alright, lets return the proper response. "Status == 3" means success.
              [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
              [s appendFormat: @"<DstMsgId>%@</DstMsgId>", dstMessageId];
              [s appendFormat: @"<Status>%d</Status>", 3];

              // Save dstMessageId in cache - it will help to recover if the request fails before the response can be sent to client
              [newSuccessfulMoveItemsOps setObject: dstMessageId  forKey: srcMessageId];
            }
        }
      else
        {
          id srcCollection, dstCollection, srcSogoObject, dstSogoObject;
          NSArray *elements, *srcObjectRoles, *dstObjectRoles;
          NSString *newUID, *origSrcMessageId;
          NSMutableDictionary *srcUidCache, *dstUidCache, *srcSyncCache, *srcDateCache, *dstSyncCache;
          NSException *ex;

          unsigned int count, max;

          srcCollection = [self collectionFromId: srcFolderId  type: srcFolderType];

          if ([srcCollection isKindOfClass: [NSException class]])
            {
              [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
              [s appendFormat: @"<Status>%d</Status>", 1];
              continue;
            }

          dstCollection = [self collectionFromId: dstFolderId  type: srcFolderType];

          if ([dstCollection isKindOfClass: [NSException class]])
            {
              [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
              [s appendFormat: @"<Status>%d</Status>", 2];
              continue;
            }

          origSrcMessageId = srcMessageId;
          srcUidCache = [srcFolderMetadata objectForKey: @"UidCache"];
          dstUidCache = [dstFolderMetadata objectForKey: @"UidCache"];
          dstSyncCache = [dstFolderMetadata objectForKey: @"SyncCache"];

          if (srcUidCache && (srcMessageId = [[srcUidCache allKeysForObject: origSrcMessageId] objectAtIndex: 0]))
            {
              if (debugOn)
                [self logWithFormat: @"EAS - Found serverId: %@ for easId: %@", srcMessageId, origSrcMessageId];
            }
          else
            srcMessageId = origSrcMessageId;

          srcSogoObject = [srcCollection lookupName: [srcMessageId sanitizedServerIdWithType: srcFolderType]
                                          inContext: context
                                            acquire: NO];
          
          if (![srcSogoObject isKindOfClass: [NSException class]])
            {
              newUID = [srcSogoObject globallyUniqueObjectId];
              dstSogoObject = [[SOGoAppointmentObject alloc] initWithName: [newUID sanitizedServerIdWithType: srcFolderType]
                                                               inContainer: dstCollection];

              dstObjectRoles = [dstSogoObject aclsForUser: [[context activeUser] login]];
              srcObjectRoles = [srcSogoObject aclsForUser: [[context activeUser] login]];

              if (([dstObjectRoles containsObject: SOGoRole_ObjectCreator] || [[dstSogoObject ownerInContext: context] isEqualToString: [[context activeUser] login]]) &&
                  ([srcObjectRoles containsObject: SOGoRole_ObjectEraser] || [[srcSogoObject ownerInContext: context] isEqualToString: [[context activeUser] login]]))
                {
                  elements = [[srcSogoObject calendar: NO secure: NO] allObjects];
                  max = [elements count];
                  for (count = 0; count < max; count++)
                    [[elements objectAtIndex: count] setUid: newUID];
                  
                  ex = [dstSogoObject saveCalendar: [srcSogoObject calendar: NO secure: NO]];
                }
              else
                {
                  if (debugOn)
                    [self logWithFormat: @"EAS - MoveItem failed due to missing permissions: srcMessageId: %@ dstMessageId: %@", srcMessageId, newUID];

                  // Make sure that the entry gets re-added to the source folder.
                  srcSyncCache = [srcFolderMetadata objectForKey: @"SyncCache"];
                  srcDateCache = [srcFolderMetadata objectForKey: @"DateCache"];
                  [srcSyncCache removeObjectForKey: srcMessageId];
                  [srcDateCache removeObjectForKey: srcMessageId];

                  // Make sure that the entry gets removed from the destination folder.
                  [dstSyncCache setObject: [dstFolderMetadata objectForKey: @"SyncKey"]  forKey: newUID];
                  ex = [dstSogoObject saveCalendar: [srcSogoObject calendar: NO secure: YES]];
                  ex = [dstSogoObject delete];
                }
            }


          if (!ex && ![srcSogoObject isKindOfClass: [NSException class]])
            {
              if (([dstObjectRoles containsObject: SOGoRole_ObjectCreator] || [[dstSogoObject ownerInContext: context] isEqualToString: [[context activeUser] login]]) &&
                  ([srcObjectRoles containsObject: SOGoRole_ObjectEraser] || [[srcSogoObject ownerInContext: context] isEqualToString: [[context activeUser] login]]))
                ex = [srcSogoObject delete];
              else
                ex = [srcSogoObject touch]; // make sure to include the object in next sync.

              if (dstUidCache)
                {
                  [dstUidCache setObject: newUID forKey: newUID];

                  if (debugOn)
                    [self logWithFormat: @"EAS - Saved new easId: %@ for serverId: %@", newUID, newUID];
                }

              [dstSyncCache setObject: [dstFolderMetadata objectForKey: @"SyncKey"]  forKey: newUID];

              [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", origSrcMessageId];
              [s appendFormat: @"<DstMsgId>%@</DstMsgId>", newUID];
              [s appendFormat: @"<Status>%d</Status>", 3];

              // Save dstMessageId in cache - it will help to recover if the request fails before the response can be sent to client
              [newSuccessfulMoveItemsOps setObject: newUID  forKey: srcMessageId];
            }
          else
            {
              if ([prevSuccessfulMoveItemsOps objectForKey: srcMessageId])
                {
                  // Move failed but we can recover the dstMessageId from previous request
                  [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", origSrcMessageId];
                  [s appendFormat: @"<DstMsgId>%@</DstMsgId>", [prevSuccessfulMoveItemsOps objectForKey: srcMessageId] ];
                  [s appendFormat: @"<Status>%d</Status>", 3];
                  [newSuccessfulMoveItemsOps setObject: [prevSuccessfulMoveItemsOps objectForKey: srcMessageId]  forKey: srcMessageId];

                  if (dstUidCache)
                    {
                      [dstUidCache setObject: newUID forKey: newUID];

                      if (debugOn)
                        [self logWithFormat: @"EAS - Saved new easId: %@ for serverId: %@", newUID, newUID];
                    }
                }
              else
                {
                  [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", origSrcMessageId];
                  [s appendFormat: @"<Status>%d</Status>", 1];
                }
            }
        }
      
      [s appendString: @"</Response>"];

      [srcFolderMetadata removeObjectForKey: @"SuccessfulMoveItemsOps"];
      [srcFolderMetadata setObject: newSuccessfulMoveItemsOps forKey: @"SuccessfulMoveItemsOps"];
      [self _setFolderMetadata: srcFolderMetadata forKey: srcNameInCache];
      [self _setFolderMetadata: dstFolderMetadata forKey: dstNameInCache];
    }
  
  [s appendString: @"</MoveItems>"];
  
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
}

//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Ping xmlns="Ping:">
//  <HeartbeatInterval>3540</HeartbeatInterval>
//  <Folders>
//   <Folder>
//    <Id>mail%2Fsogo_680f_193506d5_0</Id>
//    <Class>Email</Class>
//   </Folder>
//   <Folder>
//    <Id>vevent/personal</Id>
//    <Class>Calendar</Class>
//   </Folder>
//   <Folder>
//    <Id>vcard/personal</Id>
//    <Class>Contacts</Class>
//   </Folder>
//   <Folder>
//    <Id>mail%2Fsogo_680f_193506d5_1</Id>
//    <Class>Email</Class>
//   </Folder>
//   <Folder>
//    <Id>mail%2Fsogo_680f_193506d5_2</Id>
//    <Class>Email</Class>
//   </Folder>
//   <Folder>
//    <Id>vtodo/personal</Id>
//    <Class>Tasks</Class>
//   </Folder>
//   <Folder>
//    <Id>mail%2Fsogo_753e_193511a1_0</Id>
//    <Class>Email</Class>
//   </Folder>
//   <Folder>
//    <Id>mail%2Fsogo_753e_193511a1_1</Id>
//    <Class>Email</Class>
//   </Folder>
//  </Folders>
// </Ping>
//
- (void) processPing: (id <DOMElement>) theDocumentElement
          inResponse: (WOResponse *) theResponse
{
  NSString *collectionId, *realCollectionId, *syncKey, *processIdentifier, *pingRequestInCache;
  NSMutableArray *foldersWithChanges, *allFoldersID;
  SOGoMicrosoftActiveSyncFolderType folderType;
  NSMutableDictionary *folderMetadata;
  SOGoSystemDefaults *defaults;
  SOGoCacheGCSObject *o;
  id <DOMElement> aCollection;
  NSArray *allCollections;

  NSMutableString *s;
  id collection;
  NSData *d;
  NSAutoreleasePool *pool;

  int i, j, heartbeatInterval, defaultInterval, internalInterval, status, total_sleep, sleepInterval;
  
  // Let other ping requests know that a new request has arrived.
  processIdentifier = [NSString stringWithFormat: @"%d", [[NSProcessInfo processInfo] processIdentifier]];
  o = [SOGoCacheGCSObject objectWithName: [context objectForKey: @"DeviceId"]  inContainer: nil  useCache: NO];
  [o setObjectType: ActiveSyncGlobalCacheObject];
  [o setTableUrl: [self folderTableURL]];
  [o reloadIfNeeded];
  [[o properties] setObject: processIdentifier forKey: @"PingRequest"];
  [o save];

  defaults = [SOGoSystemDefaults sharedSystemDefaults];
  defaultInterval = [defaults maximumPingInterval];
  internalInterval = [defaults internalSyncInterval];
  sleepInterval = (internalInterval < 5) ? 5 : internalInterval;

  if (theDocumentElement)
    heartbeatInterval = [[[(id)[theDocumentElement getElementsByTagName: @"HeartbeatInterval"] lastObject] textValue] intValue];
  else
    heartbeatInterval = defaultInterval;
  
  if (heartbeatInterval > defaultInterval || heartbeatInterval == 0)
    {
      heartbeatInterval = defaultInterval;
      status = 5;
    }
  else
    {
      if (heartbeatInterval < internalInterval)
        heartbeatInterval = internalInterval; 

      status = 1;
    }

  // We build the list of folders to "ping". When the payload is empty, we use the list
  // of "cached" folders.
  allCollections = (id)[theDocumentElement getElementsByTagName: @"Folder"];
  allFoldersID = [NSMutableArray array];

  if (![allCollections count])
    {
      heartbeatInterval = [[[o properties] objectForKey: @"PingHeartbeatInterval"] intValue];

      if (debugOn)
        [self logWithFormat: @"EAS - Empty Ping request - using cached HeatbeatInterval (%d)", heartbeatInterval];

      if (heartbeatInterval > defaultInterval || heartbeatInterval == 0)
        {
          heartbeatInterval = defaultInterval;
          status = 5;
        }

      allFoldersID = [[o properties] objectForKey: @"PingCachedFolders"];
      if (![allFoldersID count])
        {
          // We received an empty Ping request. Return status '3' to ask client to resend the request with complete body.
          s = [NSMutableString string];
          [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
          [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
          [s appendString: @"<Ping xmlns=\"Ping:\">"];
          [s appendString: @"<Status>3</Status>"];
          [s appendString: @"</Ping>"];

          d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

          [theResponse setContent: d];

          return;
        }

      if (debugOn)
        [self logWithFormat: @"EAS - Empty Ping request - using cached folders %@", allFoldersID];
    }
  else
    {      
      for (i = 0; i < [allCollections count]; i++)
        {
          aCollection = [allCollections objectAtIndex: i];
          collectionId = [[(id) [aCollection getElementsByTagName: @"Id"] lastObject] textValue];
          [allFoldersID addObject: collectionId];
        }

      if (![allFoldersID isEqualToArray: [[o properties] objectForKey: @"PingCachedFolders"]])
        {
          if (debugOn)
            [self logWithFormat: @"EAS - Ping - Save folderlist to cache (HeartbeatInterval: %d) (%@)", heartbeatInterval, allFoldersID];

          [[o properties] setObject: [NSNumber numberWithInteger: heartbeatInterval] forKey: @"PingHeartbeatInterval"];
          [[o properties] setObject: allFoldersID forKey: @"PingCachedFolders"];
          [o save];
        }
    }

  foldersWithChanges = [NSMutableArray array];

  // We enter our loop detection change
  for (i = 0; i < (heartbeatInterval/internalInterval); i++)
    {
      if (easShouldTerminate)
        break;

      pool = [[NSAutoreleasePool alloc] init];
      for (j = 0; j < [allFoldersID count]; j++)
        {
          collectionId = [allFoldersID objectAtIndex: j];
          realCollectionId = [collectionId realCollectionIdWithFolderType: &folderType];
          realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];

          // We avoid loading the cache metadata if we can't get the real connection. This can happen
          // for example if the IMAP server is down. We just skip the folder for now.
          if (!realCollectionId)
            continue;

          if (folderType == ActiveSyncMailFolder)
              folderMetadata = [self _folderMetadataForKey: [NSString stringWithFormat: @"folder%@", [[collectionId stringByUnescapingURL] substringFromIndex:5]]];
          else
              folderMetadata = [self _folderMetadataForKey: [collectionId stringByUnescapingURL]];

          collection = [self collectionFromId: realCollectionId  type: folderType];

          // If collection doesn't exist skip it - next foldersync will do the cleanup
          if (!collection)
             continue;
          
          syncKey = [folderMetadata objectForKey: @"SyncKey"];
      
          if (syncKey && ![syncKey isEqualToString: [collection davCollectionTag]])
            {
              [foldersWithChanges addObject: collectionId];
            }
        }
      DESTROY(pool);

      if ([foldersWithChanges count])
        {
          [self logWithFormat: @"Change detected using Ping, we let the EAS client know to send a Sync."];
          status = 2;
          break;
        }
      else
        {
          total_sleep = 0;

          while (!easShouldTerminate && total_sleep < internalInterval)
            {
              // We check if we must break the current ping request since an other ping request
              // has just arrived.
              pingRequestInCache = [[self globalMetadataForDevice] objectForKey: @"PingRequest"];
              if (pingRequestInCache && ![pingRequestInCache isEqualToString: processIdentifier])
                {
                  if (debugOn)
                    [self logWithFormat: @"EAS - Ping request canceled (%@)", pingRequestInCache];

                  // Make sure we end the heardbeat-loop.
                  internalInterval = heartbeatInterval;

                  break;
                }
              else
                {
		  int t;

                  [self logWithFormat: @"Sleeping %d seconds while detecting changes for user %@ in Ping...", internalInterval-total_sleep, [[context activeUser] login]];

		  for (t = 0; t < sleepInterval; t++)
		    {
		      if (easShouldTerminate)
			break;
		      sleep(1);
		    }
                  total_sleep += sleepInterval;
                }
            }
        }
    }
  
  // We generate our response
  s = [NSMutableString string];
  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<Ping xmlns=\"Ping:\">"];
  [s appendFormat: @"<Status>%d</Status>", status];
  
  if ([foldersWithChanges count])
    {
      [s appendString: @"<Folders>"];

      for (i = 0; i < [foldersWithChanges count]; i++)
        {
          // A bit tricky here because we must call stringByEscapingURL on mail folders, but not on GCS ones.
          // We do the same thing in -processFolderSync
          collectionId = [foldersWithChanges objectAtIndex: i];

          if ([collectionId hasPrefix: @"mail/"])
            collectionId = [collectionId stringByEscapingURL];

          [s appendFormat: @"<Folder>%@</Folder>", collectionId];
        }

      [s appendString: @"</Folders>"];
    }

  if (status == 5)
    {
      [s appendFormat: @"<HeartbeatInterval>%d</HeartbeatInterval>", heartbeatInterval];
    }

  [s appendString: @"</Ping>"];
  
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
}

//
// We ignore everything for now.
//
- (void) processProvision: (id <DOMElement>) theDocumentElement
               inResponse: (WOResponse *) theResponse
{
  NSMutableString *s;
  NSData *d;
  
  s = [NSMutableString string];
  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<Provision xmlns=\"Provision:\">"];
  [s appendString: @"<AllowHTMLEmail>1</AllowHTMLEmail>"];
  [s appendString: @"</Provision>"];
  
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
}

//
//
//
#ifdef HAVE_OPENSSL
- (unsigned int) validateCert: (NSString *) theCert
{
  NSData *d;

  const unsigned char *data;
  X509_STORE_CTX *ctx;
  X509_LOOKUP *lookup;
  X509_STORE *store;
  X509 *cert;

  BOOL success;
  size_t len;
  int rc;

  success = NO;

  d = [theCert dataByDecodingBase64];
  data = (unsigned char *)[d bytes];
  len = [d length];

  cert = d2i_X509(NULL, &data, len);
  if (!cert)
    {
      [self logWithFormat: @"EAS - validateCert failed for device %@: d2i_X509 failed", [context objectForKey: @"DeviceId"]];
      return 17;
    }

  store = X509_STORE_new();
  OpenSSL_add_all_algorithms();

  if (store)
    {
      lookup = X509_STORE_add_lookup(store, X509_LOOKUP_file());
      if (lookup)
        {
          X509_LOOKUP_load_file(lookup, NULL, X509_FILETYPE_DEFAULT);
          lookup = X509_STORE_add_lookup(store, X509_LOOKUP_hash_dir());
          if (lookup)
            {
              X509_LOOKUP_add_dir(lookup, NULL, X509_FILETYPE_DEFAULT);
              ERR_clear_error();
              success = YES;
            }
        }
    }

  if (!success)
    {
      if (store)
        {
          X509_STORE_free(store);
          store = NULL;
        }
    }

  ctx = X509_STORE_CTX_new();
  if (!ctx)
    {
      [self logWithFormat: @"EAS - validateCert failed for device %@: X509_STORE_CTX_new failed", [context objectForKey: @"DeviceId"]];
      return 17;
    }

  if (X509_STORE_CTX_init(ctx, store, cert, NULL) != 1)
    {
      [self logWithFormat: @"EAS - validateCert failed for device %@: X509_STORE_CTX_init failed", [context objectForKey: @"DeviceId"]];
      X509_STORE_CTX_free(ctx);
      return 17;
    }

  rc = X509_verify_cert(ctx);
  X509_STORE_CTX_free(ctx);
  X509_free(cert);

  if (rc)
    {
      return 1;
    }
  else
    {
      [self logWithFormat: @"EAS - validateCert failed for device %@: err=%d", [context objectForKey: @"DeviceId"], X509_STORE_CTX_get_error(ctx)];
      return 17;
    }
}
#else
- (unsigned int) validateCert: (NSString *) theCert
{
  return 17;
}
#endif

- (void) processValidateCert: (id <DOMElement>) theDocumentElement
                  inResponse: (WOResponse *) theResponse
{
  NSMutableString *s;
  NSString *cert;
  NSData *d;

  cert =  [[(id)[theDocumentElement getElementsByTagName: @"Certificate"] lastObject] textValue];

  s = [NSMutableString string];
  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<ValidateCert xmlns=\"ValidateCert:\">"];
  [s appendString: @"<Status>1</Status><Certificate>"];
  [s appendFormat: @"<Status>%d</Status>", [self validateCert: cert]];
  [s appendString: @"</Certificate></ValidateCert>"];

  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

  [theResponse setContent: d];
}


//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <ResolveRecipients xmlns="ResolveRecipients:">
//  <To>sogo1@example.com</To>
//  <To>sogo10@sogoludo.inverse</To>
//  <Options>
//   <MaxAmbiguousRecipients>19</MaxAmbiguousRecipients>
//   <Availability>
//    <StartTime>2014-01-16T05:00:00.000Z</StartTime>
//    <EndTime>2014-01-17T04:59:00.000Z</EndTime>
//   </Availability>
//  </Options>
// </ResolveRecipients>
//
- (void) processResolveRecipients: (id <DOMElement>) theDocumentElement
                       inResponse: (WOResponse *) theResponse
{
  NSArray *allRecipients;
  int i, j, k;

  allRecipients = (id)[theDocumentElement getElementsByTagName: @"To"];

  if ([allRecipients count] && [(id)[theDocumentElement getElementsByTagName: @"Availability"] count])
    {
      NSCalendarDate *startDate, *endDate;
      SOGoAppointmentFolder *folder;
      NSString *aRecipient, *login;
      NSMutableString *s;
      NSArray *freebusy;
      SOGoUser *user;
      NSData *d;

      unsigned int startdate, enddate, increments;
      NGCalendarDateRange *r1, *r2;
      char c;

      startDate = [[[(id)[theDocumentElement getElementsByTagName: @"StartTime"] lastObject] textValue] calendarDate];
      startdate = [startDate timeIntervalSince1970];

      endDate = [[[(id)[theDocumentElement getElementsByTagName: @"EndTime"] lastObject] textValue] calendarDate];
      enddate = [endDate timeIntervalSince1970];
      
      // Number of 30 mins increments between our two dates
      increments = ceil((float)((enddate - startdate)/60/30)) + 1;
        
      s = [NSMutableString string];
  
      [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
      [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
      [s appendString: @"<ResolveRecipients xmlns=\"ResolveRecipients:\">"];
      [s appendFormat: @"<Status>%d</Status>", 1];

      for (i = 0; i < [allRecipients count]; i++)
        {
          aRecipient = [[allRecipients objectAtIndex: i] textValue];
          
          login = [[SOGoUserManager sharedUserManager] getUIDForEmail: aRecipient];

          if (login)
            {
              user = [SOGoUser userWithLogin: login];
              
              [s appendString: @"<Response>"];
              [s appendFormat: @"<To>%@</To>", aRecipient];
              [s appendFormat: @"<Status>%d</Status>", 1];
              [s appendFormat: @"<RecipientCount>%d</RecipientCount>", 1];

              [s appendString: @"<Recipient>"];              
              [s appendFormat: @"<Type>%d</Type>", 1];
              [s appendFormat: @"<DisplayName>%@</DisplayName>", [user cn]];
              [s appendFormat: @"<EmailAddress>%@</EmailAddress>", [[user allEmails] objectAtIndex: 0]];

              // Freebusy structure: http://msdn.microsoft.com/en-us/library/gg663493(v=exchg.80).aspx
              [s appendString: @"<Availability>"];
              [s appendFormat: @"<Status>%d</Status>", 1];
              [s appendString: @"<MergedFreeBusy>"];

              folder = [user personalCalendarFolderInContext: context];
              freebusy = [folder fetchFreeBusyInfosFrom: startDate  to: endDate];
              
              for (j = 0; j < increments; j++)
                {
                  c = '0';
                  
                  r1  =  [NGCalendarDateRange calendarDateRangeWithStartDate: [NSDate dateWithTimeIntervalSince1970: (startdate+j*30*60)]
                                                                     endDate: [NSDate dateWithTimeIntervalSince1970: (startdate+j*30*60 + 30)]];

                  for (k = 0; k < [freebusy count]; k++)
                    {
                      
                      r2 = [NGCalendarDateRange calendarDateRangeWithStartDate: [[freebusy objectAtIndex: k] objectForKey: @"startDate"]
                                                                       endDate: [[freebusy objectAtIndex: k] objectForKey: @"endDate"]];
                      
                      if ([r2 doesIntersectWithDateRange: r1])
                        {
                          c = '2';
                          break;
                        }
                    }
                  
                  
                  [s appendFormat: @"%c", c];
                }

              [s appendString: @"</MergedFreeBusy>"];
              [s appendString: @"</Availability>"];
              [s appendString: @"</Recipient>"];
              [s appendString: @"</Response>"];
            }
        }

      [s appendString: @"</ResolveRecipients>"];
      
      d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
      
      [theResponse setContent: d];
    }
}

//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Search xmlns="Search:">
//  <Store>
//   <Name>GAL</Name>
//   <Query>so</Query>
//   <Options>
//    <Range>0-19</Range>
//   </Options>
//  </Store>
// </Search>
//
- (void) processSearchGAL: (id <DOMElement>) theDocumentElement
              inResponse: (WOResponse *) theResponse
{
  SOGoContactSourceFolder *currentFolder;
  NSArray *allKeys, *allContacts, *mails, *a;
  NSDictionary *systemSources, *contact;
  SOGoContactFolders *contactFolders;
  NSString *current_mail, *query;
  SOGoUserFolder *userFolder;

  NSMutableString *s;
  NSData *d;
  id o;

  int i, j, t, v, total, minResult, maxResult, maxSize, maxPictures;
  BOOL withPhoto;

  withPhoto = NO;

  query = [[(id)[theDocumentElement getElementsByTagName: @"Query"] lastObject] textValue];

  userFolder = [[context activeUser] homeFolderInContext: context];
  contactFolders = [userFolder privateContacts: @"Contacts"  inContext: context];
  systemSources = [contactFolders systemSources];
  allKeys = [systemSources allKeys];

  // We check for the maximum number of results to return.
  a = [[[(id)[theDocumentElement getElementsByTagName: @"Range"] lastObject] textValue] componentsSeparatedByString: @"-"];
  minResult = [[a objectAtIndex: 0] intValue];
  maxResult = [[a objectAtIndex: 1] intValue];

  if (maxResult == 0)
    maxResult = 99;

  if ((o = [(id)[[(id)[theDocumentElement getElementsByTagName: @"Options"] lastObject] getElementsByTagName: @"Picture"] lastObject]))
    {
      withPhoto = YES;

      // We check for a MaxSize, default to 102400.
      maxSize = [[[(id)[o getElementsByTagName: @"MaxSize"] lastObject] textValue] intValue];

      // We check if we must overwrite the maxSize with a system preference. This can be useful
      // if we don't want to have pictures in the response.
      if ((v = [[SOGoSystemDefaults sharedSystemDefaults] maximumPictureSize]))
        maxSize = v;

      // We check for a MaxPictures, default to 99.
      maxPictures = [[[(id)[o getElementsByTagName: @"MaxPictures"] lastObject] textValue] intValue];

      if (maxPictures == 0)
        maxPictures = 99;
    }

  s = [NSMutableString string];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<Search xmlns=\"Search:\">"];
  [s appendFormat: @"<Status>1</Status>"];
  [s appendFormat: @"<Response>"];
  [s appendFormat: @"<Store>"];
  [s appendFormat: @"<Status>1</Status>"];

  total = 0;

  for (i = 0; i < [allKeys count]; i++)
    {
      currentFolder = [systemSources objectForKey: [allKeys objectAtIndex: i]];
      allContacts = [currentFolder lookupContactsWithFilter: query
                                                 onCriteria: nil
                                                     sortBy: @"c_cn"
                                                   ordering: NSOrderedAscending
                                                   inDomain: [[context activeUser] domain]];

      for (j = minResult; (j < [allContacts count] && j < maxResult) ; j++)
        {          
          contact = [allContacts objectAtIndex: j];
          
          // We skip lists for now and bogus entries
          if ([[contact objectForKey: @"c_component"] isEqualToString: @"vlist"] ||
	      [[contact objectForKey: @"c_name"] length] == 0)
            continue;
          
          // We get the LDIF entry of our record, for easier processing
          contact = [[currentFolder lookupName: [contact objectForKey: @"c_name"] inContext: context  acquire: NO] ldifRecord];
 
          o = [contact objectForKey: @"mail"];
          if ([o isKindOfClass: [NSArray class]])
            mails = o;
          else
            mails = [NSArray arrayWithObjects: o ? o : @"", nil];

          for (t = 0; t < [mails count]; t++)
            {
              current_mail = [mails objectAtIndex: t];
              
              [s appendString: @"<Result xmlns=\"Search:\">"];
              [s appendString: @"<Properties>"];
              
              if ((o = [contact objectForKey: @"displayname"]))
                [s appendFormat: @"<DisplayName xmlns=\"Gal:\">%@</DisplayName>", [o activeSyncRepresentationInContext: context]];
              
              if ((o = [contact objectForKey: @"title"]))
                [s appendFormat: @"<Title xmlns=\"Gal:\">%@</Title>", [o activeSyncRepresentationInContext: context]];
              
              if ((o = [contact objectForKey: @"givenname"]))
                [s appendFormat: @"<FirstName xmlns=\"Gal:\">%@</FirstName>", [o activeSyncRepresentationInContext: context]];
              
              if ((o = [contact objectForKey: @"sn"]))
                [s appendFormat: @"<LastName xmlns=\"Gal:\">%@</LastName>", [o activeSyncRepresentationInContext: context]];
              
              if ([current_mail length] > 0)
                [s appendFormat: @"<EmailAddress xmlns=\"Gal:\">%@</EmailAddress>", [current_mail activeSyncRepresentationInContext: context]];
              
              if ((o = [contact objectForKey: @"telephonenumber"]))
                [s appendFormat: @"<Phone xmlns=\"Gal:\">%@</Phone>", [o activeSyncRepresentationInContext: context]];
              
              if ((o = [contact objectForKey: @"homephone"]))
                [s appendFormat: @"<HomePhone xmlns=\"Gal:\">%@</HomePhone>", [o activeSyncRepresentationInContext: context]];
              
              if ((o = [contact objectForKey: @"mobile"]))
                [s appendFormat: @"<MobilePhone xmlns=\"Gal:\">%@</MobilePhone>", [o activeSyncRepresentationInContext: context]];
              
              if ((o = [contact objectForKey: @"o"]))
                [s appendFormat: @"<Company xmlns=\"Gal:\">%@</Company>", [o activeSyncRepresentationInContext: context]];

              if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 14.1 && withPhoto)
                {
                  o = [contact objectForKey: @"photo"];
                  if (o && [o length] <= maxSize && total < maxPictures)
                    {
                      [s appendString: @"<Picture xmlns=\"Gal:\"><Status>1</Status><Data>"];
                      [s appendString: [o activeSyncRepresentationInContext: context]];
                      [s appendString: @"</Data></Picture>"];
                    }
                  else if (!o)
                    [s appendString: @"<Picture xmlns=\"Gal:\"><Status>173</Status></Picture>"];
                  else if ([o length] > maxSize)
                    [s appendString: @"<Picture xmlns=\"Gal:\"><Status>174</Status></Picture>"];
                  else if (total >= maxPictures)
                    [s appendString: @"<Picture xmlns=\"Gal:\"><Status>175</Status></Picture>"];
                }

              [s appendString: @"</Properties>"];
              [s appendString: @"</Result>"];
              total++;
            }
        }        
    }
  
  [s appendFormat: @"<Range>0-%d</Range>", (total ? total-1 : 0)];
  [s appendFormat: @"<Total>%d</Total>", total];
  [s appendString: @"</Store>"];
  [s appendString: @"</Response>"];
  [s appendString: @"</Search>"];

  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
}

- (EOQualifier *) _qualifierFromMailboxSearchQuery: (id <DOMElement>) theDocumentElement
{
  id <DOMElement> andElement, freeTextElement, greaterThanElement;

  andElement = [(id)[theDocumentElement getElementsByTagName: @"And"] lastObject];
  if (andElement)
    {
      EOQualifier *subjectQualifier, *senderQualifier, *fetchQualifier, *notDeleted, *greaterThanQualifier, *orQualifier;
      NSString *query;
      id o;

      freeTextElement = [(id)[andElement getElementsByTagName: @"FreeText"] lastObject];
      query = [(id)freeTextElement textValue];
      greaterThanQualifier = nil;

      if (!query)
	return nil;

      // We check for the date ranges - we only support the GreaterThan since
      // the IMAP protocol is limited in this regard
      greaterThanElement = [(id)[andElement getElementsByTagName: @"GreaterThan"] lastObject];
      if (greaterThanElement && [(id)[greaterThanElement getElementsByTagName: @"DateReceived"] lastObject])
	{
	  o = [[(id)[greaterThanElement getElementsByTagName: @"Value"] lastObject] textValue];
	  greaterThanQualifier = [EOQualifier qualifierWithQualifierFormat:
						@"(DATE >= %@)", [o calendarDate]];
	}

      notDeleted = [EOQualifier qualifierWithQualifierFormat: @"(not (flags = %@))", @"deleted"];
      subjectQualifier = [EOQualifier qualifierWithQualifierFormat: [NSString stringWithFormat: @"(%@ doesContain: '%@')", @"subject", query]];
      senderQualifier = [EOQualifier qualifierWithQualifierFormat: [NSString stringWithFormat: @"(%@ doesContain: '%@')", @"from", query]];

      orQualifier = [[EOOrQualifier alloc] initWithQualifiers: subjectQualifier, senderQualifier, nil];

      fetchQualifier = [[EOAndQualifier alloc] initWithQualifiers: notDeleted, orQualifier, greaterThanQualifier, nil];

      return [fetchQualifier autorelease];
    }

  return nil;
}

//
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Search xmlns="Search:">
//  <Store>
//   <Name>Mailbox</Name>
//   <Query>
//    <And>
//     <CollectionId xmlns="AirSync:">mail%2Fsogo_7f53_1c63c93c_1</CollectionId>
//     <FreeText>aaa;bbb;09/12/2016-09/19/2016;ccc;ddd;</FreeText>
//     <GreaterThan>
//      <DateReceived xmlns="Email:"/>
//      <Value>2015-09-19T04:00:00.000Z</Value>
//     </GreaterThan>
//     <LessThan>
//      <DateReceived xmlns="Email:"/>
//      <Value>2016-09-19T14:26:00.000Z</Value>
//     </LessThan>
//    </And>
//   </Query>
//   <Options>
//    <RebuildResults/>
//    <Range>0-99</Range>
//    <BodyPreference xmlns="AirSyncBase:">
//     <Type>1</Type>
//     <TruncationSize>51200</TruncationSize>
//    </BodyPreference>
//    <MIMESupport xmlns="AirSync:">2</MIMESupport>
//    <RightsManagementSupport xmlns="RightsManagement:">1</RightsManagementSupport>
//   </Options>
//  </Store>
// </Search>
//
- (void) processSearchMailbox: (id <DOMElement>) theDocumentElement
		   inResponse: (WOResponse *) theResponse
{
  NSString *folderId, *realCollectionId, *itemId, *bodyPreferenceType, *mimeSupport;
  NSMutableArray *folderIdentifiers;
  SOGoMailAccounts *accountsFolder;
  SOGoMailAccount *accountFolder;
  SOGoMailFolder *currentFolder;
  SOGoMailObject *mailObject;
  SOGoUserFolder *userFolder;
  EOQualifier *qualifier;
  NSArray *sortedUIDs, *a;
  NSMutableString *s;
  NSData *d;

  SOGoMicrosoftActiveSyncFolderType folderType;
  int i, j, total, begin, startRange, endRange, maxResults, overallTotal;

  overallTotal = 0;

  // We build the qualifier and we launch our search operation
  qualifier = [self _qualifierFromMailboxSearchQuery: [(id)[theDocumentElement getElementsByTagName: @"Query"] lastObject]];

  if (!qualifier)
    {
      [theResponse setStatus: 500];
      return;
    }

  bodyPreferenceType = [[(id)[[(id)[theDocumentElement getElementsByTagName: @"BodyPreference"] lastObject] getElementsByTagName: @"Type"] lastObject] textValue];
  [context setObject: bodyPreferenceType  forKey: @"BodyPreferenceType"];
  mimeSupport = [[(id)[theDocumentElement getElementsByTagName: @"MIMESupport"] lastObject] textValue];
  [context setObject: mimeSupport  forKey: @"MIMESupport"];

  [context setObject: @"8" forKey: @"MIMETruncation"];

  // We check for the maximum number of results to return.
  a = [[[(id)[theDocumentElement getElementsByTagName: @"Range"] lastObject] textValue] componentsSeparatedByString: @"-"];
  startRange = [[a objectAtIndex: 0] intValue];
  begin = startRange;
  endRange = [[a objectAtIndex: 1] intValue];
  maxResults = endRange - startRange;

  if (maxResults == 0)
    maxResults = endRange = 99;

  // FIXME: support more than one CollectionId tag + DeepTraversal
  folderId = [[(id)[[(id)[theDocumentElement getElementsByTagName: @"Query"] lastObject] getElementsByTagName: @"CollectionId"] lastObject] textValue];
  folderIdentifiers = [NSMutableArray array];

  // Android 6 will send search requests with no collection ID - so we search in all folders.
  // Outlook Mobile App sends search requests with CollectionId=0 - We treat this as an all-folder-search.
  if (!folderId || [folderId isEqualToString: @"0"])
    {
      NSArray *foldersInCache;
      SOGoCacheGCSObject *o;
      NSString *prefix;

      o = [SOGoCacheGCSObject objectWithName: @"0" inContainer: nil];
      [o setObjectType: ActiveSyncFolderCacheObject];
      [o setTableUrl: folderTableURL];

      foldersInCache = [o cacheEntriesForDeviceId: [context objectForKey: @"DeviceId"] newerThanVersion: -1];
      prefix = [NSString stringWithFormat: @"/%@+folder", [context objectForKey: @"DeviceId"]];

      for (i = 0; i < [foldersInCache count]; i++)
	{
	  folderId = [foldersInCache objectAtIndex: i];
	  if ([folderId hasPrefix: prefix])
	    {
	      folderId = [NSString stringWithFormat: @"mail/%@", [folderId substringFromIndex: [prefix length]]];
	      [folderIdentifiers addObject: folderId];
	    }
	}
    }
  else
    {
      [folderIdentifiers addObject: folderId];
    }

  userFolder = [[context activeUser] homeFolderInContext: context];
  accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
  accountFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];

  // Prepare the response
  s = [NSMutableString string];
  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<Search xmlns=\"Search:\">"];
  [s appendFormat: @"<Status>1</Status>"];
  [s appendFormat: @"<Response>"];
  [s appendFormat: @"<Store>"];
  [s appendFormat: @"<Status>1</Status>"];

  for (i = 0; i < [folderIdentifiers count]; i++)
    {
      folderId = [folderIdentifiers objectAtIndex: i];
      realCollectionId = [folderId realCollectionIdWithFolderType: &folderType];
      realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];

      currentFolder = [accountFolder lookupName: [NSString stringWithFormat: @"folder%@", realCollectionId]
				      inContext: context
					acquire: NO];

      sortedUIDs = [currentFolder fetchUIDsMatchingQualifier: qualifier
						sortOrdering: @"REVERSE ARRIVAL"
						    threaded: NO];
      total = [sortedUIDs count];
      overallTotal+=total;

      if (total < startRange)
        {
          begin -= total;
          continue;;
        }

      for (j = begin; j < total && maxResults >= 0; j++)
	{
	  itemId = [[sortedUIDs objectAtIndex: j] stringValue];
	  mailObject = [currentFolder lookupName: itemId  inContext: context  acquire: NO];

	  if ([mailObject isKindOfClass: [NSException class]])
	    continue;

          maxResults--;

	  [s appendString: @"<Result xmlns=\"Search:\">"];
	  [s appendFormat: @"<LongId>%@+%@</LongId>", folderId, itemId];
	  [s appendFormat: @"<CollectionId xmlns=\"AirSyncBase:\">%@</CollectionId>", folderId];
	  [s appendString: @"<Properties>"];
	  [s appendString: [mailObject activeSyncRepresentationInContext: context]];
	  [s appendString: @"</Properties>"];
	  [s appendFormat: @"</Result>"];
	}
    }

  if (overallTotal < startRange)
    overallTotal = 0;

  [s appendFormat: @"<Range>%d-%d</Range>",(overallTotal ? startRange : 0), (overallTotal ? endRange - maxResults - 1 : 0)];
  [s appendFormat: @"<Total>%d</Total>", overallTotal];
  [s appendString: @"</Store>"];
  [s appendString: @"</Response>"];
  [s appendString: @"</Search>"];

  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

  [theResponse setContent: d];
}

//
// We support EAS Search on the GAL and Mailbox.
//
// We do NOT support it on the DocumentLibrary.
//
- (void) processSearch: (id <DOMElement>) theDocumentElement
            inResponse: (WOResponse *) theResponse
{
  NSString *name;

  name = [[(id)[theDocumentElement getElementsByTagName: @"Name"] lastObject] textValue];

  if ([name isEqualToString: @"GAL"])
    {
      return [self processSearchGAL: theDocumentElement
			 inResponse: theResponse];
    }
  else if ([name isEqualToString: @"Mailbox"])
    {
      return [self processSearchMailbox: theDocumentElement
			     inResponse: theResponse];
    }

  [theResponse setStatus: 500];
  return;
}

//
//
//
- (NSException *) _sendMail: (NSData *) theMail
                 recipients: (NSArray *) theRecipients
            saveInSentItems: (BOOL) saveInSentItems
{
  id <SOGoAuthenticator> authenticator;
  SOGoDomainDefaults *dd;
  NSException *error;
  NSString *from;

  authenticator = [SOGoDAVAuthenticator sharedSOGoDAVAuthenticator];
  dd = [[context activeUser] domainDefaults];
  
  // We generate the Sender
  from = [[[context activeUser] allEmails] objectAtIndex: 0];
  
  error = [[SOGoMailer mailerWithDomainDefaults: dd]
                       sendMailData: theMail
                       toRecipients: theRecipients
                             sender: from
                  withAuthenticator: authenticator
                          inContext: context];

  if (error)
    {
      return error;
    }
  
  if (saveInSentItems)
    {
      SOGoMailAccounts *accountsFolder;
      SOGoMailAccount *accountFolder;
      SOGoUserFolder *userFolder;
      SOGoSentFolder *sentFolder;

      userFolder = [[context activeUser] homeFolderInContext: context];
      accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
      accountFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];
      sentFolder = [accountFolder sentFolderInContext: context];

      [sentFolder postData: theMail  flags: @"seen"];
    }

  return nil;
}

- (BOOL) _isEMailValid: (NSString *) email
{
  NSArray *identities;
  int i;

  identities = [[context activeUser] allIdentities];

  for (i = 0; i < [identities count]; i++)
    {
      if ([email isEqualToString: [[identities objectAtIndex: i] objectForKey: @"email"]])
	return YES;
    }

  return NO;
}

- (NSString *) _fullNameForEMail: (NSString *) email
{
  NSArray *identities;
  int i;

  identities = [[context activeUser] allIdentities];

  for (i = 0; i < [identities count]; i++)
    {
      if ([email isEqualToString: [[identities objectAtIndex: i] objectForKey: @"email"]])
	return [[identities objectAtIndex: i] objectForKey: @"fullName"];
    }

  return nil;
}

//
// See https://msdn.microsoft.com/en-us/library/ee218647(v=exchg.80).aspx
// for valid status codes.
//
- (NSData *) _sendMailErrorResponseWithStatus: (int) status
{
  NSMutableString *s;
  NSData *d;

  s = [NSMutableString string];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<SendMail xmlns=\"ComposeMail:\">"];
  [s appendFormat: @"<Status>%d</Status>", status];
  [s appendString: @"</SendMail>"];

  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

  return d;
}

//
//
//
- (void) processSendMail: (id <DOMElement>) theDocumentElement
              inResponse: (WOResponse *) theResponse
{
  NGMimeMessageParser *parser;
  NGMimeMessage *message;
  NSException *error;
  NSMutableData *data;
  NSData *new_from_header;
  NSDictionary *identity;
  NSString *fullName, *email;
  NGMimeType *contentType;
  NSArray *from;

  const char *bytes;
  int i, e, len;
  BOOL found_header;
  email = nil;
  
  // We get the mail's data
  data = [NSMutableData dataWithData: [[[[(id)[theDocumentElement getElementsByTagName: @"MIME"] lastObject] textValue] stringByDecodingBase64] dataUsingEncoding: NSUTF8StringEncoding]];
  
  // We extract the recipients
  parser = [[NGMimeMessageParser alloc] init];
  message = [parser parsePartFromData: data];
  RELEASE(parser);

  // If an EAS client is trying to send an invitation email (request or response), we make sure to
  // remove all attendees that have NO email addresses. Outlook 2016 (and likely other EAS clients)
  // do that when sending IMIP only to "newly added or deleted attendees" - existing attendees have
  // their email addresses stripped, while keeping the display name value.
  contentType = [message contentType];

  if ([contentType isKindOfClass: [NGConcreteTextMimeType class]] &&
      [[[message contentType] subType] caseInsensitiveCompare: @"calendar"] == NSOrderedSame &&
      ([[(NGConcreteTextMimeType *)[message contentType] method] caseInsensitiveCompare: @"request"] == NSOrderedSame ||
       [[(NGConcreteTextMimeType *)[message contentType] method] caseInsensitiveCompare: @"reply"] == NSOrderedSame))
    {
      NGMimeMessageGenerator *generator;
      iCalCalendar *calendar;
      iCalPerson *attendee;
      NSArray *attendees;
      iCalEvent *event;

      calendar = [iCalCalendar parseSingleFromSource: [message body]];
      event = [[calendar events] lastObject];
      attendees = [event attendees];

      for (i = [attendees count]-1; i >= 0; i--)
	{
	  attendee = [attendees objectAtIndex: i];
	  if (![attendee rfc822Email] || [[attendee rfc822Email] caseInsensitiveCompare: @"nomail"] == NSOrderedSame)
	    [event removeFromAttendees: attendee];
	}

      // We regenerate the data to use
      [message setBody: [[calendar versitString] dataUsingEncoding: NSUTF8StringEncoding]];
      generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
      data = [NSMutableData dataWithData: [generator generateMimeFromPart: message]];
    }

  from = [message headersForKey: @"from"];

  if (![from count] || ![self _isEMailValid: [[from objectAtIndex: 0] pureEMailAddress]] ||
      [[[from objectAtIndex: 0] pureEMailAddress] isEqualToString: [from objectAtIndex: 0]] ||
      [[NSString stringWithFormat: @"<%@>", [[from objectAtIndex: 0] pureEMailAddress]] isEqualToString: [from objectAtIndex: 0]])
    {
      if ([from count] && [self _isEMailValid: [[from objectAtIndex: 0] pureEMailAddress]])
        {
          // We have a valid email address, lets fill in the fullname.
          email = [[from objectAtIndex: 0] pureEMailAddress];
          fullName = [self _fullNameForEMail: email];
        }
      else
        {
          // Fallback to primary identity.
          identity = [[context activeUser] primaryIdentity];
          fullName = [identity objectForKey: @"fullName"];
          email = [identity objectForKey: @"email"];
        }

      if ([fullName length])
        new_from_header = [[NSString stringWithFormat: @"From: %@ <%@>\r\n", [fullName asQPSubjectString: @"utf-8"], email] dataUsingEncoding: NSUTF8StringEncoding];
      else
        new_from_header = [[NSString stringWithFormat: @"From: %@\r\n", email] dataUsingEncoding: NSUTF8StringEncoding];

      bytes = [data bytes];
      len = [data length];
      i = 0;
      found_header = NO;

      // Search for the from-header
      while (i < len)
        {
          if (i == 0 &&
              (*bytes == 'f' || *bytes == 'F') &&
              (*(bytes+1) == 'r' || *(bytes+1) == 'R') &&
              (*(bytes+2) == 'o' || *(bytes+2) == 'O') &&
              (*(bytes+3) == 'm' || *(bytes+3) == 'M') &&
              (*(bytes+4) == ':'))
            {
              found_header = YES;
              break;
            }

          if (((*bytes == '\r') && (*(bytes+1) == '\n')) &&
              (*(bytes+2) == 'f' || *(bytes+2) == 'F') &&
              (*(bytes+3) == 'r' || *(bytes+3) == 'R') &&
              (*(bytes+4) == 'o' || *(bytes+4) == 'O') &&
              (*(bytes+5) == 'm' || *(bytes+5) == 'M') &&
              (*(bytes+6) == ':'))
            {
              found_header = YES;
              i = i + 2; // \r\n
              bytes = bytes + 2;
              break;
            }

          bytes++;
          i++;
        }

      // We search for the first \r\n AFTER the From: header to get the length of the string to replace.
      e = i;
      while (e < len)
	{
	  if ((*bytes == '\r') && (*(bytes+1) == '\n'))
	    {
	      e = e + 2;
	      break;
	    }

	  bytes++;
	  e++;
	}

      // Update/Add the From header in the MIMEBody of the SendMail request.
      // Any other way to modify the mail body would break s/mime emails.
      if (found_header)
        {
          // Change the From header
          [data replaceBytesInRange: NSMakeRange(i, (NSUInteger)(e-i))
                          withBytes: [new_from_header bytes]
                             length: [new_from_header length]];
        }
      else
        {
          // Add a From header
          [data replaceBytesInRange: NSMakeRange(0, 0)
                          withBytes: [new_from_header bytes]
                             length: [new_from_header length]];
        }
    }

  error = [self _sendMail: data
               recipients: [message allRecipients]
                saveInSentItems: ([(id)[theDocumentElement getElementsByTagName: @"SaveInSentItems"] count] ? YES : NO)];

  if (error)
    {
      if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 14.0)
        {
	  [theResponse setContent: [self _sendMailErrorResponseWithStatus: 120]];
        }
      else
        {
          [theResponse setStatus: 500];
          [theResponse appendContentString: @"FATAL ERROR occured during SendMail"];
        }
    }
}



//
//
// Examples:
//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Settings xmlns="Settings:">
//  <Oof>
//   <Get>
//    <BodyType>text</BodyType>
//   </Get>
//  </Oof>
// </Settings>
//
//
//
// "POST /SOGo/Microsoft-Server-ActiveSync?Cmd=Settings&User=sogo10&DeviceId=SEC17CD1A3E9E3F2&DeviceType=SAMSUNGSGHI317M HTTP/1.1"
//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Settings xmlns="Settings:">
//  <DeviceInformation>
//   <Set>
//    <Model>SGH-I317M</Model>
//    <IMEI>354422050248226</IMEI>
//    <FriendlyName>t0ltevl</FriendlyName>
//    <OS>Android</OS>
//    <OSLanguage>English</OSLanguage>
//    <PhoneNumber>15147553630</PhoneNumber>
//    <UserAgent>SAMSUNG-SGH-I317M/100.40102</UserAgent>
//    <EnableOutboundSMS>0</EnableOutboundSMS>
//    <MobileOperator>Koodo</MobileOperator>
//   </Set>
//  </DeviceInformation>
// </Settings>
//
// We ignore everything for now
// 
- (void) processSettings: (id <DOMElement>) theDocumentElement
              inResponse: (WOResponse *) theResponse
{
  SOGoDomainDefaults *dd;
  NSMutableDictionary *vacationOptions;
  NSMutableString *s;
  NSData *d;
  int OofState, time, i;
  id setElements;
  NSCalendarDate *startDate, *endDate;
  NSString *autoReplyText;
  NSArray *OofMessages;

  s = [NSMutableString string];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<Settings xmlns=\"Settings:\">"];
  [s appendString: @"<Status>1</Status>"];

  if ([(id)[[(id)[theDocumentElement getElementsByTagName: @"Oof"] lastObject] getElementsByTagName: @"Get"] lastObject])
    {
      dd = [[context activeUser] domainDefaults];
      if ([dd vacationEnabled])
        {
          vacationOptions = [[[[context activeUser] userDefaults] vacationOptions] mutableCopy];
          if (!vacationOptions)
            vacationOptions = [NSMutableDictionary new];

          if ([[vacationOptions objectForKey: @"enabled"] boolValue] && [[vacationOptions objectForKey: @"endDateEnabled"] intValue])
            OofState = 2;
          else if ([[vacationOptions objectForKey: @"enabled"] boolValue])
            OofState = 1;
          else
            OofState = 0;

          [s appendString: @"<Oof>"];
          [s appendString: @"<Status>1</Status>"];
          [s appendString: @"<Get>"];
          [s appendFormat: @"<OofState>%d</OofState>", OofState];

          time = [[vacationOptions objectForKey: @"startDate"] intValue];
          [s appendFormat: @"<StartTime>%@</StartTime>", [[NSCalendarDate dateWithTimeIntervalSince1970: time] activeSyncRepresentationInContext: context]];

          time = [[vacationOptions objectForKey: @"endDate"] intValue];
          [s appendFormat: @"<EndTime>%@</EndTime>", [[NSCalendarDate dateWithTimeIntervalSince1970: time] activeSyncRepresentationInContext: context]];

          [s appendFormat: @"<OofMessage>"];
          [s appendFormat: @"<AppliesToInternal/>"];
          [s appendFormat: @"<Enabled>%d</Enabled>", (OofState) ? 1 : 0];
          [s appendFormat: @"<ReplyMessage>%@</ReplyMessage>", [vacationOptions objectForKey: @"autoReplyText"]];
          [s appendFormat: @"<BodyType>TEXT</BodyType>"];
          [s appendFormat: @"</OofMessage>"];

          [s appendFormat: @"<OofMessage>"];
          [s appendFormat: @"<AppliesToExternalKnown/>"];
          [s appendFormat: @"<Enabled>0</Enabled>"];
          [s appendFormat: @"<ReplyMessage/>"];
          [s appendFormat: @"</OofMessage>"];

          [s appendFormat: @"<OofMessage>"];
          [s appendFormat: @"<AppliesToExternalUnknown/>"];
          [s appendFormat: @"<Enabled>0</Enabled>"];
          [s appendFormat: @"<ReplyMessage/>"];
          [s appendFormat: @"</OofMessage>"];

          [s appendString: @"</Get>"];
          [s appendString: @"</Oof>"];
        }
    }

  if ([(id)[[(id)[theDocumentElement getElementsByTagName: @"Oof"] lastObject] getElementsByTagName: @"Set"] lastObject])
    {
      dd = [[context activeUser] domainDefaults];
      if ([dd vacationEnabled])
        {
          setElements = [(id)[[(id)[theDocumentElement getElementsByTagName: @"Oof"] lastObject] getElementsByTagName: @"Set"] lastObject];
          OofState = [[[(id)[setElements getElementsByTagName: @"OofState"] lastObject] textValue] intValue];
          OofMessages = (id)[setElements getElementsByTagName: @"OofMessage"];

          autoReplyText = [NSMutableString string];

          for (i = 0; i < [OofMessages count]; i++)
            {
              if ([(id)[[OofMessages objectAtIndex: i] getElementsByTagName: @"AppliesToInternal"] lastObject])
                {
                  autoReplyText = [[(id)[[OofMessages objectAtIndex: i] getElementsByTagName: @"ReplyMessage"] lastObject] textValue];
                  break;
                }
            }

          vacationOptions = [[[[context activeUser] userDefaults] vacationOptions] mutableCopy];

          if (!vacationOptions)
            vacationOptions = [NSMutableDictionary new];

          [vacationOptions setObject: [NSNumber numberWithBool: (OofState > 0) ? YES : NO]
                    forKey: @"enabled"];

          startDate = [[[(id)[setElements getElementsByTagName: @"StartTime"] lastObject] textValue] calendarDate];

          if (startDate)
            [vacationOptions setObject: [NSNumber numberWithInt: [startDate timeIntervalSince1970]] forKey: @"startDate"];

          [vacationOptions setObject: [NSNumber numberWithBool: (OofState == 2) ? YES : NO]
                    forKey: @"startDateEnabled"];

          [vacationOptions setObject: [NSNumber numberWithBool: (OofState == 2) ? YES : NO]
                    forKey: @"endDateEnabled"];

          endDate = [[[(id)[setElements getElementsByTagName: @"EndTime"] lastObject] textValue] calendarDate];

          if (endDate)
            [vacationOptions setObject: [NSNumber numberWithInt: [endDate timeIntervalSince1970]] forKey: @"endDate"];

          if (autoReplyText)
            [vacationOptions setObject: autoReplyText forKey: @"autoReplyText"];

          [[[context activeUser] userDefaults] setVacationOptions: vacationOptions];
          [[[context activeUser] userDefaults] synchronize];

          [s appendString: @"<Oof><Status>1</Status></Oof>"];
        }
     }

  if ([(id)[[(id)[theDocumentElement getElementsByTagName: @"UserInformation"] lastObject] getElementsByTagName: @"Get"] lastObject])
    {
      NSArray *identities;
      int i;

      identities = [[context activeUser] allIdentities];

      [s appendString: @"<UserInformation>"];
      [s appendString: @"<Get>"];

      if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 14.1)
        {
          [s appendString: @"<Accounts>"];
          [s appendString: @"<Account>"];
          [s appendFormat: @"<UserDisplayName>%@</UserDisplayName>", [[[identities objectAtIndex: 0] objectForKey: @"fullName"] activeSyncRepresentationInContext: context] ];
        }

      [s appendString: @"<EmailAddresses>"];

      if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 14.1)
        [s appendFormat: @"<PrimarySmtpAddress>%@</PrimarySmtpAddress>", [[[identities objectAtIndex: 0] objectForKey: @"email"] activeSyncRepresentationInContext: context] ];
      else
        [s appendFormat: @"<SmtpAddress>%@</SmtpAddress>", [[[identities objectAtIndex: 0] objectForKey: @"email"] activeSyncRepresentationInContext: context] ];

      if ([identities count] > 1)
        {
          for (i = 1; i < [identities count]; i++)
            [s appendFormat: @"<SmtpAddress>%@</SmtpAddress>", [[[identities objectAtIndex: i] objectForKey: @"email"] activeSyncRepresentationInContext: context] ];
        }

      [s appendString: @"</EmailAddresses>"];

      if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 14.1)
        {
          [s appendString: @"</Account>"];
          [s appendString: @"</Accounts>"];
        }

      [s appendString: @"</Get>"];
      [s appendString: @"</UserInformation>"];
    }

  [s appendString: @"</Settings>"];
  
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
}


- (void) _processSmartCommand: (id <DOMElement>) theDocumentElement
                   inResponse: (WOResponse *) theResponse
               isSmartForward: (BOOL ) isSmartForward
{
  NSString *folderId, *itemId, *realCollectionId;
  SOGoMicrosoftActiveSyncFolderType folderType;
  SOGoMailAccounts *accountsFolder;
  SOGoMailFolder *currentFolder;
  SOGoUserFolder *userFolder;
  SOGoMailObject *mailObject;
  SOGoUserDefaults *ud;

  BOOL htmlComposition, isHTML;
  id value, currentCollection;
  
  isHTML = NO;
  ud = [[context activeUser] userDefaults];

  folderId = [[(id)[theDocumentElement getElementsByTagName: @"FolderId"] lastObject] textValue];

  // if folderId is not there try to get it from URL
  if (!folderId)
    {
     folderId = [[[context request] uri] collectionid];
    }

  itemId = [[(id)[theDocumentElement getElementsByTagName: @"ItemId"] lastObject] textValue];

  // if itemId is not there try to get it from URL
  if (!itemId)
    {
     itemId = [[[context request] uri] itemid];
    }

  realCollectionId = [folderId realCollectionIdWithFolderType: &folderType];
  realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];

  value = [theDocumentElement getElementsByTagName: @"ReplaceMime"];

  // We fetch the mail object from the server
  userFolder = [[context activeUser] homeFolderInContext: context];
  accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
  currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];

  currentCollection = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", realCollectionId]
				      inContext: context
					acquire: NO];

  mailObject = [currentCollection lookupName: itemId  inContext: context  acquire: NO];

  // ReplaceMime IS specified so we must NOT use the server copy
  // but rather take the data as-is from the client.
  if ([value count])
    {
      [self processSendMail: theDocumentElement  inResponse: theResponse];
      if (!isSmartForward)
	[mailObject addFlags: @"Answered"];
      else
	[mailObject addFlags: @"$Forwarded"];
      return;
    }
  
  if (folderType == ActiveSyncMailFolder)
    {
      NGMimeMessage *messageFromSmartForward, *messageToSend;
      NGMimeMessageParser *parser;
      NSData *data;

      NGMimeMessageGenerator *generator;
      NGMimeBodyPart *bodyPart;
      NGMutableHashMap *map;
      NGMimeFileData *fdata;
      NSException *error;
      NSArray *attachmentKeys;
      NSMutableArray *attachments, *references;

      id body, bodyFromSmartForward, htmlPart, textPart;
      NSString *fullName, *email, *charset, *s, *from;
      NSDictionary *identity;

      int a;

      parser = [[NGMimeMessageParser alloc] init];
      data = [[[[(id)[theDocumentElement getElementsByTagName: @"MIME"] lastObject] textValue] stringByDecodingBase64] dataUsingEncoding: NSUTF8StringEncoding];
      messageFromSmartForward = [parser parsePartFromData: data];
      RELEASE(parser);
      
      // We create a new MIME multipart/mixed message. The first part will be the text part
      // of our "smart forward" and the second part will be the message/rfc822 part of the
      // "smart forwarded" message.
      map = [NGHashMap hashMapWithDictionary: [messageFromSmartForward headers]];
      [map setObject: @"multipart/mixed"  forKey: @"content-type"];

      from = [map objectForKey: @"from"];

      if (![from length] || ![self _isEMailValid: [from pureEMailAddress]] ||
          [[from pureEMailAddress] isEqualToString: from] ||
          [[NSString stringWithFormat: @"<%@>", [from pureEMailAddress]] isEqualToString: from])
        {
          if ([from length] && [self _isEMailValid: [from pureEMailAddress]])
            {
              // We have a valid email address, lets fill in the fullname.
              email = [from pureEMailAddress];
              fullName = [self _fullNameForEMail: email];
            }
          else
            {
              // Fallback to primary identity.
              identity = [[context activeUser] primaryIdentity];

              fullName = [identity objectForKey: @"fullName"];
              email = [identity objectForKey: @"email"];
            }

          if ([fullName length])
            [map setObject: [NSString stringWithFormat: @"%@ <%@>", fullName, email]  forKey: @"from"];
          else
            [map setObject: email forKey: @"from"];
        }

      if ([mailObject messageId])
        {
          [map setObject: [mailObject messageId] forKey: @"in-reply-to"];

          references = [[[[[mailObject mailHeaders] objectForKey: @"references"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] mutableCopy] autorelease];

          // If there is no References: header, initialize it with In-Reply-To.
          if ([mailObject inReplyTo] && ![references count])
             references = [NSMutableArray arrayWithObject: [mailObject inReplyTo]];

          if ([references count] > 0)
            {
              // If there are more than ten identifiers listed, we eliminate the second one.
              if ([references count] >= 10)
                [references removeObjectAtIndex: 1];

              [references addObject: [mailObject messageId]];

              [map setObject: [references componentsJoinedByString: @" "] forKey: @"references"];
            }
          else
            {
              [map setObject: [mailObject messageId] forKey: @"references"];
            }
        }

      messageToSend = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];
      body = [[[NGMimeMultipartBody alloc] initWithPart: messageToSend] autorelease];
      
      // First part - either a text/* or a multipart/*. If it's a multipart,
      // we take the first part text/* part we see.
      map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];
      bodyFromSmartForward = nil;
      textPart = nil;
      htmlPart = nil;

      attachments = [NSMutableArray array];

      if ([[messageFromSmartForward body] isKindOfClass: [NGMimeMultipartBody class]])
        {
          NGMimeBodyPart *part, *apart;
          NSArray *parts, *aparts;
          int i, j;
          
          parts = [[messageFromSmartForward body] parts];
          
          for (i = 0; i < [parts count]; i++)
            {
              part = [parts objectAtIndex: i];
              
              if ([[[part contentType] type] isEqualToString: @"multipart"] && [[[part contentType] subType] isEqualToString: @"alternative"])
                {
                  aparts = [[part body] parts];
                  for (j = 0; j < [aparts count]; j++)
                    {
                      apart = [aparts objectAtIndex: j];
                      if ([[[apart contentType] type] isEqualToString: @"text"] && [[[apart contentType] subType] isEqualToString: @"html"])
                        htmlPart = apart;
                      if ([[[apart contentType] type] isEqualToString: @"text"] && [[[apart contentType] subType] isEqualToString: @"plain"])
                        textPart = apart;
                    }
                }
              else
                {
                  if ([[[part contentType] type] isEqualToString: @"text"] && [[[part contentType] subType] isEqualToString: @"html"])
                    htmlPart = part;
                  else if ([[[part contentType] type] isEqualToString: @"text"] && [[[part contentType] subType] isEqualToString: @"plain"])
                    textPart = part;
                  else
                    [attachments addObject: part];
               }
            }
        }
      else
        {
          if ([[[messageFromSmartForward contentType] type] isEqualToString: @"text"] && [[[messageFromSmartForward contentType] subType] isEqualToString: @"html"])
            htmlPart = messageFromSmartForward;
          else
            textPart = messageFromSmartForward;
        }

      htmlComposition = [[ud mailComposeMessageType] isEqualToString: @"html"];

      if (htmlComposition && htmlPart)
        {
          bodyFromSmartForward = [htmlPart body];
          charset = [[htmlPart contentType] valueOfParameter: @"charset"];
          isHTML = YES;
        }
      else if (!htmlComposition && !textPart)
        {
          bodyFromSmartForward = [htmlPart body];
          charset = [[htmlPart contentType] valueOfParameter: @"charset"];
          isHTML = YES;
        } 
      else
        {
          bodyFromSmartForward = [textPart body];
          charset = [[textPart contentType] valueOfParameter: @"charset"];
        }

      // We make sure everything is encoded in UTF-8.
      if ([bodyFromSmartForward isKindOfClass: [NSData class]])
        {
          if (![charset length])
            charset = @"utf-8";

          s = [NSString stringWithData: bodyFromSmartForward usingEncodingNamed: charset];

          // We fallback to ISO-8859-1 string encoding. We avoid #3103.
          if (!s)
            s = [[[NSString alloc] initWithData: bodyFromSmartForward  encoding: NSISOLatin1StringEncoding] autorelease];

          bodyFromSmartForward = s;
        }

     if (htmlComposition && !isHTML)
       {
         [map setObject: @"text/html; charset=utf-8" forKey: @"content-type"];
         bodyFromSmartForward = [[bodyFromSmartForward stringByEscapingHTMLString] stringByConvertingCRLNToHTML];
       } 
     else if (!htmlComposition && isHTML)
       {
         [map setObject: @"text/plain; charset=utf-8" forKey: @"content-type"];
         bodyFromSmartForward = [bodyFromSmartForward htmlToText]; 
       } 
     else if (htmlComposition && isHTML)
       {
         [map setObject: @"text/html; charset=utf-8" forKey: @"content-type"];
       }
     else
       {
         [map setObject: @"text/plain; charset=utf-8" forKey: @"content-type"];
       }

      bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];

      if (isSmartForward && [[ud mailMessageForwarding] isEqualToString: @"attached"])
        [bodyPart setBody: [bodyFromSmartForward dataUsingEncoding: NSUTF8StringEncoding]];
      else
        [bodyPart setBody: [[NSString stringWithFormat: @"%@%@", bodyFromSmartForward, [mailObject contentForEditing]] dataUsingEncoding: NSUTF8StringEncoding]];

      [body addBodyPart: bodyPart];

      // Add attachments
      for (a = 0; a < [attachments count]; a++)
        {
          [body addBodyPart: [attachments objectAtIndex: a]];
        }

      // For a forward decide whether do it inline or as an attachment.
      if (isSmartForward)
        {
          if ([[ud mailMessageForwarding] isEqualToString: @"attached"])
            {
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
            }
          else
            {
              attachmentKeys = [mailObject fetchFileAttachmentKeys];
              if ([attachmentKeys count])
                {
                  id currentAttachment;
                  NGHashMap *response;
                  NSData *bodydata;
                  NSArray *paths;

                  paths = [attachmentKeys keysWithFormat: @"BODY[%{path}]"];
                  response = [[mailObject fetchParts: paths] objectForKey: @"RawResponse"];

                  for (a = 0; a < [attachmentKeys count]; a++)
                    {
                      currentAttachment = [attachmentKeys objectAtIndex: a];
                      bodydata = [[[response objectForKey: @"fetch"] objectForKey: [NSString stringWithFormat: @"body[%@]", [currentAttachment objectForKey: @"path"]]] valueForKey: @"data"]; 

                      map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];
                      [map setObject: [currentAttachment objectForKey: @"mimetype"] forKey: @"content-type"];
                      [map setObject: [currentAttachment objectForKey: @"encoding"] forKey: @"content-transfer-encoding"];
                      [map addObject: [NSString stringWithFormat: @"attachment; filename=\"%@\"", [currentAttachment objectForKey: @"filename"]] forKey: @"content-disposition"];
                      if ([[currentAttachment objectForKey: @"bodyId"] length])
                        [map setObject: [currentAttachment objectForKey: @"bodyId"] forKey: @"content-id"];
                      bodyPart = [[[NGMimeBodyPart alloc] initWithHeader: map] autorelease];

                      fdata = [[NGMimeFileData alloc] initWithBytes:[bodydata bytes]  length:[bodydata length]];
                      [bodyPart setBody: fdata];
                      RELEASE(fdata);
                      [body addBodyPart: bodyPart];
                    }
                }
            }
        } //  if (isSmartForward)

      [messageToSend setBody: body];
      
      generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
      data = [generator generateMimeFromPart: messageToSend];
            
      error = [self _sendMail: data
                   recipients: [messageFromSmartForward allRecipients]
                    saveInSentItems:  ([(id)[theDocumentElement getElementsByTagName: @"SaveInSentItems"] count] ? YES : NO)];
      
      if (error)
        {
          if ([[context objectForKey: @"ASProtocolVersion"] floatValue] >= 14.0)
            {
              NSMutableString *s;
              NSData *d;

              s = [NSMutableString string];

              [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
              [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
              [s appendFormat: @"<%@ xmlns=\"ComposeMail:\">", (isSmartForward) ? @"SmartForward" : @"SmartReply"];
              [s appendString: @"<Status>120</Status>"];
              [s appendFormat: @"</%@>", (isSmartForward) ? @"SmartForward" : @"SmartReply"];

              d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

              [theResponse setContent: d];
            }
          else
            {
              [theResponse setStatus: 500];
              [theResponse appendContentString: @"FATAL ERROR occured during SmartForward"];
            }
        }
      else if (!isSmartForward)
        {
          [mailObject addFlags: @"Answered"];
        }
      else
        {
          [mailObject addFlags: @"$Forwarded"];
        }
    }
  else
    {
      // FIXME
      [theResponse setStatus: 500];
      [theResponse appendContentString: @"SmartForward not-implemented on non-mail folders."];
    }
}

//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <SmartForward xmlns="ComposeMail:">
//  <ClientId>C9FF94FE-EA40-473A-B3E2-AAEE94F753A4</ClientId>
//  <SaveInSentItems/>
//  <ReplaceMime/>
//  <Source>
//   <FolderId>mail/INBOX</FolderId>
//   <ItemId>82</ItemId>
//  </Source>
//  <MIME>... the data ...</MIME>
// </SmartForward>
//
- (void) processSmartForward: (id <DOMElement>) theDocumentElement
                  inResponse: (WOResponse *) theResponse
{
  [self _processSmartCommand: theDocumentElement
                  inResponse: theResponse
              isSmartForward: YES];
}


//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <SmartReply xmlns="ComposeMail:">
//  <ClientId>DD40B5DC-4BDF-4A6A-9D8B-4B02BE5342CD</ClientId>
//  <SaveInSentItems/>
//  <ReplaceMime/>                       -- http://msdn.microsoft.com/en-us/library/gg663506(v=exchg.80).aspx
//  <Source>
//   <FolderId>mail/INBOX</FolderId>
//   <ItemId>82</ItemId>
//  </Source>
//  <MIME>... the data ...</MIME>
// </SmartReply>
//
- (void) processSmartReply: (id <DOMElement>) theDocumentElement
                inResponse: (WOResponse *) theResponse
{
  [self _processSmartCommand: theDocumentElement
                  inResponse: theResponse
              isSmartForward: NO];
}

//
//
//
- (NSException *) dispatchRequest: (id) theRequest
                       inResponse: (id) theResponse
                          context: (id) theContext
{
  id <DOMElement> documentElement;
  NSAutoreleasePool *pool;
  id builder, dom;
  SEL aSelector;
  id activeUser;

  NSString *cmdName, *deviceId;
  NSData *d;

  pool = [[NSAutoreleasePool alloc] init];
    
  ASSIGN(context, theContext);

  activeUser = [context activeUser];
  if (![activeUser canAccessModule: @"ActiveSync"]) 
    {
      [(WOResponse *)theResponse setStatus: 403];
      [self logWithFormat: @"EAS - Forbidden access for user %@", [activeUser loginInDomain]];
      return nil;
    }     

  // Get the device ID, device type and "stash" them
  deviceId = [[theRequest uri] deviceId];

  if ([deviceId isEqualToString: @"Unknown"])
    {
      [(WOResponse *)theResponse setStatus: 500];
      [self logWithFormat: @"EAS - No device id provided, ignoring request."];
      return nil;
    }

  [context setObject: deviceId  forKey: @"DeviceId"];
  [context setObject: [[theRequest uri] deviceType]  forKey: @"DeviceType"];
  [context setObject: [[theRequest uri] attachmentName]  forKey: @"AttachmentName"];

  // Save ASProtocolVersion to context
  if ([[context request] headerForKey: @"MS-ASProtocolVersion"])
    [context setObject: [[context request] headerForKey: @"MS-ASProtocolVersion"] forKey: @"ASProtocolVersion"];
  else
    [context setObject: [[theRequest uri] protocolVersion] forKey: @"ASProtocolVersion"];

  cmdName = [[theRequest uri] command];

  // We make sure our cache table exists
  [self ensureFolderTableExists];

  //
  // If the MS-ASProtocolVersion header is set to "12.1", the body of the SendMail request is
  // is a "message/rfc822" payload - otherwise, it's a WBXML blob.
  //
  if (([cmdName caseInsensitiveCompare: @"SendMail"] == NSOrderedSame ||
      [cmdName caseInsensitiveCompare: @"SmartReply"] == NSOrderedSame ||
      [cmdName caseInsensitiveCompare: @"SmartForward"] == NSOrderedSame) &&
      [[theRequest headerForKey: @"content-type"] caseInsensitiveCompare: @"message/rfc822"] == NSOrderedSame)
    {
      NSString *s, *xml;
      
      if ([[theRequest contentAsString] rangeOfString: @"Date: "
                                              options: NSCaseInsensitiveSearch].location == NSNotFound)
        {
          NSString *value;
#if GNUSTEP_BASE_MINOR_VERSION < 21
          value = [[NSDate date] descriptionWithCalendarFormat: @"%a, %d %b %Y %H:%M:%S %z"
                                                      timeZone: [NSTimeZone timeZoneWithName: @"GMT"]
                                                        locale: nil];
#else
          value = [[NSDate date] descriptionWithCalendarFormat: @"%a, %d %b %Y %H:%M:%S %z"
                                                      timeZone: [NSTimeZone timeZoneWithName: @"GMT"]
                                                        locale: [NSDictionary dictionaryWithObjectsAndKeys:
                                                                     [NSArray arrayWithObjects: @"Jan", @"Feb", @"Mar", @"Apr",
                                                                                                @"May", @"Jun", @"Jul", @"Aug", 
                                                                                                @"Sep", @"Oct", @"Nov", @"Dec", nil],
                                                                     @"NSShortMonthNameArray",
                                                                     [NSArray arrayWithObjects: @"Sun", @"Mon", @"Tue", @"Wed", @"Thu",
                                                                                                @"Fri", @"Sat", nil],
                                                                     @"NSShortWeekDayNameArray",
                                                                     nil]];

#endif
          s = [NSString stringWithFormat: @"Date: %@\r\n%@", value, [theRequest contentAsString]];
        } 
      else
        {
          s = [theRequest contentAsString];
        }
      
      xml = [NSString stringWithFormat: @"<?xml version=\"1.0\"?><!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\"><%@ xmlns=\"ComposeMail:\"><SaveInSentItems/><MIME>%@</MIME></%@>", cmdName, [s stringByEncodingBase64], cmdName];
      d = [xml dataUsingEncoding: NSASCIIStringEncoding];
    }
  else
    {
      // Handle empty Ping request, no need to try decoding the WBXML blob here
      if ([[theRequest content] length])
	d = [[theRequest content] wbxml2xml];
      else
	d = nil;
    }
  
  documentElement = nil;

  if (!d)
    {
      // If we got no data in the SendMail request, that means SOPE rejected it because of the WOMaxUploadSize.
      // We generate here the proper failed response for SendMail
      if ([cmdName caseInsensitiveCompare: @"SendMail"] == NSOrderedSame)
	{
	  [theResponse setHeader: @"application/vnd.ms-sync.wbxml"  forKey: @"Content-Type"];
	  [theResponse setContent: [self _sendMailErrorResponseWithStatus: 122]];
	  goto return_response;
	}
      // We check if it's a Ping command with no body.
      // See http://msdn.microsoft.com/en-us/library/ee200913(v=exchg.80).aspx for details      
      else if ([cmdName caseInsensitiveCompare: @"Ping"] != NSOrderedSame && [cmdName caseInsensitiveCompare: @"GetAttachment"] != NSOrderedSame && [cmdName caseInsensitiveCompare: @"Sync"] != NSOrderedSame)
        {
          RELEASE(context);
          RELEASE(pool);
          return [NSException exceptionWithHTTPStatus: 500];
        }
    }

  if (d)
    {
      if (debugOn)
        [self logWithFormat: @"EAS - request for device %@: %@", [context objectForKey: @"DeviceId"], [[[NSString alloc] initWithData: d  encoding: NSUTF8StringEncoding] autorelease]];

      builder = [[[NSClassFromString(@"DOMSaxBuilder") alloc] init] autorelease];
      dom = [builder buildFromData: d];
      documentElement = [dom documentElement];
      
      // See 2.2.2 Commands - http://msdn.microsoft.com/en-us/library/ee202197(v=exchg.80).aspx
      // for all potential commands
      cmdName = [NSString stringWithFormat: @"process%@:inResponse:", [documentElement tagName]];
    }
  else
    {
      // Ping or Sync command with empty body
      cmdName = [NSString stringWithFormat: @"process%@:inResponse:", cmdName];
    }

  aSelector = NSSelectorFromString(cmdName);

  // The -processItemOperations: method will generate a multipart response when Content-Type is application/vnd.ms-sync.multipart
  if (([cmdName rangeOfString: @"ItemOperations" options: NSCaseInsensitiveSearch].location != NSNotFound) &&
      ([[theRequest headerForKey: @"MS-ASAcceptMultiPart"] isEqualToString:@"T"] || [[theRequest uri] acceptsMultiPart]))
    [theResponse setHeader: @"application/vnd.ms-sync.multipart"  forKey: @"Content-Type"];
  else
    [theResponse setHeader: @"application/vnd.ms-sync.wbxml"  forKey: @"Content-Type"];

  [self performSelector: aSelector  withObject: documentElement  withObject: theResponse];

 return_response:
  [theResponse setHeader: @"14.1"  forKey: @"MS-Server-ActiveSync"];
  [theResponse setHeader: @"Sync,SendMail,SmartForward,SmartReply,GetAttachment,GetHierarchy,CreateCollection,DeleteCollection,MoveCollection,FolderSync,FolderCreate,FolderDelete,FolderUpdate,MoveItems,GetItemEstimate,MeetingResponse,Search,Settings,Ping,ItemOperations,ResolveRecipients,ValidateCert"  forKey: @"MS-ASProtocolCommands"];
  [theResponse setHeader: @"2.5,12.0,12.1,14.0,14.1"  forKey: @"MS-ASProtocolVersions"];

  if (debugOn && [[theResponse headerForKey: @"Content-Type"] isEqualToString:@"application/vnd.ms-sync.wbxml"] && [[theResponse content] length] && !([(WOResponse *)theResponse status] == 500))
    [self logWithFormat: @"EAS - response for device %@: %@", [context objectForKey: @"DeviceId"], [[[NSString alloc] initWithData: [[theResponse content] wbxml2xml] encoding: NSUTF8StringEncoding] autorelease]];

  RELEASE(context);
  RELEASE(pool);

  return nil;
}

- (NSURL *) folderTableURL
{
  NSMutableString *ocFSTableName;
  NSMutableArray *parts;
  NSString *urlString;
  SOGoUser *user;

  if (!folderTableURL)
    {
      user = [context activeUser];

      if (![user loginInDomain])
        return nil;

      urlString = [[user domainDefaults] folderInfoURL];
      parts = [[urlString componentsSeparatedByString: @"/"] mutableCopy];
      [parts autorelease];
      if ([parts count] == 5)
        {
          /* If "OCSFolderInfoURL" is properly configured, we must have 5
             parts in this url. We strip the '-' character in case we have
             this in the domain part - like foo@bar-zot.com */
          ocFSTableName = [NSMutableString stringWithFormat: @"sogo_cache_folder_%@",
                                           [[user login] asCSSIdentifier]];
          [ocFSTableName replaceOccurrencesOfString: @"-"
                                         withString: @"_"
                                            options: 0
                                              range: NSMakeRange(0, [ocFSTableName length])];
          [parts replaceObjectAtIndex: 4 withObject: ocFSTableName];
          folderTableURL
            = [NSURL URLWithString: [parts componentsJoinedByString: @"/"]];
          [folderTableURL retain];
        }
      else
        [NSException raise: @"MAPIStoreIOException"
                    format: @"'OCSFolderInfoURL' is not set"];
    }

  return folderTableURL;
}

- (void) ensureFolderTableExists
{
  GCSChannelManager *cm;
  EOAdaptorChannel *channel;
  NSString *tableName, *query;
  GCSSpecialQueries *queries;

  if ([GCSFolderManager singleStoreMode])
    return;

  [self folderTableURL];

  cm = [GCSChannelManager defaultChannelManager];
  channel = [cm acquireOpenChannelForURL: folderTableURL];
  
  /* FIXME: make use of [EOChannelAdaptor describeTableNames] instead */
  tableName = [[folderTableURL path] lastPathComponent];
  if (tableName &&
      [channel evaluateExpressionX:
                 [NSString stringWithFormat: @"SELECT count(*) FROM %@",
                           tableName]])
    {
      queries = [channel specialQueries];
      query = [queries createSOGoCacheGCSFolderTableWithName: tableName];
      if ([channel evaluateExpressionX: query])
        [NSException raise: @"MAPIStoreIOException"
                    format: @"could not create special table '%@'", tableName];
    }
  else
    [channel cancelFetch];


  [cm releaseChannel: channel]; 
}

- (BOOL) easShouldTerminate
{
  return easShouldTerminate;
}

@end
