/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __SoObjects_SOGoObject_H__
#define __SoObjects_SOGoObject_H__

#import <Foundation/NSObject.h>

/*
  SOGoObject
  
  This is the abstract class used by all SOGo SoObjects. It contains the
  ability to track a container as well as the key the object was invoked with.
  
  In addition it provides some generic methods like user or group folder
  lookup.
*/

#import <NGObjWeb/SoObject.h>

@class NSString;
@class NSArray;
@class NSMutableString;
@class NSException;
@class NSTimeZone;
@class NSURL;

@class WOContext;
@class GCSFolderManager;
@class GCSFolder;

@class SOGoUserFolder;
@class SOGoGroupsFolder;
@class SOGoDAVSet;

#define $(class) NSClassFromString(class)

@interface SOGoObject : NSObject
{
  WOContext *context;
  NSString *nameInContainer;
  NSString *owner;
  id container;
}

+ (NSString *) globallyUniqueObjectId;
- (NSString *) globallyUniqueObjectId;

+ (id) objectWithName: (NSString *)_name inContainer:(id)_container;

- (id) initWithName: (NSString *) _name inContainer:(id)_container;

/* accessors */

- (NSString *) nameInContainer;
- (id) container;

- (NSArray *) pathArrayToSOGoObject;

- (NSURL *) davURL;
- (NSURL *) soURL;
- (NSURL *) soURLToBaseContainerForUser: (NSString *) uid;
- (NSURL *) soURLToBaseContainerForCurrentUser;

- (NSString *) labelForKey: (NSString *) key;

/* ownership */

- (void) setOwner: (NSString *) newOwner;
- (NSString *) ownerInContext: (id) _ctx;

/* looking up shared objects */

- (SOGoUserFolder *) lookupUserFolder;
- (SOGoGroupsFolder *) lookupGroupsFolder;

- (void) sleep;

/* hierarchy */

- (NSArray *) fetchSubfolders; /* uses toManyRelationshipKeys */

/* operations */

- (NSException *)delete;
- (id)GETAction:(id)_ctx;

- (SOGoDAVSet *) davCurrentUserPrivilegeSet;

/* etag support */

- (NSException *) matchesRequestConditionInContext:(id)_ctx;

/* acls */

- (NSArray *) subscriptionRoles;

- (BOOL) addUserInAcls: (NSString *) uid;
- (BOOL) removeUserFromAcls: (NSString *) uid;

- (NSArray *) aclUsers;
- (NSArray *) aclsForUser: (NSString *) uid;
- (void) setRoles: (NSArray *) roles
          forUser: (NSString *) uid;
- (void) removeAclsForUsers: (NSArray *) users;
- (NSString *) defaultUserID;

- (void) sendACLAdditionAdvisoryToUser: (NSString *) uid;
- (void) sendACLRemovalAdvisoryToUser: (NSString *) uid;

- (NSString *) httpURLForAdvisoryToUser: (NSString *) uid;
- (NSString *) resourceURLForAdvisoryToUser: (NSString *) uid;

/* dav */
- (NSArray *) davNamespaces;
- (NSString *) davRecordForUser: (NSString *) user;

/* description */

- (void) appendAttributesToDescription:(NSMutableString *)_ms;

@end

#endif /* __SoObjects_SOGoObject_H__ */
