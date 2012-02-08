/* SOGoGCSFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2004-2005 SKYRIX Software AG
 * Copyright (C) 2006-2010 Inverse inc.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <DOM/DOMElement.h>
#import <DOM/DOMProtocols.h>
#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <SaxObjC/XMLNamespaces.h>

#import "NSDictionary+Utilities.h"
#import "NSArray+Utilities.h"
#import "NSArray+DAV.h"
#import "NSObject+DAV.h"
#import "NSObject+Utilities.h"
#import "NSString+Utilities.h"
#import "NSString+DAV.h"

#import "DOMNode+SOGo.h"
#import "SOGoCache.h"
#import "SOGoContentObject.h"
#import "SOGoDomainDefaults.h"
#import "SOGoGroup.h"
#import "SOGoParentFolder.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"
#import "SOGoUserDefaults.h"
#import "SOGoUserSettings.h"
#import "SOGoUserManager.h"
#import "SOGoWebDAVAclManager.h"
#import "WORequest+SOGo.h"
#import "WOResponse+SOGo.h"

#import "SOGoGCSFolder.h"

static NSString *defaultUserID = @"<default>";
static NSArray *childRecordFields = nil;

@implementation SOGoGCSFolder

+ (void) initialize
{
  if (!childRecordFields)
    {
      childRecordFields = [NSArray arrayWithObjects: @"c_name", @"c_version",
				   @"c_creationdate", @"c_lastmodified",
				   @"c_component", @"c_content", nil];
      [childRecordFields retain];
    }
}

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;

  if (!aclManager)
    {
      aclManager = [SOGoWebDAVAclManager new];
      /*      [aclManager registerDAVPermission: davElement (@"read", @"DAV:")
		  abstract: YES
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"all", @"DAV:")];
      [aclManager registerDAVPermission: davElement (@"read-current-user-privilege-set", @"DAV:")
		  abstract: YES
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"read", @"DAV:")]; */
      [aclManager registerDAVPermission: davElement (@"write", @"DAV:")
		  abstract: NO
		  withEquivalent: SoPerm_AddDocumentsImagesAndFiles
		  asChildOf: davElement (@"all", @"DAV:")];
      [aclManager registerDAVPermission: davElement (@"bind", @"DAV:")
		  abstract: NO
		  withEquivalent: SoPerm_AddDocumentsImagesAndFiles
		  asChildOf: davElement (@"write", @"DAV:")];
      [aclManager registerDAVPermission: davElement (@"unbind", @"DAV:")
		  abstract: NO
		  withEquivalent: SoPerm_DeleteObjects
		  asChildOf: davElement (@"write", @"DAV:")];
      [aclManager
	registerDAVPermission: davElement (@"write-properties", @"DAV:")
	abstract: YES
	withEquivalent: SoPerm_ChangePermissions /* hackish */
	asChildOf: davElement (@"write", @"DAV:")];
      [aclManager
	registerDAVPermission: davElement (@"write-content", @"DAV:")
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"write", @"DAV:")];
      [aclManager registerDAVPermission: davElement (@"admin", @"urn:inverse:params:xml:ns:inverse-dav")
		  abstract: YES
		  withEquivalent: nil
		  asChildOf: davElement (@"all", @"DAV:")];
      [aclManager
	registerDAVPermission: davElement (@"read-acl", @"DAV:")
	abstract: YES
	withEquivalent: SOGoPerm_ReadAcls
	asChildOf: davElement (@"admin", @"urn:inverse:params:xml:ns:inverse-dav")];
      [aclManager
	registerDAVPermission: davElement (@"write-acl", @"DAV:")
	abstract: YES
	withEquivalent: SoPerm_ChangePermissions
	asChildOf: davElement (@"admin", @"urn:inverse:params:xml:ns:inverse-dav")];
    }

  return aclManager;
}

+ (id) folderWithSubscriptionReference: (NSString *) reference
			   inContainer: (id) aContainer
{
  id newFolder;
  NSArray *elements, *pathElements;
  NSString *path, *objectPath, *login, *ocsName, *folderName;
  WOContext *localContext;
  BOOL localIsSubscription;

  elements = [reference componentsSeparatedByString: @":"];
  login = [elements objectAtIndex: 0];
  localContext = [[WOApplication application] context];
  objectPath = [elements objectAtIndex: 1];
  pathElements = [objectPath componentsSeparatedByString: @"/"];
  if ([pathElements count] > 1)
    ocsName = [pathElements objectAtIndex: 1];
  else
    ocsName = @"personal";

  path = [NSString stringWithFormat: @"/Users/%@/%@/%@",
		   login, [pathElements objectAtIndex: 0], ocsName];

  localIsSubscription = ![login isEqualToString:
				  [aContainer ownerInContext: localContext]];

  if (localIsSubscription)
    folderName = [NSString stringWithFormat: @"%@_%@",
			   [login asCSSIdentifier], ocsName];
  else
    folderName = ocsName;
  
  newFolder = [self objectWithName: folderName inContainer: aContainer];
  [newFolder setOCSPath: path];
  [newFolder setOwner: login];
  [newFolder setIsSubscription: localIsSubscription];
  if (![newFolder displayName])
    newFolder = nil;

  return newFolder;
}

- (id) init
{
  if ((self = [super init]))
    {
      ocsPath = nil;
      ocsFolder = nil;
      childRecords = [NSMutableDictionary new];
      userCanAccessAllObjects = NO;
    }

  return self;
}

- (void) dealloc
{
  [ocsFolder release];
  [ocsPath release];
  [childRecords release];
  [super dealloc];
}

/* accessors */

- (void) setFolderPropertyValue: (id) theValue
                     inCategory: (NSString *) theKey
{
  SOGoUserSettings *settings;
  NSMutableDictionary *folderSettings, *values;
  NSString *module;

  settings = [[context activeUser] userSettings];
  module = [container nameInContainer];
  folderSettings = [settings objectForKey: module];
  if (!folderSettings)
    {
      folderSettings = [NSMutableDictionary dictionary];
      [settings setObject: folderSettings forKey: module];
    }
  values = [folderSettings objectForKey: theKey];
  if (theValue)
    {
      if (!values)
	{
	  // Create the property dictionary
	  values = [NSMutableDictionary dictionary];
	  [folderSettings setObject: values forKey: theKey];
	}
      [values setObject: theValue forKey: [self folderReference]];
    }
  else if (values)
    {
      // Remove the property for the folder
      [values removeObjectForKey: [self folderReference]];
      if ([values count] == 0)
	// Also remove the property dictionary when empty
	[folderSettings removeObjectForKey: theKey];
    }

  [settings synchronize];
}

- (id) folderPropertyValueInCategory: (NSString *) theKey
{
  return [self folderPropertyValueInCategory: theKey
				     forUser: [context activeUser]];
}

- (id) folderPropertyValueInCategory: (NSString *) theKey
			     forUser: (SOGoUser *) theUser
{
  SOGoUserSettings *settings;
  NSDictionary *folderSettings;
  id value;

  settings = [theUser userSettings];
  folderSettings = [settings objectForKey: [container nameInContainer]];
  value = [[folderSettings objectForKey: theKey]
            objectForKey: [self folderReference]];

  return value;
}

