/* SOGoGCSFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2004-2005 SKYRIX Software AG
 * Copyright (C) 2006-2008 Inverse inc.
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
#import <Foundation/NSUserDefaults.h>
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
#import <UI/SOGoUI/SOGoFolderAdvisory.h>
#import "NSDictionary+Utilities.h"

#import "NSArray+Utilities.h"
#import "NSObject+DAV.h"
#import "NSString+Utilities.h"
#import "NSString+DAV.h"

#import "DOMNode+SOGo.h"
#import "SOGoContentObject.h"
#import "SOGoGroup.h"
#import "SOGoParentFolder.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"
#import "SOGoWebDAVAclManager.h"
#import "WORequest+SOGo.h"

#import "SOGoGCSFolder.h"

static NSString *defaultUserID = @"<default>";
static BOOL sendFolderAdvisories = NO;
static NSArray *childRecordFields = nil;

@implementation SOGoGCSFolder

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;

  if (!aclManager)
    {
      aclManager = [SOGoWebDAVAclManager new];
      [aclManager registerDAVPermission: davElement (@"read", @"DAV:")
		  abstract: YES
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"all", @"DAV:")];
      [aclManager registerDAVPermission: davElement (@"read-current-user-privilege-set", @"DAV:")
		  abstract: YES
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"read", @"DAV:")];
      [aclManager registerDAVPermission: davElement (@"write", @"DAV:")
		  abstract: YES
		  withEquivalent: nil
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

+ (void) initialize
{
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];

  sendFolderAdvisories = [ud boolForKey: @"SOGoFoldersSendEMailNotifications"];
  if (!childRecordFields)
    {
      childRecordFields = [NSArray arrayWithObjects: @"c_name", @"c_version",
				   @"c_creationdate", @"c_lastmodified",
				   @"c_component", @"c_content", nil];
      [childRecordFields retain];
    }
}

+ (id) folderWithSubscriptionReference: (NSString *) reference
			   inContainer: (id) aContainer
{
  id newFolder;
  NSArray *elements, *pathElements;
  NSString *path, *objectPath, *login, *currentUser, *ocsName, *folderName;
  WOContext *context;

  elements = [reference componentsSeparatedByString: @":"];
  login = [elements objectAtIndex: 0];
  context = [[WOApplication application] context];
  currentUser = [[context activeUser] login];
  objectPath = [elements objectAtIndex: 1];
  pathElements = [objectPath componentsSeparatedByString: @"/"];
  if ([pathElements count] > 1)
    ocsName = [pathElements objectAtIndex: 1];
  else
    ocsName = @"personal";

  path = [NSString stringWithFormat: @"/Users/%@/%@/%@",
		   login, [pathElements objectAtIndex: 0], ocsName];
  folderName = [NSString stringWithFormat: @"%@_%@",
			 [login asCSSIdentifier], ocsName];
  newFolder = [self objectWithName: folderName inContainer: aContainer];
  [newFolder setOCSPath: path];
  [newFolder setOwner: login];
  [newFolder setIsSubscription: ![login isEqualToString: currentUser]];
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
      aclCache = [NSMutableDictionary new];
      childRecords = [NSMutableDictionary new];
      userCanAccessAllObjects = NO;
    }

  return self;
}

- (void) dealloc
{
  [ocsFolder release];
  [ocsPath release];
  [aclCache release];
  [childRecords release];
  [super dealloc];
}

/* accessors */

- (void) _setDisplayNameFromRow: (NSDictionary *) row
{
  NSString *currentLogin, *ownerLogin, *primaryDN;
  NSDictionary *ownerIdentity;

  primaryDN = [row objectForKey: @"c_foldername"];
  if ([primaryDN length])
    {
      displayName = [NSMutableString new];
      if ([primaryDN isEqualToString: [container defaultFolderName]])
	[displayName appendString: [self labelForKey: primaryDN]];
      else
	[displayName appendString: primaryDN];

      currentLogin = [[context activeUser] login];
      ownerLogin = [self ownerInContext: context];
      if (![currentLogin isEqualToString: ownerLogin])
	{
	  ownerIdentity = [[SOGoUser userWithLogin: ownerLogin roles: nil]
			    primaryIdentity];
	  [displayName
	    appendString: [ownerIdentity keysWithFormat:
					   @" (%{fullName} <%{email}>)"]];
	}
    }
}

