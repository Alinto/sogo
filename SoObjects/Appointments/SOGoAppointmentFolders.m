
/* SOGoAppointmentFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2010 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGExtensions/NSObject+Logs.h>

#import <GDLAccess/EOAdaptorChannel.h>

#import <DOM/DOMProtocols.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/WORequest+SOGo.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoParentFolder.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoWebDAVValue.h>
#import <SOGo/SOGoWebDAVAclManager.h>

#import "SOGoAppointmentFolder.h"
#import "SOGoAppointmentFolderICS.h"
#import "SOGoAppointmentFolderXML.h"
#import "SOGoAppointmentInboxFolder.h"
#import "SOGoWebAppointmentFolder.h"
#import "SOGoUser+Appointments.h"

#import "SOGoAppointmentFolders.h"

@interface SOGoParentFolder (Private)

- (NSException *) _fetchPersonalFolders: (NSString *) sql
                            withChannel: (EOAdaptorChannel *) fc;

@end

static SoSecurityManager *sm = nil;

@implementation SOGoAppointmentFolders

+ (void) initialize
{
  if (!sm)
    sm = [SoSecurityManager sharedSecurityManager];
}

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;

  if (!aclManager)
    {
      aclManager = [[super webdavAclManager] copy];
      [aclManager 
        registerDAVPermission: davElement (@"write", XMLNS_WEBDAV)
                     abstract: NO
               withEquivalent: SoPerm_AddDocumentsImagesAndFiles
                    asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager
        registerDAVPermission: davElement (@"write-properties", XMLNS_WEBDAV)
                     abstract: YES
               withEquivalent: SoPerm_AddDocumentsImagesAndFiles
                    asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager
        registerDAVPermission: davElement (@"write-content", XMLNS_WEBDAV)
                     abstract: YES
               withEquivalent: SoPerm_AddDocumentsImagesAndFiles
                    asChildOf: davElement (@"write", XMLNS_WEBDAV)];
    }

  return aclManager;
}

- (id) init
{
  if ((self = [super init]))
    {
      folderObjectKeys = nil;
    }

  return self;
}

- (void) dealloc
{
  [folderObjectKeys release];
  [super dealloc];
}

+ (NSString *) gcsFolderType
{
  return @"Appointment";
}

+ (Class) subFolderClass
{
  return [SOGoAppointmentFolder class];
}

- (NSString *) defaultFolderName
{
  return [self labelForKey: @"Personal Calendar" inContext: context];
}

- (SOGoWebAppointmentFolder *)
 newWebCalendarWithName: (NSString *) folderDisplayName
                  atURL: (NSString *) urlString
{
  NSException *error;
  SOGoAppointmentFolder *aptFolder;
  SOGoWebAppointmentFolder *webCalendar;
  NSString *name;
  NSURL *url;

  webCalendar = nil;

  if ([folderDisplayName length] > 0 && [urlString length] > 0)
    {
      url = [NSURL URLWithString: urlString];
      if ([[url scheme] hasPrefix: @"http"])
        {
          error = [self newFolderWithName: folderDisplayName
                          nameInContainer: &name];
          if (!error)
            {
              aptFolder = [subFolders objectForKey: name];
              [aptFolder setFolderPropertyValue: urlString
                                     inCategory: @"WebCalendars"];
              
              webCalendar = [SOGoWebAppointmentFolder objectWithName: name
                                                         inContainer: self];
              [webCalendar setOCSPath: [aptFolder ocsPath]];
              [subFolders setObject: webCalendar forKey: name];
            }
        }
    }

  return webCalendar;
}

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *keys;
  NSEnumerator *sortedSubFolders;
  SOGoAppointmentFolder *currentFolder;
  SOGoUser *currentUser;
  NSString *login;

  if ([[context request] isICal])
    {
      currentUser = [context activeUser];
      login = [currentUser login];
      keys = [NSMutableArray array];
      [keys addObject: @"inbox"];
      if ([owner isEqualToString: login])
        {
          sortedSubFolders = [[self subFolders] objectEnumerator];
          while ((currentFolder = [sortedSubFolders nextObject]))
            {
              if ([[currentFolder ownerInContext: context]
                    isEqualToString: owner])
                [keys addObject: [currentFolder nameInContainer]];
            }
        }
      else
        {
          sortedSubFolders = [[self subFolders] objectEnumerator];
          while ((currentFolder = [sortedSubFolders nextObject]))
            if ([currentUser hasSubscribedToCalendar: currentFolder]
                && ([currentFolder proxyPermissionForUserWithLogin: login]
                    != SOGoAppointmentProxyPermissionNone))
              [keys addObject: [currentFolder nameInContainer]];
        }
    }
  else
    keys = (NSMutableArray *) [super toManyRelationshipKeys];

  return keys;
}

- (NSArray *) folderObjectKeys
{
  NSArray *folders;
  SOGoAppointmentFolder *folder;
  NSString *folderObjectKey;
  int count, max;
  BOOL ignoreRights;

  if (!folderObjectKeys)
    {
      ignoreRights = [self ignoreRights];
      folders = [self subFolders];
      max = [folders count];
      folderObjectKeys = [[NSMutableArray alloc] initWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          folder = [folders objectAtIndex: count];
          if ([folder isMemberOfClass: [SOGoAppointmentFolder class]]
              && ![folder isSubscription]
              && (ignoreRights || ![sm validatePermission: SOGoPerm_AccessObject
                                                 onObject: folder
                                                inContext: context]))
            {
              folderObjectKey = [NSString stringWithFormat: @"%@.ics",
                                          [folder nameInContainer]];
              [folderObjectKeys addObject: folderObjectKey];
              folderObjectKey = [NSString stringWithFormat: @"%@.xml",
                                          [folder nameInContainer]];
              [folderObjectKeys addObject: folderObjectKey];
            }
        }
    }

  return folderObjectKeys;
}

- (NSArray *) toOneRelationshipKeys
{
  NSArray *keys;

  if ([[context request] isICal])
    keys = [NSArray array];
  else
    keys = [self folderObjectKeys];

  return keys;
}

- (id) lookupName: (NSString *) name
        inContext: (WOContext *) lookupContext
          acquire: (BOOL) acquire
{
  id obj;

  if ([name isEqualToString: @"inbox"])
    obj = [SOGoAppointmentInboxFolder objectWithName: name
                                         inContainer: self];
  else if ([[self folderObjectKeys] containsObject: name])
    {
      if ([name hasSuffix: @".ics"])
        obj = [SOGoAppointmentFolderICS objectWithName: name
                                           inContainer: self];
      else if ([name hasSuffix: @".xml"])
        obj = [SOGoAppointmentFolderXML objectWithName: name
                                           inContainer: self];
      else
        obj = nil;
    }
  else
    obj = [super lookupName: name inContext: lookupContext acquire: NO];

  return obj;
}

- (NSString *) _fetchPropertyWithName: (NSString *) propertyName
			      inArray: (NSArray *) section
{
  NSObject <DOMElement> *currentElement;
  NSString *currentName, *property;
  NSEnumerator *elements;
  NSObject <DOMNodeList> *values;

  property = nil;

  elements = [section objectEnumerator];
  while (!property && (currentElement = [elements nextObject]))
    {
      currentName = [NSString stringWithFormat: @"{%@}%@",
			      [currentElement namespaceURI],
			      [currentElement nodeName]];
      if ([currentName isEqualToString: propertyName])
	{
	  values = [currentElement childNodes];
	  if ([values length])
	    property = [[values objectAtIndex: 0] nodeValue];
	}
    }

  return property;
}

#warning this method may be useful at a higher level
#warning not all values are simple strings...
- (NSException *) _applyMkCalendarProperties: (NSArray *) properties
				    toObject: (SOGoObject *) newFolder
{
  NSEnumerator *allProperties;
  NSObject <DOMElement> *currentProperty;
  NSObject <DOMNodeList> *values;
  NSString *value, *currentName;
  SEL methodSel;

  allProperties = [properties objectEnumerator];
  while ((currentProperty = [allProperties nextObject]))
    {
      values = [currentProperty childNodes];
      if ([values length])
	{
	  value = [[values objectAtIndex: 0] nodeValue];
	  currentName = [NSString stringWithFormat: @"{%@}%@",
				  [currentProperty namespaceURI],
				  [currentProperty nodeName]];
	  methodSel = SOGoSelectorForPropertySetter (currentName);
	  if ([newFolder respondsToSelector: methodSel])
	    [newFolder performSelector: methodSel
		       withObject: value];
	}
    }

  return nil;
}

- (NSException *) davCreateCalendarCollection: (NSString *) newName
				    inContext: (id) createContext
{
  NSArray *subfolderNames, *setProperties;
  NSString *content, *newDisplayName;
  NSDictionary *properties;
  NSException *error;
  SOGoAppointmentFolder *newFolder;

  subfolderNames = [self toManyRelationshipKeys];
  if ([subfolderNames containsObject: newName])
    {
      content = [NSString stringWithFormat:
			    @"A collection named '%@' already exists.",
			  newName];
      error = [NSException exceptionWithHTTPStatus: 403
			   reason: content];
    }
  else
    {
      properties = [[createContext request]
		     davPatchedPropertiesWithTopTag: @"mkcalendar"];
      setProperties = [properties objectForKey: @"set"];
      newDisplayName = [self _fetchPropertyWithName: @"{DAV:}displayname"
			     inArray: setProperties];
      if (![newDisplayName length])
	newDisplayName = newName;
      error
	= [self newFolderWithName: newDisplayName andNameInContainer: newName];
      if (!error)
	{
	  newFolder = [self lookupName: newName
			    inContext: createContext
			    acquire: NO];
	  error = [self _applyMkCalendarProperties: setProperties
			toObject: newFolder];
	}
    }

  return error;
}

- (SOGoWebDAVValue *) davCalendarComponentSet
{
  static SOGoWebDAVValue *componentSet = nil;
  NSMutableArray *components;

  if (!componentSet)
    {
      components = [NSMutableArray array];
      /* Totally hackish.... we use the "n1" prefix because we know our
         extensions will assign that one to ..:caldav but we really need to
         handle element attributes */
      [components addObject: [SOGoWebDAVValue
                               valueForObject: @"<n1:comp name=\"VEVENT\"/>"
                                   attributes: nil]];
      [components addObject: [SOGoWebDAVValue
                               valueForObject: @"<n1:comp name=\"VTODO\"/>"
                                   attributes: nil]];
      componentSet
        = [davElementWithContent (@"supported-calendar-component-set",
                                  XMLNS_CALDAV, components)
                                 asWebDAVValue];
      [componentSet retain];
    }

  return componentSet;
}

