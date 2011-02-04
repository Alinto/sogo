/* MAPIStoreContext.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSThread.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSString+Utilities.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>

#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreFolderTable.h"
#import "MAPIStoreFAIMessageTable.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSArray+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

/* TODO: homogenize method names and order of parameters */

@interface SOGoFolder (MAPIStoreProtocol)

- (BOOL) create;
- (NSException *) delete;

@end

@interface SOGoObject (MAPIStoreProtocol)

- (void) setMAPIProperties: (NSDictionary *) properties;
- (void) MAPISave;
- (void) MAPISubmit;

@end

@implementation MAPIStoreContext : NSObject

/* sogo://username:password@{contacts,calendar,tasks,journal,notes,mail}/dossier/id */

static Class SOGoObjectK, SOGoMailAccountK, SOGoMailFolderK;
static Class NSArrayK, NSDataK, NSStringK;

static MAPIStoreMapping *mapping;
static NSMutableDictionary *contextClassMapping;

+ (void) initialize
{
  NSArray *classes;
  Class currentClass;
  NSUInteger count, max;
  NSString *moduleName;

  SOGoObjectK = [SOGoObject class];
  SOGoMailAccountK = [SOGoMailAccount class];
  SOGoMailFolderK = [SOGoMailFolder class];
  NSArrayK = [NSArray class];
  NSDataK = [NSData class];
  NSStringK = [NSString class];

  mapping = [MAPIStoreMapping sharedMapping];

  contextClassMapping = [NSMutableDictionary new];
  classes = GSObjCAllSubclassesOfClass (self);
  max = [classes count];
  for (count = 0; count < max; count++)
    {
      currentClass = [classes objectAtIndex: count];
      moduleName = [currentClass MAPIModuleName];
      if (moduleName)
	{
	  [contextClassMapping setObject: currentClass
			       forKey: moduleName];
	  NSLog (@"  registered class '%@' as handler of '%@' contexts",
		 NSStringFromClass (currentClass), moduleName);
	}
    }
}

+ (NSString *) MAPIModuleName
{
  [self subclassResponsibility: _cmd];

  return nil;
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) storeMapping
{
}

- (Class) messageTableClass
{
  [self subclassResponsibility: _cmd];

  return Nil;
}

- (Class) folderTableClass
{
  return [MAPIStoreFolderTable class];
}

static inline MAPIStoreContext *
_prepareContextClass (struct mapistore_context *newMemCtx,
                      Class contextClass, NSString *completeURLString,
                      NSString *username, NSString *password)
{
  MAPIStoreContext *context;
  MAPIStoreAuthenticator *authenticator;
  static NSMutableDictionary *registration = nil;

  if (!registration)
    registration = [NSMutableDictionary new];

  if (![registration objectForKey: contextClass])
    {
      [contextClass registerFixedMappings: mapping];
      [registration setObject: [NSNull null]
                       forKey: contextClass];
    }

  context = [contextClass new];
  [context setURI: completeURLString andMemCtx: newMemCtx];
  [context autorelease];

  authenticator = [MAPIStoreAuthenticator new];
  [authenticator setUsername: username];
  [authenticator setPassword: password];
  [context setAuthenticator: authenticator];
  [authenticator release];

  [context setupRequest];
  [context setupModuleFolder];
  [context tearDownRequest];

  return context;
}

