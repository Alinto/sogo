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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoApplication.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOCookie.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>


#import <NGCards/iCalEntityObject.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/NGVCard.h>


#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSString+misc.h>

#import <NGImap4/NSString+Imap4.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMail/NGMimeMessageParser.h>
#import <NGMail/NGMimeMessage.h>
#import <NGMail/NGMimeMessageGenerator.h>

#import <DOM/DOMElement.h>
#import <DOM/DOMProtocols.h>

#import <EOControl/EOQualifier.h>

#import <SOGo/NSArray+DAV.h>
#import <SOGo/NSDictionary+DAV.h>
#import <SOGo/SOGoDAVAuthenticator.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

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
#import <Mailer/SOGoMailObject.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#include "iCalEvent+ActiveSync.h"
#include "iCalToDo+ActiveSync.h"
#include "NGDOMElement+ActiveSync.h"
#include "NGVCard+ActiveSync.h"
#include "NSData+ActiveSync.h"
#include "NSString+ActiveSync.h"
#include "SOGoActiveSyncConstants.h"
#include "SOGoMailObject+ActiveSync.h"

@implementation SOGoActiveSyncDispatcher (Sync)

- (id) collectionFromId: (NSString *) theCollectionId
                   type: (SOGoMicrosoftActiveSyncFolderType) theFolderType
{
  id collection;

  collection = nil;

  switch (theFolderType)
    {
    case ActiveSyncContactFolder:
      {
        collection = [[context activeUser] personalContactsFolderInContext: context];
      }
      break;
    case ActiveSyncEventFolder:
    case ActiveSyncTaskFolder:
      {
        collection = [[context activeUser] personalCalendarFolderInContext: context];
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
      }
    }

  return collection;
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
  NSMutableDictionary *allValues;
  NSString *clientId, *serverId;
  NSArray *additions;
  
  id anAddition, sogoObject, o;
  int i;

  additions = (id)[theDocumentElement getElementsByTagName: @"Add"];
                
  if ([additions count])
    {
      for (i = 0; i < [additions count]; i++)
        {
          anAddition = [additions objectAtIndex: i];

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
                serverId = [NSString stringWithFormat: @"%@.ics", [theCollection globallyUniqueObjectId]];
                sogoObject = [[SOGoAppointmentObject alloc] initWithName: serverId
                                                             inContainer: theCollection];
                [allValues setObject: [[[context activeUser] userDefaults] timeZone]  forKey: @"SOGoUserTimeZone"];
                o = [sogoObject component: YES secure: NO];
              }
              break;
            case ActiveSyncTaskFolder:
              {
                serverId = [NSString stringWithFormat: @"%@.ics", [theCollection globallyUniqueObjectId]];
                sogoObject = [[SOGoTaskObject alloc] initWithName: serverId
                                                      inContainer: theCollection];
                [allValues setObject: [[[context activeUser] userDefaults] timeZone]  forKey: @"SOGoUserTimeZone"];
                o = [sogoObject component: YES secure: NO];     
              }
              break;
            case ActiveSyncMailFolder:
            default:
              {
                // FIXME
                continue;
              }
            }
          
          [o takeActiveSyncValues: allValues];
          [sogoObject saveComponent: o];
          
          // Everything is fine, lets generate our response
          [theBuffer appendString: @"<Add>"];
          [theBuffer appendFormat: @"<ClientId>%@</ClientId>", clientId];
          [theBuffer appendFormat: @"<ServerId>%@</ServerId>", serverId];
          [theBuffer appendFormat: @"<Status>%d</Status>", 1];
          [theBuffer appendString: @"</Add>"];
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

  int i;

  changes = (id)[theDocumentElement getElementsByTagName: @"Change"];

  if ([changes count])
    {
      for (i = 0; i < [changes count]; i++)
        {
          aChange = [changes objectAtIndex: i];
          
          serverId = [[(id)[aChange getElementsByTagName: @"ServerId"] lastObject] textValue];
          allChanges = [[(id)[aChange getElementsByTagName: @"ApplicationData"]  lastObject] applicationData];

          // Fetch the object and apply the changes
          sogoObject = [theCollection lookupName: serverId
                                       inContext: context
                                         acquire: NO];

          switch (theFolderType)
            {
            case ActiveSyncContactFolder:
              {
                o = [sogoObject vCard];
                [o takeActiveSyncValues: allChanges];
                [sogoObject saveComponent: o];
              }
              break;
            case ActiveSyncEventFolder:
            case ActiveSyncTaskFolder:
              {
                o = [sogoObject component: NO  secure: NO];
                [o takeActiveSyncValues: allChanges];
                [sogoObject saveComponent: o];
              }
              break;
            case ActiveSyncMailFolder:
            default:
              {
                [sogoObject takeActiveSyncValues: allChanges];
              }
            }

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
  NSArray *deletions;
  NSString *serverId;

  id aDelete, sogoObject;
  int i;

  deletions = (id)[theDocumentElement getElementsByTagName: @"Delete"];

  if ([deletions count])
    {
      for (i = 0; i < [deletions count]; i++)
        {
          aDelete = [deletions objectAtIndex: i];
          
          serverId = [[(id)[aDelete getElementsByTagName: @"ServerId"] lastObject] textValue];
          
          sogoObject = [theCollection lookupName: serverId
                                       inContext: context
                                         acquire: NO];

          [sogoObject delete];
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

  o = [theCollection lookupName: serverId
                      inContext: context
                        acquire: NO];
  
  // FIXME - error handling
  [theBuffer appendString: @"<Fetch>"];
  [theBuffer appendFormat: @"<ServerId>%@</ServerId>", serverId];
  [theBuffer appendFormat: @"<Status>%d</Status>", 1];
  [theBuffer appendString: @"<ApplicationData>"];
  [theBuffer appendString: [o activeSyncRepresentation]];
  [theBuffer appendString: @"</ApplicationData>"];
  [theBuffer appendString: @"</Fetch>"];
}


//
// The method handles <GetChanges/>
//
- (void) processSyncGetChanges: (id <DOMElement>) theDocumentElement
                  inCollection: (id) theCollection
                   withSyncKey: (NSString *) theSyncKey
                      withType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
                      inBuffer: (NSMutableString *) theBuffer
{
  int i;

  //
  // No changes in the collection - 2.2.2.19.1.1 Empty Sync Request.
  // We check this and we don't generate any commands if we don't have to.
  //
  if ([theSyncKey isEqualToString: [theCollection davCollectionTag]])
    return;
  
  [theBuffer appendString: @"<Commands>"];
  
  switch (theFolderType)
    {
    case ActiveSyncContactFolder:
      {
        NSArray *allContacts;
        NGVCard *card;
        id contact;
        
        allContacts = [theCollection syncTokenFieldsWithProperties: nil   matchingSyncToken: theSyncKey];
        
        for (i = 0; i < [allContacts count]; i++)
          {                
            contact = [theCollection lookupName: [[allContacts objectAtIndex: i] objectForKey: @"c_name"]
                                      inContext: context
                                        acquire: NO];
            
            if (![[[allContacts objectAtIndex: i] objectForKey: @"c_component"] isEqualToString: @"vcard"])
              continue;
            
            // FIXME: we skip list right now
            if ([contact respondsToSelector: @selector (vCard)])
              {
                card = [contact vCard];
                
                [theBuffer appendString: @"<Add xmlns=\"AirSync:\">"];
                [theBuffer appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", [contact nameInContainer]];
                [theBuffer appendString: @"<ApplicationData xmlns=\"AirSync:\">"];
                
                [theBuffer appendString: [card activeSyncRepresentation]];
                
                [theBuffer appendString: @"</ApplicationData>"];
                [theBuffer appendString: @"</Add>"];
              }
          }
      }
      break;
    case ActiveSyncEventFolder:
      {
        NSArray *allEvents;
        NSDictionary *d;
        id eventObject;

        allEvents = [theCollection syncTokenFieldsWithProperties: nil   matchingSyncToken: theSyncKey];
        
        for (i = 0; i < [allEvents count]; i++)
          {
            NSString *serverId;
            iCalEvent *event;
            
            d = [allEvents objectAtIndex: i];
            
            if (![[d objectForKey: @"c_component"] isEqualToString: @"vevent"])
              continue;
            
            serverId =  [d objectForKey: @"c_name"];
            
            [theBuffer appendString: @"<Add xmlns=\"AirSync:\">"];
            [theBuffer appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", serverId];
            [theBuffer appendString: @"<ApplicationData xmlns=\"AirSync:\">"];
            
            eventObject = [theCollection lookupName: serverId  inContext: self->context  acquire: 0];
            
            event = [eventObject component: NO  secure: NO];
            
            [theBuffer appendString: [event activeSyncRepresentation]];
            
            [theBuffer appendString: @"</ApplicationData>"];
            [theBuffer appendString: @"</Add>"];
            
          } // for (i = 0; i < [allEvents count]; i++)
      }
      break;
    case ActiveSyncTaskFolder:
      {
        NSArray *allTasks;
        NSDictionary *task;
        id taskObject;
        
        allTasks = [theCollection syncTokenFieldsWithProperties: nil   matchingSyncToken: theSyncKey];
        
        for (i = 0; i < [allTasks count]; i++)
                    
          {
            int deleted;
            
            task = [allTasks objectAtIndex: i];
            deleted = [[task objectForKey: @"c_deleted"] intValue];

            if (!deleted && ![[task objectForKey: @"c_component"] isEqualToString: @"vtodo"])
              continue;
            
            NSString *uid;
            uid = [task objectForKey: @"c_name"];
            
            if (deleted)
              {
                [theBuffer appendString: @"<Delete xmlns=\"AirSync:\">"];
                [theBuffer appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
                [theBuffer appendString: @"</Delete>"];
              }
            else
              {
                iCalToDo *todo;
                BOOL updated;
                
                updated = YES;
                
                if ([[task objectForKey: @"c_creationdate"] intValue] > [theSyncKey intValue])
                  updated = NO;
                
                if (updated)
                  [theBuffer appendString: @"<Change xmlns=\"AirSync:\">"];
                else
                  [theBuffer appendString: @"<Add xmlns=\"AirSync:\">"];
                
                [theBuffer appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
                [theBuffer appendString: @"<ApplicationData xmlns=\"AirSync:\">"];
                
                taskObject = [theCollection lookupName: uid  inContext: self->context  acquire: 0];
                
                todo = [taskObject component: NO  secure: NO];
                
                [theBuffer appendString: [todo activeSyncRepresentation]];
                
                [theBuffer appendString: @"</ApplicationData>"];
                
                if (updated)
                  [theBuffer appendString: @"</Change>"];
                else
                  [theBuffer appendString: @"</Add>"];
              }
          } // for ...
      }
      break;
    case ActiveSyncMailFolder:
    default:
      {
        NSDictionary *aMessage;
        NSArray *allMessages;
        NSString *uid, *command;
        SOGoMailObject *mailObject;
        
        allMessages = [theCollection syncTokenFieldsWithProperties: nil   matchingSyncToken: theSyncKey];
        
        for (i = 0; i < [allMessages count]; i++)
          {
            aMessage = [allMessages objectAtIndex: i];
            
            uid = [[[aMessage allKeys] lastObject] stringValue];
            command = [[aMessage allValues] lastObject];
            
            if ([command isEqualToString: @"deleted"])
              {
                [theBuffer appendString: @"<Delete xmlns=\"AirSync:\">"];
                [theBuffer appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
                [theBuffer appendString: @"</Delete>"];
              }
            else
              {
                if ([command isEqualToString: @"added"])
                  [theBuffer appendString: @"<Add xmlns=\"AirSync:\">"];
                else
                  [theBuffer appendString: @"<Change xmlns=\"AirSync:\">"];

                mailObject = [theCollection lookupName: uid
                                             inContext: context
                                               acquire: 0];

                [theBuffer appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
                [theBuffer appendString: @"<ApplicationData xmlns=\"AirSync:\">"];
                [theBuffer appendString: [mailObject activeSyncRepresentation]];
                [theBuffer appendString: @"</ApplicationData>"];
                
                if ([command isEqualToString: @"added"])
                  [theBuffer appendString: @"</Add>"];
                else
                  [theBuffer appendString: @"</Change>"];

              }
          }
      }
      break;
    } // switch (folderType) ...
  
  [theBuffer appendString: @"</Commands>"];
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

  allCommands = (id)[theDocumentElement getElementsByTagName: @"Commands"];
  
  for (i = 0; i < [allCommands count]; i++)
    {
      aCommand = [allCommands objectAtIndex: i];
      aCommandDetails = [aCommand childNodes];

      for (j = 0; j < [(id)aCommandDetails count]; j++)
        {
          element = [aCommandDetails objectAtIndex: j];

          if ([element nodeType] == DOM_ELEMENT_NODE)
            {
              if ([[element tagName] isEqualToString: @"Add"])
                {
                  // Add
                  [self processSyncAddCommand: aCommand
                                 inCollection: theCollection
                                     withType: theFolderType
                                     inBuffer: theBuffer];
                  *processed = YES;
                }
              else if ([[element tagName] isEqualToString: @"Change"])
                {
                  // Change
                  [self processSyncChangeCommand: aCommand
                                    inCollection: theCollection
                                        withType: theFolderType
                                        inBuffer: theBuffer];
                  *processed = YES;
                }
              else if ([[element tagName] isEqualToString: @"Delete"])
                {
                  // Delete
                  [self processSyncDeleteCommand: aCommand
                                    inCollection: theCollection
                                        withType: theFolderType
                                        inBuffer: theBuffer];
                }
              else if ([[element tagName] isEqualToString: @"Fetch"])
                {
                  // Fetch
                  [self processSyncFetchCommand: aCommand
                                   inCollection: theCollection
                                       withType: theFolderType
                                       inBuffer: theBuffer];
                }
            }
        }
    }
}

//
//
//
- (void) processSyncCollection: (id <DOMElement>) theDocumentElement
                      inBuffer: (NSMutableString *) theBuffer
{
  NSString *collectionId, *realCollectionId, *syncKey, *davCollectionTag, *bodyPreferenceType;
  SOGoMicrosoftActiveSyncFolderType folderType;
  id collection;

  BOOL getChanges, first_sync;

  collectionId = [[(id)[theDocumentElement getElementsByTagName: @"CollectionId"] lastObject] textValue];
  realCollectionId = [collectionId realCollectionIdWithFolderType: &folderType];
  collection = [self collectionFromId: realCollectionId  type: folderType];
  
  syncKey = [[(id)[theDocumentElement getElementsByTagName: @"SyncKey"] lastObject] textValue];
  davCollectionTag = [collection davCollectionTag];
  
  getChanges = ([(id)[theDocumentElement getElementsByTagName: @"GetChanges"] count] ? YES : NO);
  first_sync = NO;

  if ([syncKey isEqualToString: @"0"])
    {
      davCollectionTag = @"-1";
      first_sync = YES;
    }

  // We check our sync preferences and we stash them
  bodyPreferenceType = [[(id)[[(id)[theDocumentElement getElementsByTagName: @"BodyPreference"] lastObject] getElementsByTagName: @"Type"] lastObject] textValue];

  if (!bodyPreferenceType)
    bodyPreferenceType = @"1";
  
  [context setObject: bodyPreferenceType  forKey: @"BodyPreferenceType"];


  [theBuffer appendString: @"<Collection>"];
  [theBuffer appendFormat: @"<SyncKey>%@</SyncKey>", davCollectionTag];
  [theBuffer appendFormat: @"<CollectionId>%@</CollectionId>", collectionId];
  [theBuffer appendFormat: @"<Status>%d</Status>", 1];

  // We generate the commands, if any, for the response. We might also have
  // generated some in processSyncCommand:inResponse: as we could have
  // received a Fetch command
  if (getChanges && !first_sync)
    {
      [self processSyncGetChanges: theDocumentElement
                     inCollection: collection
                      withSyncKey: syncKey
                         withType: folderType
                         inBuffer: theBuffer];
    }

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

      if (processed)
        [theBuffer appendFormat: @"<Responses>%@</Responses>", s];
      else
        [theBuffer appendString: s];
    }
 
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
  id <DOMElement> aCollection;
  NSArray *allCollections;
  NSMutableString *s;
  NSData *d;

  int i;
  
  // We initialize our output buffer
  s = [NSMutableString string];

  [s appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [s appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [s appendString: @"<Sync xmlns=\"AirSync:\"><Collections>"];

  allCollections = (id)[theDocumentElement getElementsByTagName: @"Collections"];

  for (i = 0; i < [allCollections count]; i++)
    {
      aCollection = [allCollections objectAtIndex: i];

      [self processSyncCollection: aCollection  inBuffer: s];
    }

  [s appendString: @"</Collections></Sync>"];
      
  d = [[s dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

  [theResponse setContent: d];
}

@end