- (void) _setDisplayNameFromRow: (NSDictionary *) row
{
  NSString *primaryDN;
  NSDictionary *ownerIdentity;

  primaryDN = [row objectForKey: @"c_foldername"];
  if ([primaryDN length])
    {
      displayName = [NSMutableString new];
      if ([primaryDN isEqualToString: [container defaultFolderName]])
	[displayName appendString: [self labelForKey: primaryDN
                                           inContext: context]];
      else
	[displayName appendString: primaryDN];

      if (!activeUserIsOwner)
	{
	  // We MUST NOT use SOGoUser instances here (by calling -primaryIdentity)
	  // as it'll load user defaults and user settings which is _very costly_
	  // since it involves JSON parsing and database requests
	  ownerIdentity = [[SOGoUserManager sharedUserManager]
			    contactInfosForUserWithUIDorEmail: owner];

	  [displayName appendFormat: @" (%@ <%@>)", [ownerIdentity objectForKey: @"cn"],
		       [ownerIdentity objectForKey: @"c_email"]];
	}
    }
}

/* This method fetches the display name defined by the owner, but is also the
   fallback when a subscriber has not redefined the display name yet in his
   environment. */
- (void) _fetchDisplayNameFromOwner
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql;
  NSArray *attrs;
  NSDictionary *row;

  cm = [GCSChannelManager defaultChannelManager];
  folderLocation
    = [[GCSFolderManager defaultFolderManager] folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if (fc)
    {
      sql
	= [NSString stringWithFormat: (@"SELECT c_foldername FROM %@"
				       @" WHERE c_path = '%@'"),
		    [folderLocation gcsTableName], ocsPath];
      [fc evaluateExpressionX: sql];
      attrs = [fc describeResults: NO];
      row = [fc fetchAttributes: attrs withZone: NULL];
      if (row)
	[self _setDisplayNameFromRow: row];
      [fc cancelFetch];
      [cm releaseChannel: fc];
    }
}

- (void) _fetchDisplayNameFromSubscriber
{
  displayName = [self folderPropertyValueInCategory: @"FolderDisplayNames"];
  [displayName retain];
}

- (NSString *) displayName
{
  if (!displayName)
    {
      if (activeUserIsOwner)
        [self _fetchDisplayNameFromOwner];
      else
        {
          [self _fetchDisplayNameFromSubscriber];
          if (!displayName)
            [self _fetchDisplayNameFromOwner];
        }
    }

  return displayName;
}

- (void) setOCSPath: (NSString *) _path
{
  if (![ocsPath isEqualToString:_path])
    {
      if (ocsPath)
	[self warnWithFormat: @"GCS path is already set! '%@'", _path];
      ASSIGN (ocsPath, _path);
    }
}

- (NSString *) ocsPath
{
  return ocsPath;
}

- (GCSFolderManager *) folderManager
{
  static GCSFolderManager *folderManager = nil;

  if (!folderManager)
    folderManager = [GCSFolderManager defaultFolderManager];

  return folderManager;
}

- (GCSFolder *) ocsFolderForPath: (NSString *) _path
{
  return [[self folderManager] folderAtPath: _path];
}

- (BOOL) folderIsMandatory
{
  return [nameInContainer isEqualToString: @"personal"];
}

- (NSString *) folderReference
{
  return [NSString stringWithFormat: @"%@:%@/%@",
		   owner,
		   [container nameInContainer],
		   [self realNameInContainer]];
}

- (NSArray *) pathArrayToFolder
{
  NSArray *basePathElements;
  unsigned int max;

  basePathElements = [[self ocsPath] componentsSeparatedByString: @"/"];
  max = [basePathElements count];

  return [basePathElements subarrayWithRange: NSMakeRange (2, max - 2)];
}

- (NSException *) setDavDisplayName: (NSString *) newName
{
  NSException *error;

  if ([newName length])
    {
      [self renameTo: newName];
      error = nil;
    }
  else
    error = [NSException exceptionWithHTTPStatus: 400
                                          reason: @"Empty string"];

  return error;
}

- (NSURL *) publicDavURL
{
  NSMutableArray *newPath;
  NSURL *davURL;

  davURL = [self realDavURL];
  newPath = [NSMutableArray arrayWithArray: [[davURL path] componentsSeparatedByString: @"/"]];
  [newPath insertObject: @"public" atIndex: 3];
  davURL = [[NSURL alloc] initWithScheme: [davURL scheme]
				    host: [davURL host]
				    path: [newPath componentsJoinedByString: @"/"]];

  return davURL;
}

- (NSURL *) realDavURL
{
  NSURL *realDavURL, *currentDavURL;
  NSString *appName, *publicParticle, *path;

  if (isSubscription)
    {
      appName = [[context request] applicationName];
      if ([self isInPublicZone])
        publicParticle = @"/public";
      else
        publicParticle = @"";
      path = [NSString stringWithFormat: @"/%@/dav%@/%@/%@/%@/",
                       appName, publicParticle,
                       [self ownerInContext: nil],
                       [container nameInContainer],
                       [self realNameInContainer]];
      currentDavURL = [self davURL];
      realDavURL = [[NSURL alloc] initWithScheme: [currentDavURL scheme]
                                            host: [currentDavURL host]
                                            path: path];
      [realDavURL autorelease];
    }
  else
    realDavURL = [self davURL];

  return realDavURL;
}

- (GCSFolder *) ocsFolder
{
  GCSFolder *folder;
  SOGoUser *user;
  NSString *userLogin;

  if (!ocsFolder)
    {
      ocsFolder = [self ocsFolderForPath: [self ocsPath]];
      user = [context activeUser];
      userLogin = [user login];
      if (!ocsFolder
	  && [userLogin isEqualToString: [self ownerInContext: context]]
          && [user canAuthenticate]
	  && [self folderIsMandatory]
	  && [self create])
	ocsFolder = [self ocsFolderForPath: [self ocsPath]];
      [ocsFolder retain];
    }

  if ([ocsFolder isNotNull])
    folder = ocsFolder;
  else
    folder = nil;

  return folder;
}

- (BOOL) create
{
  NSException *result;
  result = [[self folderManager] createFolderOfType: [self folderType]
				 withName: displayName
                                 atPath: ocsPath];

  if (!result
      && [[context request] handledByDefaultHandler])
    [self sendFolderAdvisoryTemplate: @"Addition"];

  return (result == nil);
}

- (NSException *) delete
{
  NSException *error;
  SOGoUserSettings *us;
  NSMutableDictionary *moduleSettings;

  // We just fetch our displayName since our table will use it!
  [self displayName];
  
  if ([nameInContainer isEqualToString: @"personal"])
    error = [NSException exceptionWithHTTPStatus: 403
			 reason: @"folder 'personal' cannot be deleted"];
  else
    error = [[self folderManager] deleteFolderAtPath: ocsPath];

  if (!error)
    {
      us = [[SOGoUser userWithLogin: owner] userSettings];
      moduleSettings = [us objectForKey: [container nameInContainer]];
      [self removeFolderSettings: moduleSettings
                   withReference: [self folderReference]];
      [us synchronize];

      if ([[context request] handledByDefaultHandler])
        [self sendFolderAdvisoryTemplate: @"Removal"];
    }

  return error;
}

- (void) _ownerRenameTo: (NSString *) newName
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql;

  cm = [GCSChannelManager defaultChannelManager];
  folderLocation
    = [[GCSFolderManager defaultFolderManager] folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if (fc)
    {
#warning GDLContentStore should provide methods for renaming folders
      sql
	= [NSString stringWithFormat: (@"UPDATE %@ SET c_foldername = '%@'"
				       @" WHERE c_path = '%@'"),
		    [folderLocation gcsTableName],
		    [newName stringByReplacingString: @"'"  withString: @"''"],
		    ocsPath];
      [fc evaluateExpressionX: sql];
      [cm releaseChannel: fc];
//       sql = [sql stringByAppendingFormat:@" WHERE %@ = '%@'", 
//                  uidColumnName, [self uid]];
    }
}

- (void) _subscriberRenameTo: (NSString *) newName
{
  if ([newName length])
    [self setFolderPropertyValue: newName
                      inCategory: @"FolderDisplayNames"];
}

