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
#import "SOGoActiveSyncDispatcher+Sync.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSSortDescriptor.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
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
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/NGVCard.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <NGImap4/NSString+Imap4.h>

#import <DOM/DOMElement.h>
#import <DOM/DOMProtocols.h>

#import <EOControl/EOQualifier.h>

#import <SOGo/NSArray+DAV.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/NSDictionary+DAV.h>
#import <SOGo/SOGoDAVAuthenticator.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoCacheGCSObject.h>

#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoTaskObject.h>

#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSFolder.h>
#import <Contacts/SOGoContactFolders.h>
#import <Contacts/SOGoContactSourceFolder.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#include "iCalEvent+ActiveSync.h"
#include "iCalToDo+ActiveSync.h"
#include "NGDOMElement+ActiveSync.h"
#include "NGVCard+ActiveSync.h"
#include "NSCalendarDate+ActiveSync.h"
#include "NSDate+ActiveSync.h"
#include "NSData+ActiveSync.h"
#include "NSString+ActiveSync.h"
#include "SOGoActiveSyncConstants.h"
#include "SOGoMailObject+ActiveSync.h"
#include "SOGoSyncCacheObject.h"

#include <unistd.h>

@implementation SOGoActiveSyncDispatcher (Sync)

- (void) _setOrUnsetSyncRequest: (BOOL) set
                       collections: (NSArray *) collections
{
  SOGoCacheGCSObject *o;
  NSNumber *processIdentifier;
  NSString *key;
  int i;

  processIdentifier = [NSNumber numberWithInt: [[NSProcessInfo processInfo] processIdentifier]];

  o = [SOGoCacheGCSObject objectWithName: [context objectForKey: @"DeviceId"]  inContainer: nil  useCache: NO];
  [o setObjectType: ActiveSyncGlobalCacheObject];
  [o setTableUrl: [self folderTableURL]];
  [o reloadIfNeeded];

  if (set)
    {
      RELEASE(syncRequest);
      syncRequest = [NSNumber numberWithUnsignedInt: [[NSCalendarDate date] timeIntervalSince1970]];
      RETAIN(syncRequest);

      [[o properties] setObject: syncRequest forKey: @"SyncRequest"];

      for (i = 0; i < [collections count]; i++)
        {
          key = [NSString stringWithFormat: @"SyncRequest+%@", [[[(id)[[collections objectAtIndex: i] getElementsByTagName: @"CollectionId"] lastObject] textValue] stringByUnescapingURL]];
          [[o properties] setObject: processIdentifier forKey: key];
        }
    }
  else
    {
      [[o properties] removeObjectForKey: @"SyncRequest"];
      for (i = 0; i < [collections count]; i++)
        {
          key = [NSString stringWithFormat: @"SyncRequest+%@", [[[(id)[[collections objectAtIndex: i] getElementsByTagName: @"CollectionId"] lastObject] textValue] stringByUnescapingURL]];
          [[o properties] removeObjectForKey: key];
        }
    }

  [o save];
}

- (void) _setFolderMetadata: (NSDictionary *) theFolderMetadata
                     forKey: (NSString *) theFolderKey
{
  NSNumber *processIdentifier, *processIdentifierInCache;
  SOGoCacheGCSObject *o;
  NSDictionary *values;
  NSString *key;

  if ([theFolderKey hasPrefix: @"folder"])
    key = [NSString stringWithFormat: @"SyncRequest+mail/%@", [theFolderKey substringFromIndex: 6]];
  else
    key = [NSString stringWithFormat: @"SyncRequest+%@", theFolderKey];

  processIdentifier = [NSNumber numberWithInt: [[NSProcessInfo processInfo] processIdentifier]];
  processIdentifierInCache = [[self globalMetadataForDevice] objectForKey: key];

  // Don't update the cache if another request is processing the same collection.
  if (!([processIdentifierInCache isEqual: processIdentifier]))
    {
      if (debugOn)
        [self logWithFormat: @"EAS - We lost our lock - discard folder cache update %@ %@ <> %@", key, processIdentifierInCache, processIdentifier];

     return;
    }

  key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], theFolderKey];
  values = [theFolderMetadata copy];
  
  o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
  [o setObjectType: ActiveSyncFolderCacheObject];
  [o setTableUrl: [self folderTableURL]];
  //[o reloadIfNeeded];

  [[o properties] removeObjectForKey: @"SyncKey"];
  [[o properties] removeObjectForKey: @"SyncCache"];
  [[o properties] removeObjectForKey: @"DateCache"];
  [[o properties] removeObjectForKey: @"MoreAvailable"];
  [[o properties] removeObjectForKey: @"BodyPreferenceType"];
  [[o properties] removeObjectForKey: @"SupportedElements"];
  [[o properties] removeObjectForKey: @"SuccessfulMoveItemsOps"];
  [[o properties] removeObjectForKey: @"InitialLoadSequence"];

  [[o properties] addEntriesFromDictionary: values];
  [o save];
  [values release];
}

- (NSMutableDictionary *) _folderMetadataForKey: (NSString *) theFolderKey
{
  SOGoCacheGCSObject *o;
  NSString *key;

  key = [NSString stringWithFormat: @"%@+%@", [context objectForKey: @"DeviceId"], theFolderKey];

  o = [SOGoCacheGCSObject objectWithName: key  inContainer: nil];
  [o setObjectType: ActiveSyncFolderCacheObject];
  [o setTableUrl: [self folderTableURL]];
  [o reloadIfNeeded];
  
  return [o properties];
}

- (NSString *) _getNameInCache: (id) theCollection withType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
{
  NSString  *nameInCache;
  
  if (theFolderType == ActiveSyncMailFolder)
    nameInCache = [imapFolderGUIDS objectForKey: [theCollection nameInContainer]];
  else
    {
      NSString  *component_name;
      if (theFolderType == ActiveSyncContactFolder)
        component_name = @"vcard";
      else if (theFolderType == ActiveSyncEventFolder)
        component_name = @"vevent";
      else
        component_name = @"vtodo";
      
      nameInCache = [NSString stringWithFormat: @"%@/%@", component_name, [theCollection nameInContainer]];
    }
  
  return nameInCache;
}