- (NSString *) _davDefaultClassWithSelector: (SEL) selector
{
  SOGoUser *ownerUser;
  SOGoUserDefaults *defaults;
  NSString *classification;

  ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
  defaults = [ownerUser userDefaults];
  classification = [defaults performSelector: selector];

  return classification;
}

- (NSException *) _davSetDefaultClass: (NSString *) newClass
                         withSelector: (SEL) selector
{
  NSException *error;
  static NSArray *validClassifications = nil;
  SOGoUser *ownerUser;
  SOGoUserDefaults *defaults;

  if (!validClassifications)
    validClassifications = [[NSArray alloc] initWithObjects: @"PUBLIC",
                                           @"CONFIDENTIAL", @"PRIVATE", nil];

  if (newClass && [validClassifications containsObject: newClass])
    {
      error = nil;
      ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
      defaults = [ownerUser userDefaults];
      [defaults performSelector: selector withObject: newClass];
      [defaults synchronize];
    }
  else
    error = [NSException exceptionWithHTTPStatus: 403
                                          reason: @"invalid"
                         @" classification value"];

  return error;
}

- (NSString *) davEventsDefaultClassification
{
  return [self _davDefaultClassWithSelector: @selector (calendarEventsDefaultClassification)];
}

- (NSException *) setDavEventsDefaultClassification: (NSString *) newClass
{
  return [self _davSetDefaultClass: newClass
                      withSelector: @selector (setCalendarEventsDefaultClassification:)];
}