- (void) renameTo: (NSString *) newName
{
#warning SOGoFolder should have the corresponding method
  [displayName release];
  displayName = nil;

  if (activeUserIsOwner)
    [self _ownerRenameTo: newName];
  else
    [self _subscriberRenameTo: newName];
}

/* Returns an empty string to indicate that the filter is empty and nil when
   the query should not even be performed. */
- (NSString *) aclSQLListingFilter
{
  NSString *filter, *login;
  NSArray *roles;
  SOGoUser *activeUser;

  activeUser = [context activeUser];
  login = [activeUser login];
  if (activeUserIsOwner
      || [[self ownerInContext: nil] isEqualToString: login]
      || ([activeUser respondsToSelector: @selector (isSuperUser)]
          && [activeUser isSuperUser]))
    filter = @"";
  else
    {
      roles = [self aclsForUser: login];
      if ([roles containsObject: SOGoRole_ObjectViewer]
          || [roles containsObject: SOGoRole_ObjectEditor])
        filter = @"";
      else
        filter = nil;
    }

  return filter;
}

- (NSArray *) toOneRelationshipKeys
{
  NSArray *records, *names;
  NSString *sqlFilter;
  EOQualifier *qualifier;

  sqlFilter = [self aclSQLListingFilter];
  if (sqlFilter)
    {
      if ([sqlFilter length] > 0)
        qualifier = [EOQualifier qualifierWithQualifierFormat: sqlFilter];
      else
        qualifier = nil;

      records = [[self ocsFolder] fetchFields: childRecordFields
                            matchingQualifier: qualifier];
      if (![records isNotNull])
        {
          [self errorWithFormat: @"(%s): fetch failed!", __PRETTY_FUNCTION__];
          return nil;
        }
      if ([records isKindOfClass: [NSException class]])
        return records;

      names = [records objectsForKey: @"c_name" notFoundMarker: nil];

      [childRecords release];
      childRecords = [[NSMutableDictionary alloc] initWithObjects: records
                                                          forKeys: names];
    }
  else
    names = [NSArray array];

  return names;
}

- (NSDictionary *) _recordForObjectName: (NSString *) objectName
{
  NSArray *records;
  EOQualifier *qualifier;
  NSDictionary *record;

  qualifier
    = [EOQualifier qualifierWithQualifierFormat:
                     [NSString stringWithFormat: @"c_name='%@'", objectName]];

  records = [[self ocsFolder] fetchFields: childRecordFields
                              matchingQualifier: qualifier];
  if (![records isKindOfClass: [NSException class]]
      && [records count])
    record = [records objectAtIndex: 0];
  else
    record = nil;

  return record;
}

- (BOOL) nameExistsInFolder: (NSString *) objectName
{
  NSDictionary *record;

  record = [self _recordForObjectName: objectName];

  return (record != nil);
}

- (void) removeChildRecordWithName: (NSString *) childName
{
  [childRecords removeObjectForKey: childName];
}

- (Class) objectClassForComponentName: (NSString *) componentName
{
  [self subclassResponsibility: _cmd];

  return Nil;
}

- (Class) objectClassForContent: (NSString *) content
{
  [self subclassResponsibility: _cmd];

  return Nil;
}

- (id) createChildComponentWithRecord: (NSDictionary *) record
{
  Class klazz;

  klazz = [self objectClassForComponentName:
                       [record objectForKey: @"c_component"]];

  return [klazz objectWithRecord: record inContainer: self];
}

- (id) createChildComponentWithName: (NSString *) newName
                         andContent: (NSString *) newContent
{
  Class klazz;
  NSDictionary *record;
  unsigned int now;
  NSNumber *nowNumber;

  klazz = [self objectClassForContent: newContent];
  now = [[NSCalendarDate calendarDate] timeIntervalSince1970];
  nowNumber = [NSNumber numberWithUnsignedInt: now];
  record = [NSDictionary dictionaryWithObjectsAndKeys: newName, @"c_name",
			 newContent, @"c_content",
			 nowNumber, @"c_creationdate",
			 nowNumber, @"c_lastmodified", nil];

  return [klazz objectWithRecord: record inContainer: self];
}

- (id) lookupName: (NSString *) key
        inContext: (WOContext *) localContext
          acquire: (BOOL) acquire
{
  id obj;
  NSDictionary *record;
  WORequest *request;

  obj = [super lookupName: key inContext: localContext acquire: acquire];
  if (!obj)
    {
      record = [childRecords objectForKey: key];
      if (!record)
	{
	  record = [self _recordForObjectName: key];
	  if (record)
	    [childRecords setObject: record forKey: key];
	}
      if (record)
	obj = [self createChildComponentWithRecord: record];
      else
	{
	  request = [localContext request];
	  if ([[request method] isEqualToString: @"PUT"])
	    {
	      obj = [self createChildComponentWithName: key
                                            andContent: [request contentAsString]];
	      [obj setIsNew: YES];
	    }
	}

      if (obj)
	[[SOGoCache sharedCache]
          registerObject: obj withName: key inContainer: self];
    }

  return obj;
}

- (void) deleteEntriesWithIds: (NSArray *) ids
{
  unsigned int count, max;
  NSString *currentID;
  SOGoContentObject *deleteObject;

  max = [ids count];
  for (count = 0; count < max; count++)
    {
      currentID = [ids objectAtIndex: count];
      deleteObject = [self lookupName: currentID
			   inContext: context
			   acquire: NO];
      if (![deleteObject isKindOfClass: [NSException class]])
	{
	  if ([deleteObject respondsToSelector: @selector (prepareDelete)])
	    [deleteObject prepareDelete];
	  [deleteObject delete];
	}
    }
}

- (NSString *) davCollectionTag
{
  NSCalendarDate *lmDate;

  lmDate = [[self ocsFolder] lastModificationDate];

  return [NSString stringWithFormat: @"%d",
                   (lmDate ? (int)[lmDate timeIntervalSince1970]
                    : -1)];
}

- (BOOL) userIsSubscriber: (NSString *) subscribingUser
{
  SOGoUser *sogoUser;
  NSDictionary *moduleSettings;
  NSArray *folderSubscription;

  sogoUser = [SOGoUser userWithLogin: subscribingUser];
  moduleSettings = [[sogoUser userSettings]
                     objectForKey: [container nameInContainer]];
  folderSubscription = [moduleSettings objectForKey: @"SubscribedFolders"];

  return [folderSubscription containsObject: [self folderReference]];
}

- (BOOL) subscribeUser: (NSString *) subscribingUser
              reallyDo: (BOOL) reallyDo
{
  NSMutableArray *folderSubscription;
  NSString *subscriptionPointer;
  SOGoUserSettings *us;
  NSMutableDictionary *moduleSettings;
  SOGoUser *sogoUser;
  BOOL rc;

  sogoUser = [SOGoUser userWithLogin: subscribingUser roles: nil];
  if (sogoUser)
    {
      us = [sogoUser userSettings];
      moduleSettings = [us objectForKey: [container nameInContainer]];
      if (!(moduleSettings
            && [moduleSettings isKindOfClass: [NSMutableDictionary class]]))
        {
          moduleSettings = [NSMutableDictionary dictionary];
          [us setObject: moduleSettings forKey: [container nameInContainer]];
        }

      folderSubscription
        = [moduleSettings objectForKey: @"SubscribedFolders"];
      subscriptionPointer = [self folderReference];

      if (reallyDo)
        {
          if (!(folderSubscription
                && [folderSubscription isKindOfClass: [NSMutableArray class]]))
            {
              folderSubscription = [NSMutableArray array];
              [moduleSettings setObject: folderSubscription
                                 forKey: @"SubscribedFolders"];
            }

          [folderSubscription addObjectUniquely: subscriptionPointer];
        }
      else
        {
          [self removeFolderSettings: moduleSettings
                       withReference: subscriptionPointer];
          [folderSubscription removeObject: subscriptionPointer];
        }

      [us synchronize];

      rc = YES;
    }
  else
    rc = NO;

  return rc;
}

