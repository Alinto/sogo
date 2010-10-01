/* MAPIStoreContext.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2010 Wolfgang Sourdeau
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMapping.h"

#import "MAPIStoreContext.h"

#import "NSString+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
// #include <dlinklist.h>

        // NSNullK = NSClassFromString (@"NSNull");

        // SOGoMailAccountsK = NSClassFromString (@"SOGoMailAccounts");
        // SOGoMailAccountK = NSClassFromString (@"SOGoMailAccount");
        // SOGoMailFolderK = NSClassFromString (@"SOGoMailFolder");
        // SOGoUserFolderK = NSClassFromString (@"SOGoUserFolder");

static Class SOGoObjectK, SOGoMailAccountK, SOGoMailFolderK;

@interface SOGoFolder (MAPIStoreProtocol)

- (BOOL) create;
- (NSException *) delete;

@end

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davContentLength;

@end

@implementation MAPIStoreContext : NSObject

/* sogo://username:password@{contacts,calendar,tasks,journal,notes,mail}/dossier/id */

static MAPIStoreMapping *mapping = nil;

+ (void) initialize
{
  SOGoObjectK = [SOGoObject class];
  SOGoMailAccountK = [SOGoMailAccount class];
  SOGoMailFolderK = [SOGoMailFolder class];
  mapping = [MAPIStoreMapping new];
}

+ (id) contextFromURI: (const char *) newUri
{
        MAPIStoreContext *context;
        MAPIStoreAuthenticator *authenticator;
        NSString *contextClass, *module, *completeURLString, *urlString;
        NSURL *baseURL;

	NSLog (@"METHOD '%s' (%d) -- uri: '%s'", __FUNCTION__, __LINE__, newUri);

        context = nil;

        urlString = [NSString stringWithUTF8String: newUri];
        if (urlString) {
                completeURLString = [@"sogo://" stringByAppendingString: urlString];
                baseURL = [NSURL URLWithString: completeURLString];
                if (baseURL) {
                        module = [baseURL host];
                        if (module) {
                                if ([module isEqualToString: @"mail"])
                                        contextClass = @"MAPIStoreMailContext";
                                else if ([module isEqualToString: @"contacts"])
                                        contextClass = @"MAPIStoreContactsContext";
                                else if ([module isEqualToString: @"calendar"])
                                        contextClass = @"MAPIStoreCalendarContext";
                                else {
                                        NSLog (@"ERROR: unrecognized module name '%@'", module);
                                        contextClass = nil;
                                }
                                
                                if (contextClass) {
                                        [mapping registerURL: completeURLString];
                                        context = [NSClassFromString (contextClass) new];
                                        [context autorelease];

                                        authenticator = [MAPIStoreAuthenticator new];
                                        [authenticator setUsername: [baseURL user]];
                                        [authenticator setPassword: [baseURL password]];
                                        [context setAuthenticator: authenticator];
                                        [authenticator release];

                                        [context setupRequest];
                                        [context setupModuleFolder];
                                        [context tearDownRequest];
                                }
                        }
                }
                else
                        NSLog (@"ERROR: url could not be parsed");
        }
        else
                NSLog (@"ERROR: url is an invalid UTF-8 string");

        return context;
}

- (id) init
{
        if ((self = [super init])) {
                // objectCache = [NSMutableDictionary new];
                messageCache = [NSMutableDictionary new];
                subfolderCache = [NSMutableDictionary new];
                woContext = [WOContext contextWithRequest: nil];
                [woContext retain];
                moduleFolder = nil;
        }

        [self logWithFormat: @"-init"];

        return self;
}

- (void) dealloc
{
        [self logWithFormat: @"-dealloc"];

        // [objectCache release];
        [messageCache release];
        [subfolderCache release];

        [moduleFolder release];
        [woContext release];
        [authenticator release];
        [super dealloc];
}

- (void) setAuthenticator: (MAPIStoreAuthenticator *) newAuthenticator
{
        ASSIGN (authenticator, newAuthenticator);
}

