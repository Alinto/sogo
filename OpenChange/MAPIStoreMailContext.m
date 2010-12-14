/* MAPIStoreMailContext.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSObject+Logs.h>

#import <NGImap4/NGImap4EnvelopeAddress.h>

#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUserFolder.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMailContext.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

static Class NSDataK, NSStringK;

@implementation MAPIStoreMailContext

+ (void) initialize
{
  NSDataK = [NSData class];
  NSStringK = [NSString class];
}

+ (NSString *) MAPIModuleName
{
  return @"mail";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@mail/folderINBOX/"
                withID: 0x160001];
}

- (void) setupModuleFolder
{
  id userFolder, accountsFolder;

  userFolder = [SOGoUserFolder objectWithName: [authenticator username]
                                  inContainer: MAPIApp];
  [parentFoldersBag addObject: userFolder];
  [self logWithFormat: @"userFolder: %@", userFolder];
  [woContext setClientObject: userFolder];

  accountsFolder = [userFolder lookupName: @"Mail"
                                inContext: woContext
                                  acquire: NO];
  [parentFoldersBag addObject: accountsFolder];
  [self logWithFormat: @"accountsFolder: %@", accountsFolder];
  [woContext setClientObject: accountsFolder];

  moduleFolder = [accountsFolder lookupName: @"0"
                                  inContext: woContext
                                    acquire: NO];
  [moduleFolder retain];
  [self logWithFormat: @"moduleFolder: %@", moduleFolder];
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
		 matchingQualifier: (EOQualifier *) qualifier
{
  NSArray *keys;
  
  if (qualifier)
    {
      [self errorWithFormat: @"we need to support qualifiers: %@",
	    qualifier];
      keys = nil;
    }
  else
    keys = [(SOGoMailFolder *) folder toOneRelationshipKeys];

  return keys;
}

// - (enum MAPISTATUS) getCommonTableChildproperty: (void **) data
//                               atURL: (NSString *) childURL
//                             withTag: (enum MAPITAGS) proptag
//                            inFolder: (SOGoFolder *) folder
//                             withFID: (uint64_t) fid
// {
//         int rc;

//         rc = MAPI_E_SUCCESS;
//         switch (proptag) {
//         default:
//                 rc = [super getCommonTableChildproperty: data
//                                                   atURL: childURL
//                                                 withTag: proptag
//                                                inFolder: folder
//                                                 withFID: fid];
//         }

//         return rc;
// }

- (enum MAPISTATUS) getMessageTableChildproperty: (void **) data
					   atURL: (NSString *) childURL
					 withTag: (enum MAPITAGS) proptag
					inFolder: (SOGoFolder *) folder
					 withFID: (uint64_t) fid
{
  id child;
  // NSCalendarDate *offsetDate;
  enum MAPISTATUS rc;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_ICON_INDEX: // TODO
      /* read mail, see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      *data = MAPILongValue (memCtx, 0x00000100);
      break;
    case PR_CONVERSATION_TOPIC:
    case PR_CONVERSATION_TOPIC_UNICODE:
    case PR_SUBJECT:
    case PR_SUBJECT_UNICODE:
      child = [self lookupObject: childURL];
      *data = [[child decodedSubject] asUnicodeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup (memCtx, "IPM.Note");
      break;
    case PR_HASATTACH: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_CREATION_TIME: // DOUBT
    case PR_LAST_MODIFICATION_TIME: // DOUBT
    case PR_LATEST_DELIVERY_TIME: // DOUBT
    case PR_MESSAGE_DELIVERY_TIME:
      child = [self lookupObject: childURL];
      // offsetDate = [[child date] addYear: -1 month: 0 day: 0
      //                               hour: 0 minute: 0 second: 0];
      // *data = [offsetDate asFileTimeInMemCtx: memCtx];
      *data = [[child date] asFileTimeInMemCtx: memCtx];
      break;
    case PR_MESSAGE_FLAGS: // TODO
      // NSDictionary *coreInfos;
      // NSArray *flags;
      // child = [self lookupObject: childURL];
      // coreInfos = [child fetchCoreInfos];
      // flags = [coreInfos objectForKey: @"flags"];
      *data = MAPILongValue (memCtx, 0x02 | 0x20); // fromme + unmodified
      break;

    case PR_FLAG_STATUS: // TODO
    case PR_SENSITIVITY: // TODO
    case PR_ORIGINAL_SENSITIVITY: // TODO
    case PR_FOLLOWUP_ICON: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;

    case PR_EXPIRY_TIME: // TODO
    case PR_REPLY_TIME:
      *data = [[NSCalendarDate date] asFileTimeInMemCtx: memCtx];
      break;

    case PR_BODY:
    case PR_BODY_UNICODE:
      {
        NSMutableArray *keys;
        NSArray *acceptedTypes;

        child = [self lookupObject: childURL];

        acceptedTypes = [NSArray arrayWithObjects: @"text/plain",
                                 @"text/html", nil];
        keys = [NSMutableArray array];
        [child addRequiredKeysOfStructure: [child bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: acceptedTypes];
        if ([keys count] == 0 || [keys count] == 2)
          {
            *data = NULL;
            rc = MAPI_E_NOT_FOUND;
          }
        else
          {
            acceptedTypes = [NSArray arrayWithObject: @"text/plain"];
            [keys removeAllObjects];
            [child addRequiredKeysOfStructure: [child bodyStructure]
                                         path: @"" toArray: keys
                                acceptedTypes: acceptedTypes];
            if ([keys count] > 0)
              {
                id result;
                NSData *content;
                NSString *key, *stringContent;
                
                result = [child fetchParts: [keys objectsForKey: @"key"
                                                 notFoundMarker: nil]];
                result = [[result valueForKey: @"RawResponse"] objectForKey: @"fetch"];
                key = [[keys objectAtIndex: 0] objectForKey: @"key"];
                content = [[result objectForKey: key] objectForKey: @"data"];
		if ([content length] > 3999)
		  {
		    [self registerValue: content
			     asProperty: proptag
				 forURL: childURL];
		    *data = NULL;
		    rc = MAPI_E_NOT_ENOUGH_MEMORY;
		  }
		else
		  {
		    stringContent = [[NSString alloc] initWithData: content
							  encoding: NSISOLatin1StringEncoding];
                
		    // *data = NULL;
		    // rc = MAPI_E_NOT_FOUND;
		    *data = [stringContent asUnicodeInMemCtx: memCtx];
		  }
              }
            else
              {
                rc = MAPI_E_NOT_FOUND;
              }
          }
      }
      break;
      
    case PR_HTML:
      {
        NSMutableArray *keys;
        NSArray *acceptedTypes;

        child = [self lookupObject: childURL];
        
        acceptedTypes = [NSArray arrayWithObject: @"text/html"];
        keys = [NSMutableArray array];
        [child addRequiredKeysOfStructure: [child bodyStructure]
                                    path: @"" toArray: keys acceptedTypes: acceptedTypes];
        if ([keys count] > 0)
          {
            id result;
            NSString *key;
            NSData *content;
            
            result = [child fetchParts: [keys objectsForKey: @"key"
                                            notFoundMarker: nil]];
            result = [[result valueForKey: @"RawResponse"] objectForKey:
                                            @"fetch"];
            key = [[keys objectAtIndex: 0] objectForKey: @"key"];
            content = [[result objectForKey: key] objectForKey: @"data"];
	    if ([content length] > 3999)
	      {
		[self registerValue: content
			 asProperty: proptag
			     forURL: childURL];
		*data = NULL;
		rc = MAPI_E_NOT_ENOUGH_MEMORY;
	      }
	    else
	      *data = [content asBinaryInMemCtx: memCtx];
          }
        else
          {
            *data = NULL;
            rc = MAPI_E_NOT_FOUND;
          }
      }

      // *data = NULL;
      // rc = MAPI_E_NOT_FOUND;
      break;

      /* We don't handle any RTF content. */
    case PR_RTF_COMPRESSED:
      rc = MAPI_E_NOT_ENOUGH_MEMORY;
      break;
    case PR_RTF_IN_SYNC:
      *data = MAPIBoolValue (memCtx, NO);
      break;


      // #define PR_ITEM_TEMPORARY_FLAGS                             PROP_TAG(PT_LONG      , 0x1097) /* 0x10970003 */

      // 36030003 - PR_CONTENT_UNREAD
      // 36020003 - PR_CONTENT_COUNT
      // 10970003 - 
      // 81f80003
      // 10950003
      // 819d0003
      // 300b0102
      // 81fa000b
      // 00300040
      // 00150040

    case PR_RECEIVED_BY_NAME:
      child = [self lookupObject: childURL];
      *data = [[child to] asUnicodeInMemCtx: memCtx];
      break;

    case PR_SENT_REPRESENTING_NAME_UNICODE:
      child = [self lookupObject: childURL];
      *data = [[child from] asUnicodeInMemCtx: memCtx];
      break;
    case PR_INTERNET_MESSAGE_ID:
    case PR_INTERNET_MESSAGE_ID_UNICODE:
      child = [self lookupObject: childURL];
      *data = [[child messageId] asUnicodeInMemCtx: memCtx];
      break;

    case PR_READ_RECEIPT_REQUESTED: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;

      /* BOOL */
    case PR_ALTERNATE_RECIPIENT_ALLOWED:
    case PR_AUTO_FORWARDED:
    case PR_DL_EXPANSION_PROHIBITED:
    case PR_RESPONSE_REQUESTED:
    case PR_REPLY_REQUESTED:
    case PR_DELETE_AFTER_SUBMIT:
    case PR_PROCESSED:
    case PR_ORIGINATOR_DELIVERY_REPORT_REQUESTED:
    case PR_RECIPIENT_REASSIGNMENT_PROHIBITED:
      rc = MAPI_E_NOT_FOUND;
      break;

      /* PT_SYSTIME */
    case PR_START_DATE:
    case PR_END_DATE:
    case PR_ACTION_DATE:
    case PR_FLAG_COMPLETE:
    case PR_DEFERRED_DELIVERY_TIME:
    case PR_REPORT_TIME:
    case PR_CLIENT_SUBMIT_TIME:
    case PR_DEFERRED_SEND_TIME:
    case PR_ORIGINAL_SUBMIT_TIME:
      rc = MAPI_E_NOT_FOUND;
      break;
      
      /* PT_BINARY */
    case PR_CONVERSATION_KEY:
    case PR_ORIGINALLY_INTENDED_RECIPIENT_NAME:
    case PR_PARENT_KEY:
    case PR_REPORT_TAG:
    case PR_SENT_REPRESENTING_SEARCH_KEY:
    case PR_RECEIVED_BY_ENTRYID:
    case PR_SENT_REPRESENTING_ENTRYID:
    case PR_RCVD_REPRESENTING_ENTRYID:
    case PR_ORIGINAL_AUTHOR_ENTRYID:
    case PR_REPLY_RECIPIENT_ENTRIES:
    case PR_RECEIVED_BY_SEARCH_KEY:
    case PR_RCVD_REPRESENTING_SEARCH_KEY:
    case PR_SEARCH_KEY:
    case PR_CHANGE_KEY:
    case PR_ORIGINAL_AUTHOR_SEARCH_KEY:      
    case PR_CONVERSATION_INDEX:
    case PR_SENDER_ENTRYID:
    case PR_SENDER_SEARCH_KEY:
      rc = MAPI_E_NOT_FOUND;
      break;

      /* PT_SVREID*/
    case PR_SENT_MAILSVR_EID:
      rc = MAPI_E_NOT_FOUND;
      break;

      /* PR_LONG */
    case PR_OWNER_APPT_ID:
    case PR_ACTION_FLAG:
    case PR_INTERNET_CPID:
    case PR_INET_MAIL_OVERRIDE_FORMAT:
      rc = MAPI_E_NOT_FOUND;
      break;

    case PR_MSG_EDITOR_FORMAT:
      {
        NSMutableArray *keys;
        NSArray *acceptedTypes;
        uint32_t format;

        child = [self lookupObject: childURL];

        format = 0; /* EDITOR_FORMAT_DONTKNOW */

        acceptedTypes = [NSArray arrayWithObject: @"text/plain"];
        keys = [NSMutableArray array];
        [child addRequiredKeysOfStructure: [child bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: acceptedTypes];
        if ([keys count] == 1)
          format = EDITOR_FORMAT_PLAINTEXT;

        acceptedTypes = [NSArray arrayWithObject: @"text/html"];
        [keys removeAllObjects];
        [child addRequiredKeysOfStructure: [child bodyStructure]
                                     path: @"" toArray: keys
                            acceptedTypes: acceptedTypes];
        if ([keys count] == 1)
          format = EDITOR_FORMAT_HTML;

        *data = MAPILongValue (memCtx, format);
      }
      break;

    default:
      rc = [super getMessageTableChildproperty: data
                                         atURL: childURL
                                       withTag: proptag
                                      inFolder: folder
                                       withFID: fid];
    }

  return rc;
}