- (void) removeFolderSettings: (NSMutableDictionary *) moduleSettings
                withReference: (NSString *) reference
{
  NSMutableDictionary *refDict;

  refDict = [moduleSettings objectForKey: @"FolderDisplayNames"];
  [refDict removeObjectForKey: reference];
}

- (NSArray *) _parseDAVDelegatedUsers
{
  id <DOMDocument> document;
  id <DOMNamedNodeMap> attrs;
  id o;

  document = [[context request] contentAsDOMDocument];
  attrs = [[document documentElement] attributes];

  o = [attrs namedItem: @"users"];

  if (o) return [[o nodeValue] componentsSeparatedByString: @","];

  return nil;
}

- (WOResponse *) _davSubscribe: (BOOL) reallyDo
{
  WOResponse *response;
  SOGoUser *currentUser;
  NSArray *delegatedUsers;
  NSString *userLogin;
  int count, max;

  response = [context response];
  [response setHeader: @"text/plain; charset=utf-8"
    forKey: @"Content-Type"];
  [response setStatus: 204];

  currentUser = [context activeUser];
  delegatedUsers = [self _parseDAVDelegatedUsers];

  max = [delegatedUsers count];
  if (max)
    {
      if ([currentUser isSuperUser])
        {
          /* We trust the passed user ID here as it might generate tons or
             LDAP call but more importantly, cache propagation calls that will
             create contention on GDNC. */
          for (count = 0; count < max; count++)
            [self subscribeUser: [delegatedUsers objectAtIndex: count]
                       reallyDo: reallyDo];
        }
      else
        {
          [response setStatus: 403];
          [response appendContentString: @"You cannot subscribe another user"
                    @" to any folder unless you are a super-user."];
        }
    }
  else
    {
      userLogin = [currentUser login];
      if ([owner isEqualToString: userLogin])
        {
          [response setStatus: 403];
          [response appendContentString:
                      @"You cannot (un)subscribe to a folder that you own!"];
        }
      else
        [self subscribeUser: userLogin reallyDo: reallyDo];
    }

  return response;
}

- (id <WOActionResults>) davSubscribe: (WOContext *) queryContext
{
  return [self _davSubscribe: YES];
}

- (id <WOActionResults>) davUnsubscribe: (WOContext *) queryContext
{
  return [self _davSubscribe: NO];
}

- (NSDictionary *) davSQLFieldsTable
{
  static NSMutableDictionary *davSQLFieldsTable = nil;

  if (!davSQLFieldsTable)
    {
      davSQLFieldsTable = [NSMutableDictionary new];
      [davSQLFieldsTable setObject: @"c_version" forKey: @"{DAV:}getetag"];
      [davSQLFieldsTable setObject: @"" forKey: @"{DAV:}getcontenttype"];
      [davSQLFieldsTable setObject: @"" forKey: @"{DAV:}resourcetype"];
    }

  return davSQLFieldsTable;
}

- (NSDictionary *) _davSQLFieldsForProperties: (NSArray *) properties
{
  NSMutableDictionary *davSQLFields;
  NSDictionary *davSQLFieldsTable;
  NSString *sqlField, *property;
  unsigned int count, max;

  davSQLFieldsTable = [self davSQLFieldsTable];

  max = [properties count];
  davSQLFields = [NSMutableDictionary dictionaryWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      property = [properties objectAtIndex: count];
      sqlField = [davSQLFieldsTable objectForKey: property];
      if (sqlField)
        [davSQLFields setObject: sqlField forKey: property];
      else
        [self errorWithFormat: @"DAV property '%@' has no matching SQL field,"
          @" response could be incomplete", property];
    }

  return davSQLFields;
}

- (NSDictionary *) parseDAVRequestedProperties: (DOMElement *) propElement
{
  NSArray *properties;
  NSDictionary *sqlFieldsTable;

  properties = [propElement flatPropertyNameOfSubElements];
  sqlFieldsTable = [self _davSQLFieldsForProperties: properties];

  return sqlFieldsTable;
}

/* make this a public method? */
- (NSArray *) _fetchFields: (NSArray *) fields
             withQualifier: (EOQualifier *) qualifier
             ignoreDeleted: (BOOL) ignoreDeleted
{
  GCSFolder *folder;
  EOFetchSpecification *fetchSpec;

  folder = [self ocsFolder];

  if (qualifier)
    fetchSpec = [EOFetchSpecification
      fetchSpecificationWithEntityName: [folder folderName]
                             qualifier: qualifier
                         sortOrderings: nil];
  else
    fetchSpec = nil;

  return [folder fetchFields: fields fetchSpecification: fetchSpec
               ignoreDeleted: ignoreDeleted];
}

- (NSString *) additionalWebdavSyncFilters
{
  return @"";
}

- (NSArray *) _fetchSyncTokenFields: (NSDictionary *) properties
                  matchingSyncToken: (NSString *) syncToken
{
  /* TODO:
     - validation:
       - synctoken and return "DAV:valid-sync-token" as error if needed
       - properties
       - database errors */
  NSMutableArray *fields, *mRecords;
  NSArray *records;
  EOQualifier *qualifier;
  NSEnumerator *addFields;
  NSString *currentField, *filter;
  int syncTokenInt;

  fields = [NSMutableArray arrayWithObjects: @"c_name", @"c_component",
         @"c_creationdate", @"c_lastmodified", nil];
  addFields = [[properties allValues] objectEnumerator];
  while ((currentField = [addFields nextObject]))
    if ([currentField length])
      [fields addObjectUniquely: currentField];

  if ([syncToken length])
    {
      syncTokenInt = [syncToken intValue];
      qualifier = [EOQualifier qualifierWithQualifierFormat:
                                 @"c_lastmodified > %d", syncTokenInt];
      mRecords = [NSMutableArray arrayWithArray: [self _fetchFields: fields
                                                      withQualifier: qualifier
                                                      ignoreDeleted: YES]];
      qualifier = [EOQualifier qualifierWithQualifierFormat:
                                 @"c_lastmodified > %d and c_deleted == 1",
                               syncTokenInt];
      fields = [NSMutableArray arrayWithObjects: @"c_name", @"c_deleted", nil];
      [mRecords addObjectsFromArray: [self _fetchFields: fields
                                          withQualifier: qualifier
                                          ignoreDeleted: NO]];
      records = mRecords;
    }
  else
    {
      filter = [self additionalWebdavSyncFilters];
      if ([filter length])
        qualifier = [EOQualifier qualifierWithQualifierFormat: filter];
      else
        qualifier = nil;
      records = [self _fetchFields: fields withQualifier: qualifier
                     ignoreDeleted: YES];
    }

  return records;
}