//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Sync xmlns="AirSync:">
//  <Collections>
//   <Collection>
//    <SyncKey>1388757902</SyncKey>
//    <CollectionId>vcard/personal</CollectionId>
//    <GetChanges/>
//    <WindowSize>25</WindowSize>
//    <Options>
//     <BodyPreference xmlns="AirSyncBase:">
//      <Type>1</Type>
//      <TruncationSize>32768</TruncationSize>
//     </BodyPreference>
//    </Options>
//    <Commands>
//     <Add>
//      <ClientId>16</ClientId>
//      <ApplicationData>
//       <Body xmlns="AirSyncBase:">
//        <Type>1</Type>
//        <Data/>
//       </Body>
//       <CompanyName xmlns="Contacts:">Goo Inc.</CompanyName>
//       <Email1Address xmlns="Contacts:">annie@broccoli.com</Email1Address>
//       <FileAs xmlns="Contacts:">Broccoli, Annie</FileAs>
//       <FirstName xmlns="Contacts:">Annie</FirstName>
//       <LastName xmlns="Contacts:">Broccoli</LastName>
//       <Picture xmlns="Contacts:"/>
//      </ApplicationData>
//     </Add>
//    </Commands>
//   </Collection>
//  </Collections>
// </Sync>
//
- (void) processSyncAddCommand: (id <DOMElement>) theDocumentElement
                  inCollection: (id) theCollection
                      withType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
                      inBuffer: (NSMutableString *) theBuffer
{
  NSMutableDictionary *folderMetadata, *dateCache, *syncCache, *allValues;
  NSString *clientId, *serverId;
  NSArray *additions;
  
  id anAddition, sogoObject, o;
  BOOL is_new;
  int i;

  additions = (id)[theDocumentElement getElementsByTagName: @"Add"];
  if ([additions count])
    {
      for (i = 0; i < [additions count]; i++)
        {
          anAddition = [additions objectAtIndex: i];
          is_new = YES;

          clientId = [[(id)[anAddition getElementsByTagName: @"ClientId"] lastObject] textValue];
          allValues = [NSMutableDictionary dictionaryWithDictionary: [[(id)[anAddition getElementsByTagName: @"ApplicationData"]  lastObject] applicationData]];
          
          switch (theFolderType)
            {
            case ActiveSyncContactFolder:
              {
                serverId = [NSString stringWithFormat: @"%@.vcf", [theCollection globallyUniqueObjectId]];
                sogoObject = [[SOGoContactGCSEntry alloc] initWithName: serverId
                                                           inContainer: theCollection];
                o = [sogoObject vCard];
              }
              break;
            case ActiveSyncEventFolder:
              {
                // Before adding a new appointment, we check if one is already present with the same UID. If that's
                // the case, let's just update it. This can happen if for example, an iOS based device receives the
                // invitation email and choses "Add to calendar" BEFORE actually syncing the calendar. That would
                // create a duplicate on the server.
                if ([allValues objectForKey: @"UID"])
                  serverId = [allValues objectForKey: @"UID"];
                else
                  serverId = [theCollection globallyUniqueObjectId];
                                
                sogoObject = [theCollection lookupName: [serverId sanitizedServerIdWithType: theFolderType]
                                             inContext: context
                                               acquire: NO];
                
                // If object isn't found, we 'create' a new one
                if ([sogoObject isKindOfClass: [NSException class]])
                  {
                    sogoObject = [[SOGoAppointmentObject alloc] initWithName: [serverId sanitizedServerIdWithType: theFolderType]
                                                                 inContainer: theCollection];
                    o = [sogoObject component: YES secure: NO];
                  }
                else
                  {
                    o = [sogoObject component: NO secure: NO];
                    is_new = NO;
                  }
              }
              break;
            case ActiveSyncTaskFolder:
              {
                serverId = [NSString stringWithFormat: @"%@.ics", [theCollection globallyUniqueObjectId]];
                sogoObject = [[SOGoTaskObject alloc] initWithName: serverId
                                                      inContainer: theCollection];
                o = [sogoObject component: YES secure: NO];
              }
              break;
            case ActiveSyncMailFolder:
            default:
              {
                // FIXME - what to do?
                [self errorWithFormat: @"Fatal error occured - tried to call -processSyncAddCommand: ... on a mail folder. We abort."];
                abort();
              }
            }
          
          [o takeActiveSyncValues: allValues  inContext: context];
          [sogoObject setIsNew: is_new];
          [sogoObject saveComponent: o];
          
          // Everything is fine, lets generate our response
          [theBuffer appendString: @"<Add>"];
          [theBuffer appendFormat: @"<ClientId>%@</ClientId>", clientId];
          [theBuffer appendFormat: @"<ServerId>%@</ServerId>", serverId];
          [theBuffer appendFormat: @"<Status>%d</Status>", 1];
          [theBuffer appendString: @"</Add>"];

          // Update syncCache
          folderMetadata = [self _folderMetadataForKey: [self _getNameInCache: theCollection withType: theFolderType]];

          syncCache = [folderMetadata objectForKey: @"SyncCache"];
          dateCache = [folderMetadata objectForKey: @"DateCache"];

          [syncCache setObject: [NSString stringWithFormat:@"%f", [[sogoObject lastModified] timeIntervalSince1970]] forKey: serverId];
          [dateCache setObject: [NSCalendarDate date]  forKey: serverId];

          [self _setFolderMetadata: folderMetadata forKey: [self _getNameInCache: theCollection withType: theFolderType]];
        }
    }
}

//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Sync xmlns="AirSync:">
//  <Collections>
//   <Collection>
//    <SyncKey>1387546048</SyncKey>
//    <CollectionId>vtodo/personal</CollectionId>
//    <GetChanges/>
//    <WindowSize>25</WindowSize>
//    <Options>
//     <BodyPreference xmlns="AirSyncBase:">
//      <Type>1</Type>
//      <TruncationSize>32768</TruncationSize>
//     </BodyPreference>
//    </Options>
//    <Commands>
//     <Change>
//      <ServerId>36C5-52B36280-1-27B38F40.ics</ServerId>
//      <ApplicationData>
//       <Body xmlns="AirSyncBase:">
//        <Type>1</Type>
//        <Data/>
//       </Body>
//       <Subject xmlns="Tasks:">foobar1</Subject>
//       <Importance xmlns="Tasks:">1</Importance>
//       <Complete xmlns="Tasks:">0</Complete>
//       <Sensitivity xmlns="Tasks:">0</Sensitivity>
//       <ReminderSet xmlns="Tasks:">0</ReminderSet>
//      </ApplicationData>
//     </Change>
//    </Commands>
//   </Collection>
//  </Collections>
// </Sync>
//
- (void) processSyncChangeCommand: (id <DOMElement>) theDocumentElement
                     inCollection: (id) theCollection
                         withType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
                         inBuffer: (NSMutableString *) theBuffer
{
  NSDictionary *allChanges;
  NSString *serverId;
  NSArray *changes;
  id aChange, o, sogoObject;
  NSMutableDictionary *folderMetadata, *syncCache;

  int i;

  changes = (id)[theDocumentElement getElementsByTagName: @"Change"];

  if ([changes count])
    {
      folderMetadata = [self _folderMetadataForKey: [self _getNameInCache: theCollection withType: theFolderType]];
      syncCache = [folderMetadata objectForKey: @"SyncCache"];

      for (i = 0; i < [changes count]; i++)
        {
          aChange = [changes objectAtIndex: i];
          
          serverId = [[(id)[aChange getElementsByTagName: @"ServerId"] lastObject] textValue];
          allChanges = [[(id)[aChange getElementsByTagName: @"ApplicationData"]  lastObject] applicationData];

          // Fetch the object and apply the changes
          sogoObject = [theCollection lookupName: [serverId sanitizedServerIdWithType: theFolderType]
                                       inContext: context
                                         acquire: NO];

          // Object was removed inbetween sync/commands?
          if ([sogoObject isKindOfClass: [NSException class]])
            {
              // FIXME - return status == 8
              continue;
            }
          
          switch (theFolderType)
            {
            case ActiveSyncContactFolder:
              {
                o = [sogoObject vCard];
                [o takeActiveSyncValues: allChanges  inContext: context];
                [sogoObject saveComponent: o];

                if ([syncCache objectForKey: serverId])
                  [syncCache setObject: [NSString stringWithFormat:@"%f", [[sogoObject lastModified] timeIntervalSince1970]] forKey: serverId];
              }
              break;
            case ActiveSyncEventFolder:
            case ActiveSyncTaskFolder:
              {
                o = [sogoObject component: NO  secure: NO];

                if (theFolderType == ActiveSyncEventFolder &&
                    [(iCalEvent *)o userIsAttendee: [context activeUser]])
                  {
                    [o changeParticipationStatus: allChanges  inContext: context  component: sogoObject];
                  }
                else
                  {
                    [o takeActiveSyncValues: allChanges  inContext: context];
                    [sogoObject saveComponent: o];
                  }

                if ([syncCache objectForKey: serverId])
                  [syncCache setObject: [NSString stringWithFormat:@"%f", [[sogoObject lastModified] timeIntervalSince1970]] forKey: serverId];
              }
              break;
            case ActiveSyncMailFolder:
            default:
              {
                NSDictionary *result;
                NSNumber *modseq;

                [sogoObject takeActiveSyncValues: allChanges  inContext: context];

                result = [sogoObject fetchParts: [NSArray arrayWithObject: @"MODSEQ"]];
                modseq = [[[result objectForKey: @"RawResponse"] objectForKey: @"fetch"] objectForKey: @"modseq"];

                if (modseq && [syncCache objectForKey: serverId])
                  [syncCache setObject: [modseq stringValue] forKey: serverId];
              }
            }

          [self _setFolderMetadata: folderMetadata  forKey: [self _getNameInCache: theCollection withType: theFolderType]];


          [theBuffer appendString: @"<Change>"];
          [theBuffer appendFormat: @"<ServerId>%@</ServerId>", serverId];
          [theBuffer appendFormat: @"<Status>%d</Status>", 1];
          [theBuffer appendString: @"</Change>"];
        }
    }
}