+ (id) contextFromURI: (const char *) newUri
             inMemCtx: (struct mapistore_context *) newMemCtx
{
  MAPIStoreContext *context;
  Class contextClass;
  NSString *module, *completeURLString, *urlString;
  NSURL *baseURL;

  NSLog (@"METHOD '%s' (%d) -- uri: '%s'", __FUNCTION__, __LINE__, newUri);

  context = nil;

  urlString = [NSString stringWithUTF8String: newUri];
  if (urlString)
    {
      completeURLString = [@"sogo://" stringByAppendingString: urlString];
      if (![completeURLString hasSuffix: @"/"])
	completeURLString = [completeURLString stringByAppendingString: @"/"];
      baseURL = [NSURL URLWithString: completeURLString];
      if (baseURL)
        {
          module = [baseURL host];
          if (module)
            {
              contextClass = [contextClassMapping objectForKey: module];
              if (contextClass)
                context = _prepareContextClass (newMemCtx,
                                                contextClass,
                                                completeURLString,
                                                [baseURL user],
                                                [baseURL password]);
              else
                NSLog (@"ERROR: unrecognized module name '%@'", module);
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
  if ((self = [super init]))
    {
      messages = [NSMutableDictionary new];
      woContext = [WOContext contextWithRequest: nil];
      [woContext retain];
      parentFoldersBag = [NSMutableArray new];
      moduleFolder = nil;
      faiModuleFolder = nil;
      uri = nil;
      messageTable = nil;
      faiTable = nil;
      folderTable = nil;
    }

  [self logWithFormat: @"-init"];

  return self;
}

- (void) dealloc
{
  [self logWithFormat: @"-dealloc"];

  [parentFoldersBag release];

  [messageTable release];
  [faiTable release];
  [folderTable release];

  [messages release];

  [moduleFolder release];
  [faiModuleFolder release];
  [woContext release];
  [authenticator release];

  [uri release];

  [super dealloc];
}

- (void) setURI: (NSString *) newUri
      andMemCtx: (struct mapistore_context *) newMemCtx
{
  ASSIGN (uri, newUri);
  memCtx = newMemCtx;

  faiModuleFolder = [SOGoMAPIFSFolder folderWithURL: [NSURL URLWithString: newUri]
				       andTableType: MAPISTORE_FAI_TABLE];
  [faiModuleFolder retain];
}

- (void) setAuthenticator: (MAPIStoreAuthenticator *) newAuthenticator
{
  ASSIGN (authenticator, newAuthenticator);
}

- (MAPIStoreAuthenticator *) authenticator
{
  return authenticator;
}

- (void) setupRequest
{
  NSMutableDictionary *info;

  [MAPIApp setMAPIStoreContext: self];
  info = [[NSThread currentThread] threadDictionary];
  [info setObject: woContext forKey: @"WOContext"];
}

- (void) tearDownRequest
{
  NSMutableDictionary *info;

  info = [[NSThread currentThread] threadDictionary];
  [info removeObjectForKey: @"WOContext"];
  [MAPIApp setMAPIStoreContext: nil];
}

- (void) setupModuleFolder
{
  [self subclassResponsibility: _cmd];
}

// - (void) _setNewLastObject: (id) newLastObject
// {
//   id currentObject, container;

//   if (newLastObject != lastObject)
//     {
//       currentObject = lastObject;
//       while (currentObject)
//         {
//           container = [currentObject container];
//           [currentObject release];
//           currentObject = container;
//         }

//       currentObject = newLastObject;
//       while (currentObject)
//         {
//           [currentObject retain];
//           currentObject = [currentObject container];
//         }

//       lastObject = newLastObject;
//     }
// }


- (id) _lookupObject: (NSString *) objectURLString
      fromBaseFolder: (SOGoFolder *) baseFolder
{
  id object;
  NSURL *objectURL;
  NSArray *path;
  int count, max;
  NSString *pathString, *nameInContainer;

  // [self logWithFormat: @"lookup of '%@'", objectURLString];
  objectURL = [NSURL URLWithString: objectURLString];
  if (objectURL)
    {
      object = baseFolder;
      pathString = [objectURL path];
      if ([pathString hasPrefix: @"/"])
        pathString = [pathString substringFromIndex: 1];
      if ([pathString length] > 0)
        {
          path = [pathString componentsSeparatedByString: @"/"];
          max = [path count];
          if (max > 0)
            {
              for (count = 0;
                   object && count < max;
                   count++)
                {
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
        }
  
      // [self _setNewLastObject: object];
      // ASSIGN (lastObjectURL, objectURLString);
    }
  else
    {
      object = nil;
      [self errorWithFormat: @"url string gave nil NSURL: '%@'", objectURLString];
    }

  [woContext setClientObject: object];

  return object;
}

- (id) lookupObject: (NSString *) objectURLString
{
  if (!moduleFolder)
    [NSException raise: @"MAPIStoreIOException"
		format: @"no moduleFolder set for context"];

  return [self _lookupObject: objectURLString
	      fromBaseFolder: moduleFolder];
}

- (id) lookupFAIObject: (NSString *) objectURLString
{
  if (!faiModuleFolder)
    [NSException raise: @"MAPIStoreIOException"
		format: @"no moduleFolder set for context"];

  return [self _lookupObject: objectURLString
	      fromBaseFolder: faiModuleFolder];
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
  for (i = 0; !folderName && i < aRow->cValues; i++)
    {
      if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME_UNICODE)
        folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszW];
      else if (aRow->lpProps[i].ulPropTag == PR_DISPLAY_NAME)
        folderName = [NSString stringWithUTF8String: aRow->lpProps[i].value.lpszA];
    }

  if (folderName)
    {
      parentFolder = [self lookupObject: parentFolderURL];
      if (parentFolder)
        {
          if ([parentFolder isKindOfClass: SOGoMailAccountK]
              || [parentFolder isKindOfClass: SOGoMailFolderK])
            {
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
  else
    {
      parentFolderURL = [mapping urlFromID: parentFID];
      if (!parentFolderURL)
        [self errorWithFormat: @"No url found for FID: %lld", parentFID];
      if (parentFolderURL)
        {
          folderURL = [self _createFolder: aRow inParentURL: parentFolderURL];
          if (folderURL)
            {
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
  [self logWithFormat: @"UNIMPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_ERROR;
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
  [self logWithFormat:
	  @"UNIMPLEMENTED METHOD '%s' (%d):\n fid=0x%.16x, parentFID=0x%.16x",
	__FUNCTION__, __LINE__,
	(unsigned long long) fid,
	(unsigned long long) parentFID];

  return MAPISTORE_ERROR;
}


/**
   \details Close a folder from the sogo backend

   \param private_data pointer to the current sogo context

   \return MAPISTORE_SUCCESS on success, otherwise MAPISTORE_ERROR
*/
- (int) closeDir
{
  [self logWithFormat: @"UNIMNPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_SUCCESS;
}

/* TODO: should handle folder hierarchies */
- (MAPIStoreTable *) _tableForFID: (uint64_t) fid
		     andTableType: (uint8_t) tableType
{
  MAPIStoreTable *table;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    {
      if (!messageTable)
	{
	  messageTable = [[self messageTableClass] new];
	  [messageTable setContext: self
			withMemCtx: memCtx];
	  [messageTable setFolder: moduleFolder
			withURL: uri
			andFID: fid];
	}
      table = messageTable;
    }
  else if (tableType == MAPISTORE_FAI_TABLE)
    {
      if (!faiTable)
	{
	  faiTable = [MAPIStoreFAIMessageTable new];
	  [faiTable setContext: self
		    withMemCtx: memCtx];
	  [faiTable setFolder: faiModuleFolder
		    withURL: uri
		    andFID: fid];
	}
      table = faiTable;
    }
  else if (tableType == MAPISTORE_FOLDER_TABLE)
    {
      if (!folderTable)
	{
	  folderTable = [[self folderTableClass] new];
	  [folderTable setContext: self
		       withMemCtx: memCtx];
	  [folderTable setFolder: moduleFolder
			 withURL: uri
			  andFID: fid];
	}
      table = folderTable;
    }
  else
    {
      table = nil;
      [NSException raise: @"MAPIStoreIOException"
		   format: @"unsupported table type: %d", tableType];
    }

  return table;
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
  MAPIStoreTable *table;
  NSArray *keys;
  NSString *url;
  int rc;

  [self logWithFormat: @"METHOD '%s' (%d) -- tableType: %d",
	__FUNCTION__, __LINE__, tableType];

  // [self logWithFormat: @"context restriction state is: %@",
  // 	MAPIStringForRestrictionState (restrictionState)];
  // if (restriction)
  //   [self logWithFormat: @"  active qualifier: %@", restriction];

  // if (restrictionState == MAPIRestrictionStateAlwaysFalse)
  //   {
  //     *rowCount = 0;
  //     rc = MAPI_E_SUCCESS;
  //   }
  // else
  //   {
  url = [mapping urlFromID: fid];
  if (url)
    {
      table = [self _tableForFID: fid andTableType: tableType];
      keys = [table cachedChildKeys];
      *rowCount = [keys count];
      rc = MAPI_E_SUCCESS;
    }
  else
    {
      [self errorWithFormat: @"No url found for FID: %lld", fid];
      rc = MAPISTORE_ERR_NOT_FOUND;
    }
    // }
  [self logWithFormat: @"result: count = %d, rc = %d", *rowCount, rc];

  return rc;
}

// - (void) logRestriction: (struct mapi_SRestriction *) res
// 	      withState: (MAPIRestrictionState) state
// {
//   NSString *resStr;

//   resStr = MAPIStringForRestriction (res);

//   [self logWithFormat: @"%@  -->  %@", resStr, MAPIStringForRestrictionState (state)];
// }

- (int) setRestrictions: (const struct mapi_SRestriction *) res
		withFID: (uint64_t) fid
	   andTableType: (uint8_t) tableType
	 getTableStatus: (uint8_t *) tableStatus
{
  MAPIStoreTable *table;

  table = [self _tableForFID: fid andTableType: tableType];
  [table setRestrictions: res];
      
  return MAPISTORE_SUCCESS;
}

- (enum MAPISTATUS) getTableProperty: (void **) data
			     withTag: (enum MAPITAGS) propTag
			  atPosition: (uint32_t) pos
		       withTableType: (uint8_t) tableType
			andQueryType: (enum table_query_type) queryType
			       inFID: (uint64_t) fid
{
  NSArray *children, *restrictedChildren;
  NSString *folderURL, *childKey;
  MAPIStoreTable *table;
  const char *propName;
  int rc;

  propName = get_proptag_name (propTag);
  if (!propName)
    propName = "<unknown>";
  // [self logWithFormat: @"METHOD '%s' (%d) -- proptag: %s (0x%.8x), pos: %.8x,"
  // 	 @" tableType: %d, queryType: %d, fid: %.16x",
  // 	__FUNCTION__, __LINE__, propName, proptag, pos, tableType, queryType, fid];

  // [self logWithFormat: @"context restriction state is: %@",
  // 	MAPIStringForRestrictionState (restrictionState)];
  // if (restriction)
  //   [self logWithFormat: @"  active qualifier: %@", restriction];

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    {
      restrictedChildren = nil;
      table = [self _tableForFID: fid andTableType: tableType];
      if (queryType == MAPISTORE_PREFILTERED_QUERY)
	{
	  children = [table cachedRestrictedChildKeys];
	  restrictedChildren = nil;
	}
      else
	{
	  children = [table cachedChildKeys];
	  restrictedChildren = [table cachedRestrictedChildKeys];
	}
      
      if ([children count] > pos)
	{
	  childKey = [children objectAtIndex: pos];
	  
	  // TODO: the use of restrictedChildren might be optimized by
	  // making it a dictionary (hash versus linear search)
	  if (queryType == MAPISTORE_PREFILTERED_QUERY
	      || [restrictedChildren containsObject: childKey])
	    {
	      rc = [table getChildProperty: data
				    forKey: childKey
				   withTag: propTag];
	      if (rc == MAPI_E_SUCCESS && *data == NULL)
		{
		  [self errorWithFormat: @"both 'success' and NULL data"
			@" returned for proptag %s(0x%.8x)",
			propName, propTag];
		  rc = MAPI_E_NOT_FOUND;
		}
	    }
	  else
	    // [self logWithFormat:
	    // 	      @"child '%@' does not match active restriction",
	    // 	    childURL];
	    rc = MAPI_E_INVALID_OBJECT;
	}
      else
	{
	  // [self errorWithFormat:
	  // 	      @"Invalid row position %d for table type %d"
	  // 		  @" in FID: %lld",
	  // 	    pos, tableType, fid];
	  rc = MAPI_E_INVALID_OBJECT;
	}
    }
  else
    {
      [self errorWithFormat: @"No url found for FID: %lld", fid];
      rc = MAPI_E_INVALID_OBJECT;
    }

  return rc;
}

- (int) openMessage: (struct mapistore_message *) msg
	     forKey: (NSString *) childKey
	    inTable: (MAPIStoreTable *) table
{
  static enum MAPITAGS tags[] = { PR_SUBJECT_UNICODE, PR_HASATTACH,
				  PR_MESSAGE_DELIVERY_TIME, PR_MESSAGE_FLAGS,
				  PR_FLAG_STATUS, PR_SENSITIVITY,
				  PR_SENT_REPRESENTING_NAME_UNICODE,
				  PR_INTERNET_MESSAGE_ID_UNICODE,
				  PR_READ_RECEIPT_REQUESTED };
  struct SRowSet *recipients;
  struct SRow *properties;
  NSInteger count, max;
  const char *propName;
  void *propValue;

  // [self logWithFormat: @"INCOMPLETE METHOD '%s' (%d): no recipient handling",
  //       __FUNCTION__, __LINE__];

  recipients = talloc_zero (memCtx, struct SRowSet);
  recipients->cRows = 0;
  recipients->aRow = NULL;
  msg->recipients = recipients;

  max = 9;
  properties = talloc_zero (memCtx, struct SRow);
  properties->cValues = 0;
  properties->ulAdrEntryPad = 0;
  properties->lpProps = talloc_array (properties, struct SPropValue, max);
  for (count = 0; count < max; count++)
    {
      if ([table getChildProperty: &propValue
			   forKey: childKey
			  withTag: tags[count]]
	  == MAPI_E_SUCCESS)
	{
	  if (propValue == NULL)
	    {
	      propName = get_proptag_name (tags[count]);
	      if (!propName)
		propName = "<unknown>";
	      [self errorWithFormat: @"both 'success' and NULL data"
		    @" returned for proptag %s(0x%.8x)",
		    propName, tags[count]];
	    }
	  else
	    {
	      set_SPropValue_proptag (properties->lpProps + properties->cValues,
				      tags[count],
				      propValue);
	      properties->cValues++;
	    }
	}
    }
  msg->properties = properties;

  return MAPI_E_SUCCESS;
}

- (int) openMessage: (struct mapistore_message *) msg
            withMID: (uint64_t) mid
              inFID: (uint64_t) fid
{
  NSString *childURL, *childKey, *folderURL;
  MAPIStoreTable *table;
  BOOL isAssociated;
  int rc;

  childURL = [mapping urlFromID: mid];
  if (childURL)
    {
      childKey = [self extractChildNameFromURL: childURL
				andFolderURLAt: &folderURL];
      table = [self _tableForFID: fid andTableType: MAPISTORE_FAI_TABLE];
      if ([[table cachedChildKeys] containsObject: childKey])
	{
	  isAssociated = YES;
	  rc = [self openMessage: msg forKey: childKey inTable: table];
	}
      else
	{
	  isAssociated = NO;
	  table = [self _tableForFID: fid andTableType: MAPISTORE_MESSAGE_TABLE];
	  if ([[table cachedChildKeys] containsObject: childKey])
	    rc = [self openMessage: msg forKey: childKey inTable: table];
	  else
	    rc = MAPI_E_INVALID_OBJECT;
	}
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  if (rc == MAPI_E_SUCCESS)
    [self createMessagePropertiesWithMID: mid
				   inFID: fid
			    isAssociated: isAssociated];

  return rc;
}

- (int) createMessagePropertiesWithMID: (uint64_t) mid
                                 inFID: (uint64_t) fid
			  isAssociated: (BOOL) isAssociated
{
  NSMutableDictionary *messageProperties;
  NSNumber *midNbr;
  NSUInteger retainCount;

  messageProperties = [messages objectForKey:
				  [NSNumber numberWithUnsignedLongLong: mid]];
  if (messageProperties)
    {
      [self logWithFormat:
	      @"METHOD '%s' -- mid: 0x%.16x, fid: 0x%.16x; retainCount++",
	    __FUNCTION__, mid, fid];
      retainCount = [[messageProperties objectForKey: @"mapiRetainCount"]
		      unsignedIntValue];
      [messageProperties
	    setObject: [NSNumber numberWithUnsignedInt: retainCount + 1]
	       forKey: @"mapiRetainCount"];
    }
  else
    {
      [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, fid: 0x%.16x",
	    __FUNCTION__, mid, fid];
      messageProperties = [NSMutableDictionary new];
      [messageProperties setObject: [NSNumber numberWithUnsignedLongLong: fid]
			    forKey: @"fid"];
      midNbr = [NSNumber numberWithUnsignedLongLong: mid];
      [messageProperties setObject: midNbr forKey: @"mid"];
      [messageProperties setObject: [NSNumber numberWithBool: isAssociated]
			    forKey: @"associated"];
      [messageProperties setObject: [NSNumber numberWithInt: 1]
			    forKey: @"mapiRetainCount"];
      [messages setObject: messageProperties forKey: midNbr];
      [messageProperties release];
    }

  return MAPISTORE_SUCCESS;
}

- (id) createMessageOfClass: (NSString *) messageClass
	      inFolderAtURL: (NSString *) folderURL
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (id) _createMessageOfClass: (NSString *) messageClass
		  associated: (BOOL) associated
		     withMID: (uint64_t) mid
		       inFID: (uint64_t) fid
{
  NSString *folderURL, *messageURL;
  id message;

  message = nil;

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    {
      if (associated)
	{
	  message = [[self lookupFAIObject: folderURL] newMessage];
	  [faiTable cleanupCaches];
	}
      else
	{
	  message = [self createMessageOfClass: messageClass
				 inFolderAtURL: folderURL];
	  [messageTable cleanupCaches];
	}
      if (message)
	{
	  if (![folderURL hasSuffix: @"/"])
	    folderURL = [NSString stringWithFormat: @"%@/", folderURL];
	  messageURL = [NSString stringWithFormat: @"%@%@", folderURL,
				 [message nameInContainer]];
	  [mapping registerURL: messageURL withID: mid];
	}
      else
	[self errorWithFormat:
		@"no message created in folder '%.16x' with mid '%.16x'",
	      fid, mid];
    }
  else
    [self errorWithFormat: @"registered message without a valid fid (%.16x)", fid];

  return message;
}

- (int) _saveOrSubmitChangesInMessageWithMID: (uint64_t) mid
                                    andFlags: (uint8_t) flags
                                        save: (BOOL) isSave
{
  int rc;
  id message;
  NSMutableDictionary *messageProperties;
  NSString *messageURL;
  uint64_t fid;
  BOOL associated;

  messageProperties = [messages objectForKey:
                                  [NSNumber numberWithUnsignedLongLong: mid]];
  if (messageProperties)
    {
      if ([[messageProperties
	     objectForKey: MAPIPropertyKey (PR_MESSAGE_CLASS_UNICODE)]
	    isEqualToString: @"IPM.Schedule.Meeting.Request"])
	{
	  /* We silently discard invitation emails since this is already
	     handled internally by SOGo. */
	  rc = MAPISTORE_SUCCESS;
	}
      else
	{
	  messageURL = [mapping urlFromID: mid];
	  associated = [[messageProperties objectForKey: @"associated"] boolValue];
	  if (messageURL)
	    {
	      if (associated)
		message = [self lookupFAIObject: messageURL];
	      else
		message = [self lookupObject: messageURL];
	    }
	  else
	    {
	      fid = [[messageProperties objectForKey: @"fid"]
		      unsignedLongLongValue];
	      message = [self _createMessageOfClass: [messageProperties objectForKey: MAPIPropertyKey (PR_MESSAGE_CLASS_UNICODE)]
					 associated: associated
					    withMID: mid inFID: fid];
	    }
	  if (message)
	    {
	      if (associated)
		[faiTable cleanupCaches];
	      else
		[messageTable cleanupCaches];
	      
	      [message setMAPIProperties: messageProperties];
	      if (isSave)
		[message MAPISave];
	      else
		[message MAPISubmit];
	      rc = MAPISTORE_SUCCESS;
	    }
	  else
	    rc = MAPISTORE_ERROR;
	}
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) saveChangesInMessageWithMID: (uint64_t) mid
                           andFlags: (uint8_t) flags
{
  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, flags: 0x%x",
	__FUNCTION__, mid, flags];

  return [self _saveOrSubmitChangesInMessageWithMID: mid
                                           andFlags: flags
                                               save: YES];
}

- (int) submitMessageWithMID: (uint64_t) mid
                    andFlags: (uint8_t) flags
{
  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, flags: 0x%x",
	__FUNCTION__, mid, flags];

  return [self _saveOrSubmitChangesInMessageWithMID: mid
                                           andFlags: flags
                                               save: NO];
}

- (int) getProperties: (struct SPropTagArray *) sPropTagArray
          ofTableType: (uint8_t) tableType
                inRow: (struct SRow *) aRow
              withMID: (uint64_t) fmid
{
  MAPIStoreTable *table;
  NSArray *children;
  NSString *childURL, *folderURL, *childKey;
  NSInteger count;
  void *propValue;
  uint64_t fid;
  const char *propName;
  enum MAPITAGS tag;
  enum MAPISTATUS propRc;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, fmid, tableType];

  childURL = [mapping urlFromID: fmid];
  if (childURL)
    {
      childKey = [self extractChildNameFromURL: childURL
				andFolderURLAt: &folderURL];
      fid = [mapping idFromURL: folderURL];
      if (fid == NSNotFound)
	[NSException raise: @"MAPIStoreIOException"
		    format: @"no fid found for url '%@'", folderURL];
      
      table = [self _tableForFID: fid andTableType: tableType];
      children = [table cachedChildKeys];
      if ([children containsObject: childKey])
	{
	  aRow->lpProps = talloc_array (aRow, struct SPropValue,
					sPropTagArray->cValues);
	  for (count = 0; count < sPropTagArray->cValues; count++)
	    {
	      tag = sPropTagArray->aulPropTag[count];
	      
	      propValue = NULL;
	      propRc = [table getChildProperty: &propValue
					forKey: childKey
				       withTag: tag];
	      // propName = get_proptag_name (tag);
	      // if (!propName)
	      //   propName = "<unknown>";
	      // [self logWithFormat: @"  lookup of property %s (%.8x) returned %d",
	      // 	propName, tag, propRc];
	      
	      if (propRc == MAPI_E_SUCCESS && !propValue)
		{
		  propName = get_proptag_name (tag);
		  if (!propName)
		    propName = "<unknown>";
		  [self errorWithFormat: @"both 'success' and NULL data"
			@" returned for proptag %s(0x%.8x)",
			propName, tag];
		  propRc = MAPI_E_NOT_FOUND;
		}
	      
	      if (propRc != MAPI_E_SUCCESS)
		{
		  if (propValue)
		    talloc_free (propValue);
		  propValue = MAPILongValue (memCtx, propRc);
		  tag = (tag & 0xffff0000) | 0x000a;
		}
	      set_SPropValue_proptag (&(aRow->lpProps[aRow->cValues]),
				      tag, propValue);
	      aRow->cValues++;
	    }
	  rc = MAPI_E_SUCCESS;
	}
      else
	rc = MAPI_E_INVALID_OBJECT;
    }
  else
    {
      [self errorWithFormat: @"No url found for FMID: %lld", fmid];
      rc = MAPI_E_INVALID_OBJECT;
    }

  return rc;
}

- (int) getPath: (char **) path
         ofFMID: (uint64_t) fmid
  withTableType: (uint8_t) tableType
{
  int rc;
  NSString *objectURL;
  // TDB_DATA key, dbuf;

  objectURL = [mapping urlFromID: fmid];
  if (objectURL)
    {
      if ([objectURL hasPrefix: uri])
        {
          *path = [[objectURL substringFromIndex: 7]
		    asUnicodeInMemCtx: memCtx];
	  [self logWithFormat: @"found path '%s' for fmid %.16x",
		*path, fmid];		  
          rc = MAPISTORE_SUCCESS;
        }
      else
        {
	  [self logWithFormat: @"context (%@, %@) does not contain"
		@" found fmid: 0x%.16x",
		objectURL, uri, fmid];
          *path = NULL;
          rc = MAPI_E_NOT_FOUND;
        }
    }
  else
    {
      [self errorWithFormat: @"%s: you should *never* get here", __PRETTY_FUNCTION__];
      // /* attempt to populate our mapping dict with data from indexing.tdb */
      // key.dptr = (unsigned char *) talloc_asprintf (memCtx, "0x%.16llx",
      //                                               (long long unsigned int )fmid);
      // key.dsize = strlen ((const char *) key.dptr);

      // dbuf = tdb_fetch (memCtx->indexing_list->index_ctx->tdb, key);
      // talloc_free (key.dptr);
      // uri = talloc_strndup (memCtx, (const char *)dbuf.dptr, dbuf.dsize);
      *path = NULL;
      rc = MAPI_E_NOT_FOUND;
    }

  return rc;
}

- (int) getFID: (uint64_t *) fid
        byName: (const char *) foldername
   inParentFID: (uint64_t) parent_fid
{
  [self logWithFormat: @"METHOD '%s' (%d) -- foldername: %s, parent_fid: %lld",
        __FUNCTION__, __LINE__, foldername, parent_fid];

  return MAPISTORE_ERROR;
}

- (int) setPropertiesWithFMID: (uint64_t) fmid
                  ofTableType: (uint8_t) tableType
                        inRow: (struct SRow *) aRow
{
  NSMutableDictionary *message;
  NSNumber *midNbr;
  struct SPropValue *cValue;
  NSUInteger counter;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, fmid, tableType];

  switch (tableType)
    {
    case MAPISTORE_MESSAGE:
      midNbr = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midNbr];
      if (message)
	{
	  [self logWithFormat: @"fmid 0x%.16x found", fmid];
	  for (counter = 0; counter < aRow->cValues; counter++)
	    {
	      cValue = aRow->lpProps + counter;
	      [message setObject: NSObjectFromSPropValue (cValue)
                          forKey: MAPIPropertyKey (cValue->ulPropTag)];
	    }
	  [self logWithFormat: @"(%s) message props after op", __PRETTY_FUNCTION__];
	  MAPIStoreDumpMessageProperties (message);
	  rc = MAPISTORE_SUCCESS;
	}
      else
	{
	  [self errorWithFormat: @"fmid 0x%.16x *not* found (faking success)",
		fmid];
	  rc = MAPISTORE_SUCCESS;
	}
      break;
    case MAPISTORE_FOLDER:
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
            __FUNCTION__, tableType];
      rc = MAPISTORE_ERROR;
    }

  return rc;
}

- (int) setProperty: (enum MAPITAGS) property
	   withFMID: (uint64_t) fmid
	ofTableType: (uint8_t) tableType
	   fromFile: (NSFileHandle *) aFile
{
  NSMutableDictionary *message;
  NSNumber *midNbr;
  NSData *fileData;
  const char *propName;
  int rc;

  propName = get_proptag_name (property);
  if (!propName)
    propName = "<unknown>";
  [self logWithFormat: @"METHOD '%s' -- property: %s(%.8x), fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, propName, property, fmid, tableType];

  fileData = [aFile readDataToEndOfFile];
  switch (tableType)
    {
    case MAPISTORE_MESSAGE:
      midNbr = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midNbr];
      if (message)
	{
	  [message setObject: NSObjectFromStreamData (property, fileData)
		      forKey: MAPIPropertyKey (property)];
	  [self logWithFormat: @"(%s) message props after op", __PRETTY_FUNCTION__];
	  MAPIStoreDumpMessageProperties (message);
	  rc = MAPISTORE_SUCCESS;
	}
      else
        rc = MAPISTORE_ERR_NOT_FOUND;
      break;
    case MAPISTORE_FOLDER:
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
            __FUNCTION__, tableType];
      rc = MAPISTORE_ERROR;
    }

  return rc;
}

- (int) getProperty: (enum MAPITAGS) property
	   withFMID: (uint64_t) fmid
	ofTableType: (uint8_t) tableType
	   intoFile: (NSFileHandle *) aFile
{
  NSMutableDictionary *message;
  NSNumber *midNbr;
  NSData *fileData;
  const char *propName;
  enum MAPISTATUS rc;

  propName = get_proptag_name (property);
  if (!propName)
    propName = "<unknown>";
  [self logWithFormat: @"METHOD '%s' -- property: %s(%.8x), fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, propName, property, fmid, tableType];

  switch (tableType)
    {
    case MAPISTORE_MESSAGE:
      midNbr = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midNbr];
      if (message)
      	{
	  fileData = [message objectForKey: MAPIPropertyKey (property)];
	  /* TODO: only NSData is supported right now */
	  if (fileData)
	    {
	      [aFile writeData: fileData];
	      rc = MAPI_E_SUCCESS;
	    }
	  else
	    {
	      [self errorWithFormat: @"no data for property %s(%.8x)"
		    @" in mid %.16x", propName, fmid];
	      rc = MAPI_E_NOT_FOUND;
	    }
	}
      else
	{
	  [self errorWithFormat: @"no message found with mid %.16x", fmid];
	  rc = MAPI_E_INVALID_OBJECT;
	}
      break;
	
      // 	  [message setObject: NSObjectFromStreamData (property, fileData)
      // 		   forKey: MAPIPropertyNumber (property)];
      // 	  rc = MAPISTORE_SUCCESS;
      // 	}
      // else
    case MAPISTORE_FOLDER:
      [self errorWithFormat: @"%s: folder properties not handled yet",
            __FUNCTION__];
      rc = MAPI_E_NOT_FOUND;
      break;
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
            __FUNCTION__, tableType];
      rc = MAPI_E_INVALID_OBJECT;
    }

  return rc;
}

- (NSDictionary *) _convertRecipientFromRow: (struct RecipientRow *) row
{
  NSMutableDictionary *recipient;
  NSString *value;

  recipient = [NSMutableDictionary dictionaryWithCapacity: 5];

  if ((row->RecipientFlags & 0x07) == 1)
    {
      value = [NSString stringWithUTF8String: row->X500DN.recipient_x500name];
      [recipient setObject: value forKey: @"x500dn"];
    }

  switch ((row->RecipientFlags & 0x208))
    {
    case 0x08:
      // TODO: we cheat
      value = [NSString stringWithUTF8String: row->EmailAddress.lpszA];
      break;
    case 0x208:
      value = [NSString stringWithUTF8String: row->EmailAddress.lpszW];
      break;
    default:
      value = nil;
    }
  if (value)
    [recipient setObject: value forKey: @"email"];

  switch ((row->RecipientFlags & 0x210))
    {
    case 0x10:
      // TODO: we cheat
      value = [NSString stringWithUTF8String: row->DisplayName.lpszA];
      break;
    case 0x210:
      value = [NSString stringWithUTF8String: row->DisplayName.lpszW];
      break;
    default:
      value = nil;
    }
  if (value)
    [recipient setObject: value forKey: @"fullName"];

  return recipient;
}

- (int) modifyRecipientsWithMID: (uint64_t) mid
			 inRows: (struct ModifyRecipientRow *) rows
		      withCount: (NSUInteger) max
{
  static NSString *recTypes[] = { @"orig", @"to", @"cc", @"bcc" };
  NSMutableDictionary *message, *recipients;
  NSMutableArray *list;
  NSString *recType;
  struct ModifyRecipientRow *currentRow;
  NSUInteger count;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x", __FUNCTION__, mid];

  message = [messages
	      objectForKey: [NSNumber numberWithUnsignedLongLong: mid]];
  if (message)
    {
      recipients = [NSMutableDictionary new];
      [message setObject: recipients forKey: @"recipients"];
      [recipients release];
      for (count = 0; count < max; count++)
	{
	  currentRow = rows + count;

	  if (currentRow->RecipClass >= MAPI_ORIG
	      && currentRow->RecipClass < MAPI_BCC)
	    {
	      recType = recTypes[currentRow->RecipClass];
	      list = [recipients objectForKey: recType];
	      if (!list)
		{
		  list = [NSMutableArray new];
		  [recipients setObject: list forKey: recType];
		  [list release];
		}
	      [list addObject: [self _convertRecipientFromRow:
				       &(currentRow->RecipientRow)]];
	    }
	}
      rc = MAPISTORE_SUCCESS;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) deleteMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
                   withFlags: (uint8_t) flags
{
  NSString *childURL, *childKey;
  MAPIStoreTable *table;
  id message;
  int rc;

  [self logWithFormat: @"-deleteMessageWithMID: mid: 0x%.16x  flags: %d", mid, flags];
  
  childURL = [mapping urlFromID: mid];
  if (childURL)
    {
      [self logWithFormat: @"-deleteMessageWithMID: url (%@) found for object", childURL];

      childKey = [self extractChildNameFromURL: childURL
				andFolderURLAt: NULL];
      table = [self _tableForFID: fid andTableType: MAPISTORE_FAI_TABLE];
      if ([[table cachedChildKeys] containsObject: childKey])
        message = [self lookupFAIObject: childURL];
      else
	{
	  table = [self _tableForFID: fid andTableType: MAPISTORE_MESSAGE_TABLE];
	  if ([[table cachedChildKeys] containsObject: childKey])
            message = [self lookupObject: childURL];
	  else
            message = nil;
	}

      if (message)
        {
          if ([message delete])
            {
              rc = MAPISTORE_ERROR;
              [self logWithFormat: @"ERROR deleting object at URL: %@", childURL];
            }
          else 
            {
              [self logWithFormat: @"sucessfully deleted object at URL: %@", childURL];
              [mapping unregisterURLWithID: mid];
              rc = MAPISTORE_SUCCESS;
            }
        }
      else
        rc = MAPI_E_INVALID_OBJECT;
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) releaseRecordWithFMID: (uint64_t) fmid
		  ofTableType: (uint8_t) tableType
{
  NSNumber *midNbr;
  NSMutableDictionary *messageProperties;
  NSUInteger retainCount;
  int rc;

  switch (tableType)
    {
    case MAPISTORE_MESSAGE_TABLE:
      rc = MAPISTORE_SUCCESS;
      midNbr = [NSNumber numberWithUnsignedLongLong: fmid];
      messageProperties = [messages objectForKey: midNbr];
      if (messageProperties)
	{
	  retainCount = [[messageProperties objectForKey: @"mapiRetainCount"]
			  unsignedIntValue];
	  if (retainCount == 1)
	    {
	      [self logWithFormat: @"message with mid %.16x successfully removed"
		    @" from message cache",
		    fmid];
	      [messages removeObjectForKey: midNbr];
	    }
	  else
	    [messageProperties
	      setObject: [NSNumber numberWithUnsignedInt: retainCount - 1]
		 forKey: @"mapiRetainCount"];
	}
      else
	[self warnWithFormat: @"message with mid %.16x not found"
	      @" in message cache", fmid];
      break;
    case MAPISTORE_FOLDER_TABLE:
    default:
      [self errorWithFormat: @"%s: value of tableType not handled: %d",
	    __FUNCTION__, tableType];
      [self logWithFormat: @"  fmid: 0x%.16x  tableType: %d", fmid, tableType];
      
      rc = MAPISTORE_ERR_INVALID_PARAMETER;
    }

  return rc;
}

- (int) getFoldersList: (struct indexing_folders_list **) folders_list
              withFMID: (uint64_t) fmid
{
  int rc;
  NSString *currentURL;
  NSMutableArray *nsFolderList;
  uint64_t fid;

  [self logWithFormat: @"METHOD '%s' -- fmid: 0x%.16x", __FUNCTION__, fmid];

  rc = MAPI_E_SUCCESS;

  currentURL = [mapping urlFromID: fmid];
  if (currentURL && ![currentURL isEqualToString: uri]
      && [currentURL hasPrefix: uri])
    {
      nsFolderList = [NSMutableArray arrayWithCapacity: 32];
      [self extractChildNameFromURL: currentURL
		     andFolderURLAt: &currentURL];
      while (currentURL && rc == MAPI_E_SUCCESS
             && ![currentURL isEqualToString: uri])
        {
          fid = [mapping idFromURL: currentURL];
          if (fid == NSNotFound)
	    {
	      [self logWithFormat: @"no fid found for url '%@'", currentURL];
	      rc = MAPI_E_NOT_FOUND;
	    }
          else
            {
              [nsFolderList addObject: [NSNumber numberWithUnsignedLongLong: fid]];
	      [self extractChildNameFromURL: currentURL
			     andFolderURLAt: &currentURL];
            }
        }

      if (rc != MAPI_E_NOT_FOUND)
        {
          fid = [mapping idFromURL: uri];
	  [nsFolderList addObject: [NSNumber numberWithUnsignedLongLong: fid]];
	  [self logWithFormat: @"resulting folder list: %@", nsFolderList];
          *folders_list = [nsFolderList asFoldersListInCtx: memCtx];
        }
    }
  else
    rc = MAPI_E_NOT_FOUND;

  return rc;
}

/* utils */

- (void) registerValue: (id) value
	    asProperty: (enum MAPITAGS) property
		forURL: (NSString *) url
{
  /* TODO: this method is a hack to enable the saving of property values which
     need to be passed as streams. Must be removed after the
     getProperty/setProperty mechanisms have been rethought. */
  NSMutableDictionary *message;
  uint64_t fmid;
  NSNumber *midNbr;

  fmid = [mapping idFromURL: url];
  if (fmid != NSNotFound)
    {
      midNbr = [NSNumber numberWithUnsignedLongLong: fmid];
      message = [messages objectForKey: midNbr];
      if (!message)
	{
	  message = [NSMutableDictionary new];
	  [messages setObject: message forKey: midNbr];
	  [message release];
	  [message setObject: midNbr forKey: @"mid"];
	}
      [message setObject: value forKey: MAPIPropertyKey (property)];
    }
}

- (NSString *) extractChildNameFromURL: (NSString *) objectURL
			andFolderURLAt: (NSString **) folderURL;
{
  NSString *childKey;
  NSRange lastSlash;
  NSUInteger slashPtr;

  if ([objectURL hasSuffix: @"/"])
    objectURL = [objectURL substringToIndex: [objectURL length] - 2];
  lastSlash = [objectURL rangeOfString: @"/"
			       options: NSBackwardsSearch];
  if (lastSlash.location != NSNotFound)
    {
      slashPtr = NSMaxRange (lastSlash);
      childKey = [objectURL substringFromIndex: slashPtr];
      if ([childKey length] == 0)
	childKey = nil;
      if (folderURL)
	*folderURL = [objectURL substringToIndex: slashPtr];
    }
  else
    childKey = nil;

  return childKey;
}

@end