- (NSArray *) _davPropstatsWithProperties: (NSArray *) davProperties
                       andMethodSelectors: (SEL *) selectors
                               fromRecord: (NSDictionary *) record
{
  SOGoContentObject *sogoObject;
  unsigned int count, max;
  NSMutableArray *properties200, *properties404, *propstats;
  NSDictionary *propContent;
  id result;

  propstats = [NSMutableArray arrayWithCapacity: 2];

  max = [davProperties count];
  properties200 = [NSMutableArray arrayWithCapacity: max];
  properties404 = [NSMutableArray arrayWithCapacity: max];

  sogoObject = [self createChildComponentWithRecord: record];
  for (count = 0; count < max; count++)
    {
      if (selectors[count]
          && [sogoObject respondsToSelector: selectors[count]])
        result = [sogoObject performSelector: selectors[count]];
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

  if ([properties200 count])
    [propstats addObject: [properties200
                            asDAVPropstatWithStatus: @"HTTP/1.1 200 OK"]];
  if ([properties404 count])
    [propstats addObject: [properties404
                            asDAVPropstatWithStatus: @"HTTP/1.1 404 Not Found"]];

  return propstats;
}

- (NSDictionary *) _syncResponseWithProperties: (NSArray *) properties
                            andMethodSelectors: (SEL *) selectors
                                    fromRecord: (NSDictionary *) record
                                     withToken: (int) syncToken
                                    andBaseURL: (NSString *) baseURL
{
  static NSString *status[] = { @"HTTP/1.1 404 Not Found",
                                @"HTTP/1.1 201 Created",
                                @"HTTP/1.1 200 OK" };
  NSMutableArray *children;
  NSString *href;
  unsigned int statusIndex;

  children = [NSMutableArray arrayWithCapacity: 3];
  href = [NSString stringWithFormat: @"%@%@",
                   baseURL, [record objectForKey: @"c_name"]];
  [children addObject: davElementWithContent (@"href", XMLNS_WEBDAV,
                                              href)];
  if (syncToken)
    {
      if ([[record objectForKey: @"c_deleted"] intValue] > 0)
        statusIndex = 0;
      else
        {
          if ([[record objectForKey: @"c_creationdate"] intValue]
              >= syncToken)
            statusIndex = 1;
          else
            statusIndex = 2;
        }
    }
  else
    statusIndex = 1;

  //   NSLog (@"webdav sync: %@ (%@)", href, status[statusIndex]);
  [children addObject: davElementWithContent (@"status", XMLNS_WEBDAV,
                                              status[statusIndex])];
  if (statusIndex)
    [children
      addObjectsFromArray: [self _davPropstatsWithProperties: properties
                                          andMethodSelectors: selectors
                                                  fromRecord: record]];

  return davElementWithContent (@"sync-response", XMLNS_WEBDAV, children);
}

- (void) _appendComponentProperties: (NSArray *) properties
                        fromRecords: (NSArray *) records
                  matchingSyncToken: (int) syncToken
                         toResponse: (WOResponse *) response
{
  NSMutableArray *syncResponses;
  NSDictionary *multistatus, *record;
  unsigned int count, max, now;
  int newToken, currentLM;
  NSString *baseURL, *newTokenStr;
  SEL *selectors;

  max = [properties count];
  selectors = NSZoneMalloc (NULL, max * sizeof (SEL));
  for (count = 0; count < max; count++)
    selectors[count]
      = SOGoSelectorForPropertyGetter ([properties objectAtIndex: count]);

  now = (unsigned int) [[NSDate date] timeIntervalSince1970];

  newToken = 0;

  baseURL = [self davURLAsString];
#warning review this when fixing http://www.scalableogo.org/bugs/view.php?id=276
  if (![baseURL hasSuffix: @"/"])
    baseURL = [NSString stringWithFormat: @"%@/", baseURL];

  max = [records count];
  syncResponses = [NSMutableArray arrayWithCapacity: max + 1];
  for (count = 0; count < max; count++)
    {
      record = [records objectAtIndex: count];
      currentLM = [[record objectForKey: @"c_lastmodified"] intValue];
      if (newToken < currentLM)
        newToken = currentLM;
      [syncResponses addObject: [self _syncResponseWithProperties: properties
                                               andMethodSelectors: selectors
                                                       fromRecord: record
                                                        withToken: syncToken
                                                       andBaseURL: baseURL]];
    }

  NSZoneFree (NULL, selectors);

  /* If the most recent c_lastmodified is "now", we need to return "now - 1"
     in order to make sure during the next sync that every records that might
     get added at the same moment are not lost. */
  if (!newToken || newToken == now)
    newToken = now - 1;

  newTokenStr = [NSString stringWithFormat: @"%d", newToken];
  [syncResponses addObject: davElementWithContent (@"sync-token",
                                                   XMLNS_WEBDAV,
                                                   newTokenStr)];
  multistatus = davElementWithContent (@"multistatus", XMLNS_WEBDAV,
                                       syncResponses);
  [response
    appendContentString: [multistatus asWebDavStringWithNamespaces: nil]];
}

- (BOOL) _isValidSyncToken: (NSString *) syncToken
{
  unichar *characters;
  int count, max, value;
  BOOL valid;
  NSCalendarDate *lmDate;

  max = [syncToken length];
  if (max > 0)
    {
      characters = NSZoneMalloc (NULL, max * sizeof (unichar));
      [syncToken getCharacters: characters];
      if (max == 2
          && characters[0] == '-'
          && characters[1] == '1')
        valid = YES;
      else
        {
          lmDate = [[self ocsFolder] lastModificationDate];

          valid = YES;
          value = 0;
          for (count = 0; valid && count < max; count++)
            {
              if (characters[count] < '0'
                  || characters[count] > '9')
                valid = NO;
              else
                value = value * 10 + characters[count] - '0'; 
            }
          valid |= (value <= (int) [lmDate timeIntervalSince1970]);
        }
      NSZoneFree (NULL, characters);
    }
  else
    valid = YES;

  return valid;
}

- (WOResponse *) davSyncCollection: (WOContext *) localContext
{
  WOResponse *r;
  id <DOMDocument> document;
  DOMElement *documentElement, *propElement;
  NSString *syncToken;
  NSDictionary *properties;
  NSArray *records;

  r = [context response];
  [r prepareDAVResponse];

  document = [[context request] contentAsDOMDocument];
  documentElement = (DOMElement *) [document documentElement];
  syncToken = [[documentElement firstElementWithTag: @"sync-token"
                                        inNamespace: XMLNS_WEBDAV] textValue];
  if ([self _isValidSyncToken: syncToken])
    {
      propElement = [documentElement firstElementWithTag: @"prop"
                                             inNamespace: XMLNS_WEBDAV];
      properties = [self parseDAVRequestedProperties: propElement];
      records = [self _fetchSyncTokenFields: properties
                          matchingSyncToken: syncToken];
      [self _appendComponentProperties: [properties allKeys]
                           fromRecords: records
                     matchingSyncToken: [syncToken intValue]
                            toResponse: r];
    }
  else
    [r appendDAVError: davElement (@"valid-sync-token", XMLNS_WEBDAV)];

  return r;
}

/* handling acls from quick tables */
- (void) initializeQuickTablesAclsInContext: (WOContext *) localContext
{
  NSString *login;
  SOGoUser *activeUser;

  activeUser = [localContext activeUser];
  if (activeUserIsOwner)
    userCanAccessAllObjects = activeUserIsOwner;
  else
    {
      login = [activeUser login];
      /* we only grant "userCanAccessAllObjects" for role "ObjectEraser" and
         not "ObjectCreator" because the latter doesn't imply we can read
         properties from subobjects or even know their existence. */
      userCanAccessAllObjects
        = ([[self ownerInContext: localContext] isEqualToString: login]
           || ([activeUser respondsToSelector: @selector (isSuperUser)]
               && [activeUser isSuperUser]));
    }
}

/* acls as a container */

- (NSArray *) aclUsersForObjectAtPath: (NSArray *) objectPathArray;
{
  EOQualifier *qualifier;
  NSString *qs;
  NSArray *records, *uids;

  qs = [NSString stringWithFormat: @"c_object = '/%@'",
     [objectPathArray componentsJoinedByString: @"/"]];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
  records = [[self ocsFolder] fetchAclMatchingQualifier: qualifier];
  uids = [[records valueForKey: @"c_uid"] uniqueObjects];

  return uids;
}

- (NSArray *) _aclsFromUserRoles: (NSArray *) records
                     matchingUID: (NSString *) uid
{
  int count, max;
  NSDictionary *record;
  NSMutableArray *acls;
  NSString *currentUID;

  acls = [NSMutableArray array];

  max = [records count];
  for (count = 0; count < max; count++)
    {
      record = [records objectAtIndex: count];
      currentUID = [record valueForKey: @"c_uid"];
      if ([currentUID isEqualToString: uid])
        [acls addObject: [record valueForKey: @"c_role"]];
    }

  return acls;
}

- (NSArray *) _aclsFromGroupRoles: (NSArray *) records
                      matchingUID: (NSString *) uid
{
  int count, max;
  NSDictionary *record;
  NSString *currentUID, *domain;
  SOGoGroup *group;
  NSMutableArray *acls;

  acls = [NSMutableArray array];
#warning should it be the domain of the ownerUser instead?
  domain = [[context activeUser] domain];

  max = [records count];
  for (count = 0; count < max; count++)
    {
      record = [records objectAtIndex: count];
      currentUID = [record valueForKey: @"c_uid"];
      if ([currentUID hasPrefix: @"@"])
        {
	  group = [[SOGoCache sharedCache] groupNamed: currentUID  inDomain: domain];

	  if (!group)
	    {
	      group = [SOGoGroup groupWithIdentifier: currentUID
				 inDomain: domain];
	      [[SOGoCache sharedCache] registerGroup: group  withName: currentUID  inDomain: domain];
	    }

          if (group && [group hasMemberWithUID: uid])
            [acls addObject: [record valueForKey: @"c_role"]];
        }
    }

  return acls;
}

- (NSArray *) _fetchAclsForUser: (NSString *) uid
                forObjectAtPath: (NSString *) objectPath
{
  EOQualifier *qualifier;
  NSArray *records, *acls;
  NSString *qs;

  // We look for the exact uid or any uid that begins with "@" (corresponding to groups)
  qs = [NSString stringWithFormat: @"(c_object = '/%@') AND (c_uid = '%@' OR c_uid LIKE '@%%')",
                 objectPath, uid];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
  records = [[self ocsFolder] fetchAclMatchingQualifier: qualifier];

  acls = [self _aclsFromUserRoles: records matchingUID: uid];
  if (![acls count])
    acls = [self _aclsFromGroupRoles: records matchingUID: uid];

  return [acls uniqueObjects];
}

- (void) _cacheRoles: (NSArray *) roles
             forUser: (NSString *) uid
     forObjectAtPath: (NSString *) objectPath
{
  NSMutableDictionary *aclsForObject;

  aclsForObject = [[SOGoCache sharedCache] aclsForPath: objectPath];
  if (!aclsForObject)
    {
      aclsForObject = [NSMutableDictionary dictionary];
    }
  if (roles)
    {
      [aclsForObject setObject: roles forKey: uid];
    }
  else
    {
      [aclsForObject removeObjectForKey: uid];
    }
  
  // We update our distributed cache
  [[SOGoCache sharedCache] setACLs: aclsForObject
			   forPath: objectPath];
}

- (NSArray *) _realAclsForUser: (NSString *) uid
               forObjectAtPath: (NSArray *) objectPathArray
{
  NSArray *acls;
  NSString *objectPath;
  NSDictionary *aclsForObject;

  objectPath = [objectPathArray componentsJoinedByString: @"/"];
  aclsForObject = [[SOGoCache sharedCache] aclsForPath: objectPath];
  if (aclsForObject)
    acls = [aclsForObject objectForKey: uid];
  else
    acls = nil;
  if (!acls)
    {
      acls = [self _fetchAclsForUser: uid forObjectAtPath: objectPath];
      if (!acls)
        acls = [NSArray array];
      [self _cacheRoles: acls forUser: uid forObjectAtPath: objectPath];
    }

  return acls;
}

- (NSArray *) aclsForUser: (NSString *) uid
          forObjectAtPath: (NSArray *) objectPathArray
{
  NSArray *acls;
  NSString *module;
  SOGoDomainDefaults *dd;

  acls = [self _realAclsForUser: uid forObjectAtPath: objectPathArray];
  if (!([acls count] || [uid isEqualToString: @"anonymous"]))
    acls = [self _realAclsForUser: defaultUserID
                  forObjectAtPath: objectPathArray];

  // If we still don't have ACLs defined for this particular resource,
  // let's go get the domain defaults, if any.
  if (![acls count])
    {
      dd = [[context activeUser] domainDefaults];
      module = [container nameInContainer];
      if ([module isEqualToString: @"Calendar"])
        acls = [dd calendarDefaultRoles];
      else if ([module isEqualToString: @"Contacts"])
        acls = [dd contactsDefaultRoles];
    }

  return acls;
}

- (void) removeAclsForUsers: (NSArray *) users
            forObjectAtPath: (NSArray *) objectPathArray
{
  EOQualifier *qualifier;
  NSString *uid, *uids, *qs, *objectPath, *domain;
  NSMutableArray *usersAndGroups;
  NSMutableDictionary *aclsForObject;
  SOGoGroup *group;
  unsigned int i;

  if ([users count] > 0)
    {
      domain = [[context activeUser] domain];
      usersAndGroups = [NSMutableArray arrayWithArray: users];
      for (i = 0; i < [usersAndGroups count]; i++)
        {
          uid = [usersAndGroups objectAtIndex: i];
          if (![uid hasPrefix: @"@"])
            {
              // Prefix the UID with the character "@" when dealing with a group
              group = [SOGoGroup groupWithIdentifier: uid inDomain: domain];
              if (group)
                [usersAndGroups replaceObjectAtIndex: i
                                          withObject: [NSString stringWithFormat: @"@%@", uid]];
            }
        }
      objectPath = [objectPathArray componentsJoinedByString: @"/"];
      aclsForObject = [[SOGoCache sharedCache] aclsForPath: objectPath];
      if (aclsForObject)
	{
	  [aclsForObject removeObjectsForKeys: usersAndGroups];
	  [[SOGoCache sharedCache] setACLs: aclsForObject
				   forPath: objectPath];
	}
      uids = [usersAndGroups componentsJoinedByString: @"') OR (c_uid = '"];
      qs = [NSString
             stringWithFormat: @"(c_object = '/%@') AND ((c_uid = '%@'))",
             objectPath, uids];
      qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
      [[self ocsFolder] deleteAclMatchingQualifier: qualifier];
    }
}

- (void) _commitRoles: (NSArray *) roles
               forUID: (NSString *) uid
            forObject: (NSString *) objectPath
{
  EOAdaptorChannel *channel;
  GCSFolder *folder;
  NSEnumerator *userRoles;
  NSString *SQL, *currentRole;

  folder = [self ocsFolder];
  channel = [folder acquireAclChannel];
  [[channel adaptorContext] beginTransaction];
  userRoles = [roles objectEnumerator];
  while ((currentRole = [userRoles nextObject]))
    {
      SQL = [NSString stringWithFormat: @"INSERT INTO %@"
                      @" (c_object, c_uid, c_role)"
                      @" VALUES ('/%@', '%@', '%@')",
                      [folder aclTableName],
                      objectPath, uid, currentRole];
      [channel evaluateExpressionX: SQL];
    }

  [[channel adaptorContext] commitTransaction];
  [folder releaseChannel: channel];
}

- (void) setRoles: (NSArray *) roles
          forUser: (NSString *) uid
  forObjectAtPath: (NSArray *) objectPathArray
{
  NSString *objectPath, *aUID, *domain;
  NSMutableArray *newRoles;
  SOGoGroup *group;

  aUID = uid;
  if (![uid hasPrefix: @"@"])
    {
      // Prefix the UID with the character "@" when dealing with a group
      domain = [[context activeUser] domain];
      group = [SOGoGroup groupWithIdentifier: uid inDomain: domain];
      if (group)
        aUID = [NSString stringWithFormat: @"@%@", uid];
    }
  [self removeAclsForUsers: [NSArray arrayWithObject: aUID]
           forObjectAtPath: objectPathArray];

  newRoles = [NSMutableArray arrayWithArray: roles];
  [newRoles removeObject: SoRole_Authenticated];
  [newRoles removeObject: SoRole_Anonymous];
  [newRoles removeObject: SOGoRole_PublicUser];
  [newRoles removeObject: SOGoRole_AuthorizedSubscriber];
  [newRoles removeObject: SOGoRole_None];
  objectPath = [objectPathArray componentsJoinedByString: @"/"];
  
  if (![newRoles count])
    [newRoles addObject: SOGoRole_None];

  [self _cacheRoles: newRoles forUser: uid
	      forObjectAtPath: objectPath];

  [self _commitRoles: newRoles forUID: aUID forObject: objectPath];
}

/* acls */
- (NSArray *) aclUsers
{
  return [self aclUsersForObjectAtPath: [self pathArrayToFolder]];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  NSMutableArray *acls;
  NSArray *ownAcls, *containerAcls;

  acls = [NSMutableArray array];
  ownAcls = [self aclsForUser: uid forObjectAtPath: [self pathArrayToFolder]];
  [acls addObjectsFromArray: ownAcls];
  if ([container respondsToSelector: @selector (aclsForUser:)])
    {
      containerAcls = [container aclsForUser: uid];
      if ([containerAcls count] > 0)
        {
#warning this should be checked
          if ([containerAcls containsObject: SOGoRole_ObjectEraser])
                            [acls addObject: SOGoRole_ObjectEraser];
        }
    }

  return acls;
}

- (void) setRoles: (NSArray *) roles
          forUser: (NSString *) uid
{
  return [self    setRoles: roles
                   forUser: uid
           forObjectAtPath: [self pathArrayToFolder]];
}

- (void) removeAclsForUsers: (NSArray *) users
{
  return [self removeAclsForUsers: users
                  forObjectAtPath: [self pathArrayToFolder]];
}

- (NSString *) defaultUserID
{
  return defaultUserID;
}

/* description */

- (void) appendAttributesToDescription: (NSMutableString *) _ms
{
  [super appendAttributesToDescription:_ms];

  [_ms appendFormat:@" ocs=%@", [self ocsPath]];
}

/* tmp: multiget */

- (NSArray *) _fetchComponentsWithNames: (NSArray *) cNames
                                 fields: (NSArray *) fields
{
  NSArray *records;
  NSString *sqlFilter;
  NSMutableString *filterString;
  EOQualifier *qualifier;

  sqlFilter = [self aclSQLListingFilter];
  if (sqlFilter)
    {
      filterString = [NSMutableString stringWithCapacity: 8192];
      [filterString appendFormat: @"(c_name='%@')",
                    [cNames componentsJoinedByString: @"' OR c_name='"]];
      if ([sqlFilter length] > 0)
        [filterString appendFormat: @" AND (%@)", sqlFilter];
      qualifier = [EOQualifier qualifierWithQualifierFormat: filterString];
      records = [[self ocsFolder] fetchFields: fields
                            matchingQualifier: qualifier];
      if (![records isNotNull])
        {
          [self errorWithFormat: @"(%s): fetch failed!", __PRETTY_FUNCTION__];
          return nil;
        }
    }
  else
    records = [NSArray array];

  return records;
}

#define maxQuerySize 2500
#define baseQuerySize 160
#define idQueryOverhead 13

- (NSArray *) _fetchComponentsMatchingObjectNames: (NSArray *) cNames
                                           fields: (NSArray *) fields
{
  NSMutableArray *components;
  NSArray *records;
  NSMutableArray *currentNames;
  unsigned int count, max, currentSize, queryNameLength;
  NSString *currentName;

//   NSLog (@"fetching components matching names");

  currentNames = [NSMutableArray array];
  currentSize = baseQuerySize;

  max = [cNames count];
  components = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      currentName = [cNames objectAtIndex: count];
      queryNameLength = idQueryOverhead + [currentName length];
      if ((currentSize + queryNameLength)
	  > maxQuerySize)
	{
	  records = [self _fetchComponentsWithNames: currentNames fields: fields];
	  [components addObjectsFromArray: records];
	  [currentNames removeAllObjects];
	  currentSize = baseQuerySize;
	}
      [currentNames addObject: currentName];
      currentSize += queryNameLength;
    }

  records = [self _fetchComponentsWithNames: currentNames fields: fields];
  [components addObjectsFromArray: records];

//   NSLog (@"/fetching components matching names");

  return components;
}

