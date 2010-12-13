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
#import <Foundation/NSValue.h>

#import <EOControl/EOQualifier.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoFolder.h>
#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailFolder.h>

#import "NSArray+MAPIStore.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSData+MAPIStore.h"

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"

#import "MAPIStoreContext.h"

#import "NSString+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <libmapiproxy.h>

/* TODO: homogenize method names and order of parameters */

@interface SOGoFolder (MAPIStoreProtocol)

- (BOOL) create;
- (NSException *) delete;

@end

@interface SOGoObject (MAPIStoreProtocol)

- (NSString *) davEntityTag;
- (NSString *) davContentLength;
- (void) setMAPIProperties: (NSDictionary *) properties;
- (void) MAPISave;
- (void) MAPISubmit;

@end

/* restriction helpers */
static NSString *
MAPIStringForRestrictionState (MAPIRestrictionState state)
{
  NSString *stateStr;

  if (state == MAPIRestrictionStateAlwaysTrue)
    stateStr = @"always true";
  else if (state == MAPIRestrictionStateAlwaysFalse)
    stateStr = @"always false";
  else
    stateStr = @"needs eval";

  return stateStr;
}

static NSString *
MAPIStringForRestriction (struct mapi_SRestriction *resPtr);

// static NSString *
// _MAPIIndentString(int indent)
// {
//   NSString *spaces;
//   char *buffer;

//   if (indent > 0)
//     {
//       buffer = malloc (indent + 1);
//       memset (buffer, 32, indent);
//       *(buffer+indent) = 0;
//       spaces = [NSString stringWithFormat: @"%s", buffer];
//       free (buffer);
//     }
//   else
//     spaces = @"";

//   return spaces;
// }

static NSString *
MAPIStringForAndRestriction (struct mapi_SAndRestriction *resAnd)
{
  NSMutableArray *restrictions;
  uint16_t count;

  restrictions = [NSMutableArray arrayWithCapacity: 8];
  for (count = 0; count < resAnd->cRes; count++)
    [restrictions addObject: MAPIStringForRestriction ((struct mapi_SRestriction *) resAnd->res + count)];

  return [NSString stringWithFormat: @"(%@)", [restrictions componentsJoinedByString: @" && "]];
}

static NSString *
MAPIStringForOrRestriction (struct mapi_SOrRestriction *resOr)
{
  NSMutableArray *restrictions;
  uint16_t count;

  restrictions = [NSMutableArray arrayWithCapacity: 8];
  for (count = 0; count < resOr->cRes; count++)
    [restrictions addObject: MAPIStringForRestriction ((struct mapi_SRestriction *) resOr->res + count)];

  return [NSString stringWithFormat: @"(%@)", [restrictions componentsJoinedByString: @" || "]];
}

static NSString *
MAPIStringForNotRestriction (struct mapi_SNotRestriction *resNot)
{
  return [NSString stringWithFormat: @"!(%@)",
		   MAPIStringForRestriction ((struct mapi_SRestriction *) &resNot->res)];
}

static NSString *
MAPIStringForContentRestriction (struct mapi_SContentRestriction *resContent)
{
  NSString *eqMatch, *caseMatch;
  id value;
  const char *propName;

  switch (resContent->fuzzy & 0xf)
    {
    case 0: eqMatch = @"eq"; break;
    case 1: eqMatch = @"substring"; break;
    case 2: eqMatch = @"prefix"; break;
    default: eqMatch = @"[unknown]";
    }

  switch (((resContent->fuzzy) >> 16) & 0xf)
    {
    case 0: caseMatch = @"fl"; break;
    case 1: caseMatch = @"nc"; break;
    case 2: caseMatch = @"ns"; break;
    case 4: caseMatch = @"lo"; break;
    default: caseMatch = @"[unknown]";
    }

  propName = get_proptag_name (resContent->ulPropTag);
  if (!propName)
    propName = "<unknown>";

  value = NSObjectFromMAPISPropValue (&resContent->lpProp);

  return [NSString stringWithFormat: @"%s(0x%.8x) %@,%@ %@",
		   propName, resContent->ulPropTag, eqMatch, caseMatch, value];
}

static NSString *
MAPIStringForExistRestriction (struct mapi_SExistRestriction *resExist)
{
  const char *propName;

  propName = get_proptag_name (resExist->ulPropTag);
  if (!propName)
    propName = "<unknown>";

  return [NSString stringWithFormat: @"%s(0x%.8x) IS NOT NULL", propName, resExist->ulPropTag];
}

static NSString *
MAPIStringForPropertyRestriction (struct mapi_SPropertyRestriction *resProperty)
{
  static NSString *operators[] = { @"<", @"<=", @">", @">=", @"==", @"!=",
				   @"=~" };
  NSString *operator;
  id value;
  const char *propName;

  propName = get_proptag_name (resProperty->ulPropTag);
  if (!propName)
    propName = "<unknown>";

  if (resProperty->relop > 0 && resProperty->relop < 6)
    operator = operators[resProperty->relop];
  else
    operator = [NSString stringWithFormat: @"<invalid op %d>", resProperty->relop];
  value = NSObjectFromMAPISPropValue (&resProperty->lpProp);

  return [NSString stringWithFormat: @"%s(0x%.8x) %@ %@",
		   propName, resProperty->ulPropTag, operator, value];
}

