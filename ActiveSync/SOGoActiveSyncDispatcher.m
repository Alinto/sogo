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

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/SoApplication.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEntityObject.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/NGVCard.h>

#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NSString+Imap4.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimeType.h>
#import <NGMail/NGMimeMessageParser.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>

#import <DOM/DOMElement.h>
#import <DOM/DOMProtocols.h>
#import <DOM/DOMSaxBuilder.h>

#import <EOControl/EOQualifier.h>

#import <SOGo/NSArray+DAV.h>
#import <SOGo/NSDictionary+DAV.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoCacheGCSObject.h>
#import <SOGo/SOGoDAVAuthenticator.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/GCSSpecialQueries+SOGoCacheObject.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/WORequest+SOGo.h>

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
#import <Mailer/SOGoMailObject.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#include "iCalEvent+ActiveSync.h"
#include "iCalToDo+ActiveSync.h"
#include "NGMimeMessage+ActiveSync.h"
#include "NGVCard+ActiveSync.h"
#include "NSCalendarDate+ActiveSync.h"
#include "NSData+ActiveSync.h"
#include "NSDate+ActiveSync.h"
#include "NSString+ActiveSync.h"
#include "SOGoActiveSyncConstants.h"
#include "SOGoMailObject+ActiveSync.h"

#import <GDLContentStore/GCSChannelManager.h>

#include <unistd.h>

@interface SOGoActiveSyncDispatcher (Sync)

- (NSMutableDictionary *) _folderMetadataForKey: (NSString *) theFolderKey;
- (void) _setFolderMetadata: (NSDictionary *) theFolderMetadata forKey: (NSString *) theFolderKey;

@end

@implementation SOGoActiveSyncDispatcher

- (id) init
{
  [super init];

  folderTableURL = nil;
  return self;
}

- (void) dealloc
{
  RELEASE(folderTableURL);
  [super dealloc];
}

- (void) _setFolderSyncKey: (NSString *) theSyncKey
{
  SOGoCacheGCSObject *o;

  o = [SOGoCacheGCSObject objectWithName: [context objectForKey: @"DeviceId"]  inContainer: nil];
  [o setObjectType: ActiveSyncGlobalCacheObject];
  [o setTableUrl: [self folderTableURL]];
  [o reloadIfNeeded];
  
  [[o properties] removeAllObjects];
  [[o properties] addEntriesFromDictionary: [NSDictionary dictionaryWithObject: theSyncKey  forKey: @"FolderSyncKey"]];
  [o save];
}