- (NSDictionary *) _deduceObjectNamesFromURLs: (NSArray *) urls
{
  unsigned int count, max;
  NSString *url, *currentURL, *componentURLPath, *cName, *baseURLString;
  NSMutableDictionary *cNames;
  NSURL *componentURL, *baseURL;

  max = [urls count];
  cNames = [NSMutableDictionary dictionaryWithCapacity: max];
  baseURL = [self davURL];
  baseURLString = [self davURLAsString];

  for (count = 0; count < max; count++)
    {
      currentURL
        = [[urls objectAtIndex: count] stringByReplacingString: @"%40"
                                                    withString: @"@"];
      url = [NSString stringWithFormat: @"%@/%@",
		      [currentURL stringByDeletingLastPathComponent],
      		      [[currentURL lastPathComponent] stringByEscapingURL]];
      componentURL = [[NSURL URLWithString: url relativeToURL: baseURL]
		       standardizedURL];
      componentURLPath = [componentURL absoluteString];
      if ([componentURLPath rangeOfString: baseURLString].location
	  != NSNotFound)
	{
	  cName = [[urls objectAtIndex: count] lastPathComponent];
	  [cNames setObject: [urls objectAtIndex: count]  forKey: cName];
	}
    }

  return cNames;
}

- (NSDictionary *) _fetchComponentsMatchingURLs: (NSArray *) urls
                                         fields: (NSArray *) fields
{
  NSMutableDictionary *components;
  NSDictionary *cnames, *record;
  NSString *recordURL;
  NSArray *records;
  unsigned int count, max;

  components = [NSMutableDictionary dictionary];

  cnames = [self _deduceObjectNamesFromURLs: urls];
  records = [self _fetchComponentsMatchingObjectNames: [cnames allKeys]
                                               fields: fields];
  max = [records count];
  for (count = 0; count < max; count++)
    {
      record = [records objectAtIndex: count];
      recordURL = [cnames objectForKey: [record objectForKey: @"c_name"]];
      if (recordURL)
        [components setObject: record forKey: recordURL];
    }

  return components;
}