- (MAPIStoreAuthenticator *) authenticator
{
        return authenticator;
}

- (void) setMemCtx: (void *) newMemCtx
{
        memCtx = newMemCtx;
}

- (void) setupRequest
{
        NSMutableDictionary *info;

        [MAPIApp setMAPIStoreContext: self];
        info = [[NSThread currentThread] threadDictionary];
        [info setObject: woContext forKey:@"WOContext"];
}

- (void) tearDownRequest
{
        NSMutableDictionary *info;

        info = [[NSThread currentThread] threadDictionary];
        [info removeObjectForKey:@"WOContext"];
        [MAPIApp setMAPIStoreContext: nil];
}

- (void) setupModuleFolder
{
        [self subclassResponsibility: _cmd];
}

- (id) lookupObject: (NSString *) objectURLString
{
        id object;
        NSURL *objectURL;
        NSArray *path;
        int count, max;
        NSString *pathString, *nameInContainer;

        // object = [objectCache objectForKey: objectURLString];
        // if (!object) {
        objectURL = [NSURL URLWithString: objectURLString];
        if (!objectURL)
                [self errorWithFormat: @"url string gave nil NSURL: '%@'", objectURLString];
        object = moduleFolder;
        
        pathString = [objectURL path];
        if ([pathString hasPrefix: @"/"])
                pathString = [pathString substringFromIndex: 1];
        if ([pathString length] > 0) {
                path = [pathString componentsSeparatedByString: @"/"];
                max = [path count];
                if (max > 0) {
                        for (count = 0;
                             object && count < max;
                             count++) {
                                nameInContainer = [[path objectAtIndex: count]
                                                          stringByUnescapingURL];
                                object = [object lookupName: nameInContainer
                                                  inContext: woContext
                                                    acquire: NO];
                                if ([object isKindOfClass: SOGoObjectK])
                                        [woContext setClientObject: object];
                                else
                                        object = nil;
                        }
                }
        } else
                object = nil;

        [woContext setClientObject: object];
        // if (object && [object isKindOfClass: SOGoObjectK])
        //         [objectCache setObject: object
        //                         forKey: objectURLString];
        // else {
        //         object = nil;
        //         [woContext setClientObject: nil];
        // }
        
        return object;
}

- (NSString *) _createFolder: (struct SRow *) aRow
                 inParentURL: (NSString *) parentFolderURL
{
        NSString *newFolderURL;
        NSString *folderName, *nameInContainer;
        SOGoFolder *parentFolder, *newFolder;
        int i;

        newFolderURL = nil;

        folderName = nil;
	for (i = 0; !folderName && i < aRow->cValues; i++) {
		if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME_UNICODE) {
			folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszW];
		}
                else if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME) {
			folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszA];
                }
	}

        if (folderName) {
                parentFolder = [self lookupObject: parentFolderURL];
                if (parentFolder) {
                        if ([parentFolder isKindOfClass: SOGoMailAccountK]
                            || [parentFolder isKindOfClass: SOGoMailFolderK]) {
                                nameInContainer = [NSString stringWithFormat: @"folder%@",
                                                            [folderName asCSSIdentifier]];
                                newFolder = [SOGoMailFolderK objectWithName: nameInContainer
                                                                inContainer: parentFolder];
                                if ([newFolder create])
                                        newFolderURL = [NSString stringWithFormat: @"%@/%@",
                                                                 parentFolderURL,
                                                                 [nameInContainer stringByEscapingURL]];
                        }
                }
        }

        return newFolderURL;
}

/**
   \details Create a folder in the sogo backend
   
   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
 */