- (NSMutableDictionary *) _globalMetadataForDevice
{
  SOGoCacheGCSObject *o;

  o = [SOGoCacheGCSObject objectWithName: [context objectForKey: @"DeviceId"]  inContainer: nil];
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
      [o setObjectType: ActiveSyncGlobalCacheObject];
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
      NSDictionary *imapGUIDs;

      userFolder = [[context activeUser] homeFolderInContext: context];
      accountsFolder = [userFolder lookupName: @"Mail" inContext: context acquire: NO];
      accountFolder = [accountsFolder lookupName: @"0" inContext: context acquire: NO];
      
      // Get the GUID of the IMAP folder
      imapGUIDs = [accountFolder imapFolderGUIDs];
      
      //return [[imapGUIDs allKeysForObject: theIdToTranslate] objectAtIndex: 0];
      return [[[imapGUIDs allKeysForObject:  [NSString stringWithFormat: @"folder%@", theIdToTranslate]] objectAtIndex: 0] substringFromIndex: 6] ;
    }
  
  return theIdToTranslate;
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

            nameInContainer = [[NSString stringWithFormat: @"mail/%@", [nameInContainer  substringFromIndex: 6]] stringByEscapingURL];
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
        
        nameInContainer = nil;
        
        appointmentFolders = [userFolder privateCalendars: @"Calendar" inContext: context];
        [appointmentFolders newFolderWithName: displayName
                              nameInContainer: &nameInContainer];
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
        
        nameInContainer = nil;
        
        contactFolders = [userFolder privateContacts: @"Contacts" inContext: context];
        [contactFolders newFolderWithName: displayName
                          nameInContainer: &nameInContainer];
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
  [s appendFormat: @"<ServerId>%@</ServerId>", nameInContainer];
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
  NSString *key, *cKey, *nkey, *name, *serverId, *parentId, *nameInCache, *personalFolderName, *syncKey, *folderType;
  NSDictionary *folderMetadata, *imapGUIDs;
  NSArray *allFoldersMetadata, *allKeys;
  NSMutableDictionary *cachedGUIDs, *metadata;
  SOGoMailAccounts *accountsFolder;
  SOGoMailAccount *accountFolder;
  NSMutableString *s, *commands;
  SOGoUserFolder *userFolder;
  NSMutableArray *folders;
  SoSecurityManager *sm;
  SOGoCacheGCSObject *o;
  id currentFolder;
  NSData *d;

  int status, command_count, i, type, fi, count;

  BOOL first_sync;

  sm = [SoSecurityManager sharedSecurityManager];
  metadata = [self _globalMetadataForDevice];
  syncKey = [[(id)[theDocumentElement getElementsByTagName: @"SyncKey"] lastObject] textValue];
  s = [NSMutableString string];

  first_sync = NO;
  status = 1;
  command_count = 0;
  commands = [NSMutableString string];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];

  if ([syncKey isEqualToString: @"0"])
    {
      first_sync = YES;
      syncKey = @"1";
    }
  else if (![syncKey isEqualToString: [metadata objectForKey: @"FolderSyncKey"]])
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

  allFoldersMetadata = [accountFolder allFoldersMetadata];
  
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

      foldersInCache =  [o cacheEntriesForDeviceId: [context objectForKey: @"DeviceId"] newerThanVersion: -1];

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

              if ([ cKey rangeOfString: @"/"].location != NSNotFound) 
                currentFolder = [[[[context activeUser] homeFolderInContext: context] lookupName: folderType inContext: context acquire: NO]
                                                            lookupName: [cKey substringFromIndex: [cKey rangeOfString: @"/"].location+1]  inContext: context acquire: NO];

              // remove the folder from device if it doesn't exists or it has not the proper permissions
              if (!currentFolder ||
                  [sm validatePermission: SoPerm_DeleteObjects
                                onObject: currentFolder
                               inContext: context] ||
                  [sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
                                onObject: currentFolder
                               inContext: context])
                {
                  [commands appendFormat: @"<Delete><ServerId>%@</ServerId></Delete>", [cKey stringByEscapingURL] ];
                  command_count++;
                  [o destroy];
                }
            }
         }
      }

  // Handle addition and changes
  for (i = 0; i < [allFoldersMetadata count]; i++)
   {
     folderMetadata = [allFoldersMetadata objectAtIndex: i];
       
     nameInCache = [NSString stringWithFormat: @"folder%@",  [[folderMetadata objectForKey: @"path"] substringFromIndex: 1]];

     // we have no guid - ignore the folder
     if (![imapGUIDs objectForKey: nameInCache])
       continue;

     serverId = [NSString stringWithFormat: @"mail/%@",  [[imapGUIDs objectForKey: nameInCache] substringFromIndex: 6]];
     name = [folderMetadata objectForKey: @"displayName"];
          
     if ([name hasPrefix: @"/"])
       name = [name substringFromIndex: 1];
          
     if ([name hasSuffix: @"/"])
       name = [name substringToIndex: [name length]-1];
          
     type = [[folderMetadata objectForKey: @"type"] activeSyncFolderType];
     parentId = @"0";
         
     if ([folderMetadata objectForKey: @"parent"])
       {
         parentId = [NSString stringWithFormat: @"mail/%@", [[imapGUIDs objectForKey: [NSString stringWithFormat: @"folder%@",  [[folderMetadata objectForKey: @"parent"] substringFromIndex: 1]]] substringFromIndex: 6]];
         name = [[name pathComponents] lastObject];
       }
          
     // Decide between add and change
     if ([cachedGUIDs objectForKey: [imapGUIDs objectForKey: nameInCache]])
       {
         // Search GUID to check name change in cache (diff between IMAP and cache)
         key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], [cachedGUIDs objectForKey: [imapGUIDs objectForKey: nameInCache ]]];
         nkey = [NSString stringWithFormat: @"%@+folder%@", [context objectForKey: @"DeviceId"], [[folderMetadata objectForKey: @"path"] substringFromIndex: 1] ];
                   
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

             [[o properties ]  setObject: [[folderMetadata objectForKey: @"path"] substringFromIndex: 1]  forKey: @"displayName"];
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
              
         [[o properties ]  setObject: [[folderMetadata objectForKey: @"path"] substringFromIndex: 1] forKey: @"displayName"];

         // clean cache content to avoid stale data
         [[o properties] removeObjectForKey: @"SyncKey"];
         [[o properties] removeObjectForKey: @"SyncCache"];
         [[o properties] removeObjectForKey: @"DateCache"];
         [[o properties] removeObjectForKey: @"MoreAvailable"];
         [[o properties] removeObjectForKey: @"BodyPreferenceType"];
         [[o properties] removeObjectForKey: @"SuccessfulMoveItemsOps"];
         [o save];
              
         command_count++;
       }
    }

    personalFolderName = [[[context activeUser] personalCalendarFolderInContext: context] nameInContainer];
    folders = [[[[[context activeUser] homeFolderInContext: context] lookupName: @"Calendar" inContext: context acquire: NO] subFolders] mutableCopy];
    [folders addObjectsFromArray: [[[[context activeUser] homeFolderInContext: context] lookupName: @"Contacts" inContext: context acquire: NO] subFolders]];

    // Inside this loop we remove all the folder without write/delete permissions
    count = [folders count]-1;
    for (; count >= 0; count--)
     {
       if ([sm validatePermission: SoPerm_DeleteObjects
                         onObject: [folders objectAtIndex: count]
                        inContext: context] ||
           [sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
                         onObject: [folders objectAtIndex: count]
                        inContext: context])
         {
           [folders removeObjectAtIndex: count];
         }
     }

    count = [folders count]-1;
    NSString *operation;

    for (fi = 0; fi <= count ; fi++)
     {
       if ([[folders objectAtIndex:fi] isKindOfClass: [SOGoAppointmentFolder class]]) 
         name = [NSString stringWithFormat: @"vevent/%@", [[folders objectAtIndex:fi] nameInContainer]];
       else
         name = [NSString stringWithFormat: @"vcard/%@", [[folders objectAtIndex:fi] nameInContainer]];
          
       key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], name];
       o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
       [o setObjectType: ActiveSyncFolderCacheObject];
       [o setTableUrl: [self folderTableURL]];
       [o reloadIfNeeded];

       // Decide between add and change
       if (![[o properties ]  objectForKey: @"displayName"] || first_sync)
         operation = @"Add";
       else  if (![[[o properties ]  objectForKey: @"displayName"] isEqualToString:  [[folders objectAtIndex:fi] displayName]])
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

               [[o properties ]  setObject:  [[folders objectAtIndex:fi] displayName]  forKey: @"displayName"];
               [o save];

               name = [NSString stringWithFormat: @"vtodo/%@", [[folders objectAtIndex:fi] nameInContainer]];
               type = ([[[folders objectAtIndex:fi] nameInContainer] isEqualToString: personalFolderName] ? 7 : 15);
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
                   [[o properties] removeObjectForKey: @"MoreAvailable"];
                   [[o properties] removeObjectForKey: @"BodyPreferenceType"];
                   [[o properties] removeObjectForKey: @"SuccessfulMoveItemsOps"];
                 }

               [o save];
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
                   [[o properties] removeObjectForKey: @"MoreAvailable"];
                   [[o properties] removeObjectForKey: @"BodyPreferenceType"];
                   [[o properties] removeObjectForKey: @"SuccessfulMoveItemsOps"];
                 }

               [o save];
             }
         }
     }

  
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

      NSRange r1, r2;

      r1 = [realCollectionId rangeOfString: @"/"];
      r2 = [realCollectionId rangeOfString: @"/"  options: 0  range: NSMakeRange(NSMaxRange(r1)+1, [realCollectionId length]-NSMaxRange(r1)-1)];

      folderName = [realCollectionId substringToIndex: r1.location];
      messageName = [realCollectionId substringWithRange: NSMakeRange(NSMaxRange(r1), r2.location-r1.location-1)];
      pathToPart = [realCollectionId substringFromIndex: r2.location+1];

      userFolder = [[context activeUser] homeFolderInContext: context];
      accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
      currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];

      currentCollection = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", folderName]
                                          inContext: context
                                            acquire: NO];

      mailObject = [currentCollection lookupName: messageName  inContext: context  acquire: NO];
      currentBodyPart = [mailObject lookupImap4BodyPartKey: pathToPart  inContext: context];

      [theResponse setHeader: [NSString stringWithFormat: @"%@/%@", [[currentBodyPart partInfo] objectForKey: @"type"], [[currentBodyPart partInfo] objectForKey: @"subtype"]]
                 forKey: @"Content-Type"];

      [theResponse setContent: [currentBodyPart fetchBLOB] ];
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
      
           allMessages = [currentCollection syncTokenFieldsWithProperties: nil  matchingSyncToken: syncKey  fromDate: filter];

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
  NSString *fileReference, *realCollectionId; 
  NSMutableString *s;
  NSArray *fetchRequests;
  id aFetch;
  int i;

  SOGoMicrosoftActiveSyncFolderType folderType;

  s = [NSMutableString string];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<ItemOperations xmlns=\"ItemOperations:\">"];
  [s appendString: @"<Status>1</Status>"];
  [s appendString: @"<Response>"];

  fetchRequests = (id)[theDocumentElement getElementsByTagName: @"Fetch"];
  
  if ([fetchRequests count])
    {
      NSMutableData *bytes, *parts;
      NSMutableArray *partLength;
      NSData *d;

      bytes = [NSMutableData data];
      parts = [NSMutableData data];
      partLength = [NSMutableArray array];

      for (i = 0; i < [fetchRequests count]; i++)
        {
          aFetch = [fetchRequests objectAtIndex: i];
          fileReference = [[[(id)[aFetch getElementsByTagName: @"FileReference"] lastObject] textValue] stringByUnescapingURL];
          realCollectionId = [fileReference realCollectionIdWithFolderType: &folderType];

          if (folderType == ActiveSyncMailFolder)
            {
              id currentFolder, currentCollection, currentBodyPart;
              NSString *folderName, *messageName, *pathToPart;
              SOGoMailAccounts *accountsFolder;
              SOGoUserFolder *userFolder;
              SOGoMailObject *mailObject;

              NSRange r1, r2;

              r1 = [realCollectionId rangeOfString: @"/"];
              r2 = [realCollectionId rangeOfString: @"/"  options: 0  range: NSMakeRange(NSMaxRange(r1)+1, [realCollectionId length]-NSMaxRange(r1)-1)];
      
              folderName = [realCollectionId substringToIndex: r1.location];
              messageName = [realCollectionId substringWithRange: NSMakeRange(NSMaxRange(r1), r2.location-r1.location-1)];
              pathToPart = [realCollectionId substringFromIndex: r2.location+1];

              userFolder = [[context activeUser] homeFolderInContext: context];
              accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
              currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];

              currentCollection = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", folderName]
                                                  inContext: context
                                                    acquire: NO];

              mailObject = [currentCollection lookupName: messageName  inContext: context  acquire: NO];
              currentBodyPart = [mailObject lookupImap4BodyPartKey: pathToPart  inContext: context];

              [s appendString: @"<Fetch>"];
              [s appendString: @"<Status>1</Status>"];
              [s appendFormat: @"<FileReference xmlns=\"AirSyncBase:\">%@</FileReference>", [fileReference stringByEscapingURL]];
              [s appendString: @"<Properties>"];

              [s appendFormat: @"<ContentType xmlns=\"AirSyncBase:\">%@/%@</ContentType>", [[currentBodyPart partInfo] objectForKey: @"type"], [[currentBodyPart partInfo] objectForKey: @"subtype"]];

              if ([[theResponse headerForKey: @"Content-Type"] isEqualToString:@"application/vnd.ms-sync.multipart"])
                {
                  [s appendFormat: @"<Part>%d</Part>", i+1];
                  [partLength addObject: [NSNumber numberWithInteger: [[currentBodyPart fetchBLOB] length]]];
                  [parts  appendData:[currentBodyPart fetchBLOB]];
                }
              else
                {
                  [s appendFormat: @"<Range>0-%d</Range>", [[[currentBodyPart fetchBLOB] activeSyncRepresentationInContext: context] length]-1];
                  [s appendFormat: @"<Data>%@</Data>", [[currentBodyPart fetchBLOB] activeSyncRepresentationInContext: context]];
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
  NSString *realCollectionId, *requestId, *participationStatus, *calendarId;
  SOGoAppointmentObject *appointmentObject;
  SOGoMailObject *mailObject;
  NSMutableString *s;
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
  requestId = [[(id)[theDocumentElement getElementsByTagName: @"RequestId"] lastObject] textValue];  
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
      appointmentObject = [collection lookupName: [requestId sanitizedServerIdWithType: ActiveSyncEventFolder]
                                       inContext: context
                                         acquire: NO];
      calendarId = requestId;
      
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
      mailObject = [collection lookupName: requestId
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
          appointmentObject = [collection lookupName: [NSString stringWithFormat: @"%@.ics", [event uid]]
                                           inContext: context
                                             acquire: NO];
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
      [s appendFormat: @"<RequestId>%@</RequestId>", requestId];
      [s appendFormat: @"<CalendarId>%@</CalendarId>", calendarId];
      [s appendFormat: @"<Status>%d</Status>", status];
      [s appendString: @"</Result>"];
      [s appendString: @"</MeetingResponse>"];
      
      d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
      
      [theResponse setContent: d];
    }
  else
    {
      [theResponse setStatus: 500];
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
  NSString *srcMessageId, *srcFolderId, *dstFolderId, *dstMessageId, *nameInCache, *currentFolder;
  NSMutableDictionary *folderMetadata, *prevSuccessfulMoveItemsOps, *newSuccessfulMoveItemsOps;
  SOGoMicrosoftActiveSyncFolderType srcFolderType, dstFolderType;
  id <DOMElement> aMoveOperation;
  NSArray *moveOperations;
  SoSecurityManager *sm;
  NSMutableString *s;
  NSData *d; 
  int i;
  
  currentFolder = nil;

  moveOperations = (id)[theDocumentElement getElementsByTagName: @"Move"];
  
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

      if (srcFolderType == ActiveSyncMailFolder)
        nameInCache = [NSString stringWithFormat: @"folder%@", [[[[(id)[aMoveOperation getElementsByTagName: @"SrcFldId"] lastObject] textValue] stringByUnescapingURL] substringFromIndex: 5]];
      else
        nameInCache = [[[(id)[aMoveOperation getElementsByTagName: @"SrcFldId"] lastObject] textValue] stringByUnescapingURL];
      
      if (![nameInCache isEqualToString: currentFolder])
        {
          folderMetadata = [self _folderMetadataForKey: nameInCache];
          prevSuccessfulMoveItemsOps = [folderMetadata objectForKey: @"SuccessfulMoveItemsOps"];
          newSuccessfulMoveItemsOps = [NSMutableDictionary dictionary] ;
          currentFolder = nameInCache;
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
              if ([prevSuccessfulMoveItemsOps objectForKey: srcMessageId])
                {
                  // Previous move failed operation but we can recover the dstMessageId from previous request
                  [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
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
          NSArray *elements;
          NSString *newUID;
          NSException *ex;

          unsigned int count, max;

          srcCollection = [self collectionFromId: srcFolderId  type: srcFolderType];
          dstCollection = [self collectionFromId: dstFolderId  type: srcFolderType];
          
          srcSogoObject = [srcCollection lookupName: [srcMessageId sanitizedServerIdWithType: srcFolderType]
                                          inContext: context
                                            acquire: NO];
          
          sm = [SoSecurityManager sharedSecurityManager];
          if (![sm validatePermission: SoPerm_DeleteObjects
                             onObject: srcCollection
                            inContext: context])
            {
              if (![sm validatePermission: SoPerm_AddDocumentsImagesAndFiles
                                 onObject: dstCollection
                                inContext: context])
                {
                  newUID = [srcSogoObject globallyUniqueObjectId];
                  dstSogoObject = [[SOGoAppointmentObject alloc] initWithName: [newUID sanitizedServerIdWithType: srcFolderType]
                                                                  inContainer: dstCollection];
                  elements = [[srcSogoObject calendar: NO secure: NO] allObjects];
                  max = [elements count];
                  for (count = 0; count < max; count++)
                    [[elements objectAtIndex: count] setUid: newUID];
                  
                  ex = [dstSogoObject saveCalendar: [srcSogoObject calendar: NO secure: NO]];
                  if (!ex)
                    {
                      ex = [srcSogoObject delete];
                      [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
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
                          [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
                          [s appendFormat: @"<DstMsgId>%@</DstMsgId>", [prevSuccessfulMoveItemsOps objectForKey: srcMessageId] ];
                          [s appendFormat: @"<Status>%d</Status>", 3];
                          [newSuccessfulMoveItemsOps setObject: [prevSuccessfulMoveItemsOps objectForKey: srcMessageId]  forKey: srcMessageId];
                        }
                      else
                        {
                          [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
                          [s appendFormat: @"<Status>%d</Status>", 1];
                        }
                    }
                } 
              else 
                {
                  [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
                  [s appendFormat: @"<Status>%d</Status>", 2];
                }
            }
          else
            {
              [s appendFormat: @"<SrcMsgId>%@</SrcMsgId>", srcMessageId];
              [s appendFormat: @"<Status>%d</Status>", 1];
            }
        }
      
      [s appendString: @"</Response>"];

      [folderMetadata removeObjectForKey: @"SuccessfulMoveItemsOps"];
      [folderMetadata setObject: newSuccessfulMoveItemsOps forKey: @"SuccessfulMoveItemsOps"];
      [self _setFolderMetadata: folderMetadata forKey: nameInCache];
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
  NSString *collectionId, *realCollectionId, *syncKey;
  NSMutableArray *foldersWithChanges, *allFoldersID;
  SOGoMicrosoftActiveSyncFolderType folderType;
  NSMutableDictionary *folderMetadata;
  SOGoSystemDefaults *defaults;
  id <DOMElement> aCollection;
  NSArray *allCollections;

  NSMutableString *s;
  id collection;
  NSData *d;
  

  int i, j, heartbeatInterval, defaultInterval, internalInterval, status;
  
  defaults = [SOGoSystemDefaults sharedSystemDefaults];
  defaultInterval = [defaults maximumPingInterval];
  internalInterval = [defaults internalSyncInterval];

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
      status = 1;
    }

  // We build the list of folders to "ping". When the payload is empty, we use the list
  // of "cached" folders.
  allCollections = (id)[theDocumentElement getElementsByTagName: @"Folder"];
  allFoldersID = [NSMutableArray array];

  if (![allCollections count])
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
  else
    {      
      for (i = 0; i < [allCollections count]; i++)
        {
          aCollection = [allCollections objectAtIndex: i];
          collectionId = [[(id) [aCollection getElementsByTagName: @"Id"] lastObject] textValue];
          [allFoldersID addObject: collectionId];
        }
    }

  foldersWithChanges = [NSMutableArray array];

  // We enter our loop detection change
  for (i = 0; i < (heartbeatInterval/internalInterval); i++)
    {
      for (j = 0; j < [allFoldersID count]; j++)
        {
          collectionId = [allFoldersID objectAtIndex: j];
          realCollectionId = [collectionId realCollectionIdWithFolderType: &folderType];
          realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];

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
      
      if ([foldersWithChanges count])
        {
          [self logWithFormat: @"Change detected, we push the content."];
          status = 2;
          break;
        }
      else
        {
          [self logWithFormat: @"Sleeping %d seconds while detecting changes...", internalInterval];
          sleep(internalInterval);
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
              

              NGCalendarDateRange *r1, *r2;
              
              for (j = 1; j <= increments; j++)
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
- (void) processSearch: (id <DOMElement>) theDocumentElement
            inResponse: (WOResponse *) theResponse
{
  SOGoContactSourceFolder *currentFolder;
  NSDictionary *systemSources, *contact;
  SOGoContactFolders *contactFolders;
  NSArray *allKeys, *allContacts;
  SOGoUserFolder *userFolder;
  NSString *name, *query;
  NSMutableString *s;
  NSData *d;

  int i, j, total;
            
  name = [[(id)[theDocumentElement getElementsByTagName: @"Name"] lastObject] textValue];
  query = [[(id)[theDocumentElement getElementsByTagName: @"Query"] lastObject] textValue];
  
  // FIXME: for now, we only search in the GAL
  if (![name isEqualToString: @"GAL"])
    {
      [theResponse setStatus: 500];
      return;
    }
    

  userFolder = [[context activeUser] homeFolderInContext: context];
  contactFolders = [userFolder privateContacts: @"Contacts"  inContext: context];
  systemSources = [contactFolders systemSources];
  allKeys = [systemSources allKeys];

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
                                                 onCriteria: @"name_or_address"
                                                     sortBy: @"c_cn"
                                                   ordering: NSOrderedAscending
                                                   inDomain: [[context activeUser] domain]];

      for (j = 0; j < [allContacts count]; j++)
        {          
          contact = [allContacts objectAtIndex: j];
          
          // We skip lists for now
          if ([[contact objectForKey: @"c_component"] isEqualToString: @"vlist"])
            continue;
          
          // We get the LDIF entry of our record, for easier processing
          contact = [[currentFolder lookupName: [contact objectForKey: @"c_name"] inContext: context  acquire: NO] ldifRecord];
          
          [s appendString: @"<Result xmlns=\"Search:\">"];
          [s appendString: @"<Properties>"];
          [s appendFormat: @"<DisplayName xmlns=\"Gal:\">%@</DisplayName>", [contact objectForKey: @"displayname"]];
          [s appendFormat: @"<FirstName xmlns=\"Gal:\">%@</FirstName>", [contact objectForKey: @"givenname"]];
          [s appendFormat: @"<LastName xmlns=\"Gal:\">%@</LastName>", [contact objectForKey: @"sn"]];
          [s appendFormat: @"<EmailAddress xmlns=\"Gal:\">%@</EmailAddress>", [contact objectForKey: @"mail"]];
          [s appendFormat: @"<Phone xmlns=\"Gal:\">%@</Phone>", [contact objectForKey: @"telephonenumber"]];
          [s appendFormat: @"<Company xmlns=\"Gal:\">%@</Company>", [contact objectForKey: @"o"]];
          [s appendString: @"</Properties>"];
          [s appendString: @"</Result>"];
          total++;
        }        
    }
  
  [s appendFormat: @"<Range>0-%d</Range>", total-1];
  [s appendFormat: @"<Total>%d</Total>", total];
  [s appendString: @"</Store>"];
  [s appendString: @"</Response>"];
  [s appendString: @"</Search>"];

  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
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

//
//
//
- (void) processSendMail: (id <DOMElement>) theDocumentElement
              inResponse: (WOResponse *) theResponse
{
  NGMimeMessageParser *parser;
  NGMimeMessage *message;
  NSException *error;
  NSData *data;
  NGMutableHashMap *map;
  NGMimeMessage *messageToSend;
  NGMimeMessageGenerator *generator;
  NSDictionary *identity;
  NSString *fullName, *email;
  
  // We get the mail's data
  data = [[[[(id)[theDocumentElement getElementsByTagName: @"MIME"] lastObject] textValue] stringByDecodingBase64] dataUsingEncoding: NSUTF8StringEncoding];
  
  // We extract the recipients
  parser = [[NGMimeMessageParser alloc] init];
  message = [parser parsePartFromData: data];
  RELEASE(parser);

  map = [NGHashMap hashMapWithDictionary: [message headers]];

  identity = [[context activeUser] primaryIdentity];

  fullName = [identity objectForKey: @"fullName"];
  email = [identity objectForKey: @"email"];
  if ([fullName length])
    [map setObject: [NSString stringWithFormat: @"%@ <%@>", fullName, email]  forKey: @"from"];
  else
    [map setObject: email forKey: @"from"];

  messageToSend = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];

  [messageToSend setBody: [message body]];

  generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
  data = [generator generateMimeFromPart: messageToSend];
  
  error = [self _sendMail: data
               recipients: [message allRecipients]
                saveInSentItems: ([(id)[theDocumentElement getElementsByTagName: @"SaveInSentItems"] count] ? YES : NO)];

  if (error)
    {
      [theResponse setStatus: 500];
      [theResponse appendContentString: @"FATAL ERROR occured during SendMail"];
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
  
  NSMutableString *s;
  NSData *d;
  
  s = [NSMutableString string];
  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<Settings xmlns=\"Settings:\">"];
  [s appendFormat: @"    <Status>1</Status>"];
  [s appendString: @"</Settings>"];
  
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
  
  [theResponse setContent: d];
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
  NSString *folderId, *itemId, *realCollectionId;
  SOGoMicrosoftActiveSyncFolderType folderType;
  id value;

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

  // ReplaceMime IS specified so we must NOT use the server copy
  // but rather take the data as-is from the client.
  if ([value count])
    {
      [self processSendMail: theDocumentElement
                 inResponse: theResponse];
      return;
    }
  
  if (folderType == ActiveSyncMailFolder)
    {
      SOGoMailAccounts *accountsFolder;
      SOGoMailFolder *currentFolder;
      SOGoUserFolder *userFolder;
      SOGoMailObject *mailObject;
      id currentCollection;

      NGMimeMessage *messageFromSmartForward, *messageToSend;
      NGMimeMessageParser *parser;
      NSData *data;

      NGMimeMessageGenerator *generator;
      NGMimeBodyPart *bodyPart;
      NGMutableHashMap *map;
      NGMimeFileData *fdata;
      NSException *error;

      id body, bodyFromSmartForward;
      NSString *fullName, *email;
      NSDictionary *identity;

      userFolder = [[context activeUser] homeFolderInContext: context];
      accountsFolder = [userFolder lookupName: @"Mail"  inContext: context  acquire: NO];
      currentFolder = [accountsFolder lookupName: @"0"  inContext: context  acquire: NO];
      
      currentCollection = [currentFolder lookupName: [NSString stringWithFormat: @"folder%@", realCollectionId]
                                          inContext: context
                                            acquire: NO];

      mailObject = [currentCollection lookupName: itemId  inContext: context  acquire: NO];


      parser = [[NGMimeMessageParser alloc] init];
      data = [[[[(id)[theDocumentElement getElementsByTagName: @"MIME"] lastObject] textValue] stringByDecodingBase64] dataUsingEncoding: NSUTF8StringEncoding];
      messageFromSmartForward = [parser parsePartFromData: data];
      RELEASE(parser);
      
      // We create a new MIME multipart/mixed message. The first part will be the text part
      // of our "smart forward" and the second part will be the message/rfc822 part of the
      // "smart forwarded" message.
      map = [NGHashMap hashMapWithDictionary: [messageFromSmartForward headers]];
      [map setObject: @"multipart/mixed"  forKey: @"content-type"];

      identity = [[context activeUser] primaryIdentity];

      fullName = [identity objectForKey: @"fullName"];
      email = [identity objectForKey: @"email"];
      if ([fullName length])
        [map setObject: [NSString stringWithFormat: @"%@ <%@>", fullName, email]  forKey: @"from"];
      else
        [map setObject: email forKey: @"from"];

      messageToSend = [[[NGMimeMessage alloc] initWithHeader: map] autorelease];
      body = [[[NGMimeMultipartBody alloc] initWithPart: messageToSend] autorelease];
      
      // First part - either a text/* or a multipart/*. If it's a multipart,
      // we take the first part text/* part we see.
      map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];
      bodyFromSmartForward = nil;

      if ([[messageFromSmartForward body] isKindOfClass: [NGMimeMultipartBody class]])
        {
          NGMimeBodyPart *part;
          NSArray *parts;
          int i;
          
          parts = [[messageFromSmartForward body] parts];
          
          for (i = 0; i < [parts count]; i++)
            {
              part = [parts objectAtIndex: i];
              
              if ([[[part contentType] type] isEqualToString: @"text"])
                {
                  [map setObject: [[part contentType] stringValue] forKey: @"content-type"];
                  bodyFromSmartForward = [part body];
                  break;
                }
            }
        }
      else
        {
          [map setObject: [[messageFromSmartForward contentType] stringValue] forKey: @"content-type"];
          bodyFromSmartForward = [messageFromSmartForward body];
        }

      bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
      [bodyPart setBody: bodyFromSmartForward];
      [body addBodyPart: bodyPart];

      // Second part
      map = [[[NGMutableHashMap alloc] initWithCapacity: 1] autorelease];
      [map setObject: @"message/rfc822" forKey: @"content-type"];
      [map setObject: @"8bit" forKey: @"content-transfer-encoding"];
      bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
      
      data = [mailObject content];
      fdata = [[NGMimeFileData alloc] initWithBytes:[data bytes]
                                             length:[data length]];

      [bodyPart setBody: fdata];
      RELEASE(fdata);
      [body addBodyPart: bodyPart];
      [messageToSend setBody: body];
      
      generator = [[[NGMimeMessageGenerator alloc] init] autorelease];
      data = [generator generateMimeFromPart: messageToSend];
            
      error = [self _sendMail: data
                   recipients: [messageFromSmartForward allRecipients]
                    saveInSentItems:  ([(id)[theDocumentElement getElementsByTagName: @"SaveInSentItems"] count] ? YES : NO)];
      
      if (error)
        {
          [theResponse setStatus: 500];
          [theResponse appendContentString: @"FATAL ERROR occured during SmartForward"];
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
  [self processSmartForward: theDocumentElement  inResponse: theResponse];
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

  NSString *cmdName, *deviceId;
  NSData *d;

  pool = [[NSAutoreleasePool alloc] init];
    
  ASSIGN(context, theContext);
  
  // Get the device ID, device type and "stash" them
  deviceId = [[theRequest uri] deviceId];
  [context setObject: deviceId  forKey: @"DeviceId"];
  [context setObject: [[theRequest uri] deviceType]  forKey: @"DeviceType"];
  [context setObject: [[theRequest uri] attachmentName]  forKey: @"AttachmentName"];

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
          
          value = [[NSDate date] descriptionWithCalendarFormat: @"%a, %d %b %Y %H:%M:%S %z"  timeZone: [NSTimeZone timeZoneWithName: @"GMT"]  locale: nil];
          s = [NSString stringWithFormat: @"Date: %@\n%@", value, [theRequest contentAsString]];
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
      d = [[theRequest content] wbxml2xml];
    }
  
  documentElement = nil;

  if (!d)
    {
      // We check if it's a Ping command with no body.
      // See http://msdn.microsoft.com/en-us/library/ee200913(v=exchg.80).aspx for details      
      if ([cmdName caseInsensitiveCompare: @"Ping"] != NSOrderedSame && [cmdName caseInsensitiveCompare: @"GetAttachment"] != NSOrderedSame && [cmdName caseInsensitiveCompare: @"Sync"] != NSOrderedSame)
        {
          RELEASE(context);
          RELEASE(pool);
          return [NSException exceptionWithHTTPStatus: 500];
        }
    }

  if (d)
    {
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

  [theResponse setHeader: @"14.1"  forKey: @"MS-Server-ActiveSync"];
  [theResponse setHeader: @"Sync,SendMail,SmartForward,SmartReply,GetAttachment,GetHierarchy,CreateCollection,DeleteCollection,MoveCollection,FolderSync,FolderCreate,FolderDelete,FolderUpdate,MoveItems,GetItemEstimate,MeetingResponse,Search,Settings,Ping,ItemOperations,ResolveRecipients,ValidateCert"  forKey: @"MS-ASProtocolCommands"];
  [theResponse setHeader: @"2.5,12.0,12.1,14.0,14.1"  forKey: @"MS-ASProtocolVersions"];

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
      parts = [[urlString componentsSeparatedByString: @"/"]
                mutableCopy];
      [parts autorelease];
      if ([parts count] == 5)
        {
          /* If "OCSFolderInfoURL" is properly configured, we must have 5
             parts in this url. We strip the '-' character in case we have
             this in the domain part - like foo@bar-zot.com */
          ocFSTableName = [NSMutableString stringWithFormat: @"sogo_cache_folder_%@",
                                           [[user loginInDomain] asCSSIdentifier]];
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

@end