//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Sync xmlns="AirSync:">
//  <Collections>
//   <Collection>
//    <SyncKey>1388764784</SyncKey>
//    <CollectionId>vtodo/personal</CollectionId>
//    <GetChanges/>
//    <WindowSize>25</WindowSize>
//    <Options>
//     <BodyPreference xmlns="AirSyncBase:">
//      <Type>1</Type>
//      <TruncationSize>32768</TruncationSize>
//     </BodyPreference>
//    </Options>
//    <Commands>
//     <Delete>
//      <ServerId>2CB5-52B36080-1-1C1D0240.ics</ServerId>
//     </Delete>
//    </Commands>
//   </Collection>
//  </Collections>
// </Sync>
//
- (void) processSyncDeleteCommand: (id <DOMElement>) theDocumentElement
                     inCollection: (id) theCollection
                         withType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
                         inBuffer: (NSMutableString *) theBuffer
{

  id aDelete, sogoObject, value;
  NSArray *deletions;
  NSString *serverId;

  BOOL deletesAsMoves, useTrash;
  int i;

  deletions = (id)[theDocumentElement getElementsByTagName: @"Delete"];

  if ([deletions count])
    {
      // From the documention, if DeletesAsMoves is missing, we must assume it's a YES.
      // See https://msdn.microsoft.com/en-us/library/gg675480(v=exchg.80).aspx for all details.
      value = [theDocumentElement getElementsByTagName: @"DeletesAsMoves"];
      deletesAsMoves = YES;
      useTrash = YES;

      if ([value count] && [[[value lastObject] textValue] length])
        deletesAsMoves = [[[value lastObject] textValue] boolValue];

      for (i = 0; i < [deletions count]; i++)
        {
          aDelete = [deletions objectAtIndex: i];
          
          serverId = [[(id)[aDelete getElementsByTagName: @"ServerId"] lastObject] textValue];
          
          sogoObject = [theCollection lookupName: [serverId sanitizedServerIdWithType: theFolderType]
                                       inContext: context
                                         acquire: NO];

          if (![sogoObject isKindOfClass: [NSException class]])
            {
              // FIXME: handle errors here
              if (deletesAsMoves && theFolderType == ActiveSyncMailFolder)
                [(SOGoMailFolder *)[sogoObject container] deleteUIDs: [NSArray arrayWithObjects: serverId, nil] useTrashFolder: &useTrash inContext: context];
              else if (theFolderType == ActiveSyncEventFolder || theFolderType == ActiveSyncTaskFolder)
                {
                  [sogoObject prepareDelete];
                  [sogoObject delete];
                }
              else
                [sogoObject delete];
            }

          [theBuffer appendString: @"<Delete>"];
          [theBuffer appendFormat: @"<ServerId>%@</ServerId>", serverId];
          [theBuffer appendFormat: @"<Status>%d</Status>", 1];
          [theBuffer appendString: @"</Delete>"];

          // update syncCache
          NSMutableDictionary *folderMetadata, *dateCache, *syncCache;
          folderMetadata = [self _folderMetadataForKey: [self _getNameInCache: theCollection withType: theFolderType]];

          syncCache = [folderMetadata objectForKey: @"SyncCache"];
          dateCache = [folderMetadata objectForKey: @"DateCache"];

          [syncCache removeObjectForKey: serverId];
          [dateCache removeObjectForKey: serverId];

          [self _setFolderMetadata: folderMetadata forKey: [self _getNameInCache: theCollection withType: theFolderType]];
        }
    }
}


//
//  <Fetch>
//    <ServerId>91</ServerId>
//  </Fetch>
//
- (void) processSyncFetchCommand: (id <DOMElement>) theDocumentElement
                    inCollection: (id) theCollection
                        withType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
                        inBuffer: (NSMutableString *) theBuffer
{
  NSString *serverId;
  id o;

  serverId = [[(id)[theDocumentElement getElementsByTagName: @"ServerId"] lastObject] textValue];

  o = [theCollection lookupName: [serverId sanitizedServerIdWithType: theFolderType]
                      inContext: context
                        acquire: NO];
  
  // FIXME - error handling
  [theBuffer appendString: @"<Fetch>"];
  [theBuffer appendFormat: @"<ServerId>%@</ServerId>", serverId];
  [theBuffer appendFormat: @"<Status>%d</Status>", 1];
  [theBuffer appendString: @"<ApplicationData>"];
  [theBuffer appendString: [o activeSyncRepresentationInContext: context]];
  [theBuffer appendString: @"</ApplicationData>"];
  [theBuffer appendString: @"</Fetch>"];
}

