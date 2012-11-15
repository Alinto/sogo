/* SOGoCalendarProxy.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <SaxObjC/XMLNamespaces.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserSettings.h>

#import <SOGo/NSObject+DAV.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoWebDAVAclManager.h>

#import "SOGoAppointmentFolders.h"

#import "SOGoCalendarProxy.h"

@implementation SOGoCalendarProxy

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;
  NSString *nsI;

  if (!aclManager)
    {
      nsI = @"urn:inverse:params:xml:ns:inverse-dav";

      aclManager = [SOGoWebDAVAclManager new];
      [aclManager registerDAVPermission: davElement (@"read", XMLNS_WEBDAV)
                               abstract: YES
                         withEquivalent: SoPerm_WebDAVAccess
                              asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager
        registerDAVPermission: davElement (@"read-current-user-privilege-set", XMLNS_WEBDAV)
                     abstract: YES
               withEquivalent: SoPerm_WebDAVAccess
                    asChildOf: davElement (@"read", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"write", XMLNS_WEBDAV)
                               abstract: YES
                         withEquivalent: nil
                              asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"bind", XMLNS_WEBDAV)
                               abstract: NO
                         withEquivalent: SoPerm_AddDocumentsImagesAndFiles
                              asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"unbind", XMLNS_WEBDAV)
                               abstract: NO
                         withEquivalent: SoPerm_DeleteObjects
                              asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager
	registerDAVPermission: davElement (@"write-properties", XMLNS_WEBDAV)
                     abstract: NO
               withEquivalent: SoPerm_ChangePermissions /* hackish */
                    asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager
	registerDAVPermission: davElement (@"write-content", XMLNS_WEBDAV)
                     abstract: NO
               withEquivalent: SoPerm_AddDocumentsImagesAndFiles
                    asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"admin", nsI)
                               abstract: YES
                         withEquivalent: nil
                              asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"read-acl", XMLNS_WEBDAV)
                               abstract: YES
                         withEquivalent: SOGoPerm_ReadAcls
                              asChildOf: davElement (@"admin", nsI)];
      [aclManager registerDAVPermission: davElement (@"write-acl", XMLNS_WEBDAV)
                               abstract: YES
                         withEquivalent: SoPerm_ChangePermissions
                              asChildOf: davElement (@"admin", nsI)];
    }

  return aclManager;
}

- (id) init
{
  if ((self = [super init]))
    {
      hasWriteAccess = NO;
    }

  return self;
}

- (void) setWriteAccess: (BOOL) newHasWriteAccess
{
  hasWriteAccess = newHasWriteAccess;
}

- (NSArray *) davResourceType
{
  NSString *proxyType;
  NSMutableArray *rType;

  rType = [NSMutableArray arrayWithArray: [super davResourceType]];
  [rType addObject: @"principal"];
  if (hasWriteAccess)
    proxyType = @"calendar-proxy-write";
  else
    proxyType = @"calendar-proxy-read";
  [rType addObject: [NSArray arrayWithObjects: proxyType,
                             XMLNS_CalendarServerOrg, nil]];

  return rType;
}

- (NSArray *) davGroupMemberSet
{
  NSMutableArray *members;
  NSArray *proxySubscribers, *member;
  NSString *appName, *proxyUser;
  int count, max;

  appName = [[context request] applicationName];

  proxySubscribers
    = [[[self lookupUserFolder] lookupName: @"Calendar"
                                 inContext: context
                                   acquire: NO]
        proxySubscribersWithWriteAccess: hasWriteAccess];
  max = [proxySubscribers count];
  members = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      proxyUser = [proxySubscribers objectAtIndex: count];
      member = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                        [NSString stringWithFormat: @"/%@/dav/%@/",
                                  appName, proxyUser],
                        nil];
      [members addObject: member];
    }

  return members;
}

- (NSString *) _parseSubscriber: (NSString *) memberSet
                          until: (int) length
{
  int begin, end;
  NSRange beginRange;

  end = length;
  if ([memberSet characterAtIndex: end - 1] == '/')
    end--;
  beginRange = [memberSet rangeOfString: @"/"
                                options: NSBackwardsSearch
                                  range: NSMakeRange (0, end)];
  begin = NSMaxRange (beginRange);

  return [memberSet substringWithRange: NSMakeRange (begin, end - begin)];
}

- (NSArray *) _parseSubscribers: (NSString *) memberSet
{
  NSRange endRange;
  NSMutableArray *subscribers;
  NSMutableString *mMemberSet;
  NSString *subscriber;

  subscribers = [NSMutableArray array];
  mMemberSet = [NSMutableString stringWithString: memberSet];

  endRange = [mMemberSet rangeOfString: @"</"];
  while (endRange.location != NSNotFound)
    {
      subscriber = [self _parseSubscriber: mMemberSet
                                    until: endRange.location];
      [subscribers addObjectUniquely: subscriber];
      [mMemberSet
        deleteCharactersInRange: NSMakeRange (0, endRange.location + 1)];
      endRange = [mMemberSet rangeOfString: @"</"];
    }

  return subscribers;
}

- (NSException *) setDavGroupMemberSet: (NSString *) memberSet
{
  NSMutableArray *addedSubscribers, *removedSubscribers;
  NSArray *oldProxySubscribers, *newProxySubscribers;
  SOGoAppointmentFolders *folders;

  folders = [[self lookupUserFolder] lookupName: @"Calendar"
                                      inContext: context
                                        acquire: NO];
  oldProxySubscribers
    = [folders proxySubscribersWithWriteAccess: hasWriteAccess];
  if (!oldProxySubscribers)
    oldProxySubscribers = [NSMutableArray array];
  newProxySubscribers = [self _parseSubscribers: memberSet];
  if (!newProxySubscribers)
    newProxySubscribers = [NSMutableArray array];

  addedSubscribers = [newProxySubscribers mutableCopy];
  [addedSubscribers removeObjectsInArray: oldProxySubscribers];
  [addedSubscribers autorelease];
  [folders addProxySubscribers: addedSubscribers
               withWriteAccess: hasWriteAccess];

  removedSubscribers = [oldProxySubscribers mutableCopy];
  [removedSubscribers removeObjectsInArray: newProxySubscribers];
  [removedSubscribers autorelease];
  [folders removeProxySubscribers: removedSubscribers
                  withWriteAccess: hasWriteAccess];

  return nil;
}

@end