static NSString *
MAPIStringForBitmaskRestriction (struct mapi_SBitmaskRestriction *resBitmask)
{
  NSString *format;
  const char *propName;

  propName = get_proptag_name (resBitmask->ulPropTag);
  if (!propName)
    propName = "<unknown>";

  if (resBitmask->relMBR == 0)
    format = @"((%s(0x%.8x) & 0x%.8x))";
  else
    format = @"((^%s(0x%.8x) & 0x%.8x))";

  return [NSString stringWithFormat: format,
		   propName, resBitmask->ulPropTag, resBitmask->ulMask];
}

static NSString *
MAPIStringForRestriction (struct mapi_SRestriction *resPtr)
{
  NSString *restrictionStr;

  if (resPtr)
    {
      switch (resPtr->rt)
	{
	  // RES_CONTENT=(int)(0x3),
	  // RES_BITMASK=(int)(0x6),
	  // RES_EXIST=(int)(0x8),

	case 0: restrictionStr = MAPIStringForAndRestriction(&resPtr->res.resAnd); break;
	case 1: restrictionStr = MAPIStringForOrRestriction(&resPtr->res.resOr); break;
	case 2: restrictionStr = MAPIStringForNotRestriction(&resPtr->res.resNot); break;
	case 3: restrictionStr = MAPIStringForContentRestriction(&resPtr->res.resContent); break;
	case 4: restrictionStr = MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
	case 6: restrictionStr = MAPIStringForBitmaskRestriction(&resPtr->res.resBitmask); break;
	case 8: restrictionStr = MAPIStringForExistRestriction(&resPtr->res.resExist); break;
	  // case 5: MAPIStringForComparePropsRestriction(&resPtr->res.resCompareProps); break;
	  // case 7: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
	  // case 9: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
	  // case 10: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
	default:
	  restrictionStr
	    = [NSString stringWithFormat: @"[unhandled restriction type: %d]",
			resPtr->rt];
	}
    }
  else
    restrictionStr = @"[unrestricted]";

  return restrictionStr;
}

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
      messageCache = [NSMutableDictionary new];
      subfolderCache = [NSMutableDictionary new];
      messages = [NSMutableDictionary new];
      woContext = [WOContext contextWithRequest: nil];
      [woContext retain];
      parentFoldersBag = [NSMutableArray new];
      moduleFolder = nil;
      uri = nil;
      baseContextSet = NO;

      restrictedMessageCache = [NSMutableDictionary new];
      restrictionState = MAPIRestrictionStateAlwaysTrue;
      restriction = nil;
    }

  [self logWithFormat: @"-init"];

  return self;
}

- (void) dealloc
{
  [self logWithFormat: @"-dealloc"];

  [parentFoldersBag release];
  [restriction release];
  [restrictedMessageCache release];

  [messageCache release];
  [subfolderCache release];
  [messages release];

  [moduleFolder release];
  [woContext release];
  [authenticator release];

  [uri release];

  [super dealloc];
}