- (NSString *) davTasksDefaultClassification
{
  return [self _davDefaultClassWithSelector: @selector (calendarTasksDefaultClassification)];
}

- (NSException *) setDavTasksDefaultClassification: (NSString *) newClass
{
  return [self _davSetDefaultClass: newClass
                      withSelector: @selector (setCalendarTasksDefaultClassification:)];
}

/* This method fixes an issue that occurred previously in
   _migrateWebCalendarsSettings, where the active user, rather than the
   owner's login would be taken to compose the expected key prefix, leading to
   a corrupted calendar key with an endless chain of
   [user]:/Calendar/[user]:/Calendar/[user].... occurrences. */
- (NSString *) _fixedWebCalendarKey: (NSString *) oldKey
{
  NSString *newKey;
  NSRange lastOccurrence;

  lastOccurrence = [oldKey rangeOfString: @":Calendar/"
                                 options: NSBackwardsSearch];
  if ([oldKey rangeOfString: @":Calendar/"].location
      != lastOccurrence.location)
    {
      newKey
        = [NSString stringWithFormat: @"%@%@", owner,
                    [oldKey substringFromIndex: lastOccurrence.location]];
      [self logWithFormat: @"fixed erroneous calendar key: '%@' -> '%@'",
            oldKey, newKey];
    }
  else
    newKey = nil;

  return newKey;
}