- (int) mkDir: (struct SRow *) aRow
      withFID: (uint64_t) fid
  inParentFID: (uint64_t) parentFID
{
        NSString *folderURL, *parentFolderURL;
        int rc;

	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

        folderURL = [mapping urlFromID: fid];
        if (folderURL)
                rc = MAPISTORE_ERR_EXIST;
        else {
                parentFolderURL = [mapping urlFromID: parentFID];
                if (!parentFolderURL)
                        [self errorWithFormat: @"No url found for FID: %lld", parentFID];
                if (parentFolderURL) {
                        folderURL = [self _createFolder: aRow inParentURL: parentFolderURL];
                        if (folderURL) {
                                [mapping registerURL: folderURL withID: fid];
                                // if ([sogoFolder isKindOfClass: SOGoMailAccountK])
                                //         [sogoFolder subscribe];
                                rc = MAPISTORE_SUCCESS;
                        }
                        else
                                rc = MAPISTORE_ERR_NOT_FOUND;
                }
                else
                        rc = MAPISTORE_ERR_NO_DIRECTORY;
        }

	return rc;
}


/**
   \details Delete a folder from the sogo backend

   \param private_data pointer to the current sogo context
   \param parentFID the FID for the parent of the folder to delete
   \param fid the FID for the folder to delete

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
 */
- (int) rmDirWithFID: (uint64_t) fid
         inParentFID: (uint64_t) parentFid
{
	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	return MAPISTORE_SUCCESS;
}


/**
   \details Open a folder from the sogo backend

   \param private_data pointer to the current sogo context
   \param parentFID the parent folder identifier
   \param fid the identifier of the colder to open

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
 */