//
// The method handles <GetChanges/>
//
- (void) processSyncGetChanges: (id <DOMElement>) theDocumentElement
                  inCollection: (id) theCollection
                withWindowSize: (unsigned int) theWindowSize
       withMaxSyncResponseSize: (unsigned int) theMaxSyncResponseSize
                   withSyncKey: (NSString *) theSyncKey
                withFolderType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
                withFilterType: (NSCalendarDate *) theFilterType
                      inBuffer: (NSMutableString *) theBuffer
                 lastServerKey: (NSString **) theLastServerKey
               defaultInterval: (unsigned int) theDefaultInterval
{
  NSMutableDictionary *folderMetadata, *dateCache, *syncCache;
  NSString *davCollectionTagToStore;
  NSAutoreleasePool *pool;
  NSMutableString *s;
  
  BOOL cleanup_needed, more_available;
  int i, max;

  s = [NSMutableString string];
  cleanup_needed = more_available = NO;

  folderMetadata = [self _folderMetadataForKey: [self _getNameInCache: theCollection withType: theFolderType]];

  // If this is a new sync operation, DateCache and SyncCache need to be deleted
  if ([theSyncKey isEqualToString: @"-1"])
    {
      [folderMetadata setObject: [NSMutableDictionary dictionary]  forKey: @"SyncCache"];
      [folderMetadata setObject: [NSMutableDictionary dictionary]  forKey: @"DateCache"];
    }
  else if ([folderMetadata objectForKey: @"SyncKey"] && !([theSyncKey isEqualToString: [folderMetadata objectForKey: @"SyncKey"]]))
    {
      // The syncKey received from the client doesn't match the syncKey we have in cache - client might have missed a response.
      // We need to cleanup this mess.
      [self logWithFormat: @"Cache cleanup needed for device %@ - user: %@ syncKey: %@ cache: %@", [context objectForKey: @"DeviceId"], [[context activeUser] login], theSyncKey, [folderMetadata objectForKey: @"SyncKey"]];
      cleanup_needed = YES;
    }

  syncCache = [folderMetadata objectForKey: @"SyncCache"];
  dateCache = [folderMetadata objectForKey: @"DateCache"];

  if ((theFolderType == ActiveSyncMailFolder || theFolderType == ActiveSyncEventFolder || theFolderType == ActiveSyncTaskFolder) && 
      (cleanup_needed ||
       ( !([folderMetadata objectForKey: @"MoreAvailable"]) && // previous sync operation reached the windowSize or maximumSyncReponseSize
         !([folderMetadata objectForKey: @"InitialLoadSequence"]))) &&
         theFilterType
     )
    {
      NSArray *allKeys;
      NSString *key;
      
      int softdelete_count;

      softdelete_count = 0;
          
      allKeys = [dateCache allKeys];
      for (i = 0; i < [allKeys count]; i++)
        {
          key = [allKeys objectAtIndex: i];
              
          if ([[dateCache objectForKey:key] compare: theFilterType] == NSOrderedAscending)
            {
              if ([syncCache objectForKey:key])
                {
                  if (debugOn)
                    [self logWithFormat: @"EAS - SoftDelete %@", key];

                  [s appendString: @"<SoftDelete xmlns=\"AirSync:\">"];
                  [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", key];
                  [s appendString: @"</SoftDelete>"];

                  [syncCache removeObjectForKey: key];
                  //[dateCache removeObjectForKey: key];
              
                  softdelete_count++;
                }
              else if (cleanup_needed)
                {
                  if (debugOn)
                    [self logWithFormat: @"EAS - SoftDelete cleanup %@", key];

                  // With this we make sure that a SoftDelete is set again on next sync.
                  [syncCache setObject: @"0" forKey: key];
                }
              else
                {
                  if (debugOn)
                    [self logWithFormat: @"EAS - SoftDelete final delete %@", key];

                  // Now we are save to remove the dateCache entry.
                  [dateCache removeObjectForKey: key];
                }
            }
          
          if (softdelete_count >= theWindowSize || (theMaxSyncResponseSize > 0 && [s length] >= theMaxSyncResponseSize))
            {
              [folderMetadata setObject: [NSNumber numberWithBool: YES]  forKey: @"MoreAvailable"];
              [self _setFolderMetadata: folderMetadata forKey: [self _getNameInCache: theCollection withType: theFolderType]];
              
              more_available = YES;
              *theLastServerKey = theSyncKey;
              
              // Since WindowSize is reached don't even try to add more to the response, let's just
              // jump to the end and return the response immediately
              goto return_response;
          }
        }
          
      [folderMetadata removeObjectForKey: @"MoreAvailable"];
      [self _setFolderMetadata: folderMetadata forKey: [self _getNameInCache: theCollection withType: theFolderType]];
    }
  
  //
  // No changes in the collection - 2.2.2.19.1.1 Empty Sync Request.
  // We check this and we don't generate any commands if we don't have to.
  //
  if ([theSyncKey isEqualToString: [theCollection davCollectionTag]] && !([s length]))
    return;

  davCollectionTagToStore = [theCollection davCollectionTag];

  switch (theFolderType)
    {
      // Handle all the GCS components
    case ActiveSyncContactFolder:
    case ActiveSyncEventFolder:
    case ActiveSyncTaskFolder:
      {
        id sogoObject, componentObject;
        NSString *uid, *component_name;
        NSDictionary *component;
        NSArray *allComponents;

        BOOL updated, initialLoadInProgress;
        int deleted, return_count;
          
        if (theFolderType == ActiveSyncContactFolder)
          component_name = @"vcard";
        else if (theFolderType == ActiveSyncEventFolder)
          component_name = @"vevent";
        else
          component_name = @"vtodo";

        initialLoadInProgress = NO;

        if ([theSyncKey isEqualToString: @"-1"])
          [folderMetadata setObject: davCollectionTagToStore forKey: @"InitialLoadSequence"];

        if ([folderMetadata objectForKey: @"InitialLoadSequence"])
          {
            if ([theSyncKey intValue] < [[folderMetadata objectForKey: @"InitialLoadSequence"] intValue])
              initialLoadInProgress = YES;
            else
              [folderMetadata removeObjectForKey: @"InitialLoadSequence"];
          }

        allComponents = [theCollection syncTokenFieldsWithProperties: nil
                                                   matchingSyncToken: theSyncKey
                                                            fromDate: theFilterType
                                                         initialLoad: initialLoadInProgress];
        allComponents = [allComponents sortedArrayUsingDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"c_lastmodified" ascending: YES] autorelease]]];

        
        // Check for the WindowSize
        max = [allComponents count];

        //
        // Cleanup the mess
        //
        if (cleanup_needed)
          {

            for (i = 0; i < max; i++)
              {
                component = [allComponents objectAtIndex: i];
                deleted = [[component objectForKey: @"c_deleted"] intValue];

                if (!deleted && ![[component objectForKey: @"c_component"] isEqualToString: component_name])
                    continue;

                uid = [[component objectForKey: @"c_name"] sanitizedServerIdWithType: theFolderType];

                if (deleted)
                  {
                    if (debugOn)
                      [self logWithFormat: @"EAS - Cache cleanup: DELETE %@", uid];
 
                    // For deletes we have to recreate a cache entry to make sure the delete is sent again.
                    [syncCache setObject: @"0"  forKey: uid];
                  }
                else
                  {
                    if ([syncCache objectForKey: uid] && [[component objectForKey: @"c_creationdate"] intValue] > [theSyncKey intValue])
                      {
                        if (debugOn)
                          [self logWithFormat: @"EAS - Cache cleanup: ADD %@", uid];

                        // Cleanup the cache to make sure the add is sent again.
                        [syncCache removeObjectForKey: uid];
                        [dateCache removeObjectForKey: uid];
                      }
                    else 
                      {
                        if (debugOn)
                          [self logWithFormat: @"EAS - Cache cleanup: CHANGE %@", uid];

                        // Update cache entry to make sure the change is sent again.
                        [syncCache setObject: @"0"  forKey: uid];
                      }
                  }
              }
          }

        return_count = 0;

        for (i = 0; i < max; i++)
          {
            pool = [[NSAutoreleasePool alloc] init];

            // Check for the WindowSize and slice accordingly
            if (return_count >= theWindowSize || (theMaxSyncResponseSize > 0 && [s length] >= theMaxSyncResponseSize))
              {
                more_available = YES;

                // -1 to make sure that we miss no event in case there are more with the same c_lastmodified
                *theLastServerKey = [[NSString alloc] initWithFormat: @"%d", [[component objectForKey: @"c_lastmodified"] intValue] - 1];

                DESTROY(pool);
                break;
              }

            component = [allComponents objectAtIndex: i];
            deleted = [[component objectForKey: @"c_deleted"] intValue];

            if (!deleted && ![[component objectForKey: @"c_component"] isEqualToString: component_name])
              {
                DESTROY(pool);
                continue;
              }
            
            uid = [[component objectForKey: @"c_name"] sanitizedServerIdWithType: theFolderType];
            
            if (deleted)
              {
                if ([syncCache objectForKey: uid])
                  {
                    [s appendString: @"<Delete xmlns=\"AirSync:\">"];
                    [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
                    [s appendString: @"</Delete>"];

                    [syncCache removeObjectForKey: uid];
                    [dateCache removeObjectForKey: uid];
                    return_count++;
                  }
              }
            else
              {
                updated = YES;
                
                if (![syncCache objectForKey: uid])
                  updated = NO;
                else if ([[component objectForKey: @"c_lastmodified"] intValue] == [[syncCache objectForKey: uid] intValue])
                  {
                    DESTROY(pool);
                    continue;
                  }
                
                return_count++;
                
	        sogoObject = [theCollection lookupName: [uid sanitizedServerIdWithType: theFolderType]
                                             inContext: context
                                               acquire: 0];
                
                if (theFolderType == ActiveSyncContactFolder)
                  componentObject = [sogoObject vCard];
                else
                  componentObject = [sogoObject component: NO  secure: NO];

                [syncCache setObject: [component objectForKey: @"c_lastmodified"] forKey: uid];

                // No need to set dateCache for Contacts
                if ((theFolderType == ActiveSyncEventFolder || theFolderType == ActiveSyncTaskFolder))
                  {
                    NSCalendarDate *d;

                    if ([[component objectForKey: @"c_cycleenddate"] intValue])
                      d = [NSCalendarDate dateWithTimeIntervalSince1970: [[component objectForKey: @"c_cycleenddate"] intValue]];
                    else if ([[component objectForKey: @"c_enddate"] intValue])
                      d = [NSCalendarDate dateWithTimeIntervalSince1970: [[component objectForKey: @"c_enddate"] intValue]];
                    else
                      d = [NSCalendarDate distantFuture];

                    [dateCache setObject: d forKey: uid];
                  }
                
                if (updated)
                  [s appendString: @"<Change xmlns=\"AirSync:\">"];
                else
                  [s appendString: @"<Add xmlns=\"AirSync:\">"];
                
                [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
                [s appendString: @"<ApplicationData xmlns=\"AirSync:\">"];
                
                [s appendString: [componentObject activeSyncRepresentationInContext: context]];
                
                [s appendString: @"</ApplicationData>"];
                
                if (updated)
                  [s appendString: @"</Change>"];
                else
                  [s appendString: @"</Add>"];

                return_count++;
              }

            DESTROY(pool);
          } // for (i = 0; i < max; i++) ...

        if (more_available)
          {
            [folderMetadata setObject: [NSNumber numberWithBool: YES]  forKey: @"MoreAvailable"];
            [folderMetadata setObject: *theLastServerKey  forKey: @"SyncKey"];
          }
        else
          {
            [folderMetadata removeObjectForKey: @"MoreAvailable"];
            [folderMetadata setObject: davCollectionTagToStore forKey: @"SyncKey"];
          }

        [self _setFolderMetadata: folderMetadata
                          forKey: [NSString stringWithFormat: @"%@/%@", component_name, [theCollection nameInContainer]]];

        RELEASE(*theLastServerKey);
      }
      break;
    case ActiveSyncMailFolder:
    default:
      {
        SOGoSyncCacheObject *lastCacheObject, *aCacheObject;
        NSMutableArray *allCacheObjects, *sortedBySequence;

        SOGoMailObject *mailObject;
        NSArray *allMessages, *a;
        NSString *firstUIDAdded;

        int j, k, return_count, highestmodseq;
        BOOL found_in_cache, initialLoadInProgress;

        initialLoadInProgress = NO;
        found_in_cache = NO;
        firstUIDAdded = nil;

        if ([theSyncKey isEqualToString: @"-1"])
          {
            highestmodseq = 0;

            a = [[theCollection davCollectionTag] componentsSeparatedByString: @"-"];
            [folderMetadata setObject: [a objectAtIndex: 1] forKey: @"InitialLoadSequence"];
          }
        else
         {
           a = [theSyncKey componentsSeparatedByString: @"-"];
           highestmodseq = [[a objectAtIndex: 1] intValue];
         }

        if ([folderMetadata objectForKey: @"InitialLoadSequence"])
          {
            if (highestmodseq < [[folderMetadata objectForKey: @"InitialLoadSequence"] intValue])
              initialLoadInProgress = YES;
            else
              [folderMetadata removeObjectForKey: @"InitialLoadSequence"];
          }

        allMessages = [theCollection syncTokenFieldsWithProperties: nil  matchingSyncToken: theSyncKey  fromDate: theFilterType  initialLoad: initialLoadInProgress];
        max = [allMessages count];
        
        allCacheObjects = [NSMutableArray array];
        
        for (i = 0; i < max; i++)
          {
            [allCacheObjects addObject: [SOGoSyncCacheObject syncCacheObjectWithUID: [[[allMessages objectAtIndex: i] allKeys] lastObject]
                                                                           sequence: [[[allMessages objectAtIndex: i] allValues] lastObject]]];
          }
        
        sortedBySequence = [[NSMutableArray alloc] initWithDictionary: syncCache];
        [sortedBySequence sortUsingSelector: @selector(compareSequence:)];
        [sortedBySequence autorelease];

        [allCacheObjects sortUsingSelector: @selector(compareSequence:)];

        if (debugOn)
          {
              [self logWithFormat: @"EAS - sortedBySequence (%d) - lastObject: %@", [sortedBySequence count], [sortedBySequence lastObject]];
              [self logWithFormat: @"EAS - allCacheObjects (%d) - lastObject: %@", [allCacheObjects count], [allCacheObjects lastObject]];
          }
              
        lastCacheObject = [sortedBySequence lastObject];

        //
        // Cleanup the mess
        //
        if (cleanup_needed)
          {
            NSMutableArray *sortedByUID;
            int uidnextFromCache;

            sortedByUID = [[NSMutableArray alloc] initWithDictionary: syncCache];
            [sortedByUID sortUsingSelector: @selector(compareUID:)];

            // Get the uid from SyncKey in cache. The uid is the first uid added to cache by the last sync request.
            a = [[folderMetadata objectForKey: @"SyncKey"] componentsSeparatedByString: @"-"];
            uidnextFromCache = [[a objectAtIndex: 0] intValue];

            if (debugOn)
              [self logWithFormat: @"EAS - Cache cleanup: from uid: %d to uid: %d", uidnextFromCache, [[[sortedByUID lastObject] uid] intValue]];

            // Remove all entries from cache beginning with the first uid added by the last sync request.
            for (j = uidnextFromCache; j <= [[[sortedByUID lastObject] uid] intValue]; j++)
              {
                if (debugOn)
                  [self logWithFormat: @"EAS - Cache cleanup: ADD %d", j];

                [syncCache removeObjectForKey: [NSString stringWithFormat:@"%d", j]];
                [dateCache removeObjectForKey: [NSString stringWithFormat:@"%d", j]];
              }

            RELEASE(sortedByUID);

            for (j = 0; j < [allCacheObjects count]; j++)
              {
                // Update the modseq in cache, sence othersie, it would be identical to the modseq from server
                //and we would skip the cache when generating the response.
                if ([syncCache objectForKey: [[allCacheObjects objectAtIndex: j] uid]] && ![[[allCacheObjects objectAtIndex: j] sequence] isEqual: [NSNull null]])
                  {
                    if (debugOn)
                      [self logWithFormat: @"EAS - Cache cleanup: CHANGE %@", [[allCacheObjects objectAtIndex: j] uid]];

                    [syncCache setObject: @"0"  forKey:[[allCacheObjects objectAtIndex: j] uid]];
                  }
                else if ([[[allCacheObjects objectAtIndex: j] sequence] isEqual: [NSNull null]])
                  {
                    if (debugOn)
                      [self logWithFormat: @"EAS - Cache cleanup: DELETE %@", [[allCacheObjects objectAtIndex: j] uid]];

                    // For deletes we have to recreate a cache entry to have the <Delete> included in the response.
                    [syncCache setObject: @"0"  forKey:[[allCacheObjects objectAtIndex: j] uid]];
                  }
              }
          }
        
        if (!cleanup_needed &&
            [folderMetadata objectForKey: @"MoreAvailable"] &&
            lastCacheObject && 
            !([[lastCacheObject sequence] isEqual: @"0"])) // Sequence 0 is set during cache cleanup.
          {
            for (j = 0; j < [allCacheObjects count]; j++)
              {
                if (([[[allCacheObjects objectAtIndex: j] sequence] isEqual: [NSNull null]] && [syncCache objectForKey: [[allCacheObjects objectAtIndex: j] uid]]) ||
                    (![[[allCacheObjects objectAtIndex: j] sequence] isEqual: [NSNull null]] && ![syncCache objectForKey: [[allCacheObjects objectAtIndex: j] uid]]))
                   {
                    // We need to continue with adds or deletes from here.
                    found_in_cache = YES;
                    j--;
                    break;
                  }

                if ([[lastCacheObject uid] isEqual: [[allCacheObjects objectAtIndex: j] uid]])
                  {
                    // Found out where we're at, let's continue from there...
                    found_in_cache = YES;
                    break;
                  }
              }
          }
        else
          found_in_cache = NO;

        if (found_in_cache)
          k = j+1;
        else
          j = k = 0;

        if (debugOn)
          [self logWithFormat: @"EAS - found in cache: %d  k = %d", found_in_cache, k];
        
        return_count = 0;
        
        for (; k < [allCacheObjects count]; k++)
          {
            pool = [[NSAutoreleasePool alloc] init];
            
            // Check for the WindowSize and slice accordingly
            if (return_count >= theWindowSize || (theMaxSyncResponseSize > 0 && [s length] >= theMaxSyncResponseSize))
              {
                NSString *lastSequence;
                more_available = YES;
                
                if (!firstUIDAdded)
                  {
                    a = [davCollectionTagToStore componentsSeparatedByString: @"-"];
                    firstUIDAdded = [a objectAtIndex: 0];
                    RETAIN(firstUIDAdded);
                  }
                lastSequence = ([[aCacheObject sequence] isEqual: [NSNull null]] ? [NSString stringWithFormat:@"%d", highestmodseq] : [aCacheObject sequence]);
                *theLastServerKey = [[NSString alloc] initWithFormat: @"%@-%@", firstUIDAdded, lastSequence];

                if (debugOn)
                  [self logWithFormat: @"EAS - Reached windowSize - lastUID will be: %@", *theLastServerKey];

                DESTROY(pool);
                break;
              }
            
            aCacheObject = [allCacheObjects objectAtIndex: k];

            if (debugOn)
              [self logWithFormat: @"EAS - Dealing with cacheObject: %@", aCacheObject];

            // If found in cache, it's either a Change or a Delete operation.
            if ([syncCache objectForKey: [aCacheObject uid]])
              {
                if ([[aCacheObject sequence] isEqual: [NSNull null]])
                  {
                    if (debugOn)
                      [self logWithFormat: @"EAS - DELETE!"];

                    // Deleted
                    [s appendString: @"<Delete xmlns=\"AirSync:\">"];
                    [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", [aCacheObject uid]];
                    [s appendString: @"</Delete>"];
                    
                    [syncCache removeObjectForKey: [aCacheObject uid]];
                    [dateCache removeObjectForKey: [aCacheObject uid]];

                    return_count++;
                  }
                else
                  {
                    // Changed
                  outlook_hack:
                    mailObject = [theCollection lookupName: [aCacheObject uid]
                                                 inContext: context
                                                   acquire: 0];

                    if (![[aCacheObject sequence] isEqual: [syncCache objectForKey: [aCacheObject uid]]])
                      {
                        if (debugOn)
                          [self logWithFormat: @"EAS - CHANGE!"];

                        [s appendString: @"<Change xmlns=\"AirSync:\">"];
                        [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", [aCacheObject uid]];
                        [s appendString: @"<ApplicationData xmlns=\"AirSync:\">"];
                        [s appendString: [mailObject activeSyncRepresentationInContext: context]];
                        [s appendString: @"</ApplicationData>"];
                        [s appendString: @"</Change>"];

                        return_count++;
                      }

                    [syncCache setObject: [aCacheObject sequence]  forKey: [aCacheObject uid]];
                  }
              }
            else
              {
                if (debugOn)
                  [self logWithFormat: @"EAS - ADD!"];

                // Added
                if (![[aCacheObject sequence] isEqual: [NSNull null]])
                  {
                    NSString *key;

                    // We check for Outlook stupidity to avoid creating duplicates - see the comment
                    // in SOGoActiveSyncDispatcher.m: -processMoveItems:inResponse: for more details.
                    key = [NSString stringWithFormat: @"%@+%@+%@+%@",
                                    [[context activeUser] login],
                               [context objectForKey: @"DeviceType"],
                                    [theCollection displayName],
                                    [aCacheObject uid]];
                    
                    if ([[SOGoCache sharedCache] valueForKey: key])
                      {
                        [[SOGoCache sharedCache] removeValueForKey: key];
                        goto outlook_hack;
                      }

                    mailObject = [theCollection lookupName: [aCacheObject uid]
                                                 inContext: context
                                                   acquire: 0];
                    
                    [s appendString: @"<Add xmlns=\"AirSync:\">"];
                    [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", [aCacheObject uid]];
                    [s appendString: @"<ApplicationData xmlns=\"AirSync:\">"];
                    [s appendString: [mailObject activeSyncRepresentationInContext: context]];
                    [s appendString: @"</ApplicationData>"];
                    [s appendString: @"</Add>"];
                    
                    [syncCache setObject: [aCacheObject sequence]  forKey: [aCacheObject uid]];
                    [dateCache setObject: [NSCalendarDate date]  forKey: [aCacheObject uid]];

                    // Save the frist UID we add. We will use it for the synckey late.
                    if (!firstUIDAdded)
                      {
                        firstUIDAdded = [aCacheObject uid];
                        RETAIN(firstUIDAdded);
                        if (debugOn)
                          [self logWithFormat: @"EAS - first uid added %@", firstUIDAdded];
                      }

                    return_count++;
                  }
                else
                  {
                    if (debugOn)
                      [self logWithFormat: @"EAS - skipping old deleted UID: %@",  [aCacheObject uid]];
                  }
              }

            DESTROY(pool);
          } // for (; k < ...)

        if (more_available)
          {
            [folderMetadata setObject: [NSNumber numberWithInt: YES]  forKey: @"MoreAvailable"];
            [folderMetadata setObject: *theLastServerKey  forKey: @"SyncKey"];
          }
        else
          {
            [folderMetadata removeObjectForKey: @"MoreAvailable"];

            if (firstUIDAdded)
              {
                a = [davCollectionTagToStore componentsSeparatedByString: @"-"];
                [folderMetadata setObject: [[NSString alloc] initWithFormat: @"%@-%@", firstUIDAdded, [a objectAtIndex: 1]] forKey: @"SyncKey"];
                RELEASE(firstUIDAdded);
              }
            else
              [folderMetadata setObject: davCollectionTagToStore forKey: @"SyncKey"];
          }
        
        [self _setFolderMetadata: folderMetadata forKey: [self _getNameInCache: theCollection withType: theFolderType]];

        RELEASE(*theLastServerKey);
        
      } // default:
      break;
    } // switch (folderType) ...
  
 return_response:
  
  if ([s length])
    {
      [theBuffer appendString: @"<Commands>"];
      [theBuffer appendString: s];
      [theBuffer appendString: @"</Commands>"];
    }
}

//
// We have something like this:
//
// <Commands>
//  <Fetch>
//   <ServerId>91</ServerId>
//  </Fetch>
// </Commands>
//
- (void) processSyncCommands: (id <DOMElement>) theDocumentElement
                inCollection: (id) theCollection
                    withType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
                    inBuffer: (NSMutableString *) theBuffer
                   processed: (BOOL *) processed
{
  id <DOMNodeList> aCommandDetails;
  id <DOMElement> aCommand, element;
  NSArray *allCommands;
  int i, j;
  int commandCount, detailCount;
  NSAutoreleasePool *pool;

  allCommands = (id)[theDocumentElement getElementsByTagName: @"Commands"];

  commandCount = [allCommands count];

  for (i = 0; i < commandCount; i++)
    {
      aCommand = [allCommands objectAtIndex: i];
      aCommandDetails = [aCommand childNodes];

      detailCount = [(id)aCommandDetails count];

      for (j = 0; j < detailCount; j++)
        {
          pool = [[NSAutoreleasePool alloc] init];

          element = [aCommandDetails objectAtIndex: j];

          if ([element nodeType] == DOM_ELEMENT_NODE)
            {
              if ([[element tagName] isEqualToString: @"Add"])
                {
                  // Add
                  [self processSyncAddCommand: element
                                 inCollection: theCollection
                                     withType: theFolderType
                                     inBuffer: theBuffer];
                  *processed = YES;
                }
              else if ([[element tagName] isEqualToString: @"Change"])
                {
                  // Change
                  [self processSyncChangeCommand: element
                                    inCollection: theCollection
                                        withType: theFolderType
                                        inBuffer: theBuffer];
                  *processed = YES;
                }
              else if ([[element tagName] isEqualToString: @"Delete"])
                {
                  // Delete
                  [self processSyncDeleteCommand: element
                                    inCollection: theCollection
                                        withType: theFolderType
                                        inBuffer: theBuffer];
                  *processed = YES;
                }
              else if ([[element tagName] isEqualToString: @"Fetch"])
                {
                  // Fetch
                  [self processSyncFetchCommand: element
                                   inCollection: theCollection
                                       withType: theFolderType
                                       inBuffer: theBuffer];
                  *processed = YES;
                }
            }
          DESTROY(pool);
       }
    }
}

//
//
//
- (void) processSyncCollection: (id <DOMElement>) theDocumentElement
                      inBuffer: (NSMutableString *) theBuffer
                changeDetected: (BOOL *) changeDetected
           maxSyncResponseSize: (int) theMaxSyncResponseSize
{
  NSString *collectionId, *realCollectionId, *syncKey, *davCollectionTag, *bodyPreferenceType, *mimeSupport, *lastServerKey, *syncKeyInCache, *folderKey;
  NSMutableDictionary *folderMetadata, *folderOptions;
  NSMutableArray *supportedElements, *supportedElementNames;
  NSMutableString *changeBuffer, *commandsBuffer;
  id collection, value;

  SOGoMicrosoftActiveSyncFolderType folderType;
  unsigned int windowSize, v, status, i;
  BOOL getChanges, first_sync;

  changeBuffer = [NSMutableString string];
  commandsBuffer = [NSMutableString string];
  
  collectionId = [[(id)[theDocumentElement getElementsByTagName: @"CollectionId"] lastObject] textValue];
  realCollectionId = [collectionId realCollectionIdWithFolderType: &folderType];
  realCollectionId = [self globallyUniqueIDToIMAPFolderName: realCollectionId  type: folderType];
  collection = [self collectionFromId: realCollectionId  type: folderType];
  
  syncKey = davCollectionTag = [[(id)[theDocumentElement getElementsByTagName: @"SyncKey"] lastObject] textValue];

  if (collection == nil)
    {
      // Collection not found - next folderSync will do the cleanup
      //NSLog(@"Sync Collection not found %@ %@", collectionId, realCollectionId);
      //Outlook doesn't like following response
      //[theBuffer appendString: @"<Collection>"];
      //[theBuffer appendFormat: @"<SyncKey>%@</SyncKey>", syncKey];
      //[theBuffer appendFormat: @"<CollectionId>%@</CollectionId>", collectionId];
      //[theBuffer appendFormat: @"<Status>%d</Status>", 8];
      //[theBuffer appendString: @"</Collection>"];
      return;
    }

  //
  // First check if we have any concurrent Sync requests going on for this device.
  // If we do and we are still within our maximumSyncInterval, we let our EAS
  // device know to retry.
  //
  folderKey = [self _getNameInCache: collection withType: folderType];
  folderMetadata = [self _folderMetadataForKey: folderKey];

  // We check for a window size, default to 100 if not specfied or out of bounds
  windowSize = [[[(id)[theDocumentElement getElementsByTagName: @"WindowSize"] lastObject] textValue] intValue];
  
  if (windowSize == 0 || windowSize > 512)
    windowSize = 100;
  
  // We check if we must overwrite the windowSize with a system preference. This can be useful
  // if the user population has large mailboxes and slow connectivity
  if ((v = [[SOGoSystemDefaults sharedSystemDefaults] maximumSyncWindowSize]))
    windowSize = v;

  lastServerKey = nil;
  status = 1;
  
  // From the documention, if GetChanges is missing, we must assume it's a YES.
  // See http://msdn.microsoft.com/en-us/library/gg675447(v=exchg.80).aspx for all details.
  value = [theDocumentElement getElementsByTagName: @"GetChanges"];
  getChanges = YES;

  if ([value count] && [[[value lastObject] textValue] length])
    getChanges = [[[value lastObject] textValue] boolValue];
                  
  first_sync = NO;

  if ([syncKey isEqualToString: @"0"])
    {
      davCollectionTag = @"-1";
      first_sync = YES;
      *changeDetected = YES;

      supportedElementNames = [[[NSMutableArray alloc] init] autorelease];
      value = [theDocumentElement getElementsByTagName: @"Supported"];

      if ([value count])
        {
          supportedElements = (id)[[value lastObject] childNodes];

          if ([supportedElements count])
            {
              for (i = 0; i < [supportedElements count]; i++)
                {
                if ([[supportedElements objectAtIndex: i] nodeType] == DOM_ELEMENT_NODE)
                  [supportedElementNames addObject: [[supportedElements objectAtIndex: i] tagName]];
                }
            }

          [folderMetadata setObject: supportedElementNames forKey: @"SupportedElements"];

          [self _setFolderMetadata: folderMetadata forKey: folderKey];

          if (debugOn)
            [self logWithFormat: @"EAS - %d %@: supportedElements saved: %@", [supportedElements count], [collection nameInContainer], supportedElementNames];
        }
    }
  else if ((![syncKey isEqualToString: @"-1"]) && !([folderMetadata objectForKey: @"SyncCache"]))
    {
      //NSLog(@"Reset folder: %@", [collection nameInContainer]);
      davCollectionTag = @"0";
      first_sync = YES;
      *changeDetected = YES;
      
      if (!([folderMetadata objectForKey: @"displayName"]))
        status = 12;  // need folderSync
      else 
        status = 3;   // do a complete resync 
    }

  // We check our sync preferences and we stash them
  bodyPreferenceType = [[(id)[[(id)[theDocumentElement getElementsByTagName: @"BodyPreference"] lastObject] getElementsByTagName: @"Type"] lastObject] textValue];

  if (!bodyPreferenceType)
   {
     bodyPreferenceType = [[folderMetadata objectForKey: @"FolderOptions"] objectForKey: @"BodyPreferenceType"];

     // By default, send MIME mails. See #3146 for details.
     if (!bodyPreferenceType)
       bodyPreferenceType = @"4";

     mimeSupport = [[folderMetadata objectForKey: @"FolderOptions"] objectForKey: @"MIMESupport"];

     if (!mimeSupport)
       mimeSupport = @"1";
   }
  else
   {
     mimeSupport = [[(id)[theDocumentElement getElementsByTagName: @"MIMESupport"] lastObject] textValue];

     if (!mimeSupport)
        mimeSupport = [[folderMetadata objectForKey: @"FolderOptions"] objectForKey: @"MIMESupport"];

     if (!mimeSupport)
        mimeSupport = @"0";

     if ([mimeSupport isEqualToString: @"1"] && [bodyPreferenceType isEqualToString: @"4"])
        bodyPreferenceType = @"2";
     else if ([mimeSupport isEqualToString: @"2"] && [bodyPreferenceType isEqualToString: @"4"])
        bodyPreferenceType = @"4";
     else if ([mimeSupport isEqualToString: @"0"] && [bodyPreferenceType isEqualToString: @"4"])
        bodyPreferenceType = @"2";


     // Avoid writing to cache if there is nothing to change.
     if (![[[folderMetadata objectForKey: @"FolderOptions"] objectForKey: @"BodyPreferenceType"] isEqualToString: bodyPreferenceType] ||
         ![[[folderMetadata objectForKey: @"FolderOptions"] objectForKey: @"MIMESupport"] isEqualToString: mimeSupport])
       {
         folderOptions = [[NSDictionary alloc] initWithObjectsAndKeys: mimeSupport, @"MIMESupport", bodyPreferenceType, @"BodyPreferenceType", nil];
         [folderMetadata setObject: folderOptions forKey: @"FolderOptions"];
         [self _setFolderMetadata: folderMetadata forKey: folderKey];
       }
   }
  
  [context setObject: bodyPreferenceType  forKey: @"BodyPreferenceType"];
  [context setObject: mimeSupport  forKey: @"MIMESupport"];
  [context setObject: [folderMetadata objectForKey: @"SupportedElements"]  forKey: @"SupportedElements"];

  //
  // We process the commands from the request
  //
  if (!first_sync)
    {
      NSMutableString *s;
      BOOL processed;

      s = [NSMutableString string];
      processed = NO;

      [self processSyncCommands: theDocumentElement
                   inCollection: collection
                       withType: folderType
                       inBuffer: s
                      processed: &processed];

      // Windows phones don't like empty Responses tags - such as: <Responses></Responses>.
      // We only generate this tag when there is a response
      if (processed && [s length])
        [commandsBuffer appendFormat: @"<Responses>%@</Responses>", s];
    }


  // We generate the commands, if any, for the response. We might also have
  // generated some in processSyncCommand:inResponse: as we could have
  // received a Fetch command
  if (getChanges && !first_sync)
    {
      [self processSyncGetChanges: theDocumentElement
                     inCollection: collection
                   withWindowSize: windowSize
          withMaxSyncResponseSize: theMaxSyncResponseSize
                      withSyncKey: syncKey
                   withFolderType: folderType
                   withFilterType: [NSCalendarDate dateFromFilterType: [[(id)[theDocumentElement getElementsByTagName: @"FilterType"] lastObject] textValue]]
                         inBuffer: changeBuffer
                    lastServerKey: &lastServerKey
                  defaultInterval: [[SOGoSystemDefaults sharedSystemDefaults] maximumSyncInterval]];
    }

  folderMetadata = [self _folderMetadataForKey: folderKey];

  // If we got any changes or if we have applied any commands
  // let's regenerate our SyncKey based on the collection tag.
  if ([changeBuffer length] || [commandsBuffer length])
    {
      if (lastServerKey)
        davCollectionTag = lastServerKey;
      else
        {
          // Use the SyncKey saved by processSyncGetChanges - if processSyncGetChanges is not called (because of getChanges=false)
          // SyncKey has the value of the previous sync operation.
          davCollectionTag = [folderMetadata objectForKey: @"SyncKey"];
          
          if (!davCollectionTag)
            davCollectionTag = [collection davCollectionTag];
        }
      
      *changeDetected = YES;
    }
  else
    {
      // Make sure that client is updated with the right syncKey. - This keeps vtodo's and vevent's syncKey in sync.
      syncKeyInCache = [folderMetadata  objectForKey: @"SyncKey"];
      if (syncKeyInCache && !([davCollectionTag isEqualToString:syncKeyInCache]) && !first_sync)
        {
          davCollectionTag = syncKeyInCache;
          *changeDetected = YES;
        }
    }

  // Generate the response buffer
  [theBuffer appendString: @"<Collection>"];
  
  if (folderType == ActiveSyncMailFolder)
    [theBuffer appendString: @"<Class>Email</Class>"];
  else if (folderType == ActiveSyncContactFolder)
    [theBuffer appendString: @"<Class>Contacts</Class>"];
  else if (folderType == ActiveSyncEventFolder)
    [theBuffer appendString: @"<Class>Calendar</Class>"];
  else if (folderType == ActiveSyncTaskFolder)
    [theBuffer appendString: @"<Class>Tasks</Class>"];
  
  [theBuffer appendFormat: @"<SyncKey>%@</SyncKey>", davCollectionTag];
  [theBuffer appendFormat: @"<CollectionId>%@</CollectionId>", collectionId];
  [theBuffer appendFormat: @"<Status>%d</Status>", status];

  // MoreAvailable breaks Windows Mobile devices if not between <Status> and <Commands>
  // https://social.msdn.microsoft.com/Forums/en-US/040b254e-f47e-4cc1-a397-6d8393cdb819/airsyncmoreavailable-breaks-windows-mobile-devices-what-am-i-doing-wrong?forum=os_exchangeprotocols
  if ([folderMetadata objectForKey: @"MoreAvailable"])
    [theBuffer appendString: @"<MoreAvailable/>"];

  [theBuffer appendString: commandsBuffer];
  [theBuffer appendString: changeBuffer];

  [theBuffer appendString: @"</Collection>"];
}

//
// Initial folder sync:
//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Sync xmlns="AirSync:">
//  <Collections>
//   <Collection>
//    <SyncKey>0</SyncKey>
//    <CollectionId>folderINBOX</CollectionId>
//   </Collection>
//  </Collections>
// </Sync>
//
//
// Following this will be a GetItemEstimate call. Following our response to the GetItemEstimate, we'll
// have a new Sync call like this:
//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Sync xmlns="AirSync:">
//  <Collections>
//   <Collection>
//    <SyncKey>1</SyncKey>
//    <CollectionId>folderINBOX</CollectionId>
//    <DeletesAsMoves>1</DeletesAsMoves>
//    <GetChanges/>
//    <WindowSize>50</WindowSize>
//    <Options>
//     <FilterType>5</FilterType>                                           -- http://msdn.microsoft.com/en-us/library/gg709713(v=exchg.80).aspx
//     <BodyPreference xmlns="AirSyncBase:">                                -- http://msdn.microsoft.com/en-us/library/ee218197(v=exchg.80).aspx
//      <Type>2</Type>                                                      -- 
//      <TruncationSize>51200</TruncationSize>
//     </BodyPreference>
//     <BodyPreference xmlns="AirSyncBase:">
//      <Type>4</Type>
//     </BodyPreference>
//    </Options>
//   </Collection>
//  </Collections>
// </Sync>
//
//
//
// When adding a new task, we might have something like this:
//
// <?xml version="1.0"?>
// <!DOCTYPE ActiveSync PUBLIC "-//MICROSOFT//DTD ActiveSync//EN" "http://www.microsoft.com/">
// <Sync xmlns="AirSync:">
//  <Collections>
//   <Collection>
//    <SyncKey>1</SyncKey>
//    <CollectionId>personal</CollectionId>
//    <DeletesAsMoves/>
//    <GetChanges/>                                                        -- http://msdn.microsoft.com/en-us/library/gg675447(v=exchg.80).aspx
//    <WindowSize>5</WindowSize>                                           -- http://msdn.microsoft.com/en-us/library/gg650865(v=exchg.80).aspx
//    <Options>
//     <BodyPreference xmlns="AirSyncBase:">                               -- http://msdn.microsoft.com/en-us/library/ee218197(v=exchg.80).aspx
//      <Type>1</Type>
//      <TruncationSize>400000</TruncationSize>
//     </BodyPreference>
//    </Options>
//    <Commands>
//     <Add>
//      <ClientId>new_task_1386614771261</ClientId>
//      <ApplicationData>
//       <Body xmlns="AirSyncBase:">
//        <Type>1</Type>
//        <EstimatedDataSize>6</EstimatedDataSize>
//        <Data>tomate</Data>
//       </Body>
//       <Subject xmlns="Tasks:">test 1</Subject>
//       <Importance xmlns="Tasks:">1</Importance>
//       <UTCDueDate xmlns="Tasks:">2013-12-09T19:00:00.000Z</UTCDueDate>
//       <Complete xmlns="Tasks:">0</Complete>
//       <ReminderSet xmlns="Tasks:">0</ReminderSet>
//       <DueDate xmlns="Tasks:">2013-12-09T19:00:00.000Z</DueDate>
//      </ApplicationData>
//     </Add>
//    </Commands>
//   </Collection>
//  </Collections>
// </Sync>
//
// The algorithm here is pretty simple:
//
// 1. extract the list of collections
// 2. for each collection
//  2.1. extract the metadata (id, synckey, etc.)
//  2.2. extract the list of commands
//  2.3. for each command
//   2.3.1 process the command (add/change/delete/fetch)
//   2.3.2 build a response during the processsing
// 
//
- (void) processSync: (id <DOMElement>) theDocumentElement
          inResponse: (WOResponse *) theResponse
{
  SOGoSystemDefaults *defaults;
  id <DOMElement> aCollection;
  NSMutableString *output, *s;
  NSMutableDictionary *globalMetadata;
  NSNumber *syncRequestInCache, *processIdentifier;
  NSString *key;
  NSArray *allCollections;
  NSData *d;

  int i, j, defaultInterval, heartbeatInterval, internalInterval, maxSyncResponseSize, total_sleep;
  BOOL changeDetected;
  
  // We initialize our output buffer
  output = [[NSMutableString alloc] init];

  defaults = [SOGoSystemDefaults sharedSystemDefaults];
  defaultInterval = [defaults maximumSyncInterval];
  processIdentifier = [NSNumber numberWithInt: [[NSProcessInfo processInfo] processIdentifier]];

  allCollections = (id)[theDocumentElement getElementsByTagName: @"Collection"];

  [output appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [output appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [output appendString: @"<Sync xmlns=\"AirSync:\">"];

  //
  // We don't support yet empty Sync requests. See: http://msdn.microsoft.com/en-us/library/ee203280(v=exchg.80).aspx
  // We return '13' - see http://msdn.microsoft.com/en-us/library/gg675457(v=exchg.80).aspx
  //
  if (!theDocumentElement || [[(id)[theDocumentElement getElementsByTagName: @"Partial"] lastObject] textValue])
    {
      [output appendString: @"<Status>13</Status>"];
      [output appendString: @"</Sync>"];
      d = [[output dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];
      [theResponse setContent: d];
      RELEASE(output);
      return;
    }

  // Let other requests know about the collections we are dealing with.
  [self _setOrUnsetSyncRequest: YES  collections: allCollections];
  
  changeDetected = NO;
  maxSyncResponseSize = [[SOGoSystemDefaults sharedSystemDefaults] maximumSyncResponseSize];
  heartbeatInterval = [[[(id)[theDocumentElement getElementsByTagName: @"HeartbeatInterval"] lastObject] textValue] intValue];
  internalInterval = [defaults internalSyncInterval];

  // If the request doesn't contain "HeartbeatInterval" there is no reason to delay the response.
  if (heartbeatInterval == 0)
     heartbeatInterval = internalInterval = 1;

  // We check to see if our heartbeat interval falls into the supported ranges.
  if (heartbeatInterval > defaultInterval || heartbeatInterval < 1)
    {
      int limit;
      // Interval is too long, inform the client.
      heartbeatInterval = defaultInterval;

      // When Status = 14, the Wait interval is specified in minutes while
      // defaultInterval is specifed in seconds. Adjust accordinlgy.
      limit = defaultInterval/60;
      if (limit < 1)  limit = 1;
      if (limit > 59)  limit = 59;
      //[output appendFormat: @"<Limit>%d</Limit>", limit];
      //[output appendFormat: @"<Status>%d</Status>", 14];
    }

  [output appendString: @"<Collections>"];

  // We enter our loop detection change
  for (i = 0; i < (heartbeatInterval/internalInterval); i++)
    {
      s = [NSMutableString string];

      for (j = 0; j < [allCollections count]; j++)
        {
          aCollection = [allCollections objectAtIndex: j];

          [self processSyncCollection: aCollection
                             inBuffer: s
                       changeDetected: &changeDetected
                  maxSyncResponseSize: maxSyncResponseSize];

          // Don't return a response if another Sync is waiting.
          globalMetadata = [self globalMetadataForDevice];
          key = [NSString stringWithFormat: @"SyncRequest+%@", [[[(id)[aCollection getElementsByTagName: @"CollectionId"] lastObject] textValue] stringByUnescapingURL]];

          if (!([[globalMetadata objectForKey: key] isEqual: processIdentifier]))
            {
              if (debugOn)
                [self logWithFormat: @"EAS - Discard response %@", [self globalMetadataForDevice]];

              [theResponse setStatus: 503];

              RELEASE(output);
              return;
            }

          if ((maxSyncResponseSize > 0 && [s length] >= maxSyncResponseSize))
            break;
        }

      if (changeDetected)
        {
          [self logWithFormat: @"Change detected during Sync, we push the content."];
          break;
        }
      else if (heartbeatInterval > 1)
        {
          total_sleep = 0;

          while (total_sleep < internalInterval)
            {
              // We check if we must break the current synchronization since an other Sync
              // has just arrived.
              syncRequestInCache = [[self globalMetadataForDevice] objectForKey: @"SyncRequest"];
              if (!([syncRequest isEqualToNumber: syncRequestInCache]))
                {
                  if (debugOn)
                    [self logWithFormat: @"EAS - Heartbeat stopped %@", [self globalMetadataForDevice]];

                  // Make sure we end the heardbeat-loop.
                  heartbeatInterval = internalInterval = 1;

                  break;
                }
              else
                {
                  [self logWithFormat: @"Sleeping %d seconds while detecting changes in Sync...", internalInterval-total_sleep];
                  sleep(5);
                  total_sleep += 5;
                }
            }
        }
      else
        {
          break;
        }
    }

  //
  // Only send a response if there are changes or MS-ASProtocolVersion is either 2.5 or 12.0,
  // otherwise send an empty response.
  //
  if (changeDetected || [[[context request] headerForKey: @"MS-ASProtocolVersion"] isEqualToString: @"2.5"] || [[[context request] headerForKey: @"MS-ASProtocolVersion"] isEqualToString: @"12.0"])
    {
      // We always return the last generated response.
      // If we only return <Sync><Collections/></Sync>,
      // iOS powered devices will simply crash.
      [output appendString: s];

      [output appendString: @"</Collections></Sync>"];

      d = [output dataUsingEncoding: NSUTF8StringEncoding];
      d = [d xml2wbxml];
      [theResponse setContent: d];
    }

  // Avoid overloading the autorelease pool here, as Sync command can
  // generate fairly large responses.
  RELEASE(output);
}

@end