- (void) _migrateWebCalendarsSettings
{
  SOGoUserSettings *us;
  NSDictionary *module;
  NSMutableDictionary *webCalendars;
  NSArray *keys;
  NSString *oldKey, *prefix, *newKey;
  int count, max;
  BOOL hasChanged;

  hasChanged = NO;

  prefix = [NSString stringWithFormat: @"%@:Calendar/",
                 [self ownerInContext: context]];

  us = [[SOGoUser userWithLogin: owner] userSettings];
  module = [us objectForKey: @"Calendar"];
  webCalendars = [module objectForKey: @"WebCalendars"];
  keys = [webCalendars allKeys];
  max = [keys count];

  for (count = 0; count < max; count++)
    {
      oldKey = [keys objectAtIndex: count];
      if ([oldKey hasPrefix: prefix])
        newKey = [self _fixedWebCalendarKey: oldKey];
      else
        newKey = [prefix stringByAppendingString: oldKey];
      if (newKey && ![newKey isEqualToString: oldKey])
        {
          [webCalendars setObject: [webCalendars objectForKey: oldKey]
                           forKey: newKey];
          [webCalendars removeObjectForKey: oldKey];
          hasChanged = YES;
        }
    }
  if (hasChanged)
    [us synchronize];
}

- (void) reloadWebCalendars: (BOOL) forceReload
{
  NSArray *refs;
  SOGoWebAppointmentFolder *folder;
  SOGoUserSettings *us;
  NSDictionary *calSettings;
  NSString *ref;
  int count, max;

  [self _migrateWebCalendarsSettings];
  us = [[SOGoUser userWithLogin: owner] userSettings];
  calSettings = [us objectForKey: @"Calendar"];
  refs = [[calSettings objectForKey: @"WebCalendars"] allKeys];
  max = [refs count];

  for (count = 0; count < max; count++)
    {
      ref = [refs objectAtIndex: count];
      folder = [SOGoWebAppointmentFolder
                 folderWithSubscriptionReference: ref
                                     inContainer: self];
      if (folder
          && (forceReload || [folder reloadOnLogin]))
        [folder loadWebCalendar];
    }
}

- (NSException *) _fetchPersonalFolders: (NSString *) sql
                            withChannel: (EOAdaptorChannel *) fc
{
  BOOL isWebRequest;
  NSException *error;
  NSArray *folders;
  int count, max;
  SOGoAppointmentFolder *folder;
  SOGoWebAppointmentFolder *webFolder;
  NSString *name;

  error = [super _fetchPersonalFolders: sql withChannel: fc];
  if (!error)
    {
      isWebRequest = [[context request] handledByDefaultHandler];
      folders = [subFolders allValues];
      max = [folders count];

      [self _migrateWebCalendarsSettings];
      for (count = 0; count < max; count++)
        {
          folder = [folders objectAtIndex: count];
          if ([folder folderPropertyValueInCategory: @"WebCalendars"])
            {
              name = [folder nameInContainer];
              if (isWebRequest)
                {
                  webFolder = [SOGoWebAppointmentFolder objectWithName: name
                                                        inContainer: self];
                  [webFolder setOCSPath: [folder ocsPath]];
                  [subFolders setObject: webFolder forKey: name];
                }
              else
                [subFolders removeObjectForKey: name];
            }
        }
    }

  return error;
}

- (BOOL) hasProxyCalendarsWithWriteAccess: (BOOL) write
                         forUserWithLogin: (NSString *) userLogin
{
  NSEnumerator *sortedSubFolders;
  SOGoAppointmentFolder *currentFolder;
  SOGoUser *currentUser;
  SOGoAppointmentProxyPermission permission, curPermission, foundPermission;
  BOOL rc;

  if ([owner isEqualToString: userLogin])
    rc = NO;
  else
    {
      foundPermission = SOGoAppointmentProxyPermissionNone;
      permission = (write
                    ? SOGoAppointmentProxyPermissionWrite
                    : SOGoAppointmentProxyPermissionRead);
      currentUser = [SOGoUser userWithLogin: userLogin];
      sortedSubFolders = [[self subFolders] objectEnumerator];
      while ((currentFolder = [sortedSubFolders nextObject]))
        if ([currentUser hasSubscribedToCalendar: currentFolder]
            && [owner
                  isEqualToString: [currentFolder ownerInContext: nil]])
          {
            curPermission = [currentFolder
                              proxyPermissionForUserWithLogin: userLogin];
            if ((foundPermission == SOGoAppointmentProxyPermissionNone)
                || (foundPermission == SOGoAppointmentProxyPermissionRead
                    && curPermission == SOGoAppointmentProxyPermissionWrite))
              foundPermission = curPermission;
          }
      rc = (foundPermission == permission);
    }

  return rc;
}