- (void) setURI: (NSString *) newUri
      andMemCtx: (struct mapistore_context *) newMemCtx
{
  struct loadparm_context *lpCtx;

  ASSIGN (uri, newUri);
  memCtx = newMemCtx;

  lpCtx = loadparm_init (newMemCtx);
  ldbCtx = mapiproxy_server_openchange_ldb_init (lpCtx);
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

- (id) lookupObject: (NSString *) objectURLString
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
      object = moduleFolder;
      if (!object)
	[NSException raise: @"MAPIStoreIOException"
		    format: @"no moduleFolder set for context"];

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

- (NSArray *) _messageKeysForFolderURL: (NSString *) folderURL
{
  NSArray *keys;
  SOGoFolder *folder;

  keys = [messageCache objectForKey: folderURL];
  if (!keys)
    {
      folder = [self lookupObject: folderURL];
      if (folder)
        keys = [self getFolderMessageKeys: folder
			matchingQualifier: nil];
      else
	keys = [NSArray array];
      [messageCache setObject: keys forKey: folderURL];
    }

  [self logWithFormat: @"message keys for '%@': %@", folderURL, keys];

  return keys;
}

- (NSArray *) _restrictedMessageKeysForFolderURL: (NSString *) folderURL
{
  NSArray *keys;
  SOGoFolder *folder;

  keys = [restrictedMessageCache objectForKey: folderURL];
  if (!keys)
    {
      folder = [self lookupObject: folderURL];
      if (folder)
        keys = [self getFolderMessageKeys: folder
			matchingQualifier: restriction];
      else
	keys = [NSArray array];
      [restrictedMessageCache setObject: keys forKey: folderURL];
    }

  [self logWithFormat: @"restricted message keys for '%@': %@", folderURL, keys];

  return keys;
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
		 matchingQualifier: (EOQualifier *) qualifier
{
  [self subclassResponsibility: _cmd];
  
  return nil;
}

- (NSArray *) _subfolderKeysForFolderURL: (NSString *) folderURL
{
  NSArray *keys;
  SOGoFolder *folder;

  keys = [subfolderCache objectForKey: folderURL];
  if (!keys)
    {
      folder = [self lookupObject: folderURL];
      if (folder)
        {
          keys = [folder toManyRelationshipKeys];
          if (!keys)
            keys = [NSArray array];
        }
      else
	keys = [NSArray array];
      [subfolderCache setObject: keys forKey: folderURL];
    }

  [self logWithFormat: @"folder keys for '%@': %@", folderURL, keys];

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

  [self logWithFormat: @"context restriction state is: %@",
	MAPIStringForRestrictionState (restrictionState)];
  if (restriction)
    [self logWithFormat: @"  active qualifier: %@", restriction];

  if (restrictionState == MAPIRestrictionStateAlwaysFalse)
    {
      *rowCount = 0;
      rc = MAPI_E_SUCCESS;
    }
  else
    {
      url = [mapping urlFromID: fid];
      if (url)
	{
	  if (tableType == MAPISTORE_FOLDER_TABLE)
	    ids = [self _subfolderKeysForFolderURL: url];
	  else
	    ids = [self _messageKeysForFolderURL: url];
	  
	  if ([ids isKindOfClass: NSArrayK])
	    *rowCount = [ids count];
	  else
	    *rowCount = 0;
	  rc = MAPI_E_SUCCESS;
	}
      else
	{
	  [self errorWithFormat: @"No url found for FID: %lld", fid];
	  rc = MAPISTORE_ERR_NOT_FOUND;
	}
    }
  [self logWithFormat: @"result: count = %d, rc = %d", *rowCount, rc];

  return rc;
}

- (enum MAPISTATUS) getCommonTableChildproperty: (void **) data
					  atURL: (NSString *) childURL
					withTag: (enum MAPITAGS) proptag
				       inFolder: (SOGoFolder *) folder
					withFID: (uint64_t) fid
{
  NSString *stringValue;
  id child;
  // uint64_t *llongValue;
  // uint32_t *longValue;
  int rc;
  const char *propName;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_DISPLAY_NAME_UNICODE:
      child = [self lookupObject: childURL];
      *data = [[child displayName] asUnicodeInMemCtx: memCtx];
      break;
    case PR_SEARCH_KEY:
      child = [self lookupObject: childURL];
      stringValue = [child nameInContainer];
      *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
		asBinaryInMemCtx: memCtx];
      break;
    default:
      // rc = MAPI_E_NOT_FOUND;
      // if ((proptag & 0x001F) == 0x001F)
      //   {
      propName = get_proptag_name (proptag);
      if (!propName)
	propName = "<unknown>";
      [self errorWithFormat: @"Unhandled value: %s (0x%.8x), childURL: %@",
	    propName, proptag, childURL];
      *data = NULL;
      // *data = [stringValue asUnicodeInMemCtx: memCtx];
      // rc = MAPI_E_SUCCESS;
      //   [self errorWithFormat: @"Unknown proptag (returned): %.8x for child '%@'",
      //         proptag, childURL];
      // }
      //   }
      // else
      //   {
      // *data = NULL;
      rc = MAPI_E_NOT_FOUND;
      break;
    }

  return rc;
}

- (enum MAPISTATUS) getMessageTableChildproperty: (void **) data
					   atURL: (NSString *) childURL
					 withTag: (enum MAPITAGS) proptag
					inFolder: (SOGoFolder *) folder
					 withFID: (uint64_t) fid
{
  int rc;
  uint32_t contextId;
  uint64_t mappingId;
  NSString *folderURL, *stringValue;
  id child;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_INST_ID: // TODO: DOUBT
      /* we return a unique id based on the url */
      *data = MAPILongLongValue (memCtx, [childURL hash]);
      break;
    case PR_INSTANCE_NUM: // TODO: DOUBT
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_ROW_TYPE: // TODO: DOUBT
      *data = MAPILongValue (memCtx, TBL_LEAF_ROW);
      break;
    case PR_DEPTH: // TODO: DOUBT
      *data = MAPILongLongValue (memCtx, 0);
      break;
    case PR_ACCESS: // TODO
      *data = MAPILongValue (memCtx, 0x02);
      break;
    case PR_ACCESS_LEVEL: // TODO
      *data = MAPILongValue (memCtx, 0x00000000);
      break;
    case PR_VD_VERSION:
      /* mandatory value... wtf? */
      *data = MAPILongValue (memCtx, 8);
      break;
    case PR_FID:
      *data = MAPILongLongValue (memCtx, fid);
      break;
    case PR_MID:
      mappingId = [mapping idFromURL: childURL];
      if (mappingId == NSNotFound)
        {
          openchangedb_get_new_folderID (ldbCtx, &mappingId);
          [mapping registerURL: childURL withID: mappingId];
          folderURL = [mapping urlFromID: fid];
          NSAssert (folderURL != nil,
                    @"folder URL is expected to be known here");
          contextId = 0;
          mapistore_search_context_by_uri (memCtx, [uri UTF8String] + 7,
                                           &contextId);
          NSAssert (contextId > 0, @"no matching context found");
          mapistore_indexing_record_add_mid (memCtx, contextId, mappingId);
        }
      *data = MAPILongLongValue (memCtx, mappingId);
      break;
    case PR_MESSAGE_CODEPAGE:
      *data = MAPILongValue (memCtx, 0x0000); // use folder object codepage
      break;
    case PR_MESSAGE_LOCALE_ID:
      *data = MAPILongValue (memCtx, 0x0409);
      break;
    case PR_MESSAGE_FLAGS: // TODO
      *data = MAPILongValue (memCtx, 0x02 | 0x20); // fromme + unmodified
      break;
    case PR_MESSAGE_SIZE: // TODO
      child = [self lookupObject: childURL];
      /* TODO: choose another name in SOGo for that method */
      *data = MAPILongValue (memCtx, [[child davContentLength] intValue]);
      break;
    case PR_MSG_STATUS: // TODO
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_SUBJECT_PREFIX_UNICODE: // TODO
      *data = [@"" asUnicodeInMemCtx: memCtx];
      break;
    case PR_IMPORTANCE: // TODO -> subclass?
      *data = MAPILongValue (memCtx, 1);
      break;
    case PR_PRIORITY: // TODO -> subclass?
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_SENSITIVITY: // TODO -> subclass in calendar
      *data = MAPILongValue (memCtx, 0);
      break;
    case PR_CHANGE_KEY:
      child = [self lookupObject: childURL];
      stringValue = [child davEntityTag];
      *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
		asShortBinaryInMemCtx: memCtx];
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
  if ([parts count] > 3)
    {
      newParts = [parts mutableCopy];
      [newParts autorelease];
      [newParts removeLastObject];
      [newParts addObject: @""];
      newURL = [newParts componentsJoinedByString: @"/"];
    }
  else
    newURL = nil;

  return newURL;
}

