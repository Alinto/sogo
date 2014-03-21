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

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEntityObject.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/NGVCard.h>

#import <NGExtensions/NSCalendarDate+misc.h>
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

#include <unistd.h>

@implementation SOGoActiveSyncDispatcher (Sync)

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
                // FIXME
                //continue;
                NSLog(@"BLARG!");
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
              }
              break;
            case ActiveSyncEventFolder:
            case ActiveSyncTaskFolder:
              {
                o = [sogoObject component: NO  secure: NO];
                [o takeActiveSyncValues: allChanges  inContext: context];
                [sogoObject saveComponent: o];
              }
              break;
            case ActiveSyncMailFolder:
            default:
              {
                [sogoObject takeActiveSyncValues: allChanges  inContext: context];
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
          
          sogoObject = [theCollection lookupName: [serverId sanitizedServerIdWithType: theFolderType]
                                       inContext: context
                                         acquire: NO];

          if (![sogoObject isKindOfClass: [NSException class]])
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
                   withSyncKey: (NSString *) theSyncKey
                withFolderType: (SOGoMicrosoftActiveSyncFolderType) theFolderType
                withFilterType: (NSCalendarDate *) theFilterType
                      inBuffer: (NSMutableString *) theBuffer
                 lastServerKey: (NSString **) theLastServerKey

{
  NSMutableString *s;
  
  BOOL more_available;
  int i, max;

  //
  // No changes in the collection - 2.2.2.19.1.1 Empty Sync Request.
  // We check this and we don't generate any commands if we don't have to.
  //
  if ([theSyncKey isEqualToString: [theCollection davCollectionTag]])
    return;
  
  s = [NSMutableString string];
  more_available = NO;

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

        BOOL updated;
        int deleted;
          
        if (theFolderType == ActiveSyncContactFolder)
          component_name = @"vcard";
        else if (theFolderType == ActiveSyncEventFolder)
          component_name = @"vevent";
        else
          component_name = @"vtodo";

        allComponents = [theCollection syncTokenFieldsWithProperties: nil   matchingSyncToken: theSyncKey  fromDate: theFilterType];
        
        // Check for the WindowSize
        max = [allComponents count];

        // Disabled for now for GCS folders.
        // if (max > theWindowSize)
        //   {
        //     max = theWindowSize;
        //     more_available = YES;
        //   }
        
        for (i = 0; i < max; i++)
          {
            component = [allComponents objectAtIndex: i];
            deleted = [[component objectForKey: @"c_deleted"] intValue];

            if (!deleted && ![[component objectForKey: @"c_component"] isEqualToString: component_name])
              continue;
            
            uid = [[component objectForKey: @"c_name"] sanitizedServerIdWithType: theFolderType];
            
            if (deleted)
              {
                [s appendString: @"<Delete xmlns=\"AirSync:\">"];
                [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
                [s appendString: @"</Delete>"];
              }
            else
              {
                updated = YES;
                
                if ([[component objectForKey: @"c_creationdate"] intValue] > [theSyncKey intValue])
                  updated = NO;
                
	        sogoObject = [theCollection lookupName: [uid sanitizedServerIdWithType: theFolderType]
                                             inContext: context
                                               acquire: 0];
                
                if (theFolderType == ActiveSyncContactFolder)
                  componentObject = [sogoObject vCard];
                else
                  componentObject = [sogoObject component: NO  secure: NO];                
                
                
                //
                // We do NOT synchronize NEW events that are in fact, invitations
                // to events. This is due to the fact that Outlook 2013 creates
                // "phantom" events in the calendar that are mapped to invitations mails.
                // If we synchronize these events too, it'll interfere with the whole thing
                // and prevent Outlook from properly calling MeetingResponse.
                //
                if (!updated && theFolderType == ActiveSyncEventFolder)
                  {
                    iCalPersonPartStat partstat;
                    iCalPerson *attendee;
                    NSString *email;

                    email = [[[context activeUser] allEmails] objectAtIndex: 0];
                    attendee = [componentObject findAttendeeWithEmail: email];

                    if (attendee)
                      {
                        partstat = [attendee participationStatus];
                        
                        if (partstat == iCalPersonPartStatNeedsAction)
                          continue;
                      }
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
              }
          } // for ...
      }
      break;
    case ActiveSyncMailFolder:
    default:
      {
        NSMutableArray *addedOrChangedMessages;
        NSString *uid, *command, *key;
        SOGoMailObject *mailObject;
        NSDictionary *aMessage;
        NSArray *allMessages;
        int deleted_count;

        allMessages = [theCollection syncTokenFieldsWithProperties: nil   matchingSyncToken: theSyncKey  fromDate: theFilterType];
        addedOrChangedMessages = [NSMutableArray array];
        deleted_count = 0;

        // Check for the WindowSize.
        // FIXME: we should eventually check for modseq and slice the maximum
        //        amount of messages returned to ensure we don't have the same
        //        modseq accross contiguous boundaries
        max = [allMessages count];
        
        // We first check the number of deleted messages we have
        // We do NOT honor the window size here as it seems to be
        // impossible to get the modseq of an expunged message so
        // we can't iterate in the list of deleted messages.
        for (i = 0; i < max; i++)
          {
            aMessage = [allMessages objectAtIndex: i];
            
            uid = [[[aMessage allKeys] lastObject] stringValue];
            command = [[aMessage allValues] lastObject];
            
            if ([command isEqualToString: @"deleted"])
              {
                [s appendString: @"<Delete xmlns=\"AirSync:\">"];
                [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
                [s appendString: @"</Delete>"];
                deleted_count++;
              }
            else
              {
                [addedOrChangedMessages addObject: aMessage];
              }
          }

        // We then "pad" with our added/changed messages. We ALWAYS
        // at least return one if available
        max = [addedOrChangedMessages count];
        
        for (i = 0; i < max; i++)
          {
            aMessage = [addedOrChangedMessages objectAtIndex: i];
            
            uid = [[[aMessage allKeys] lastObject] stringValue];
            command = [[aMessage allValues] lastObject];          
            
            // We check for Outlook stupidity to avoid creating duplicates - see the comment
            // in SOGoActiveSyncDispatcher.m: -processMoveItems:inResponse: for more details.
            key = [NSString stringWithFormat: @"%@+%@+%@+%@",
                            [[context activeUser] login],
                       [context objectForKey: @"DeviceType"],
                            [theCollection displayName],
                            uid];
            
            if ([[SOGoCache sharedCache] valueForKey: key])
              {
                [[SOGoCache sharedCache] removeValueForKey: key];
                command = @"changed";
              }
            
            if ([command isEqualToString: @"added"])
              [s appendString: @"<Add xmlns=\"AirSync:\">"];
            else
              [s appendString: @"<Change xmlns=\"AirSync:\">"];
            
            mailObject = [theCollection lookupName: uid
                                         inContext: context
                                           acquire: 0];
            
            [s appendFormat: @"<ServerId xmlns=\"AirSync:\">%@</ServerId>", uid];
            [s appendString: @"<ApplicationData xmlns=\"AirSync:\">"];
            [s appendString: [mailObject activeSyncRepresentationInContext: context]];
            [s appendString: @"</ApplicationData>"];
            
            if ([command isEqualToString: @"added"])
              [s appendString: @"</Add>"];
            else
              [s appendString: @"</Change>"];
            
            
            // We check if we must stop padding
            if (i+1+deleted_count > theWindowSize)
              {
                more_available = YES;
                break;
              }
          }
      
        //
        if (more_available)
          {
            *theLastServerKey = uid;
          }
      }
      break;
    } // switch (folderType) ...
  
  if ([s length])
    {
      [theBuffer appendString: @"<Commands>"];
      [theBuffer appendString: s];
      [theBuffer appendString: @"</Commands>"];

      if (more_available)
        [theBuffer appendString: @"<MoreAvailable/>"];
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
                  *processed = YES;
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
                changeDetected: (BOOL *) changeDetected
{
  NSString *collectionId, *realCollectionId, *syncKey, *davCollectionTag, *bodyPreferenceType, *lastServerKey;
  SOGoMicrosoftActiveSyncFolderType folderType;
  id collection, value;
  
  NSMutableString *changeBuffer, *commandsBuffer;
  BOOL getChanges, first_sync;
  unsigned int windowSize;
  
  changeBuffer = [NSMutableString string];
  commandsBuffer = [NSMutableString string];
  
  collectionId = [[(id)[theDocumentElement getElementsByTagName: @"CollectionId"] lastObject] textValue];
  realCollectionId = [collectionId realCollectionIdWithFolderType: &folderType];
  collection = [self collectionFromId: realCollectionId  type: folderType];
  
  syncKey = davCollectionTag = [[(id)[theDocumentElement getElementsByTagName: @"SyncKey"] lastObject] textValue];
  
  // We check for a window size, default to 100 if not specfied or out of bounds
  windowSize = [[[(id)[theDocumentElement getElementsByTagName: @"WindowSize"] lastObject] textValue] intValue];
  
  if (windowSize == 0 || windowSize > 512)
    windowSize = 100;

  lastServerKey = nil;
  
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
    }

  // We check our sync preferences and we stash them
  bodyPreferenceType = [[(id)[[(id)[theDocumentElement getElementsByTagName: @"BodyPreference"] lastObject] getElementsByTagName: @"Type"] lastObject] textValue];

  if (!bodyPreferenceType)
    bodyPreferenceType = @"1";
  
  [context setObject: bodyPreferenceType  forKey: @"BodyPreferenceType"];


  // We generate the commands, if any, for the response. We might also have
  // generated some in processSyncCommand:inResponse: as we could have
  // received a Fetch command
  if (getChanges && !first_sync)
    {
      [self processSyncGetChanges: theDocumentElement
                     inCollection: collection
                   withWindowSize: windowSize
                      withSyncKey: syncKey
                   withFolderType: folderType
                   withFilterType: [NSCalendarDate dateFromFilterType: [[(id)[theDocumentElement getElementsByTagName: @"FilterType"] lastObject] textValue]]
                         inBuffer: changeBuffer
                    lastServerKey: &lastServerKey];
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
        [commandsBuffer appendFormat: @"<Responses>%@</Responses>", s];
      else
        [commandsBuffer appendString: s];
    }
 
  // If we got any changes or if we have applied any commands
  // let's regenerate our SyncKey based on the collection tag.
  if ([changeBuffer length] || [commandsBuffer length])
    {
      if (lastServerKey)
        davCollectionTag = [collection davCollectionTagFromId: lastServerKey];
      else
        davCollectionTag = [collection davCollectionTag];
     
      *changeDetected = YES;
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
  [theBuffer appendFormat: @"<Status>%d</Status>", 1];

  [theBuffer appendString: changeBuffer];
  [theBuffer appendString: commandsBuffer];

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
  NSArray *allCollections;
  NSData *d;

  int i, j, defaultInterval, heartbeatInterval, internalInterval;
  BOOL changeDetected;
  
  // We initialize our output buffer
  output = [NSMutableString string];

  [output appendString: @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"];
  [output appendString: @"<!DOCTYPE ActiveSync PUBLIC \"-//MICROSOFT//DTD ActiveSync//EN\" \"http://www.microsoft.com/\">"];
  [output appendString: @"<Sync xmlns=\"AirSync:\">"];
  
  defaults = [SOGoSystemDefaults sharedSystemDefaults];
  heartbeatInterval = [[[(id)[theDocumentElement getElementsByTagName: @"HeartbeatInterval"] lastObject] textValue] intValue];
  defaultInterval = [defaults maximumSyncInterval];
  internalInterval = [defaults internalSyncInterval];

  // We check to see if our heartbeat interval falls into the supported ranges.
  if (heartbeatInterval > defaultInterval || heartbeatInterval < 1)
    {
      // Interval is too long, inform the client.
      heartbeatInterval = defaultInterval;

      // Outlook doesn't like this...
      //[output appendFormat: @"<Limit>%d</Limit>", defaultInterval];
      //[output appendFormat: @"<Status>%d</Status>", 14];
    }

  [output appendString: @"<Collections>"];
  
  allCollections = (id)[theDocumentElement getElementsByTagName: @"Collection"];

  // We enter our loop detection change
  for (i = 0; i < (defaultInterval/internalInterval); i++)
    {
      s = [NSMutableString string];

      for (j = 0; j < [allCollections count]; j++)
        {
          aCollection = [allCollections objectAtIndex: j];
          
          [self processSyncCollection: aCollection  inBuffer: s  changeDetected: &changeDetected];
        }

      if (changeDetected)
        {
          NSLog(@"Change detected, we push the content.");
          break;
        }
      else
        {
          NSLog(@"Sleeping %d seconds while detecting changes...", internalInterval);
          sleep(internalInterval);
        }
    }

  // We always return the last generated response.
  // If we only return <Sync><Collections/></Sync>,
  // iOS powered devices will simply crash.
  [output appendString: s];

  [output appendString: @"</Collections></Sync>"];
      
  d = [[output dataUsingEncoding: NSUTF8StringEncoding] xml2wbxml];

  [theResponse setContent: d];
}

@end