- (NSArray *) proxySubscribersWithWriteAccess: (BOOL) write
{
  SOGoAppointmentFolder *currentFolder;
  SOGoUser *currentUser;
  NSArray *subFolderNames, *aclUsers;
  NSString *aclUser;
  NSMutableArray *subscribers;
  int folderCount, folderMax, userCount, userMax;

  subscribers = [NSMutableArray array];

  subFolderNames = [self subFolders];
  folderMax = [subFolderNames count];
  for (folderCount = 0; folderCount < folderMax; folderCount++)
    {
      currentFolder = [subFolderNames objectAtIndex: folderCount];
      if ([owner isEqualToString: [currentFolder ownerInContext: nil]])
        {
          aclUsers = [currentFolder aclUsersWithProxyWriteAccess: write];
          userMax = [aclUsers count];
          for (userCount = 0; userCount < userMax; userCount++)
            {
              aclUser = [aclUsers objectAtIndex: userCount];
              if (![subscribers containsObject: aclUser])
                {
                  currentUser = [SOGoUser userWithLogin: aclUser];
                  if ([currentUser hasSubscribedToCalendar: currentFolder])
                    [subscribers addObject: aclUser];
                }
            }
        }
    }

  return subscribers;
}

- (NSArray *) _requiredProxyRolesWithWriteAccess: (BOOL) hasWriteAccess
{
  static NSArray *writeAccessRoles = nil;
  static NSArray *readAccessRoles = nil;
 
  if (!writeAccessRoles)
    writeAccessRoles = [[NSArray alloc] initWithObjects:
                                          SOGoCalendarRole_ConfidentialModifier,
                                        SOGoRole_ObjectCreator,
                                        SOGoRole_ObjectEraser,
                                        SOGoCalendarRole_PrivateModifier,
                                        SOGoCalendarRole_PublicModifier,
                                        nil];
 
  if (!readAccessRoles)
    readAccessRoles = [[NSArray alloc] initWithObjects:
                                         SOGoCalendarRole_ConfidentialViewer,
                                       SOGoCalendarRole_PrivateViewer,
                                       SOGoCalendarRole_PublicViewer,
                                       nil];

  return (hasWriteAccess) ? writeAccessRoles : readAccessRoles;
}

- (void) addProxySubscribers: (NSArray *) proxySubscribers
             withWriteAccess: (BOOL) write
{
  SOGoAppointmentFolder *currentFolder;
  NSArray *subFolderNames, *proxyRoles;
  int folderCount, folderMax, userCount, userMax;

  proxyRoles = [self _requiredProxyRolesWithWriteAccess: write];
  subFolderNames = [self subFolders];
  folderMax = [subFolderNames count];
  for (folderCount = 0; folderCount < folderMax; folderCount++)
    {
      currentFolder = [subFolderNames objectAtIndex: folderCount];
      if ([owner isEqualToString: [currentFolder ownerInContext: nil]])
        {
          [currentFolder setRoles: proxyRoles
                         forUsers: proxySubscribers];

          userMax = [proxySubscribers count];
          for (userCount = 0; userCount < userMax; userCount++)
            [currentFolder
              subscribeUserOrGroup: [proxySubscribers objectAtIndex: userCount]
			  reallyDo: YES];
        }
    }
}

- (void) removeProxySubscribers: (NSArray *) proxySubscribers
                withWriteAccess: (BOOL) write
{
  SOGoAppointmentFolder *currentFolder;
  NSArray *subFolderNames;
  int folderCount, folderMax, userCount, userMax;

  subFolderNames = [self subFolders];
  folderMax = [subFolderNames count];
  for (folderCount = 0; folderCount < folderMax; folderCount++)
    {
      currentFolder = [subFolderNames objectAtIndex: folderCount];
      if ([owner isEqualToString: [currentFolder ownerInContext: nil]])
        {
          [currentFolder removeAclsForUsers: proxySubscribers];

          userMax = [proxySubscribers count];
          for (userCount = 0; userCount < userMax; userCount++)
            [currentFolder
              subscribeUserOrGroup: [proxySubscribers objectAtIndex: userCount]
			  reallyDo: NO];
        }
    }
}

@end