- (enum MAPISTATUS) getFolderTableChildproperty: (void **) data
					  atURL: (NSString *) childURL
					withTag: (enum MAPITAGS) proptag
				       inFolder: (SOGoFolder *) folder
					withFID: (uint64_t) fid
{
  // id child;
  // struct Binary_r *binaryValue;
  uint32_t contextId;
  uint64_t mappingId;
  int rc;
  NSString *folderURL;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_FID:
       mappingId = [mapping idFromURL: childURL];
       if (mappingId == NSNotFound)
         {
           openchangedb_get_new_folderID (ldbCtx, &mappingId);
           [mapping registerURL: childURL withID: mappingId];
           folderURL = [mapping urlFromID: fid];
           NSAssert (folderURL != nil,
                     @"folder URL is expected to be known here");
           contextId = 0;
           mapistore_search_context_by_uri (memCtx, [uri UTF8String] + 7,
                                            &contextId);
           NSAssert (contextId > 0, @"no matching context found");
           mapistore_indexing_record_add_fid (memCtx, contextId, mappingId);
         }
        //   mappingId = [mapping idFromURL: childURL];
        // }
      *data = MAPILongLongValue (memCtx, mappingId);
      break;
    case PR_PARENT_FID:
      *data = MAPILongLongValue (memCtx, fid);
      break;
    case PR_ATTR_HIDDEN:
    case PR_ATTR_SYSTEM:
    case PR_ATTR_READONLY:
      *data = MAPIBoolValue (memCtx, NO);
      break;
    case PR_SUBFOLDERS:
      *data = MAPIBoolValue (memCtx,
                             [[self _subfolderKeysForFolderURL: childURL]
                               count] > 0);
      break;
    case PR_CONTENT_COUNT:
      *data = MAPILongValue (memCtx,
                             [[self _messageKeysForFolderURL: childURL]
                               count]);
      break;
    // case PR_EXTENDED_FOLDER_FLAGS: // TODO: DOUBT: how to indicate the
    //   // number of subresponses ?
    //   binaryValue = talloc_zero(memCtx, struct Binary_r);
    //   *data = binaryValue;
    //   break;
    default:
      rc = [self getCommonTableChildproperty: data
                                       atURL: childURL
                                     withTag: proptag
                                    inFolder: folder
                                     withFID: fid];
    }

  return rc;
}

- (void) logRestriction: (struct mapi_SRestriction *) res
	      withState: (MAPIRestrictionState) state
{
  NSString *resStr;

  resStr = MAPIStringForRestriction (res);

  [self logWithFormat: @"%@  -->  %@", resStr, MAPIStringForRestrictionState (state)];
}

- (MAPIRestrictionState) evaluateRestriction: (struct mapi_SRestriction *) res
			       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState state;

  switch (res->rt)
    {
      /* basic operators */
    case 0: state = [self evaluateAndRestriction: &res->res.resAnd
				   intoQualifier: qualifier];
      break;
    case 1: state = [self evaluateOrRestriction: &res->res.resOr
				  intoQualifier: qualifier];
      break;
    case 2: state = [self evaluateNotRestriction: &res->res.resNot
				   intoQualifier: qualifier];
      break;

      /* content restrictions */
    case 3: state = [self evaluateContentRestriction: &res->res.resContent
				       intoQualifier: qualifier];
      break;
    case 4: state = [self evaluatePropertyRestriction: &res->res.resProperty
					intoQualifier: qualifier];
      break;
    case 6: state = [self evaluateBitmaskRestriction: &res->res.resBitmask
				       intoQualifier: qualifier];
      break;
    case 8: state = [self evaluateExistRestriction: &res->res.resExist
				     intoQualifier: qualifier];
      break;
    // case 5: MAPIStringForComparePropsRestriction(&resPtr->res.resCompareProps); break;
    // case 7: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
    // case 9: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
    // case 10: MAPIStringForPropertyRestriction(&resPtr->res.resProperty); break;
    default:
      [NSException raise: @"MAPIStoreRestrictionException"
		  format: @"unhandled restriction type"];
      state = MAPIRestrictionStateAlwaysTrue;
    }

  [self logRestriction: res withState: state];

  return state;
}