#warning the two following methods should be replaced with the new dav rendering mechanism
- (NSString *) _nodeTagForProperty: (NSString *) property
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSString *) _nodeTag: (NSString *) property
{
  static NSMutableDictionary *tags = nil;
  NSString *nodeTag;

  if (!tags)
    tags = [NSMutableDictionary new];
  nodeTag = [tags objectForKey: property];
  if (!nodeTag)
    {
      nodeTag = [self _nodeTagForProperty: property];
      [tags setObject: nodeTag forKey: property];
    }

  return nodeTag;
}

- (NSString **) _properties: (NSString **) properties
                      count: (unsigned int) propertiesCount
                   ofObject: (NSDictionary *) object
{
  SOGoContentObject *sogoObject;
  NSString **currentProperty;
  NSString **values, **currentValue;
  SEL methodSel;

//   NSLog (@"_properties:ofObject:: %@", [NSDate date]);

  values = NSZoneMalloc (NULL,
                         (propertiesCount + 1) * sizeof (NSString *));
  *(values + propertiesCount) = nil;

  //c = [self objectClassForComponentName: [object objectForKey: @"c_component"]];

  sogoObject = [self createChildComponentWithRecord: object];
  currentProperty = properties;
  currentValue = values;
  while (*currentProperty)
    {
      methodSel = SOGoSelectorForPropertyGetter (*currentProperty);
      if (methodSel && [sogoObject respondsToSelector: methodSel])
        *currentValue = [[sogoObject performSelector: methodSel]
                          stringByEscapingXMLString];
      currentProperty++;
      currentValue++;
    }

//    NSLog (@"/_properties:ofObject:: %@", [NSDate date]);

  return values;
}