- (int) openDir: (uint64_t) fid
    inParentFID: (uint64_t) parentFID
{
        [self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	return MAPISTORE_SUCCESS;
}


/**
   \details Close a folder from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
 */
- (int) closeDir
{
	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	return MAPISTORE_SUCCESS;
}

- (NSArray *) _messageKeysForFolderURL: (NSString *) folderURL
{
        NSArray *keys;
        SOGoFolder *folder;

        keys = [messageCache objectForKey: folderURL];
        if (!keys) {
                folder = [self lookupObject: folderURL];
                if (folder)
                        keys = [folder toOneRelationshipKeys];
                else
                        keys = (NSArray *) [NSNull null];
                [messageCache setObject: keys forKey: folderURL];
        }

        return keys;
}

- (NSArray *) _subfolderKeysForFolderURL: (NSString *) folderURL
{
        NSArray *keys;
        SOGoFolder *folder;

        keys = [subfolderCache objectForKey: folderURL];
        if (!keys) {
                folder = [self lookupObject: folderURL];
                if (folder) {
                        keys = [folder toManyRelationshipKeys];
                        if (!keys)
                                keys = (NSArray *) [NSNull null];
                }
                else
                        keys = (NSArray *) [NSNull null];
                [subfolderCache setObject: keys forKey: folderURL];
        }

        return keys;
}

/**
   \details Read directory content from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
 */
- (int) readCount: (uint32_t *) rowCount
      ofTableType: (uint8_t) tableType
            inFID: (uint64_t) fid
{
        NSArray *ids;
        NSString *url;
        int rc;

	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

        url = [mapping urlFromID: fid];
        if (!url)
                [self errorWithFormat: @"No url found for FID: %lld", fid];

        switch (tableType) {
        case MAPISTORE_FOLDER_TABLE:
                ids = [self _subfolderKeysForFolderURL: url];
                break;
        case MAPISTORE_MESSAGE_TABLE:
                ids = [self _messageKeysForFolderURL: url];
                break;
        default:
                rc = MAPISTORE_ERR_INVALID_PARAMETER;
                ids = nil;
        }

        if ([ids isKindOfClass: [NSArray class]]) {
                rc = MAPI_E_SUCCESS;
                *rowCount = [ids count];
        }
        else
                rc = MAPISTORE_ERR_NO_DIRECTORY;

        return rc;
}

- (int) getCommonTableChildproperty: (void **) data
                              atURL: (NSString *) childURL
                            withTag: (uint32_t) proptag
                           inFolder: (SOGoFolder *) folder
                            withFID: (uint64_t) fid
{
        NSString *stringValue;
        id child;
        // uint64_t *llongValue;
        // uint32_t *longValue;
        int rc;

        rc = MAPI_E_SUCCESS;
        switch (proptag) {
        case PR_DISPLAY_NAME_UNICODE:
                child = [self lookupObject: childURL];
                *data = [[child displayName] asUnicodeInMemCtx: memCtx];
                break;
        default:
                if ((proptag & 0x001F) == 0x001F) {
                        stringValue = [NSString stringWithFormat: @"Unhandled unicode value: 0x%x", proptag];
                        *data = [stringValue asUnicodeInMemCtx: memCtx];
                        [self errorWithFormat: @"Unknown proptag (returned): %.8x for child '%@'",
                              proptag, childURL];
                        break;
                }
                else {
                  [self errorWithFormat: @"Unknown proptag: %.8x for child '%@'",
                        proptag, childURL];
                  *data = NULL;
                }
                rc = MAPI_E_NOT_FOUND;
        }

        return rc;
}

- (int) getMessageTableChildproperty: (void **) data
                               atURL: (NSString *) childURL
                             withTag: (uint32_t) proptag
                            inFolder: (SOGoFolder *) folder
                             withFID: (uint64_t) fid
{
        uint32_t *longValue;
        uint64_t *llongValue;
        int rc;

        rc = MAPI_E_SUCCESS;
        switch (proptag) {
        case PR_INST_ID: // TODO: DOUBT
                llongValue = talloc_zero(memCtx, uint64_t);
                // *llongValue = 1;
                *llongValue = [childURL hash]; /* we return a unique id based on the url */
                *data = llongValue;
                break;
                // case PR_INST_ID: // TODO: DOUBT
        case PR_INSTANCE_NUM: // TODO: DOUBT
                longValue = talloc_zero(memCtx, uint32_t);
                *longValue = 0;
                *data = longValue;
                break;
        case PR_VD_VERSION:
                longValue = talloc_zero(memCtx, uint32_t);
                *longValue = 8; /* mandatory value... wtf? */
                *data = longValue;
                break;
        // case PR_DEPTH: // TODO: DOUBT
        //         longValue = talloc_zero(memCtx, uint32_t);
        //         *longValue = 1;
        //         *data = longValue;
        //         break;
        case PR_FID:
                llongValue = talloc_zero(memCtx, uint64_t);
                *llongValue = fid;
                *data = llongValue;
        case PR_MID:
                llongValue = talloc_zero(memCtx, uint64_t);
                *llongValue = [mapping idFromURL: childURL];
                if (*llongValue == NSNotFound) {
                        [mapping registerURL: childURL];
                        *llongValue = [mapping idFromURL: childURL];
                }
                *data = llongValue;
                break;

                /* those are queried while they really pertain to the
                   addressbook module */
// #define PR_OAB_LANGID                                       PROP_TAG(PT_LONG      , 0x6807) /* 0x68070003 */
                // case PR_OAB_NAME_UNICODE:
                // case PR_OAB_CONTAINER_GUID_UNICODE:

// 0x68420102  PidTagScheduleInfoDelegatorWantsCopy (BOOL)


        default:
                rc = [self getCommonTableChildproperty: data
                                                 atURL: childURL
                                               withTag: proptag
                                              inFolder: folder
                                               withFID: fid];
        }

        return rc;
}

- (NSString *) _parentURLFromURL: (NSString *) urlString
{
        NSString *newURL;
        NSArray *parts;
        NSMutableArray *newParts;

        parts = [urlString componentsSeparatedByString: @"/"];
        if ([parts count] > 3) {
                newParts = [parts mutableCopy];
                [newParts autorelease];
                [newParts removeLastObject];
                newURL = [newParts componentsJoinedByString: @"/"];
        }
        else
                newURL = nil;

        return newURL;
}

- (int) getFolderTableChildproperty: (void **) data
                              atURL: (NSString *) childURL
                            withTag: (uint32_t) proptag
                           inFolder: (SOGoFolder *) folder
                            withFID: (uint64_t) fid
{
        // id child;
        uint64_t *llongValue;
        uint8_t *boolValue;
        uint32_t *longValue;
        struct Binary_r *binaryValue;
        int rc;
        NSString *parentURL;

        rc = MAPI_E_SUCCESS;
        switch (proptag) {
        case PR_FID:
                llongValue = talloc_zero(memCtx, uint64_t);
                *llongValue = [mapping idFromURL: childURL];
                if (*llongValue == NSNotFound) {
                        [mapping registerURL: childURL];
                        *llongValue = [mapping idFromURL: childURL];
                }
                *data = llongValue;
                break;
        case PR_PARENT_FID:
                llongValue = talloc_zero(memCtx, uint64_t);
                parentURL = [self _parentURLFromURL: childURL];
                if (parentURL) {
                        *llongValue = [mapping idFromURL: childURL];
                        if (*llongValue == NSNotFound) {
                                [mapping registerURL: childURL];
                                *llongValue = [mapping idFromURL: childURL];
                        }
                        *data = llongValue;
                }
                else {
                        *data = NULL;
                        rc = MAPISTORE_ERR_NOT_FOUND;
                }
                break;
        case PR_ATTR_HIDDEN:
        case PR_ATTR_SYSTEM:
        case PR_ATTR_READONLY:
                boolValue = talloc_zero(memCtx, uint8_t);
                *boolValue = NO;
                *data = boolValue;
                break;
        case PR_SUBFOLDERS:
                boolValue = talloc_zero(memCtx, uint8_t);
                *boolValue = ([[self _subfolderKeysForFolderURL: childURL]
                                      count] > 0);
                *data = boolValue;
                break;
        case PR_CONTENT_COUNT:
                longValue = talloc_zero(memCtx, uint32_t);
                *longValue = ([[self _messageKeysForFolderURL: childURL]
                                      count] > 0);
                *data = longValue;
                break;
        case PR_EXTENDED_FOLDER_FLAGS: // TODO: DOUBT: how to indicate the
                                       // number of subresponses ?
                binaryValue = talloc_zero(memCtx, struct Binary_r);
                *data = binaryValue;
                break;
        default:
                rc = [self getCommonTableChildproperty: data
                                                 atURL: childURL
                                               withTag: proptag
                                              inFolder: folder
                                               withFID: fid];
        }

        return rc;
}

- (int) getTableProperty: (void **) data
                 withTag: (uint32_t) proptag
              atPosition: (uint32_t) pos
           withTableType: (uint8_t) tableType
                   inFID: (uint64_t) fid
{
        NSArray *children;
        NSString *folderURL, *childURL, *childName;
        SOGoFolder *folder;
        int rc;

	[self logWithFormat: @"METHOD '%s' (%d) -- proptag: 0x%.8x, pos: %ld, tableType: %d, fid: %lld",
              __FUNCTION__, __LINE__, proptag, pos, tableType, fid];

        folderURL = [mapping urlFromID: fid];
        if (folderURL) {
                folder = [self lookupObject: folderURL];
                switch (tableType) {
                case MAPISTORE_FOLDER_TABLE:
                        children = [self _subfolderKeysForFolderURL: folderURL];
                        break;
                case MAPISTORE_MESSAGE_TABLE:
                        children = [self _messageKeysForFolderURL: folderURL];
                        break;
                default:
                        children = nil;
                        break;
                }

                if ([children count] > pos) {
                        childName = [children objectAtIndex: pos];
                        childURL = [folderURL stringByAppendingFormat: @"/%@",
                                              [childName stringByEscapingURL]];

                        if (tableType == MAPISTORE_FOLDER_TABLE) {
                                [self logWithFormat: @"  querying child folder at URL: %@", childURL];
                                rc = [self getFolderTableChildproperty: data
                                                                 atURL: childURL
                                                               withTag: proptag
                                                              inFolder: folder
                                                               withFID: fid];
                        }
                        else {
                                [self logWithFormat: @"  querying child message at URL: %@", childURL];
                                rc = [self getMessageTableChildproperty: data
                                                                  atURL: childURL
                                                                withTag: proptag
                                                               inFolder: folder
                                                                withFID: fid];
                        }
                        /* Unhandled: */
// #define PR_EXPIRY_TIME                                      PROP_TAG(PT_SYSTIME   , 0x0015) /* 0x00150040 */
// #define PR_REPLY_TIME                                       PROP_TAG(PT_SYSTIME   , 0x0030) /* 0x00300040 */
// #define PR_SENSITIVITY                                      PROP_TAG(PT_LONG      , 0x0036) /* 0x00360003 */
// #define PR_MESSAGE_DELIVERY_TIME                            PROP_TAG(PT_SYSTIME   , 0x0e06) /* 0x0e060040 */
// #define PR_FOLLOWUP_ICON                                    PROP_TAG(PT_LONG      , 0x1095) /* 0x10950003 */
// #define PR_ITEM_TEMPORARY_FLAGS                             PROP_TAG(PT_LONG      , 0x1097) /* 0x10970003 */
// #define PR_SEARCH_KEY                                       PROP_TAG(PT_BINARY    , 0x300b) /* 0x300b0102 */
// #define PR_CONTENT_COUNT                                    PROP_TAG(PT_LONG      , 0x3602) /* 0x36020003 */
// #define PR_CONTENT_UNREAD                                   PROP_TAG(PT_LONG      , 0x3603) /* 0x36030003 */
// #define PR_FID                                              PROP_TAG(PT_I8        , 0x6748) /* 0x67480014 */
// unknown 36de0003 http://social.msdn.microsoft.com/Forums/en-US/os_exchangeprotocols/thread/17c68add-1f62-4b68-9d83-f9ec7c1c6c9b
// unknown 819d0003
// unknown 81f80003
// unknown 81fa000b

                }
                else
                        rc = MAPISTORE_ERROR;
        }
        else {
                [self errorWithFormat: @"No url found for FID: %lld", fid];
                rc = MAPISTORE_ERR_NOT_FOUND;
        }

	return rc;
}


- (int) openMessage: (struct mapistore_message *) msg
            withMID: (uint64_t) mid
              inFID: (uint64_t) fid
{
	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	return MAPI_E_SUCCESS;
}

- (int) createMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
{
	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	return MAPI_E_SUCCESS;
}

- (int) saveChangesInMessageWithMID: (uint64_t) mid
                           andFlags: (uint8_t) flags
{
	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	return MAPI_E_SUCCESS;
}

- (int) submitMessageWithMID: (uint64_t) mid
                    andFlags: (uint8_t) flags
{
	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	return MAPI_E_SUCCESS;
}

- (int) getProperties: (struct SPropTagArray *) SPropTagArray
                inRow: (struct SRow *) aRow
              withMID: (uint64_t) fmid
                 type: (uint8_t) tableType
{
	[self logWithFormat: @"METHOD '%s' (%d) -- tableType: %d, mid: %lld",
              __FUNCTION__, __LINE__, tableType, fmid];

	switch (tableType) {
	case MAPISTORE_FOLDER:
		break;
	case MAPISTORE_MESSAGE:
		break;
	}

	return MAPI_E_SUCCESS;
}

- (int) getFID: (uint64_t *) fid
        byName: (const char *) foldername
   inParentFID: (uint64_t) parent_fid
{
	[self logWithFormat: @"METHOD '%s' (%d) -- foldername: %s, parent_fid: %lld",
              __FUNCTION__, __LINE__, foldername, parent_fid];

        return MAPISTORE_ERR_INVALID_PARAMETER;
}

- (int) setPropertiesWithMID: (uint64_t) fmid
                        type: (uint8_t) type
                       inRow: (struct SRow *) aRow
{
	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	switch (type) {
	case MAPISTORE_FOLDER:
		break;
	case MAPISTORE_MESSAGE:
		break;
	}

	return MAPI_E_SUCCESS;
}

- (int) deleteMessageWithMID: (uint64_t) mid
                   withFlags: (uint8_t) flags
{
	[self logWithFormat: @"METHOD '%s' (%d)", __FUNCTION__, __LINE__];

	return MAPI_E_SUCCESS;
}

@end