- (MAPIRestrictionState) evaluateNotRestriction: (struct mapi_SNotRestriction *) res
				  intoQualifier: (EOQualifier **) qualifierPtr
{
  MAPIRestrictionState state, subState;
  EONotQualifier *qualifier;
  EOQualifier *subQualifier;

  subState = [self evaluateRestriction: (struct mapi_SRestriction *)&res->res
			 intoQualifier: &subQualifier];
  if (subState == MAPIRestrictionStateAlwaysTrue)
    state = MAPIRestrictionStateAlwaysFalse;
  else if (subState == MAPIRestrictionStateAlwaysFalse)
    state = MAPIRestrictionStateAlwaysTrue;
  else
    {
      state = MAPIRestrictionStateNeedsEval;
      qualifier = [[EONotQualifier alloc] initWithQualifier: subQualifier];
      [qualifier autorelease];
      *qualifierPtr = qualifier;
    }

  return state;
}

- (MAPIRestrictionState) evaluateAndRestriction: (struct mapi_SAndRestriction *) res
				  intoQualifier: (EOQualifier **) qualifierPtr
{
  MAPIRestrictionState state, subState;
  EOAndQualifier *qualifier;
  EOQualifier *subQualifier;
  NSMutableArray *subQualifiers;
  uint16_t count;

  state = MAPIRestrictionStateNeedsEval;

  subQualifiers = [NSMutableArray arrayWithCapacity: 8];
  for (count = 0;
       state == MAPIRestrictionStateNeedsEval && count < res->cRes;
       count++)
    {
      subState = [self evaluateRestriction: (struct mapi_SRestriction *) res->res + count
			     intoQualifier: &subQualifier];
      if (subState == MAPIRestrictionStateNeedsEval)
	[subQualifiers addObject: subQualifier];
      else if (subState == MAPIRestrictionStateAlwaysFalse)
	state = MAPIRestrictionStateAlwaysFalse;
    }

  if (state == MAPIRestrictionStateNeedsEval)
    {
      if ([subQualifiers count] == 0)
	state = MAPIRestrictionStateAlwaysTrue;
      else
	{
	  qualifier = [[EOAndQualifier alloc]
			initWithQualifierArray: subQualifiers];
	  [qualifier autorelease];
	  *qualifierPtr = qualifier;
	}
    }

  return state;
}