- (NSArray *) _propstats: (NSString **) properties
                   count: (unsigned int) propertiesCount
		ofObject: (NSDictionary *) object
{
  NSMutableArray *propstats, *properties200, *properties404, *propDict;
  NSString **property, **values, **currentValue;
  NSString *propertyValue, *nodeTag;

//   NSLog (@"_propstats:ofObject:: %@", [NSDate date]);

  propstats = [NSMutableArray array];

  properties200 = [NSMutableArray array];
  properties404 = [NSMutableArray array];

  values = [self _properties: properties count: propertiesCount
                    ofObject: object];
  currentValue = values;

  property = properties;
  while (*property)
    {
      nodeTag = [self _nodeTag: *property];
      if (*currentValue)
	{
	  propertyValue = [NSString stringWithFormat: @"<%@>%@</%@>",
				    nodeTag, *currentValue, nodeTag];
	  propDict = properties200;
	}
      else
	{
	  propertyValue = [NSString stringWithFormat: @"<%@/>", nodeTag];
	  propDict = properties404;
	}
      [propDict addObject: propertyValue];
      property++;
      currentValue++;
    }
  free (values);

  if ([properties200 count])
    [propstats addObject: [NSDictionary dictionaryWithObjectsAndKeys:
					  properties200, @"properties",
					@"HTTP/1.1 200 OK", @"status",
					nil]];
  if ([properties404 count])
    [propstats addObject: [NSDictionary dictionaryWithObjectsAndKeys:
					  properties404, @"properties",
					@"HTTP/1.1 404 Not Found", @"status",
					nil]];
//    NSLog (@"/_propstats:ofObject:: %@", [NSDate date]);

  return propstats;
}

- (void) _appendPropstat: (NSDictionary *) propstat
                toBuffer: (NSMutableString *) r
{
  NSArray *properties;
  unsigned int count, max;

  [r appendString: @"<D:propstat><D:prop>"];
  properties = [propstat objectForKey: @"properties"];
  max = [properties count];
  for (count = 0; count < max; count++)
    [r appendString: [properties objectAtIndex: count]];
  [r appendString: @"</D:prop><D:status>"];
  [r appendString: [propstat objectForKey: @"status"]];
  [r appendString: @"</D:status></D:propstat>"];
}

#warning We need to use the new DAV utilities here...
#warning this is baddddd because we return a single-valued dictionary containing \
  a cname which may not event exist... the logic behind appendObject:... should be \
  rethought, especially since we may start using SQL views

- (void) appendObject: (NSDictionary *) object
	   properties: (NSString **) properties
                count: (unsigned int) propertiesCount
          withBaseURL: (NSString *) baseURL
	     toBuffer: (NSMutableString *) r
{
  NSArray *propstats;
  unsigned int count, max;

  [r appendFormat: @"<D:response><D:href>"];
  [r appendString: baseURL];
  [r appendString: [[object objectForKey: @"c_name"] stringByEscapingURL]];
  [r appendString: @"</D:href>"];

//   NSLog (@"(appendPropstats...): %@", [NSDate date]);
  propstats = [self _propstats: properties count: propertiesCount
                      ofObject: object];
  max = [propstats count];
  for (count = 0; count < max; count++)
    [self _appendPropstat: [propstats objectAtIndex: count]
	  toBuffer: r];
//   NSLog (@"/(appendPropstats...): %@", [NSDate date]);

  [r appendString: @"</D:response>"];
}

- (void) appendMissingObjectRef: (NSString *) href
		       toBuffer: (NSMutableString *) r
{
  [r appendString: @"<D:response><D:href>"];
  [r appendString: href];
  [r appendString: @"</D:href><D:status>HTTP/1.1 404 Not Found</D:status></D:response>"];
}

- (void) _appendComponentProperties: (NSDictionary *) properties
                       matchingURLs: (id <DOMNodeList>) refs
                         toResponse: (WOResponse *) response
{
  NSObject <DOMElement> *element;
  NSDictionary *currentComponent, *components;
  NSString *currentURL, *baseURL, *currentField;
  NSString **propertiesArray;
  NSMutableArray *urls, *fields;
  NSMutableString *buffer;
  unsigned int count, max, propertiesCount;
  NSEnumerator *addFields;

  baseURL = [self davURLAsString];
#warning review this when fixing http://www.scalableogo.org/bugs/view.php?id=276
  if (![baseURL hasSuffix: @"/"])
    baseURL = [NSString stringWithFormat: @"%@/", baseURL];

  urls = [NSMutableArray array];
  max = [refs length];
  for (count = 0; count < max; count++)
    {
      element = [refs objectAtIndex: count];
      currentURL = [[[element firstChild] nodeValue] stringByUnescapingURL];
      [urls addObject: currentURL];
    }

  propertiesArray = [[properties allKeys] asPointersOfObjects];
  propertiesCount = [properties count];

  fields = [NSMutableArray arrayWithObjects: @"c_name", @"c_component", nil];
  addFields = [[properties allValues] objectEnumerator];
  while ((currentField = [addFields nextObject]))
    if ([currentField length])
      [fields addObjectUniquely: currentField];

  components = [self _fetchComponentsMatchingURLs: urls fields: fields];
  max = [urls count];
//   NSLog (@"adding properties with url");
  buffer = [NSMutableString stringWithCapacity: max*512];
  for (count = 0; count < max; count++)
    {
      currentURL = [urls objectAtIndex: count];
      currentComponent = [components objectForKey: currentURL];
      if (currentComponent)
        [self appendObject: currentComponent
                properties: propertiesArray
                     count: propertiesCount
               withBaseURL: baseURL
                  toBuffer: buffer];
      else
        [self appendMissingObjectRef: currentURL
                            toBuffer: buffer];
    }
  [response appendContentString: buffer];
//   NSLog (@"/adding properties with url");

  NSZoneFree (NULL, propertiesArray);
}

- (WOResponse *) performMultigetInContext: (WOContext *) queryContext
                              inNamespace: (NSString *) namespace
{
  WOResponse *r;
  id <DOMDocument> document;
  DOMElement *documentElement, *propElement;

  r = [context response];
  [r prepareDAVResponse];
  [r appendContentString:
       [NSString stringWithFormat: @"<D:multistatus xmlns:D=\"DAV:\""
                         @" xmlns:C=\"%@\">", namespace]];
  document = [[queryContext request] contentAsDOMDocument];
  documentElement = (DOMElement *) [document documentElement];
  propElement = [documentElement firstElementWithTag: @"prop"
                                         inNamespace: @"DAV:"];
  [self _appendComponentProperties: [self parseDAVRequestedProperties: propElement]
                      matchingURLs: [documentElement getElementsByTagName: @"href"]
                        toResponse: r];
  [r appendContentString:@"</D:multistatus>"];

  return r;
}

@end /* SOGoFolder */