- (void) _fetchDisplayName
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

- (NSString *) displayName
{
  if (!displayName)
    [self _fetchDisplayName];

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

- (NSString *) davDisplayName
{
  return [self displayName];
}

- (NSException *) setDavDisplayName: (NSString *) newName
{
  NSException *error;
  NSArray *currentRoles;

  currentRoles = [[context activeUser] rolesForObject: self
				       inContext: context];
  if ([currentRoles containsObject: SoRole_Owner])
    {
      if ([newName length])
	{
	  [self renameTo: newName];
	  error = nil;
	}
      else
	error = [NSException exceptionWithHTTPStatus: 400
			     reason: @"Empty string"];
    }
  else
    error = [NSException exceptionWithHTTPStatus: 403
			 reason: @"Modification denied."];

  return error;
}

- (GCSFolder *) ocsFolder
{
  GCSFolder *folder;
  NSString *userLogin;

  if (!ocsFolder)
    {
      ocsFolder = [self ocsFolderForPath: [self ocsPath]];
      userLogin = [[context activeUser] login];
      if (!ocsFolder
	  && [userLogin isEqualToString: [self ownerInContext: context]]
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

- (void) sendFolderAdvisoryTemplate: (NSString *) template
{
  NSString *pageName;
  SOGoUser *user;
  SOGoFolderAdvisory *page;

  if (sendFolderAdvisories)
    {
      user = [context activeUser];
      pageName = [NSString stringWithFormat: @"SOGoFolder%@%@Advisory",
			   [user language], template];

      page = [[WOApplication application] pageWithName: pageName
					  inContext: context];
      [page setFolderObject: self];
      [page setRecipientUID: [user login]];
      [page send];
    }
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

  // We just fetch our displayName since our table will use it!
  [self displayName];
  
  if ([nameInContainer isEqualToString: @"personal"])
    error = [NSException exceptionWithHTTPStatus: 403
			 reason: @"folder 'personal' cannot be deleted"];
  else
    error = [[self folderManager] deleteFolderAtPath: ocsPath];

  if (!error && [[context request] handledByDefaultHandler])
    [self sendFolderAdvisoryTemplate: @"Removal"];

  return error;
}

- (void) renameTo: (NSString *) newName
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql;

  [displayName release];
  displayName = nil;

  cm = [GCSChannelManager defaultChannelManager];
  folderLocation
    = [[GCSFolderManager defaultFolderManager] folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if (fc)
    {
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

- (NSArray *) fetchContentObjectNames
{
  NSArray *records, *names;
  
  records = [[self ocsFolder] fetchFields: childRecordFields
			      matchingQualifier:nil];
  if (![records isNotNull])
    {
      [self errorWithFormat: @"(%s): fetch failed!", __PRETTY_FUNCTION__];
      return nil;
    }
  if ([records isKindOfClass: [NSException class]])
    return records;

  [childRecords release];
  names = [records objectsForKey: @"c_name" notFoundMarker: nil];
  childRecords = [[NSMutableDictionary alloc] initWithObjects: records
					      forKeys: names];

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

- (id) _createChildComponentWithRecord: (NSDictionary *) record
{
  Class klazz;

  klazz = [self objectClassForComponentName:
		  [record objectForKey: @"c_component"]];

  return [klazz objectWithRecord: record inContainer: self];
}

- (id) _createChildComponentWithName: (NSString *) newName
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

  obj = [super lookupName: key
	       inContext: localContext
	       acquire: acquire];
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
	obj = [self _createChildComponentWithRecord: record];
      else
	{
	  request = [localContext request];
	  if ([[request method] isEqualToString: @"PUT"])
	    {
	      obj = [self _createChildComponentWithName: key
			  andContent: [request contentAsString]];
	      [obj setIsNew: YES];
	    }
	}
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
  NSArray *records;
  GCSFolder *folder;
  EOFetchSpecification *cTagSpec;
  EOSortOrdering *ordering;
  NSNumber *lastModified;
  NSString *cTag;

  folder = [self ocsFolder];
  ordering = [EOSortOrdering sortOrderingWithKey: @"c_lastmodified"
                                        selector: EOCompareDescending];
  cTagSpec = [EOFetchSpecification
                   fetchSpecificationWithEntityName: [folder folderName]
                                          qualifier: nil
                                      sortOrderings: [NSArray arrayWithObject: ordering]];

  records = [folder fetchFields: [NSArray arrayWithObject: @"c_lastmodified"]
		    fetchSpecification: cTagSpec
		    ignoreDeleted: NO];
  if ([records count])
    {
      lastModified = [[records objectAtIndex: 0]
                       objectForKey: @"c_lastmodified"];
      cTag = [lastModified stringValue];
    }
  else
    cTag = @"-1";

  return cTag;
}

#warning this code should be cleaned up
- (void) _subscribeUser: (SOGoUser *) subscribingUser
	       reallyDo: (BOOL) reallyDo
     fromMailInvitation: (BOOL) isMailInvitation
	     inResponse: (WOResponse *) response
{
  NSMutableArray *folderSubscription;
  NSString *subscriptionPointer, *mailInvitationURL;
  NSUserDefaults *ud;
  NSMutableDictionary *moduleSettings;

  if ([owner isEqualToString: [subscribingUser login]])
    {
      [response setStatus: 403];
      [response appendContentString:
		 @"You cannot (un)subscribe to a folder that you own!"];
    }
  else
    {
      ud = [subscribingUser userSettings];
      moduleSettings = [ud objectForKey: [container nameInContainer]];
      if (!(moduleSettings
	    && [moduleSettings isKindOfClass: [NSMutableDictionary class]]))
	{
	  moduleSettings = [NSMutableDictionary dictionary];
	  [ud setObject: moduleSettings forKey: [container nameInContainer]];
	}

      folderSubscription
	= [moduleSettings objectForKey: @"SubscribedFolders"];
      if (!(folderSubscription
	    && [folderSubscription isKindOfClass: [NSMutableArray class]]))
	{
	  folderSubscription = [NSMutableArray array];
	  [moduleSettings setObject: folderSubscription
			  forKey: @"SubscribedFolders"];
	}

      subscriptionPointer = [self folderReference];
      if (reallyDo)
	[folderSubscription addObjectUniquely: subscriptionPointer];
      else
	[folderSubscription removeObject: subscriptionPointer];

      [ud synchronize];

      if (isMailInvitation)
	{
	  mailInvitationURL = [[self soURLToBaseContainerForCurrentUser]
				absoluteString];
	  [response setStatus: 302];
	  [response setHeader: mailInvitationURL
		    forKey: @"location"];
	}
      else
	[response setStatus: 204];
    }
}

- (WOResponse *) subscribe: (BOOL) reallyDo
	      inTheNamesOf: (NSArray *) delegatedUsers
	fromMailInvitation: (BOOL) isMailInvitation
		 inContext: (WOContext *) localContext
{
  WOResponse *response;
  SOGoUser *currentUser;

  response = [localContext response];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"Content-Type"];

  currentUser = [localContext activeUser];

  if ([delegatedUsers count])
    {
      if (![currentUser isSuperUser])
	{
	  [response setStatus: 403];
	  [response appendContentString:
		      @"You cannot subscribe another user to any folder"
		    @" unless you are a super-user."];
	}
      else
	{
	  // The current user is a superuser...
	  SOGoUser *subscriptionUser;
	  int i;

	  for (i = 0; i < [delegatedUsers count]; i++)
	    {
	      // We trust the passed user ID here as it might generate tons or LDAP
	      // call but more importantly, cache propagation calls that will create
	      // contention on GDNC.
	      subscriptionUser = [SOGoUser userWithLogin: [delegatedUsers objectAtIndex: i]
					   roles: nil
					   trust: YES];
	      
	      [self _subscribeUser: subscriptionUser
		    reallyDo: reallyDo
		    fromMailInvitation: isMailInvitation
		    inResponse: response];
	    }
	}
    }
  else
    {
      [self _subscribeUser: currentUser
	    reallyDo: reallyDo
	    fromMailInvitation: isMailInvitation
	    inResponse: response];
    }

  return response;
}

- (NSArray *) _parseDAVDelegatedUser: (WOContext *) queryContext
{
  id <DOMDocument> document;
  id <DOMNamedNodeMap> attrs;
  id o;
  document = [[queryContext request] contentAsDOMDocument];
  attrs = [[document documentElement] attributes];

  o = [attrs namedItem: @"users"];
  
  if (o) return [[o nodeValue] componentsSeparatedByString: @","];
 
  return nil;
}

- (id <WOActionResults>) davSubscribe: (WOContext *) queryContext
{
  return [self subscribe: YES
            inTheNamesOf: [self _parseDAVDelegatedUser: queryContext]
               fromMailInvitation: NO
	       inContext: queryContext];
}

- (id <WOActionResults>) davUnsubscribe: (WOContext *) queryContext
{
  return [self subscribe: NO
            inTheNamesOf: [self _parseDAVDelegatedUser: queryContext]
	       fromMailInvitation: NO
	       inContext: queryContext];
}

- (NSDictionary *) davSQLFieldsTable
{
  static NSMutableDictionary *davSQLFieldsTable = nil;

  if (!davSQLFieldsTable)
    {
      davSQLFieldsTable = [NSMutableDictionary new];
      [davSQLFieldsTable setObject: @"c_version" forKey: @"{DAV:}getetag"];
      [davSQLFieldsTable setObject: @"" forKey: @"{DAV:}getcontenttype"];
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

- (NSArray *) _fetchSyncTokenFields: (NSDictionary *) properties
                  matchingSyncToken: (int) syncToken
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
  NSString *currentField;

  fields = [NSMutableArray arrayWithObjects: @"c_name", @"c_component",
                           @"c_creationdate", @"c_lastmodified", nil];
  addFields = [[properties allValues] objectEnumerator];
  while ((currentField = [addFields nextObject]))
    if ([currentField length])
      [fields addObjectUniquely: currentField];

  if (syncToken)
    {
      qualifier = [EOQualifier qualifierWithQualifierFormat:
                                 @"c_lastmodified > %d", syncToken];
      mRecords = [NSMutableArray arrayWithArray: [self _fetchFields: fields
                                                      withQualifier: qualifier
                                                      ignoreDeleted: YES]];
      qualifier = [EOQualifier qualifierWithQualifierFormat:
                                 @"c_lastmodified > %d and c_deleted == 1",
                               syncToken];
      fields = [NSMutableArray arrayWithObjects: @"c_name", @"c_deleted", nil];
      [mRecords addObjectsFromArray: [self _fetchFields: fields
                                          withQualifier: qualifier
                                          ignoreDeleted: NO]];
      records = mRecords;
    }
  else
    records = [self _fetchFields: fields withQualifier: nil
                   ignoreDeleted: YES];

  return records;
}

/* These methods are the optimal ones to generate propstats for DAV reports,
   it should be used in other subclasses. */
- (NSDictionary *) _davPropstat: (NSArray *) properties
                     withStatus: (NSString *) status
{
  NSMutableArray *propstat;

  propstat = [NSMutableArray arrayWithCapacity: 2];
  [propstat addObject: davElementWithContent (@"prop", XMLNS_WEBDAV,
                                              properties)];
  [propstat addObject: davElementWithContent (@"status", XMLNS_WEBDAV,
                                              status)];

  return davElementWithContent (@"propstat", XMLNS_WEBDAV, propstat);
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

  sogoObject = [self _createChildComponentWithRecord: record];
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
    [propstats addObject: [self _davPropstat: properties200
                                  withStatus: @"HTTP/1.1 200 OK"]];
  if ([properties404 count])
    [propstats addObject: [self _davPropstat: properties404
                                  withStatus: @"HTTP/1.1 404 Not Found"]];

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
  selectors = NSZoneMalloc (NULL, sizeof (max * sizeof (SEL)));
  for (count = 0; count < max; count++)
    selectors[count]
      = SOGoSelectorForPropertyGetter ([properties objectAtIndex: count]);

  now = (unsigned int) [[NSDate date] timeIntervalSince1970];

  newToken = 0;

  baseURL = [[self davURL] absoluteString];

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

- (WOResponse *) davSyncCollection: (WOContext *) localContext
{
  WOResponse *r;
  id <DOMDocument> document;
  DOMElement *documentElement, *propElement;
  NSString *syncToken;
  NSDictionary *properties;
  NSArray *records;
  int syncTokenInt;

  r = [context response];
  [r setStatus: 207];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];
  [r appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n"];

  document = [[context request] contentAsDOMDocument];
  documentElement = (DOMElement *) [document documentElement];
  syncToken = [[documentElement firstElementWithTag: @"sync-token"
                                        inNamespace: XMLNS_WEBDAV] textValue];
  propElement = [documentElement firstElementWithTag: @"prop"
                                         inNamespace: XMLNS_WEBDAV];

  syncTokenInt = [syncToken intValue];
  properties = [self parseDAVRequestedProperties: propElement];
  records = [self _fetchSyncTokenFields: properties
                      matchingSyncToken: syncTokenInt];
  [self _appendComponentProperties: [properties allKeys]
                       fromRecords: records
                 matchingSyncToken: syncTokenInt
                        toResponse: r];

  return r;
}

/* handling acls from quick tables */
- (void) initializeQuickTablesAclsInContext: (WOContext *) localContext
{
  NSString *login;

  if (activeUserIsOwner)
    userCanAccessAllObjects = activeUserIsOwner;
  else
    {
      login = [[localContext activeUser] login];
      /* we only grant "userCanAccessAllObjects" for role "ObjectEraser" and
         not "ObjectCreator" because the latter doesn't imply we can read
         properties from subobjects or even know their existence. */
      userCanAccessAllObjects = ([[self ownerInContext: localContext]
                                   isEqualToString: login]
                                 || [[self aclsForUser: login]
                                      containsObject: SOGoRole_ObjectEraser]);
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

- (NSArray *) _fetchAclsForUser: (NSString *) uid
		forObjectAtPath: (NSString *) objectPath
{
  EOQualifier *qualifier;
  NSArray *records;
  NSMutableArray *acls;
  NSString *qs;

  // We look for the exact uid or any uid that begins with "@" (corresponding to groups)
  qs = [NSString stringWithFormat: @"(c_object = '/%@') AND (c_uid = '%@' OR c_uid LIKE '@%%')",
		 objectPath, uid];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
  records = [[self ocsFolder] fetchAclMatchingQualifier: qualifier];
  acls = [NSMutableArray array];

  unsigned int i, j;
  NSArray *members;
  NSDictionary *record;
  NSString *currentUid;
  SOGoGroup *group;
  SOGoUser *user;

  for (i = 0; i < [records count]; i ++)
    {
      record = [records objectAtIndex: i];
      currentUid = [record valueForKey: @"c_uid"];
      if ([currentUid isEqualToString: uid])
	[acls addObject: [record valueForKey: @"c_role"]];
      else
	{
	  group = [SOGoGroup groupWithIdentifier: currentUid];
	  if (group)
	    {
	      members = [group members];
	      for (j = 0; j < [members count]; j++)
		{
		  user = [members objectAtIndex: j];
		  if ([[user login] isEqualToString: uid])
		    {
		      [acls addObject: [record valueForKey: @"c_role"]];
		      break;
		    }
		}
	    }
	}
    }
 
  return [acls uniqueObjects];
}

- (void) _cacheRoles: (NSArray *) roles
	     forUser: (NSString *) uid
     forObjectAtPath: (NSString *) objectPath
{
  NSMutableDictionary *aclsForObject;

  aclsForObject = [aclCache objectForKey: objectPath];
  if (!aclsForObject)
    {
      aclsForObject = [NSMutableDictionary dictionary];
      [aclCache setObject: aclsForObject
                   forKey: objectPath];
    }
  if (roles)
    [aclsForObject setObject: roles forKey: uid];
  else
    [aclsForObject removeObjectForKey: uid];
}

- (NSArray *) aclsForUser: (NSString *) uid
          forObjectAtPath: (NSArray *) objectPathArray
{
  NSArray *acls;
  NSString *objectPath;
  NSDictionary *aclsForObject;

  objectPath = [objectPathArray componentsJoinedByString: @"/"];
  aclsForObject = [aclCache objectForKey: objectPath];
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

  if (!([acls count] || [uid isEqualToString: defaultUserID]))
    acls = [self aclsForUser: defaultUserID
		 forObjectAtPath: objectPathArray];

  // If we still don't have ACLs defined for this particular resource,
  // let's go get the system-wide defaults, if any.
  if (![acls count])
    {
      if ([[container nameInContainer] isEqualToString: @"Calendar"]
          || [[container nameInContainer] isEqualToString: @"Contacts"])
	acls = [[NSUserDefaults standardUserDefaults] 
		 objectForKey: [NSString stringWithFormat: @"SOGo%@DefaultRoles",
					 [container nameInContainer]]];
    }

  return acls;
}

- (void) removeAclsForUsers: (NSArray *) users
            forObjectAtPath: (NSArray *) objectPathArray
{
  EOQualifier *qualifier;
  NSString *uid, *uids, *qs, *objectPath;
  NSMutableArray *usersAndGroups;
  NSMutableDictionary *aclsForObject;
  SOGoGroup *group;
  unsigned int i;

  if ([users count] > 0)
    {
      usersAndGroups = [NSMutableArray arrayWithArray: users];
      for (i = 0; i < [usersAndGroups count]; i++)
	{
	  uid = [usersAndGroups objectAtIndex: i];
	  if (![uid hasPrefix: @"@"])
	    {
	      // Prefix the UID with the character "@" when dealing with a group
	      group = [SOGoGroup groupWithIdentifier: uid];
	      if (group)
		[usersAndGroups replaceObjectAtIndex: i
				withObject: [NSString stringWithFormat: @"@%@", uid]];
	    }
	}
      objectPath = [objectPathArray componentsJoinedByString: @"/"];
      aclsForObject = [aclCache objectForKey: objectPath];
      if (aclsForObject)
	[aclsForObject removeObjectsForKeys: usersAndGroups];
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
  NSString *objectPath, *aUID;
  NSMutableArray *newRoles;
  SOGoGroup *group;

  aUID = uid;
  if (![uid hasPrefix: @"@"])
    {
      // Prefix the UID with the character "@" when dealing with a group
      group = [SOGoGroup groupWithIdentifier: uid];
      if (group)
	aUID = [NSString stringWithFormat: @"@%@", uid];
    }
  [self removeAclsForUsers: [NSArray arrayWithObject: aUID]
        forObjectAtPath: objectPathArray];

  newRoles = [NSMutableArray arrayWithArray: roles];
  [newRoles removeObject: SOGoRole_AuthorizedSubscriber];
  [newRoles removeObject: SOGoRole_None];
  objectPath = [objectPathArray componentsJoinedByString: @"/"];
  [self _cacheRoles: newRoles forUser: uid
	forObjectAtPath: objectPath];
  if (![newRoles count])
    [newRoles addObject: SOGoRole_None];

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
  return [self setRoles: roles
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

@end /* SOGoFolder */