- (MAPIRestrictionState) evaluateOrRestriction: (struct mapi_SOrRestriction *) res
				 intoQualifier: (EOQualifier **) qualifierPtr
{
  MAPIRestrictionState state, subState;
  EOOrQualifier *qualifier;
  EOQualifier *subQualifier;
  NSMutableArray *subQualifiers;
  uint16_t count, falseCount;

  state = MAPIRestrictionStateNeedsEval;

  falseCount = 0;
  subQualifiers = [NSMutableArray arrayWithCapacity: 8];
  for (count = 0;
       state == MAPIRestrictionStateNeedsEval && count < res->cRes;
       count++)
    {
      subState = [self evaluateRestriction: (struct mapi_SRestriction *) res->res + count
			     intoQualifier: &subQualifier];
      if (subState == MAPIRestrictionStateNeedsEval)
	[subQualifiers addObject: subQualifier];
      else if (subState == MAPIRestrictionStateAlwaysTrue)
	state = MAPIRestrictionStateAlwaysTrue;
      else
	falseCount++;
    }

  if (falseCount == res->cRes)
    state = MAPIRestrictionStateAlwaysFalse;
  else if ([subQualifiers count] == 0)
    state = MAPIRestrictionStateAlwaysTrue;

  if (state == MAPIRestrictionStateNeedsEval)
    {
      qualifier = [[EOOrQualifier alloc]
		    initWithQualifierArray: subQualifiers];
      [qualifier autorelease];
      *qualifierPtr = qualifier;
    }

  return state;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (void) _raiseUnhandledPropertyException: (enum MAPITAGS) property
{
  const char *propName;

  propName = get_proptag_name (property);
  if (!propName)
    propName = "<unknown>";
  [NSException raise: @"MAPIStoreUnhandledPropertyException"
	      format: @"property %s (%.8x) has no matching field name (%@)",
	       propName, property, self];
}

- (MAPIRestrictionState) evaluateContentRestriction: (struct mapi_SContentRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier
{
  NSString *property;
  SEL operator;
  id value;

  property = [self backendIdentifierForProperty: res->ulPropTag];
  if (!property)
    [self _raiseUnhandledPropertyException: res->ulPropTag];
  
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

  switch (res->fuzzy & 0xf)
    {
    case 0:
      operator = EOQualifierOperatorEqual;
      break;
    case 1:
      operator = EOQualifierOperatorLike;
      value = [NSString stringWithFormat: @"%%%@%%", value];
      break;
    case 2:
      operator = EOQualifierOperatorEqual;
      value = [NSString stringWithFormat: @"%@%%", value];
      break;
    default: [NSException raise: @"MAPIStoreInvalidOperatorException"
			 format: @"fuzzy operator value '%.4x' is invalid",
			  res->fuzzy];
    }

  *qualifier = [[EOKeyValueQualifier alloc] initWithKey: property
				       operatorSelector: EOQualifierOperatorCaseInsensitiveLike
						  value: value];
  [*qualifier autorelease];

  [self logWithFormat: @"%s: resulting qualifier: %@",
	__PRETTY_FUNCTION__, *qualifier];

  return MAPIRestrictionStateNeedsEval;
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  static SEL operators[] = { EOQualifierOperatorLessThan,
			     EOQualifierOperatorLessThanOrEqualTo,
			     EOQualifierOperatorGreaterThan,
			     EOQualifierOperatorGreaterThanOrEqualTo,
			     EOQualifierOperatorEqual,
			     EOQualifierOperatorNotEqual,
			     EOQualifierOperatorContains };
  SEL operator;
  id value;
  NSString *property;

  property = [self backendIdentifierForProperty: res->ulPropTag];
  if (!property)
    [self _raiseUnhandledPropertyException: res->ulPropTag];

  if (res->relop > 0 && res->relop < 6)
    operator = operators[res->relop];
  else
    {
      operator = NULL;
      [NSException raise: @"MAPIStoreRestrictionException"
		   format: @"unhandled operator type"];
    }

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  *qualifier = [[EOKeyValueQualifier alloc] initWithKey: property
				       operatorSelector: operator
						  value: value];
  [*qualifier autorelease];

  return MAPIRestrictionStateNeedsEval;
}

- (MAPIRestrictionState) evaluateBitmaskRestriction: (struct mapi_SBitmaskRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier
{
  [self subclassResponsibility: _cmd];

  return MAPIRestrictionStateAlwaysTrue;
}

- (MAPIRestrictionState) evaluateExistRestriction: (struct mapi_SExistRestriction *) res
				    intoQualifier: (EOQualifier **) qualifier
{
  
  NSString *property;

  property = [self backendIdentifierForProperty: res->ulPropTag];
  if (!property)
    [self _raiseUnhandledPropertyException: res->ulPropTag];

  *qualifier = [[EOKeyValueQualifier alloc] initWithKey: property
				       operatorSelector: EOQualifierOperatorNotEqual
						  value: nil];
  [*qualifier autorelease];

  return MAPIRestrictionStateNeedsEval;
}

- (int) setRestrictions: (struct mapi_SRestriction *) res
		withFID: (uint64_t) fid
	   andTableType: (uint8_t) type
	 getTableStatus: (uint8_t *) tableStatus
{
  NSString *folderURL;

  NSLog (@"set restriction to (table type: %d): %@",
	 type, MAPIStringForRestriction (res));

  [restriction release];
  if (res)
    restrictionState = [self evaluateRestriction: res
				   intoQualifier: &restriction];
  else
    restrictionState = MAPIRestrictionStateAlwaysTrue;

  if (restrictionState == MAPIRestrictionStateNeedsEval)
    [restriction retain];
  else
    restriction = nil;

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    [restrictedMessageCache removeObjectForKey: folderURL];

  if (restriction)
    [self logWithFormat: @"  resulting EOQualifier: %@", restriction];

  return MAPISTORE_SUCCESS;
}

- (enum MAPISTATUS) getTableProperty: (void **) data
			     withTag: (enum MAPITAGS) proptag
			  atPosition: (uint32_t) pos
		       withTableType: (uint8_t) tableType
			andQueryType: (enum table_query_type) queryType
			       inFID: (uint64_t) fid
{
  NSArray *children, *restrictedChildren;
  NSString *folderURL, *childURL, *childName;
  SOGoFolder *folder;
  const char *propName;
  int rc;

  propName = get_proptag_name (proptag);
  if (!propName)
    propName = "<unknown>";
  [self logWithFormat: @"METHOD '%s' (%d) -- proptag: %s (0x%.8x), pos: %.8x,"
	 @" tableType: %d, queryType: %d, fid: %.16x",
	__FUNCTION__, __LINE__, propName, proptag, pos, tableType, queryType, fid];

  [self logWithFormat: @"context restriction state is: %@",
  	MAPIStringForRestrictionState (restrictionState)];
  // if (restriction)
  //   [self logWithFormat: @"  active qualifier: %@", restriction];

  if (restrictionState == MAPIRestrictionStateAlwaysFalse)
    rc = MAPI_E_INVALID_OBJECT;
  else
    {
      folderURL = [mapping urlFromID: fid];
      if (folderURL)
	{
	  folder = [self lookupObject: folderURL];
	  restrictedChildren = nil;
	  if (tableType == MAPISTORE_FOLDER_TABLE)
	    {
	      if (queryType != MAPISTORE_PREFILTERED_QUERY)
		[NSException raise: @"MAPIStoreIOException"
			    format: @"filtering is not supported for folder tables"];
	      children = [self _subfolderKeysForFolderURL: folderURL];
	    }
	  else
	    { // MAPISTORE_MESSAGE_TABLE:
	      if (queryType == MAPISTORE_PREFILTERED_QUERY)
		children = [self _restrictedMessageKeysForFolderURL: folderURL];
	      else
		{
		  children = [self _messageKeysForFolderURL: folderURL];
		  restrictedChildren = [self _restrictedMessageKeysForFolderURL: folderURL];
		}
	    }

	  if ([children count] > pos)
	    {
	      childName = [[children objectAtIndex: pos] stringByEscapingURL];
	      if ([folderURL hasSuffix: @"/"])
		childURL = [folderURL stringByAppendingString: childName];
	      else
		childURL = [folderURL stringByAppendingFormat: @"/%@",
				      childName];

	      if (tableType == MAPISTORE_FOLDER_TABLE)
		{
		  [self logWithFormat: @"  querying child folder at URL: %@", childURL];
		  rc = [self getFolderTableChildproperty: data
						   atURL: childURL
						 withTag: proptag
						inFolder: folder
						 withFID: fid];
		}
	      else
		{
		  // TODO: the use of restrictedChildren might be optimized by
		  // making it a dictionary (hash versus linear search)
		  if (queryType == MAPISTORE_PREFILTERED_QUERY
		      || [restrictedChildren containsObject: childName])
		    {
		      // [self logWithFormat: @"  querying child message at URL: %@", childURL];
		      rc = [self getMessageTableChildproperty: data
							atURL: childURL
						      withTag: proptag
						     inFolder: folder
						      withFID: fid];
		    }
		  else
		    {
		      [self logWithFormat:
			      @"child '%@' does not match active restriction",
			    childURL];
		      rc = MAPI_E_INVALID_OBJECT;
		    }
		}
	      if (rc == MAPI_E_SUCCESS && *data == NULL)
		{
		  [self errorWithFormat: @"both 'success' and NULL data"
			@" returned for proptag %s(0x%.8x)",
			propName, proptag];
		  rc = MAPI_E_NOT_FOUND;
		}
	    }
	  else
	    {
	      [self errorWithFormat:
		      @"Invalid row position %d for table type %d"
			  @" in FID: %lld",
		    pos, tableType, fid];
	      rc = MAPI_E_INVALID_OBJECT;
	    }
	}
      else
	{
	  [self errorWithFormat: @"No url found for FID: %lld", fid];
	  rc = MAPI_E_INVALID_OBJECT;
	}
    }

  return rc;
}

- (int) openMessage: (struct mapistore_message *) msg
            withMID: (uint64_t) mid
              inFID: (uint64_t) fid
{
  NSString *childURL;
  int rc;

  childURL = [mapping urlFromID: mid];
  if (childURL)
    {
      rc = [self openMessage: msg atURL: childURL];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) openMessage: (struct mapistore_message *) msg
              atURL: (NSString *) childURL
{
  [self logWithFormat: @"UNIMPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];

  return MAPISTORE_ERROR;
}

- (int) createMessagePropertiesWithMID: (uint64_t) mid
                                 inFID: (uint64_t) fid
{
  NSMutableDictionary *newMessage;
  NSNumber *midNbr;

  [self logWithFormat: @"METHOD '%s' -- mid: 0x%.16x, fid: 0x%.16x",
	__FUNCTION__, mid, fid];
  newMessage = [NSMutableDictionary new];
  [newMessage setObject: [NSNumber numberWithUnsignedLongLong: fid]
                 forKey: @"fid"];
  midNbr = [NSNumber numberWithUnsignedLongLong: mid];
  [newMessage setObject: midNbr forKey: @"mid"];
  [messages setObject: newMessage forKey: midNbr];
  [newMessage release];

  return MAPISTORE_SUCCESS;
}

- (id) createMessageInFolder: (id) parentFolder
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (id) _createMessageWithMID: (uint64_t) mid
                       inFID: (uint64_t) fid
{
  NSString *folderURL, *messageURL;
  SOGoFolder *parentFolder;
  id message;

  message = nil;

  folderURL = [mapping urlFromID: fid];
  if (folderURL)
    {
      parentFolder = [self lookupObject: folderURL];
      if (parentFolder)
        {
	  [self logWithFormat: @"%s: instantiate message in folder: %@",
		__PRETTY_FUNCTION__, folderURL];
          message = [self createMessageInFolder: parentFolder];
          if (message)
            {
              if (![folderURL hasSuffix: @"/"])
                folderURL = [NSString stringWithFormat: @"%@/", folderURL];
              messageURL = [NSString stringWithFormat: @"%@%@", folderURL,
                                     [message nameInContainer]];
              [mapping registerURL: messageURL withID: mid];

	      [messageCache removeObjectForKey: folderURL];
	      [restrictedMessageCache removeObjectForKey: folderURL];
            }
	  else
	    [self errorWithFormat:
		    @"no message created in folder '%.16x' with mid '%.16x'",
		  fid, mid];
        }
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
  BOOL viewMessage;

  viewMessage = NO;
  messageProperties = [messages objectForKey:
                                  [NSNumber numberWithUnsignedLongLong: mid]];
  if (messageProperties)
    {
      if ([[messageProperties
	     objectForKey: MAPIPropertyKey (PR_MESSAGE_CLASS_UNICODE)]
	  isEqualToString: @"IPM.Microsoft.FolderDesign.NamedView"])
	{
	  [self logWithFormat: @"ignored message with view data:"];
	  MAPIStoreDumpMessageProperties (messageProperties);
	  rc = MAPI_E_NO_SUPPORT;
	}
      else
	{
	  messageURL = [mapping urlFromID: mid];
	  if (messageURL)
	    message = [self lookupObject: messageURL];
	  else
	    {
	      fid = [[messageProperties objectForKey: @"fid"]
		      unsignedLongLongValue];
	      message = [self _createMessageWithMID: mid inFID: fid];
	    }
	  if (message)
	    {
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
  NSString *childURL;
  int rc;

  [self logWithFormat: @"METHOD '%s' -- fmid: 0x%.16x, tableType: %d",
	__FUNCTION__, fmid, tableType];

  childURL = [mapping urlFromID: fmid];
  if (childURL)
    {
      switch (tableType)
        {
        case MAPISTORE_MESSAGE:
          rc = [self getMessageProperties: sPropTagArray inRow: aRow
                                    atURL: childURL];
          break;
        case MAPISTORE_FOLDER:
        default:
          [self errorWithFormat: @"%s: value of tableType not handled: %d",
                __FUNCTION__, tableType];
          rc = MAPISTORE_ERROR;
          break;
        }
    }
  else
    {
      [self errorWithFormat: @"No url found for FMID: %lld", fmid];
      rc = MAPISTORE_ERR_NOT_FOUND;
    }

  return rc;
}

- (int) getMessageProperties: (struct SPropTagArray *) sPropTagArray
                       inRow: (struct SRow *) aRow
                       atURL: (NSString *) childURL
{
  id child;
  NSInteger count;
  void *propValue;
  const char *propName;
  enum MAPITAGS tag;
  enum MAPISTATUS propRc;
  int rc;

  child = [self lookupObject: childURL];
  if (child)
    {
      aRow->lpProps = talloc_array (aRow, struct SPropValue,
                                    sPropTagArray->cValues);
      for (count = 0; count < sPropTagArray->cValues; count++)
        {
          tag = sPropTagArray->aulPropTag[count];

	  propValue = NULL;
	  propRc = [self getMessageTableChildproperty: &propValue
						atURL: childURL
					      withTag: tag
					     inFolder: nil
					      withFID: 0];
	  propName = get_proptag_name (tag);
	  if (!propName)
	    propName = "<unknown>";
	  [self logWithFormat: @"  lookup of property %s (%.8x) returned %d",
		propName, tag, propRc];

	  if (propRc == MAPI_E_SUCCESS && !propValue)
	    [self errorWithFormat: @"both 'success' and NULL data returned"];
	  
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
    rc = MAPI_E_NOT_FOUND;

  return rc;
}

// struct indexing_context_list {
// 	struct tdb_wrap			*index_ctx;
// 	char				*username;
// 	uint32_t			ref_count;
// 	struct indexing_context_list	*prev;
// 	struct indexing_context_list	*next;
// };

// struct tdb_wrap {
// 	struct tdb_context	*tdb;
// 	const char		*name;
// 	struct tdb_wrap		*prev;
// 	struct tdb_wrap		*next;
// };

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
          rc = MAPISTORE_SUCCESS;
        }
      else
        {
	  [self logWithFormat: @"fmid 0x%.16x was found that is not"
		@" part of this context (%@, %@)",
		fmid, objectURL, uri];
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

  [self logWithFormat: @"getPath....  %.16x -> (%s, %d)", fmid, *path, rc];

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
	      cValue = &(aRow->lpProps[counter]);
	      [message setObject: NSObjectFromSPropValue (cValue)
                          forKey: MAPIPropertyKey (cValue->ulPropTag)];
	    }
	  [self logWithFormat: @"(%s) message props after op", __PRETTY_FUNCTION__];
	  MAPIStoreDumpMessageProperties (message);
	  rc = MAPISTORE_SUCCESS;
	}
      else
	{
	  [self errorWithFormat: @"fmid 0x%.16x *not* found", fmid];
	  rc = MAPISTORE_ERR_NOT_FOUND;
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
	  if (currentRow->RecipClass >= 0
	      && currentRow->RecipClass < 3)
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
                   withFlags: (uint8_t) flags
{
  [self logWithFormat: @"UNIMPLEMENTED METHOD '%s' (%d)", __FUNCTION__, __LINE__];
  [self logWithFormat: @"  mid: 0x%.16x  flags: %d", mid, flags];

  return MAPISTORE_ERROR;
}

- (int) releaseRecordWithFMID: (uint64_t) fmid
		  ofTableType: (uint8_t) tableType
{
  int rc;
  NSNumber *midNbr;

  switch (tableType)
    {
    case MAPISTORE_MESSAGE_TABLE:
      midNbr = [NSNumber numberWithUnsignedLongLong: fmid];
      if ([messages objectForKey: midNbr])
	{
	  [self logWithFormat: @"message with mid %.16x successfully removed"
		@" from message cache",
		fmid];
	  [messages removeObjectForKey: midNbr];
	  rc = MAPISTORE_SUCCESS;
	}
      else
	{
	  [self errorWithFormat: @"message with mid %.16x not found"
		@" in message cache",
		fmid];
	  rc = MAPISTORE_ERR_NOT_FOUND;
	}
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
      currentURL = [self _parentURLFromURL: currentURL];
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
              currentURL = [self _parentURLFromURL: currentURL];
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

@end
