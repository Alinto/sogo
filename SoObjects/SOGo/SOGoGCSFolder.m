/* SOGoGCSFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2004-2005 SKYRIX Software AG
 * Copyright (C) 2006-2008 Inverse groupe conseil
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
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
#import <DOM/DOMProtocols.h>
#import <EOControl/EOQualifier.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderType.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <SaxObjC/XMLNamespaces.h>
#import <UI/SOGoUI/SOGoFolderAdvisory.h>
#import "NSDictionary+Utilities.h"

#import "NSArray+Utilities.h"
#import "NSObject+DAV.h"
#import "NSString+Utilities.h"

#import "SOGoContentObject.h"
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
  SOGoWebDAVAclManager *webdavAclManager = nil;

  if (!webdavAclManager)
    {
      webdavAclManager = [SOGoWebDAVAclManager new];
      [webdavAclManager registerDAVPermission: davElement (@"read", @"DAV:")
			abstract: YES
			withEquivalent: SoPerm_WebDAVAccess
			asChildOf: davElement (@"all", @"DAV:")];
      [webdavAclManager registerDAVPermission: davElement (@"read-current-user-privilege-set", @"DAV:")
			abstract: YES
			withEquivalent: SoPerm_WebDAVAccess
			asChildOf: davElement (@"read", @"DAV:")];
      [webdavAclManager registerDAVPermission: davElement (@"write", @"DAV:")
			abstract: YES
			withEquivalent: nil
			asChildOf: davElement (@"all", @"DAV:")];
      [webdavAclManager registerDAVPermission: davElement (@"bind", @"DAV:")
			abstract: NO
			withEquivalent: SoPerm_AddDocumentsImagesAndFiles
			asChildOf: davElement (@"write", @"DAV:")];
      [webdavAclManager registerDAVPermission: davElement (@"unbind", @"DAV:")
			abstract: NO
			withEquivalent: SoPerm_DeleteObjects
			asChildOf: davElement (@"write", @"DAV:")];
      [webdavAclManager
	registerDAVPermission: davElement (@"write-properties", @"DAV:")
	abstract: YES
	withEquivalent: SoPerm_ChangePermissions /* hackish */
	asChildOf: davElement (@"write", @"DAV:")];
      [webdavAclManager
	registerDAVPermission: davElement (@"write-content", @"DAV:")
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"write", @"DAV:")];
      [webdavAclManager registerDAVPermission: davElement (@"admin", @"urn:inverse:params:xml:ns:inverse-dav")
			abstract: YES
			withEquivalent: nil
			asChildOf: davElement (@"all", @"DAV:")];
      [webdavAclManager
	registerDAVPermission: davElement (@"read-acl", @"DAV:")
	abstract: YES
	withEquivalent: SOGoPerm_ReadAcls
	asChildOf: davElement (@"admin", @"urn:inverse:params:xml:ns:inverse-dav")];
      [webdavAclManager
	registerDAVPermission: davElement (@"write-acl", @"DAV:")
	abstract: YES
	withEquivalent: SoPerm_ChangePermissions
	asChildOf: davElement (@"admin", @"urn:inverse:params:xml:ns:inverse-dav")];
    }

  return webdavAclManager;
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
  folderName = [NSString stringWithFormat: @"%@_%@", login, ocsName];
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

  user = [context activeUser];
  pageName = [NSString stringWithFormat: @"SOGoFolder%@%@Advisory",
		       [user language], template];

  page = [[WOApplication application] pageWithName: pageName
				      inContext: context];
  [page setFolderObject: self];
  [page setRecipientUID: [user login]];
  [page send];
}