- (enum MAPISTATUS) getFolderTableChildproperty: (void **) data
					  atURL: (NSString *) childURL
					withTag: (enum MAPITAGS) proptag
				       inFolder: (SOGoFolder *) folder
					withFID: (uint64_t) fid
{
  enum MAPISTATUS rc;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_CONTENT_UNREAD:
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_CONTAINER_CLASS_UNICODE:
      *data = talloc_strdup (memCtx, "IPF.Note");
      break;
    default:
      rc = [super getFolderTableChildproperty: data
                                        atURL: childURL
                                      withTag: proptag
                                     inFolder: folder
                                      withFID: fid];
    }
  
  return rc;
}

- (int) openMessage: (struct mapistore_message *) msg
              atURL: (NSString *) childURL
{
  id child;
  int rc;
  struct SRowSet *recipients;
  struct SRow *properties;
  NSArray *to;
  NSInteger count, max;
  NGImap4EnvelopeAddress *currentAddress;
  NSString *name;
  enum MAPITAGS tags[] = { PR_SUBJECT_UNICODE, PR_HASATTACH,
			   PR_MESSAGE_DELIVERY_TIME, PR_MESSAGE_FLAGS,
			   PR_FLAG_STATUS, PR_SENSITIVITY,
			   PR_SENT_REPRESENTING_NAME_UNICODE,
			   PR_INTERNET_MESSAGE_ID_UNICODE,
			   PR_READ_RECEIPT_REQUESTED };
  void *propValue;

  child = [self lookupObject: childURL];
  if (child)
    {
      /* Retrieve recipients from the message */
      to = [child toEnvelopeAddresses];
      max = [to count];
      recipients = talloc_zero (memCtx, struct SRowSet);
      recipients->cRows = max;
      recipients->aRow = talloc_array (recipients, struct SRow, max);
      for (count = 0; count < max; count++)
        {
          recipients->aRow[count].ulAdrEntryPad = 0;
          recipients->aRow[count].cValues = 2;
          recipients->aRow[count].lpProps = talloc_array (recipients->aRow,
                                                          struct SPropValue,
                                                          2);

          // TODO (0x01 = primary recipient)
          set_SPropValue_proptag (&(recipients->aRow[count].lpProps[0]),
                                  PR_RECIPIENT_TYPE,
                                  MAPILongValue (memCtx, 0x01));

          currentAddress = [to objectAtIndex: count];
          // name = [currentAddress personalName];
          // if (![name length])
          name = [currentAddress baseEMail];
          set_SPropValue_proptag (&(recipients->aRow[count].lpProps[1]),
                                  PR_DISPLAY_NAME,
                                  [name asUnicodeInMemCtx: recipients->aRow[count].lpProps]);
        }
      msg->recipients = recipients;

      max = 9;

      properties = talloc_zero (memCtx, struct SRow);
      properties->cValues = 0;
      properties->ulAdrEntryPad = 0;
      properties->lpProps = talloc_array (properties, struct SPropValue, max);
      for (count = 0; count < max; count++)
        {
          if ([self getMessageTableChildproperty: &propValue
                                           atURL: childURL
                                         withTag: tags[count]
                                        inFolder: nil
                                         withFID: 0]
              == MAPI_E_SUCCESS)
            {
              set_SPropValue_proptag (&(properties->lpProps[properties->cValues]),
                                      tags[count],
                                      propValue);
              properties->cValues++;
              // talloc_free (propValue);
            }
        }

      msg->properties = properties;
      
      rc = MAPI_E_SUCCESS;
    }
  else
    rc = MAPI_E_NOT_FOUND;

  return rc;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"DATE"
		       forKey: MAPIPropertyKey (PR_MESSAGE_DELIVERY_TIME)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

/* restrictions */

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Note"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    default:
      rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

- (MAPIRestrictionState) evaluateContentRestriction: (struct mapi_SContentRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  if ([value isKindOfClass: NSDataK])
    {
      value = [[NSString alloc] initWithData: value
				    encoding: NSUTF8StringEncoding];
      [value autorelease];
    }
  else if (![value isKindOfClass: NSStringK])
    [NSException raise: @"MAPIStoreTypeConversionException"
		format: @"unhandled content restriction for class '%@'",
		 NSStringFromClass ([value class])];

  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Note"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    default:
      rc = [super evaluateContentRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

- (MAPIRestrictionState) evaluateExistRestriction: (struct mapi_SExistRestriction *) res
				    intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;

  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;
    case PR_MESSAGE_DELIVERY_TIME:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    default:
      rc = [super evaluateExistRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

@end