- (BOOL) create
{
  NSException *result;

  result = [[self folderManager] createFolderOfType: [self folderType]
				 withName: displayName
                                 atPath: ocsPath];

  if (!result
      && [[context request] handledByDefaultHandler]
      && sendFolderAdvisories)
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

  if (!error && sendFolderAdvisories
      && [[context request] handledByDefaultHandler])
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
		    [folderLocation gcsTableName], newName, ocsPath];
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
  names = [records objectsForKey: @"c_name"];
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
	    obj = [self _createChildComponentWithName: key
			andContent:[request contentAsString]];
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

  ud = [subscribingUser userSettings];
  moduleSettings = [ud objectForKey: [container nameInContainer]];

  if ([owner isEqualToString: [subscribingUser login]])
    {
      [response setStatus: 403];
      [response appendContentString:
		 @"You cannot (un)subscribe to a folder that you own!"];
    }
  else
    {
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
	       inTheNameOf: (NSString *) delegatedUser
	fromMailInvitation: (BOOL) isMailInvitation
		 inContext: (WOContext *) localContext
{
  WOResponse *response;
  SOGoUser *currentUser, *subscriptionUser;
  BOOL validRequest;

  response = [localContext response];
  currentUser = [localContext activeUser];

  if ([delegatedUser length])
    {
      validRequest = ([currentUser isSuperUser]);
      subscriptionUser = [SOGoUser userWithLogin: delegatedUser roles: nil];
    }
  else
    {
      validRequest = YES;
      subscriptionUser = currentUser;
    }

  if (validRequest)
    [self _subscribeUser: subscriptionUser
	  reallyDo: reallyDo
	  fromMailInvitation: isMailInvitation
	  inResponse: response];
  else
    {
      [response setStatus: 403];
      [response appendContentString:
		 @"You cannot subscribe another user to any folder"
		@" unless you are a super-user."];
    }

  return response;
}

- (NSString *) _parseDAVDelegatedUser: (WOContext *) queryContext
{
  id <DOMDocument> document;
  id <DOMNamedNodeMap> attrs;

  document = [[queryContext request] contentAsDOMDocument];
  attrs = [[document documentElement] attributes];

  return [[attrs namedItem: @"user"] nodeValue];
}

- (id <WOActionResults>) davSubscribe: (WOContext *) queryContext
{
  return [self subscribe: YES
	       inTheNameOf: [self _parseDAVDelegatedUser: queryContext]
	       fromMailInvitation: NO
	       inContext: queryContext];
}

- (id <WOActionResults>) davUnsubscribe: (WOContext *) queryContext
{
  return [self subscribe: NO
	       inTheNameOf: [self _parseDAVDelegatedUser: queryContext]
	       fromMailInvitation: NO
	       inContext: queryContext];
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

  qs = [NSString stringWithFormat: @"(c_object = '/%@') AND (c_uid = '%@')",
		 objectPath, uid];
  qualifier = [EOQualifier qualifierWithQualifierFormat: qs];
  records = [[self ocsFolder] fetchAclMatchingQualifier: qualifier];

  acls = [NSMutableArray array];
  if ([records count] > 0)
    [acls addObjectsFromArray: [records valueForKey: @"c_role"]];

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
      [self _cacheRoles: acls forUser: uid forObjectAtPath: objectPath];
    }

  if (!([acls count] || [uid isEqualToString: defaultUserID]))
    acls = [self aclsForUser: defaultUserID
		 forObjectAtPath: objectPathArray];

  return acls;
}

- (void) removeAclsForUsers: (NSArray *) users
            forObjectAtPath: (NSArray *) objectPathArray
{
  EOQualifier *qualifier;
  NSString *uids, *qs, *objectPath;
  NSMutableDictionary *aclsForObject;

  if ([users count] > 0)
    {
      objectPath = [objectPathArray componentsJoinedByString: @"/"];
      aclsForObject = [aclCache objectForKey: objectPath];
      if (aclsForObject)
	[aclsForObject removeObjectsForKeys: users];
      uids = [users componentsJoinedByString: @"') OR (c_uid = '"];
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
  userRoles = [roles objectEnumerator];
  currentRole = [userRoles nextObject];
  while (currentRole)
    {
      SQL = [NSString stringWithFormat: @"INSERT INTO %@"
		      @" (c_object, c_uid, c_role)"
		      @" VALUES ('/%@', '%@', '%@')",
		      [folder aclTableName],
		      objectPath, uid, currentRole];
      [channel evaluateExpressionX: SQL];
      currentRole = [userRoles nextObject];
    }

  [folder releaseChannel: channel];
}

- (void) setRoles: (NSArray *) roles
          forUser: (NSString *) uid
  forObjectAtPath: (NSArray *) objectPathArray
{
  NSString *objectPath;
  NSMutableArray *newRoles;

  [self removeAclsForUsers: [NSArray arrayWithObject: uid]
        forObjectAtPath: objectPathArray];

  newRoles = [NSMutableArray arrayWithArray: roles];
  [newRoles removeObject: SOGoRole_AuthorizedSubscriber];
  [newRoles removeObject: SOGoRole_None];
  objectPath = [objectPathArray componentsJoinedByString: @"/"];
  [self _cacheRoles: newRoles forUser: uid
	forObjectAtPath: objectPath];
  if (![newRoles count])
    [newRoles addObject: SOGoRole_None];

  [self _commitRoles: newRoles forUID: uid forObject: objectPath];
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
