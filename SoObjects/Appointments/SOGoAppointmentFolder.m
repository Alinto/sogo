/*
  Copyright (C) 2007-2019 Inverse inc.
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSCalendarDate.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSString+misc.h>
#import <GDLContentStore/GCSFolder.h>
#import <EOControl/EOQualifier.h>
#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalFreeBusy.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalTimeZonePeriod.h>
#import <NGCards/iCalToDo.h>
#import <NGCards/NSString+NGCards.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/DOMNode+SOGo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoWebDAVAclManager.h>
#import <SOGo/SOGoWebDAVValue.h>
#import <SOGo/WORequest+SOGo.h>
#import <SOGo/WOResponse+SOGo.h>
#import <SOGo/SOGoSource.h>

#import "iCalCalendar+SOGo.h"
#import "iCalRepeatableEntityObject+SOGo.h"
#import "iCalEvent+SOGo.h"
#import "iCalPerson+SOGo.h"
#import "SOGoAppointmentObject.h"
#import "SOGoAppointmentFolders.h"
#import "SOGoFreeBusyObject.h"
#import "SOGoTaskObject.h"
#import "SOGoWebAppointmentFolder.h"

#define defaultColor @"#AAAAAA"

@interface SOGoGCSFolder (SOGoPrivate)

- (void) appendObject: (NSDictionary *) object
	   properties: (NSString **) properties
                count: (unsigned int) propertiesCount
          withBaseURL: (NSString *) baseURL
	     toBuffer: (NSMutableString *) r;

@end

@implementation SOGoAppointmentFolder

static NSNumber *sharedYes = nil;
static Class iCalEventK = nil;

+ (void) initialize
{
  static BOOL didInit = NO;

  if (!didInit)
    {
      didInit = YES;
      sharedYes = [[NSNumber numberWithBool: YES] retain];
      [iCalEntityObject initializeSOGoExtensions];

      iCalEventK  = [iCalEvent class];
    }
}

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
      [aclManager registerDAVPermission: davElement (@"read-free-busy", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: SOGoCalendarPerm_ReadFreeBusy
                              asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"write", XMLNS_WEBDAV)
                               abstract: YES
                         withEquivalent: nil
                              asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"bind", XMLNS_WEBDAV)
                               abstract: NO
                         withEquivalent: SoPerm_AddDocumentsImagesAndFiles
                              asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"schedule",
						     XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"bind", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"schedule-post",
						     XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-post-vevent", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-post", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-post-vtodo", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-post", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-post-vjournal", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-post", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-post-vfreebusy", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-post", XMLNS_CALDAV)];
      [aclManager registerDAVPermission: davElement (@"schedule-deliver",
						     XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-deliver-vevent", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-deliver", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-deliver-vtodo", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-deliver", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-deliver-vjournal", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-deliver", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-deliver-vfreebusy", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-deliver", XMLNS_CALDAV)];
      [aclManager registerDAVPermission: davElement (@"schedule-respond",
						     XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-respond-vevent", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-respond", XMLNS_CALDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"schedule-respond-vtodo", XMLNS_CALDAV)
                               abstract: NO
                         withEquivalent: nil
                              asChildOf: davElement (@"schedule-respond", XMLNS_CALDAV)];
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

      /* read-acl and write-acl are defined in RFC3744 */
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

      /* Default permissions for calendars. These are very important so that DAV client can
         detect permission changes on calendars and reload all items, if necessary */

      /* Public ones */
      [aclManager registerDAVPermission: davElement (@"viewwhole-public-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ViewWholePublicRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"viewdant-public-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ViewDAndTOfPublicRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"modify-public-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ModifyPublicRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"respondto-public-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_RespondToPublicRecords
                              asChildOf: davElement (@"admin", nsI)];

      /* Private ones */
      [aclManager registerDAVPermission: davElement (@"viewwhole-private-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ViewWholePrivateRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"viewdant-private-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ViewDAndTOfPrivateRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"modify-private-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ModifyPrivateRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"respondto-private-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_RespondToPrivateRecords
                              asChildOf: davElement (@"admin", nsI)];

      /* Condifential ones */
      [aclManager registerDAVPermission: davElement (@"viewwhole-confidential-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ViewWholeConfidentialRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"viewdant-confidential-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ViewDAndTOfConfidentialRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"modify-confidential-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_ModifyConfidentialRecords
                              asChildOf: davElement (@"admin", nsI)];

      [aclManager registerDAVPermission: davElement (@"respondto-confidential-records", nsI)
                               abstract: YES
                         withEquivalent: SOGoCalendarPerm_RespondToConfidentialRecords
                              asChildOf: davElement (@"admin", nsI)];
    }

  return aclManager;
}

- (id) initWithName: (NSString *) name
	inContainer: (id) newContainer
{
  SOGoUser *user;
  if ((self = [super initWithName: name inContainer: newContainer]))
    {
      user = [context activeUser];
      timeZone = [[user userDefaults] timeZone];
      aclMatrix = [NSMutableDictionary new];
      stripFields = nil;
      uidToFilename = nil;
      memset (userCanAccessObjectsClassifiedAs, NO,
              iCalAccessClassCount * sizeof (BOOL));

      davCalendarStartTimeLimit = [[user domainDefaults] davCalendarStartTimeLimit];
      davTimeLimitSeconds = davCalendarStartTimeLimit * 86400;
      /* 86400 / 2 = 43200. We hardcode that value in order to avoid
         integer and float confusion. */
      davTimeHalfLimitSeconds = davCalendarStartTimeLimit * 43200;
      componentSet = nil;

      baseCalDAVURL = nil;
      basePublicCalDAVURL = nil;
    }

  return self;
}

- (void) dealloc
{
  [aclMatrix release];
  [stripFields release];
  [uidToFilename release];
  [componentSet release];
  [baseCalDAVURL release];
  [basePublicCalDAVURL release];
  [super dealloc];
}

- (Class) objectClassForComponentName: (NSString *) componentName
{
  Class objectClass;

  if ([componentName isEqualToString: @"vevent"])
    objectClass = [SOGoAppointmentObject class];
  else if ([componentName isEqualToString: @"vtodo"])
    objectClass = [SOGoTaskObject class];
  else
    objectClass = Nil;

  return objectClass;
}

- (NSString *) calendarColor
{
  NSString *color;

  color = [self folderPropertyValueInCategory: @"FolderColors"];
  if (!color)
    color = defaultColor;

  return color;
}

- (void) setCalendarColor: (NSString *) newColor
{
  if (![newColor length])
    newColor = nil;

  [self setFolderPropertyValue: newColor
                    inCategory: @"FolderColors"];
}

- (BOOL) showCalendarAlarms
{
  NSNumber *showAlarms;

  showAlarms = [self folderPropertyValueInCategory: @"FolderShowAlarms"];

  return (showAlarms ? [showAlarms boolValue] : YES);
}

- (void) setShowCalendarAlarms: (BOOL) new
{
  NSNumber *showAlarms;

  if (new)
    showAlarms = nil;
  else
    showAlarms = [NSNumber numberWithBool: NO];

  [self setFolderPropertyValue: showAlarms
                    inCategory: @"FolderShowAlarms"];    
}

- (BOOL) showCalendarTasks
{
  NSNumber *showTasks;

  showTasks = [self folderPropertyValueInCategory: @"FolderShowTasks"];

  return (showTasks ? [showTasks boolValue] : YES);
}

- (void) setShowCalendarTasks: (BOOL) new
{
  NSNumber *showTasks;

  /* the default value is "YES", so we keep only those with a value of "NO"... */
  if (new)
    showTasks = nil;
  else
    showTasks = [NSNumber numberWithBool: NO];

  [self setFolderPropertyValue: showTasks
                    inCategory: @"FolderShowTasks"];    
}

- (BOOL) subscribeUserOrGroup: (NSString *) theIdentifier
		     reallyDo: (BOOL) reallyDo
                     response: (WOResponse *) theResponse
{
  NSMutableDictionary *moduleSettings, *folderShowAlarms, *freeBusyExclusions;
  NSString *subscriptionPointer, *domain;
  NSMutableArray *allUsers;
  SOGoUserSettings *us;
  NSDictionary *dict;
  BOOL rc;
  int i;

  rc = [super subscribeUserOrGroup: theIdentifier reallyDo: reallyDo response: theResponse];

  if (rc)
    {
#warning Duplicated code from SOGoGCSFolder subscribeUserOrGroup
     domain = [[context activeUser] domain];
     dict = [[SOGoUserManager sharedUserManager] contactInfosForUserWithUIDorEmail: theIdentifier
                                                                          inDomain: domain];

     if (dict && [[dict objectForKey: @"isGroup"] boolValue])
       {
         id <SOGoSource> source;

         source = [[SOGoUserManager sharedUserManager] sourceWithID: [dict objectForKey: @"SOGoSource"]];
         if ([source conformsToProtocol:@protocol(SOGoMembershipSource)])
           {
             NSArray *members;

             members = [(id<SOGoMembershipSource>)(source) membersForGroupWithUID: [dict objectForKey: @"c_uid"]];
             allUsers = [NSMutableArray array];

             for (i = 0; i < [members count]; i++)
               {
                 [allUsers addObject: [[members objectAtIndex: i] objectForKey: @"c_uid"]];
               }
             // We remove the active user from the group (if present) in order to
             // not subscribe him to their own resource!
             [allUsers removeObject: [[context activeUser] login]];
           }
         else
           {
             [self errorWithFormat: @"Inconsistency error - got group identifier (%@) from a source (%@) that does not support groups (%@).", theIdentifier, [dict objectForKey: @"SOGoSource"], NSStringFromClass([source class])];
             return NO;
           }
       }
     else
       {
         if (dict)
           allUsers = [NSArray arrayWithObject: [dict objectForKey: @"c_uid"]];
         else
           allUsers = [NSArray array];
       }

      for (i = 0; i < [allUsers count]; i++)
        {
          us = [SOGoUserSettings settingsForUser: [allUsers objectAtIndex: i]];
          moduleSettings = [us objectForKey: [container nameInContainer]];
          if (!(moduleSettings
                && [moduleSettings isKindOfClass: [NSMutableDictionary class]]))
            {
              moduleSettings = [NSMutableDictionary dictionary];
              [us setObject: moduleSettings forKey: [container nameInContainer]];
            }

          subscriptionPointer = [self folderReference];

          folderShowAlarms = [moduleSettings objectForKey: @"FolderShowAlarms"];
          freeBusyExclusions = [moduleSettings objectForKey: @"FreeBusyExclusions"];

          if (reallyDo)
            {
              if (!(folderShowAlarms
                    && [folderShowAlarms isKindOfClass: [NSMutableDictionary class]]))
                {
                  folderShowAlarms = [NSMutableDictionary dictionary];
                  [moduleSettings setObject: folderShowAlarms
                                     forKey: @"FolderShowAlarms"];
                }

              // By default, we disable alarms on subscribed calendars
              [folderShowAlarms setObject: [NSNumber numberWithBool: NO]
                                   forKey: subscriptionPointer];
            }
          else
            {
              [folderShowAlarms removeObjectForKey: subscriptionPointer];
              [freeBusyExclusions removeObjectForKey: subscriptionPointer];
            }

          [us synchronize];

          rc = YES;
        }
    }

  return rc;
}

//
// If the user is the owner of the calendar, by default we include the freebusy information.
//
// If the user is NOT the owner of the calendar, by default we exclude the freebusy information.
//
// We must include the freebusy information of other users if we are actually looking at their freebusy information
// but we aren't necessarily subscribed to their calendars.
//
- (BOOL) includeInFreeBusy
{
  NSNumber *excludeFromFreeBusy;
  NSString *userLogin, *ownerInContext;
  BOOL is_owner;
  
  userLogin = [[context activeUser] login];
  ownerInContext = [[self container] ownerInContext: context];
  is_owner = [userLogin isEqualToString: ownerInContext];

  if (is_owner)
    excludeFromFreeBusy
      = [self folderPropertyValueInCategory: @"FreeBusyExclusions"
				    forUser: [context activeUser]];
  else
    excludeFromFreeBusy
      = [self folderPropertyValueInCategory: @"FreeBusyExclusions"
				    forUser: [SOGoUser userWithLogin: ownerInContext]];

  // User has no setting for freebusy inclusion/exclusion,
  //   * include it if it's a personal folder;
  //   * exclude it if it's a subscription.
  if (!excludeFromFreeBusy)
    {
      if ([self isSubscription])
        return NO;
      else
        return YES;
    }

  return ![excludeFromFreeBusy boolValue];
}

- (void) setIncludeInFreeBusy: (BOOL) newInclude
{
  NSNumber *excludeFromFreeBusy;

  excludeFromFreeBusy = [NSNumber numberWithBool: !newInclude];

  [self setFolderPropertyValue: excludeFromFreeBusy
                    inCategory: @"FreeBusyExclusions"];
}

- (BOOL) _notificationValueForKey: (NSString *) theKey
                 defaultDomainKey: (NSString *) theDomainKey
{
  SOGoUser *ownerUser;
  NSNumber *notify;
  
  ownerUser = [SOGoUser userWithLogin: self->owner];
  notify = [self folderPropertyValueInCategory: theKey
				       forUser: ownerUser];

  if (!notify && theDomainKey)
    notify = [NSNumber numberWithBool: [[[context activeUser] domainDefaults]
					 boolForKey: theDomainKey]];

  return [notify boolValue];
}

//
// We MUST keep the 'NO' value here, because we will always
// fallback to the domain defaults otherwise.
//
- (void) _setNotificationValue: (BOOL) b
                        forKey: (NSString *) theKey
{
  [self setFolderPropertyValue: [NSNumber numberWithBool: b]
		    inCategory: theKey];
}

- (BOOL) notifyOnPersonalModifications
{
  return [self _notificationValueForKey: @"NotifyOnPersonalModifications"
		       defaultDomainKey: @"SOGoNotifyOnPersonalModifications"];
}

- (void) setNotifyOnPersonalModifications: (BOOL) b
{
  [self _setNotificationValue: b  forKey: @"NotifyOnPersonalModifications"];
}

- (BOOL) notifyOnExternalModifications
{
  return [self _notificationValueForKey: @"NotifyOnExternalModifications"
		       defaultDomainKey: @"SOGoNotifyOnExternalModifications"];
}

- (void) setNotifyOnExternalModifications: (BOOL) b
{
  [self _setNotificationValue: b  forKey: @"NotifyOnExternalModifications"];
}

- (BOOL) notifyUserOnPersonalModifications
{
  return [self _notificationValueForKey: @"NotifyUserOnPersonalModifications"
		       defaultDomainKey: nil];
}

- (void) setNotifyUserOnPersonalModifications: (BOOL) b
{
  [self _setNotificationValue: b  forKey: @"NotifyUserOnPersonalModifications"];
  
}

- (NSString *) notifiedUserOnPersonalModifications
{
  SOGoUser *ownerUser;

  ownerUser = [SOGoUser userWithLogin: self->owner];

  return [self folderPropertyValueInCategory: @"NotifiedUserOnPersonalModifications"
				     forUser: ownerUser];
}

- (void) setNotifiedUserOnPersonalModifications: (NSString *) theUser
{
  [self setFolderPropertyValue: theUser
                    inCategory: @"NotifiedUserOnPersonalModifications"];
}

/* selection */

- (NSArray *) calendarUIDs 
{
  /* this is used for group calendars (this folder just returns itself) */
  NSString *s;
  s = [[self container] nameInContainer];
//   [self logWithFormat:@"CAL UID: %@", s];
  return [s isNotNull] ? [NSArray arrayWithObjects:&s count:1] : nil;
}

/* fetching */

- (NSString *) _sqlStringRangeFrom: (NSCalendarDate *) _startDate
                                to: (NSCalendarDate *) _endDate
                             cycle: (BOOL) _isCycle
{
  NSString *format;
  unsigned int start, end;

  start = (unsigned int) [_startDate timeIntervalSince1970];
  end = (unsigned int) [_endDate timeIntervalSince1970];

  // vTODOs don't necessarily have start/end dates
  if (_isCycle)
    format = (@"(c_startdate = NULL OR c_startdate <= %u)"
              @" AND (c_cycleenddate = NULL OR c_cycleenddate >= %u)");
  else
    format = (@"(c_startdate = NULL OR c_startdate <= %u)"
              @" AND (c_enddate = NULL OR c_enddate >= %u)");

  return [NSString stringWithFormat: format, end, start];
}

- (NSString *) aclSQLListingFilter
{
  NSString *filter;
  NSMutableArray *grantedClasses, *deniedClasses;
  NSNumber *classNumber;
  unsigned int grantedCount;
  iCalAccessClass currentClass;
  WOContext *localContext;

  /* FIXME: The stored context from initialisation may have changed
     by setContext by other operations in OpenChange library,
     so we keep tighly to use the current session one. Without
     this, the login is set to nil and a NSException is raised
     at [SOGoAppointmentFolder:roleForComponentsWithAccessClass:forUser]
     inside [SOGoAppointmentFolder:initializeQuickTablesAclsInContext]. */
  localContext = [[WOApplication application] context];
  [self initializeQuickTablesAclsInContext: localContext];
  grantedClasses = [NSMutableArray arrayWithCapacity: 3];
  deniedClasses = [NSMutableArray arrayWithCapacity: 3];
  for (currentClass = 0;
       currentClass < iCalAccessClassCount; currentClass++)
    {
      classNumber = [NSNumber numberWithInt: currentClass];
      if (userCanAccessObjectsClassifiedAs[currentClass])
        [grantedClasses addObject: classNumber];
      else
        [deniedClasses addObject: classNumber];
    }
  grantedCount = [grantedClasses count];
  if (grantedCount == 3)
    {
      // User have access to all three classifications
      filter = @"";
    }
  else if (grantedCount == 2)
    {
      // User has access to all but one of the classifications
      filter = [NSString stringWithFormat: @"c_classification != %@",
                         [deniedClasses objectAtIndex: 0]];
    }
  else if (grantedCount == 1)
    {
      // User has access to only one classification
      filter = [NSString stringWithFormat: @"c_classification = %@",
                         [grantedClasses objectAtIndex: 0]];
    }
  else
    {
      // User has access to no classification
      filter = nil;
    }

  return filter;
}

- (NSString *) componentSQLFilter
{
  NSString *filter;

  if ([self showCalendarTasks])
    filter = nil;
  else
    filter = @"c_component != 'vtodo'";

  return filter;
}

- (BOOL) _checkIfWeCanRememberRecords: (NSArray *) fields
{
  return ([fields containsObject: @"c_name"]
	  && [fields containsObject: @"c_version"]
	  && [fields containsObject: @"c_lastmodified"]
	  && [fields containsObject: @"c_creationdate"]
	  && [fields containsObject: @"c_component"]);
}

- (void) _rememberRecords: (NSArray *) records
{
  NSEnumerator *recordsEnum;
  NSDictionary *currentRecord;

  recordsEnum = [records objectEnumerator];
  while ((currentRecord = [recordsEnum nextObject]))
    [childRecords setObject: currentRecord
		  forKey: [currentRecord objectForKey: @"c_name"]];
}

#warning filters should make use of EOQualifier
- (NSArray *) bareFetchFields: (NSArray *) fields
                         from: (NSCalendarDate *) startDate
                           to: (NSCalendarDate *) endDate 
                        title: (NSString *) title
                    component: (NSString *) component
            additionalFilters: (NSString *) filters
{
  EOQualifier *qualifier;
  GCSFolder *folder;
  NSMutableArray *baseWhere;
  NSString *where, *privacySQLString;
  NSArray *records;

  folder = [self ocsFolder];

  baseWhere = [NSMutableArray arrayWithCapacity: 32];
  if (startDate && endDate)
    [baseWhere addObject: [self _sqlStringRangeFrom: startDate to: endDate
                                              cycle: NO]];

  if ([title length])
    [baseWhere
      addObject: [NSString stringWithFormat: @"c_title isCaseInsensitiveLike: '%%%@%%'",
                           [title asSafeSQLString]]];

  if (component)
    {
      if ([component isEqualToString: @"vtodo"] && ![self showCalendarTasks])
        return [NSArray array];
      else
        [baseWhere addObject: [NSString stringWithFormat: @"c_component = '%@'",
                                        component]];
    }
  else if (![self showCalendarTasks])
      [baseWhere addObject: @"c_component != 'vtodo'"];

  if ([filters length])
    [baseWhere addObject: filters];

  privacySQLString = [self aclSQLListingFilter];
  if (privacySQLString)
    {
      if ([privacySQLString length])
        [baseWhere addObject: privacySQLString];

      /* sql is empty when we fetch everything (all parameters are nil) */
      if ([baseWhere count] > 0)
        {
          where = [baseWhere componentsJoinedByString: @" AND "];
          qualifier = [EOQualifier qualifierWithQualifierFormat: where];
        }
      else
        qualifier = nil;

      /* fetch non-recurrent apts first */
      records = [folder fetchFields: fields matchingQualifier: qualifier];
    }
  else
    records = [NSArray array];
  
  if ([self _checkIfWeCanRememberRecords: fields])
    [self _rememberRecords: records];

  return records;
}

/**
 * Set the timezone of the event start and end dates to the user's timezone.
 * @param theRecord a dictionary with the attributes of the event.
 * @return a copy of theRecord with adjusted dates.
 */
- (NSMutableDictionary *) _fixupRecord: (NSDictionary *) theRecord
{
  NSMutableDictionary *record;
  static NSString *fields[] = { @"c_startdate", @"startDate",
				@"c_enddate", @"endDate" };
  unsigned int count;
  NSCalendarDate *date;
  NSNumber *dateValue;
  BOOL isAllDay;
  NSInteger offset;

  isAllDay = [[theRecord objectForKey: @"c_isallday"] boolValue];
  record = [[theRecord mutableCopy] autorelease];
  for (count = 0; count < 2; count++)
    {
      dateValue = [theRecord objectForKey: fields[count * 2]];
      if (dateValue)
	{
	  date = [NSCalendarDate dateWithTimeIntervalSince1970: [dateValue unsignedIntValue]];
	  if (date)
	    {
	      [date setTimeZone: timeZone];
              if (isAllDay)
		{
		  // Since there's no timezone associated to all-day events,
		  // their time must be adjusted for the user's timezone.
		  offset = [timeZone secondsFromGMTForDate: date];
		  date = (NSCalendarDate*)[date dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
							  seconds:-offset];
		  [record setObject: [NSNumber numberWithInt: [dateValue intValue] - offset] forKey: fields[count * 2]];
		}
	      [record setObject: date forKey: fields[count * 2 + 1]];
	    }
	}
      else
	[self logWithFormat: @"missing '%@' in record?", fields[count * 2]];
    }

  return record;
}

//
//
//
- (NSArray *) _fixupRecords: (NSArray *) theRecords
{
  // TODO: is the result supposed to be sorted by date?
  NSMutableArray *ma;
  unsigned count, max;
  id row;

  if (theRecords)
    {
      max = [theRecords count];
      ma = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
	{
	  row = [self _fixupRecord: [theRecords objectAtIndex: count]];
	  if (row)
	    [ma addObject: row];
	}
    }
  else
    ma = nil;

  return ma;
}

/**
 * Adjust the timezone of the start and end dates to the user's timezone.
 * The event is recurrent and the dates must first be adjusted with respect to
 * the event's timezone.
 * @param theRecord
 * @param theCycle
 * @param theFirstCycle
 * @param theEventTimeZone
 * @see fixupRecord:
 * @return a copy of theRecord with adjusted dates.
 */
- (NSMutableDictionary *) fixupCycleRecord: (NSDictionary *) theRecord
                                cycleRange: (NGCalendarDateRange *) theCycle
	    firstInstanceCalendarDateRange: (NGCalendarDateRange *) theFirstCycle
			 withEventTimeZone: (iCalTimeZone *) theEventTimeZone
{
  NSMutableDictionary *record;
  NSNumber *dateSecs;
  id date;
  int secondsOffsetFromGMT;

  record = [[theRecord mutableCopy] autorelease];

  date = [theCycle startDate];
  if (theEventTimeZone)
    {
      secondsOffsetFromGMT = (int) [[theEventTimeZone periodForDate: date] secondsOffsetFromGMT];
      date = [date dateByAddingYears: 0 months: 0 days: 0 hours: 0 minutes: 0 seconds: -secondsOffsetFromGMT];
    }
  [date setTimeZone: timeZone];
  [record setObject: date forKey: @"startDate"];
  dateSecs = [NSNumber numberWithInt: [date timeIntervalSince1970]];
  [record setObject: dateSecs forKey: @"c_startdate"];

  if ([[record valueForKey: @"c_isallday"] boolValue])
    {
      // Refer to all-day recurrence id by their GMT-based start date
      date = [theCycle startDate];
      secondsOffsetFromGMT = (int) [[date timeZone] secondsFromGMTForDate: date];
      date = [date dateByAddingYears: 0 months: 0 days: 0 hours: 0 minutes: 0 seconds: secondsOffsetFromGMT];
      dateSecs = [NSNumber numberWithInt: [date timeIntervalSince1970]];
    }
  [record setObject: dateSecs forKey: @"c_recurrence_id"];

  date = [record valueForKey: @"c_enddate"];
  if ([date isNotNull])
    {
      date = [theCycle endDate];
      if (theEventTimeZone)
        {
          secondsOffsetFromGMT = (int) [[theEventTimeZone periodForDate: date] secondsOffsetFromGMT];
          date = [date dateByAddingYears: 0 months: 0 days: 0 hours: 0 minutes: 0 seconds: -secondsOffsetFromGMT];
        }
      [date setTimeZone: timeZone];
      [record setObject: date forKey: @"endDate"];
      dateSecs = [NSNumber numberWithInt: [date timeIntervalSince1970]];
      [record setObject: dateSecs forKey: @"c_enddate"];
    }
  else
    [record removeObjectForKey: @"endDate"];
  
  return record;
}

//
//
//
- (int) _indexOfRecordMatchingDate: (NSCalendarDate *) matchDate
			   inArray: (NSArray *) recordArray
{
  int count, max, recordIndex;
  NSDictionary *currentRecord;

  recordIndex = -1;
  count = 0;
  max = [recordArray count];
  while (recordIndex == -1 && count < max)
    {
      currentRecord = [recordArray objectAtIndex: count];
      if ([[currentRecord objectForKey: @"startDate"]
	    compare: matchDate] == NSOrderedSame)
	recordIndex = count;
      else
	count++;
    }

  return recordIndex;
}

//
//
//
- (void) _fixExceptionRecord: (NSMutableDictionary *) recRecord
		     fromRow: (NSDictionary *) row
{
  NSArray *objects;
  static NSArray *fields = nil;

  if (!fields)
    {
      fields = [NSArray arrayWithObjects: @"c_name", nil];
      [fields retain];
    }

  objects = [row objectsForKeys: fields notFoundMarker: @""];
  [recRecord setObjects: objects forKeys: fields];
}

//
//
//
- (void) _computeAlarmForRow: (NSMutableDictionary *) row
                      master: (iCalEntityObject *) master
{
  iCalEntityObject *component;
  iCalAlarm *alarm;
  
  if (![master recurrenceId])
    {
      component = [master copy];

      [component setStartDate: [NSCalendarDate dateWithTimeIntervalSince1970: [[row objectForKey: @"c_startdate"] intValue]]];

      if ([component isKindOfClass: [iCalEvent class]])
        {
          [(iCalEvent *)component setEndDate: [NSCalendarDate dateWithTimeIntervalSince1970: [[row objectForKey: @"c_enddate"] intValue]]];
        }
      else
        {
          [(iCalToDo *)component setDue: [NSCalendarDate dateWithTimeIntervalSince1970: [[row objectForKey: @"c_enddate"] intValue]]];
        }
    }
  else
    {
      component = master;
      RETAIN(component);
    }

  // Check if we have any alarm, that could happen for recurrence exceptions with no
  // alarm defined.
  if ([[component alarms] count])
    {
      alarm = [component firstSupportedAlarm];
      [row setObject: [NSNumber numberWithInt: [[alarm nextAlarmDate] timeIntervalSince1970]]
              forKey: @"c_nextalarm"];
    }

  RELEASE(component);
}

//
//
//
- (void) _appendCycleException: (iCalRepeatableEntityObject *) component
firstInstanceCalendarDateRange: (NGCalendarDateRange *) fir
		       fromRow: (NSDictionary *) row
		      forRange: (NGCalendarDateRange *) dateRange
                  withTimeZone: (NSTimeZone *) tz
                       toArray: (NSMutableArray *) ma
{
  NGCalendarDateRange *recurrenceIdRange;
  NSCalendarDate *recurrenceId, *masterEndDate, *endDate;
  NSMutableDictionary *newRecord;
  NGCalendarDateRange *newRecordRange;
  NSNumber *dateSecs;
  id master;

  int recordIndex, secondsOffsetFromGMT;
  NSTimeInterval delta;

  newRecord = nil;
  recurrenceId = [component recurrenceId];

  if (!recurrenceId)
    {
      [self errorWithFormat: @"ignored component with an empty EXCEPTION-ID"];
      return;
    }
  
  if (tz)
    {
      // The following adjustment is necessary for floating all-day events.
      // For example, the recurrence-id 20120523T000000Z for timezone -0400
      // will become 20120523T000400Z
      secondsOffsetFromGMT = [tz secondsFromGMTForDate: recurrenceId];
      recurrenceId = (NSCalendarDate *) [recurrenceId dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                                seconds:-secondsOffsetFromGMT];
      [recurrenceId setTimeZone: tz];
    }

  if ([component isKindOfClass: [iCalEvent class]])
    {
      master = [[[component parent] events] objectAtIndex: 0];
      masterEndDate = [master endDate];
      endDate = [(iCalEvent*) component endDate];
    }
  else
    {
      master = [[[component parent] todos] objectAtIndex: 0];
      masterEndDate = [master due];
      endDate = [(iCalToDo*) component due];
    }

  if (![master startDate])
    {
      [self errorWithFormat: @"ignored component with no DTSTART"];
      return;
    }

  delta = [masterEndDate timeIntervalSinceDate: [master startDate]];
  recurrenceIdRange = [NGCalendarDateRange calendarDateRangeWithStartDate: recurrenceId
								  endDate: [recurrenceId dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds: delta]];
  if ([dateRange doesIntersectWithDateRange: recurrenceIdRange])
    {
      // The recurrence exception intersects with the date range;
      // find the occurence and replace it with the new record
      recordIndex = [self _indexOfRecordMatchingDate: recurrenceId inArray: ma];
      if (recordIndex > -1)
	{
          if ([dateRange containsDate: [component startDate]] ||
	      (endDate && [dateRange containsDate: endDate]))
	    {
              // We must pass nil to :container here in order to avoid re-entrancy issues.
              newRecord = [self _fixupRecord: [component quickRecordFromContent: nil  container: nil  nameInContainer: nil]];
              [ma replaceObjectAtIndex: recordIndex withObject: newRecord];
            }
          else
            // The range doesn't cover the exception; remove it from the records
            [ma removeObjectAtIndex: recordIndex];
        }
      else
	[self errorWithFormat:
		@"missing exception record for recurrence-id %@ (uid %@)",
	      recurrenceId, [component uid]];
    }
  else
    {
      // The recurrence id of the exception is outside the date range;
      // simply add the exception to the records array.
      // We must pass nil to :container here in order to avoid re-entrancy issues.
      newRecord = [self _fixupRecord: [component quickRecordFromContent: nil  container: nil  nameInContainer: nil]];
      if ([newRecord objectForKey: @"startDate"] && [newRecord objectForKey: @"endDate"]) {
        newRecordRange = [NGCalendarDateRange
                           calendarDateRangeWithStartDate: [newRecord objectForKey: @"startDate"]
                                                  endDate: [newRecord objectForKey: @"endDate"]];
        if ([dateRange doesIntersectWithDateRange: newRecordRange])
          [ma addObject: newRecord];
        else
          newRecord = nil;
      } else {
        [self warnWithFormat: @"Recurrence %@ without dtstart or dtend. Ignoring", recurrenceId];
        newRecord = nil;
      }
    }

  if (newRecord)
    {
      recurrenceId = [component recurrenceId];
      dateSecs = [NSNumber numberWithInt: [recurrenceId timeIntervalSince1970]];

      [newRecord setObject: dateSecs forKey: @"c_recurrence_id"];
      [newRecord setObject: [NSNumber numberWithInt: 1] forKey: @"c_iscycle"];

      // We identified the record as an exception.
      [newRecord setObject: [NSNumber numberWithInt: 1] forKey: @"isException"];

      [self _fixExceptionRecord: newRecord fromRow: row];
    }

  // We finally adjust the c_nextalarm
  [self _computeAlarmForRow: (id)row
                     master: component];
}

//
//
//
- (void) _appendCycleExceptionsFromRow: (NSDictionary *) row
        firstInstanceCalendarDateRange: (NGCalendarDateRange *) fir
			      forRange: (NGCalendarDateRange *) dateRange
                          withTimeZone: (NSTimeZone *) tz
                          withCalendar: (iCalCalendar *) calendar
			       toArray: (NSMutableArray *) ma
{
  NSArray *components;
  NSString *content;

  unsigned int count, max;

  content = [row objectForKey: @"c_content"];

  if (!calendar && [content isNotNull])
    {
      calendar = [iCalCalendar parseSingleFromSource: content];
    }
  
  if (calendar)
    {
      components = [calendar allObjects];
      max = [components count];
      for (count = 1; count < max; count++) // skip master event
        [self _appendCycleException: [components objectAtIndex: count]
              firstInstanceCalendarDateRange: fir
                            fromRow: row
                           forRange: dateRange
                       withTimeZone: tz
                            toArray: ma];
    }
}

/**
 * Calculate and return the occurrences of the recurrent event for the given
 * period.
 * @param theRecord the event definition.
 * @param theRange the period to look in.
 * @param theRecords the array into which are copied the resulting occurrences.
 * @see [iCalRepeatableEntityObject+SOGo doesOccurOnDate:]
 */
- (void) flattenCycleRecord: (NSDictionary *) theRecord
                   forRange: (NGCalendarDateRange *) theRange
                  intoArray: (NSMutableArray *) theRecords
               withCalendar: (iCalCalendar *) calendar

{
  NSMutableDictionary *row, *fixedRow;
  NSMutableArray *records, *ranges;
  NSDictionary *cycleinfo;
  NGCalendarDateRange *firstRange, *recurrenceRange, *oneRange;
  NSArray *rules, *exRules, *rDates, *exDates;
  NSArray *components;
  NSString *content;
  NSCalendarDate *checkStartDate, *checkEndDate, *firstStartDate, *firstEndDate;
  NSTimeZone *allDayTimeZone;
  iCalDateTime *dtstart;
  iCalRepeatableEntityObject *component;
  iCalTimeZone *eventTimeZone;
  unsigned count, max;
  NSInteger offset;
  id tz;

  content = [theRecord objectForKey: @"c_cycleinfo"];
  if (![content isNotNull])
    {
      // If c_iscycle is set but c_cycleinfo is null, that means we're dealing with a vcalendar that
      // contains ONLY one or more vevent with recurrence-id set for each of them. This can happen if
      // an organizer invites an attendee only to one or many occurences of a repetitive event.
      iCalCalendar *c;
      NSDictionary *record;

      c = [iCalCalendar parseSingleFromSource: [theRecord objectForKey: @"c_content"]];
      components = [self _fixupRecords:
                           [c quickRecordsFromContent: [theRecord objectForKey: @"c_content"]
                                            container: nil
                                      nameInContainer: [theRecord objectForKey: @"c_name"]]];
      max = [components count];
      for (count = 0; count < max; count++)
        {
          record = [components objectAtIndex: count];
          oneRange = [NGCalendarDateRange calendarDateRangeWithStartDate: [record objectForKey: @"startDate"]
                                                                 endDate: [record objectForKey: @"endDate"]];
          if ([theRange doesIntersectWithDateRange: oneRange])
            {
              [theRecords addObject: record];
            }
        }
      return;
    }

  cycleinfo = [content propertyList];
  if (!cycleinfo)
    {
      [self errorWithFormat:@"cyclic record doesn't have cycleinfo -> %@",
	    theRecord];
      return;
    }
  rules = [cycleinfo objectForKey: @"rules"];
  exRules = [cycleinfo objectForKey: @"exRules"];
  rDates = [cycleinfo objectForKey: @"rDates"];
  exDates = [cycleinfo objectForKey: @"exDates"];
  eventTimeZone = nil;
  allDayTimeZone = nil;
  tz = nil;

  row = [self _fixupRecord: theRecord];
  [row removeObjectForKey: @"c_cycleinfo"];
  [row setObject: sharedYes forKey: @"isRecurrentEvent"];

  content = [theRecord objectForKey: @"c_content"];

  if (!calendar && [content isNotNull])
    {
      calendar = [iCalCalendar parseSingleFromSource: content];
    }

  if (calendar)
    {
      if ([[theRecord objectForKey: @"c_component"] isEqualToString: @"vtodo"])
        components = [calendar todos];
      else
        components = [calendar events];
      
      if ([components count])
        {
          // Retrieve the range of the first/master event
          component = [components objectAtIndex: 0];
          dtstart = (iCalDateTime *) [component uniqueChildWithTag: @"dtstart"];
          firstRange = [component firstOccurenceRange]; // ignores timezone
          
          eventTimeZone = [dtstart timeZone];
          if (eventTimeZone)
            {
              // Adjust the range to check with respect to the event timezone (extracted from the start date)
              checkStartDate = [eventTimeZone computedDateForDate: [theRange startDate]];
              checkEndDate = [eventTimeZone computedDateForDate: [theRange endDate]];
              recurrenceRange = [NGCalendarDateRange calendarDateRangeWithStartDate: checkStartDate
                                                                            endDate: checkEndDate];
              
            }
          else 
            {
              recurrenceRange = theRange;
              if ([[theRecord objectForKey: @"c_isallday"] boolValue])
                {
                  // The event lasts all-day and has no timezone (floating); we convert the range of the first event
                  // to the user's timezone
                  allDayTimeZone = timeZone;
                  offset = [allDayTimeZone secondsFromGMTForDate: [firstRange startDate]];
                  firstStartDate = [[firstRange startDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                                     seconds:-offset];
                  firstEndDate = [[firstRange endDate] dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
                                                                 seconds:-offset];
                  [firstStartDate setTimeZone: allDayTimeZone];
                  [firstEndDate setTimeZone: allDayTimeZone];
                  firstRange = [NGCalendarDateRange calendarDateRangeWithStartDate: firstStartDate
                                                                           endDate: firstEndDate];
                }
            }
          
#warning this code is ugly: we should not mix objects with different types as \
  it reduces readability
          tz = eventTimeZone ? eventTimeZone : allDayTimeZone;
          if (tz)
            {
              // Adjust the recurrence and exception dates
              exDates = [component exceptionDatesWithTimeZone: tz];
              rDates = [component recurrenceDatesWithTimeZone: tz];
              
              // Adjust the recurrence rules "until" dates
              rules = [component recurrenceRulesWithTimeZone: tz];
              exRules = [component exceptionRulesWithTimeZone: tz];
            }
          
          // Calculate the occurrences for the given range
          records = [NSMutableArray array];
          ranges =
            [NSMutableArray arrayWithArray:
                              [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange: recurrenceRange
                                                                 firstInstanceCalendarDateRange: firstRange
                                                                                recurrenceRules: rules
                                                                                 exceptionRules: exRules
                                                                                recurrenceDates: rDates
                                                                                 exceptionDates: exDates]];

          // Add the master occurrence when dealing with RDATES.
          // However, the master event must not be flagged with X-MOZ-FAKED-MASTER.
          if ([component hasRecurrenceDates] &&
              ![[[component uniqueChildWithTag: @"x-moz-faked-master"]
                  flattenedValuesForKey: @""] isEqualToString: @"1"] &&
              [recurrenceRange doesIntersectWithDateRange: firstRange])
            {
              [ranges insertObject: firstRange atIndex: 0];
            }

          max = [ranges count];
          for (count = 0; count < max; count++)
            {
              oneRange = [ranges objectAtIndex: count];
              fixedRow = [self fixupCycleRecord: row
                                     cycleRange: oneRange
                 firstInstanceCalendarDateRange: firstRange
                              withEventTimeZone: eventTimeZone];
              
              // We now adjust the c_nextalarm based on each occurences. For each of them, we use the master event
              // alarm information since exceptions to recurrence rules might have their own, while that is not the
              // case for standard occurences.
              if ([component hasAlarms])
                {
                  [self _computeAlarmForRow: fixedRow
                                     master: component];
                }
              
              [records addObject: fixedRow];
            }
          
          [self _appendCycleExceptionsFromRow: row
               firstInstanceCalendarDateRange: firstRange
                                     forRange: theRange
                                 withTimeZone: allDayTimeZone
                                 withCalendar: calendar
                                      toArray: records];
          
          [theRecords addObjectsFromArray: records];
        } // if ([components count]) ...
    }
  else
    [self errorWithFormat:@"cyclic record doesn't have content -> %@", theRecord];
}

//
// TODO: is the result supposed to be sorted by date?
//
- (NSArray *) _flattenCycleRecords: (NSArray *) _records
                        fetchRange: (NGCalendarDateRange *) _r
{
  NSMutableArray *ma;
  NSDictionary *row;
  unsigned int count, max;

  max = [_records count];
  ma = [NSMutableArray arrayWithCapacity: max];

  _r = [NGCalendarDateRange calendarDateRangeWithStartDate: [_r startDate]
						   endDate: [_r endDate]];

  for (count = 0; count < max; count++)
    {
      row = [_records objectAtIndex: count];
      [self flattenCycleRecord: row forRange: _r intoArray: ma  withCalendar: nil];
    }

  return ma;
}

//
//
//
- (void) _buildStripFieldsFromFields: (NSArray *) fields
{
  stripFields = [[NSMutableArray alloc] initWithCapacity: [fields count]];
  [stripFields setArray: fields];

  // What we keep....
  [stripFields removeObjectsInArray: [NSArray arrayWithObjects: @"c_name",
					      @"c_uid", @"c_startdate",
					      @"c_enddate", @"c_isallday",
					      @"c_iscycle", @"c_isopaque",
					      @"c_cycleinfo",
					      @"c_cycleenddate",
					      @"c_classification",
					      @"c_component", nil]];
}

//
//
//
- (void) _fixupProtectedInformation: (NSEnumerator *) ma
			   inFields: (NSArray *) fields
			    forUser: (NSString *) uid
{
  NSMutableDictionary *currentRecord;
  NSString *roles[] = {nil, nil, nil};
  iCalAccessClass accessClass;
  NSString *fullRole, *role;

  if (!stripFields)
    [self _buildStripFieldsFromFields: fields];

#warning we do not take the participation status into account
  while ((currentRecord = [ma nextObject]))
    {
      accessClass = [[currentRecord objectForKey: @"c_classification"] intValue];
      role = roles[accessClass];
      if (!role)
        {
          fullRole = [self roleForComponentsWithAccessClass: accessClass
                                                    forUser: uid];
          if ([fullRole length] > 9)
            role = [fullRole substringFromIndex: 9];
          roles[accessClass] = role;
        }
      if ([role isEqualToString: @"DAndTViewer"])
        [currentRecord removeObjectsForKeys: stripFields];
    }
}

/* TODO: this method should make use of bareFetchFields instead and only keep
   its "intelligence" part for handling protected infos and recurrent
   events... */
- (NSArray *)    fetchFields: (NSArray *) _fields
                        from: (NSCalendarDate *) _startDate
                          to: (NSCalendarDate *) _endDate 
                       title: (NSString *) title
                   component: (id) _component
           additionalFilters: (NSString *) filters
 includeProtectedInformation: (BOOL) _includeProtectedInformation
{
  EOQualifier *qualifier;
  GCSFolder *folder;
  NSMutableArray *fields, *ma;
  NSMutableDictionary *currentRecord;
  NSArray *records;
  NSEnumerator *matchingRecords;
  NSMutableArray *baseWhere;
  NSString *where, *dateSqlString, *privacySQLString, *currentLogin;
  NSCalendarDate *endDate;
  NGCalendarDateRange *r;
  BOOL rememberRecords, canCycle;
  SOGoUser *ownerUser;

  ownerUser = [SOGoUser userWithLogin: owner roles: nil];
  rememberRecords = [self _checkIfWeCanRememberRecords: _fields];
  canCycle = [_component isEqualToString: @"vevent"] || [_component isEqualToString: @"vtodo"];
//   if (rememberRecords)
//     NSLog (@"we will remember those records!");

  folder = [self ocsFolder];
  if (!folder)
    {
      [self errorWithFormat:@"(%s): missing folder for fetch!",
            __PRETTY_FUNCTION__];
      return nil;
    }

  baseWhere = [NSMutableArray arrayWithCapacity: 32];
  if (_component)
    {
      if ([_component isEqualToString: @"vtodo"] && ![self showCalendarTasks])
        return [NSArray array];
      else
        [baseWhere addObject: [NSString stringWithFormat: @"c_component = '%@'",
                                               _component]];
    }
  else if (![self showCalendarTasks])
    [baseWhere addObject: @"c_component != 'vtodo'"];

  if (_startDate)
    {
      if (_endDate)
        endDate = _endDate;
      else
        endDate = [NSCalendarDate distantFuture];
      r = [NGCalendarDateRange calendarDateRangeWithStartDate: _startDate
                                                      endDate: endDate];
      dateSqlString = [self _sqlStringRangeFrom: _startDate to: endDate
                                          cycle: NO];
    }
  else
    {
      r = nil;
      dateSqlString = nil;
    }

  privacySQLString = [self aclSQLListingFilter];

  // Check for access to classification and also make sure the user is still active
  if (privacySQLString && ownerUser)
    {
      if ([privacySQLString length])
        [baseWhere addObject: privacySQLString];
      
      if ([title length])
        {
          if ([filters length])
            {
              if ([filters isEqualToString:@"title_Category_Location"] || [filters isEqualToString:@"entireContent"])
                {
                  [baseWhere addObject: [NSString stringWithFormat: @"(c_title isCaseInsensitiveLike: '%%%@%%' OR c_category isCaseInsensitiveLike: '%%%@%%' OR c_location isCaseInsensitiveLike: '%%%@%%')",
                                                  [title asSafeSQLString],
                                                  [title asSafeSQLString],
                                                  [title asSafeSQLString]]];
                }
            }
          else
            [baseWhere addObject: [NSString stringWithFormat: @"c_title isCaseInsensitiveLike: '%%%@%%'",
                                            [title asSafeSQLString]]];
        }
      
      /* prepare mandatory fields */
      
      fields = [NSMutableArray arrayWithArray: _fields];
      [fields addObjectUniquely: @"c_name"];
      [fields addObjectUniquely: @"c_uid"];
      [fields addObjectUniquely: @"c_startdate"];
      [fields addObjectUniquely: @"c_enddate"];
      [fields addObjectUniquely: @"c_isallday"];

      if (canCycle)
        {
          if (dateSqlString)
            [baseWhere addObject: dateSqlString];
          [baseWhere addObject: @"c_iscycle = 0"];
        }

      where = [baseWhere componentsJoinedByString: @" AND "];

      /* fetch non-recurrent apts first */
      qualifier = [EOQualifier qualifierWithQualifierFormat: where];
      records = [folder fetchFields: fields matchingQualifier: qualifier];

      if (records)
        {
          if (r)
            records = [self _fixupRecords: records];
          ma = [NSMutableArray arrayWithArray: records];
        }
      else
        ma = nil;

      // Fetch recurrent apts now. We support the following scenarios:
      // "All events" - so the start and end date is nil
      // "All future events" - start is defined, date is nil
      if (canCycle)
        {
          unsigned int delta;

          delta = 1;

          // If we don't have a start date, we use the current date - 1 year
          if (!_startDate)
            {
              _startDate = [[NSCalendarDate date] dateByAddingYears: -1  months: 0  days: 0  hours: 0  minutes: 0  seconds: 0];
              delta++;
            }

          // We if we don't have an end date, we use the start date + 1 year
          if (!_endDate)
            {
              endDate = [_startDate dateByAddingYears: delta  months: 0  days: 0  hours: 0  minutes: 0  seconds: 0];
            }

          r = [NGCalendarDateRange calendarDateRangeWithStartDate: _startDate
                                                          endDate: endDate];

          // we know the last element of "baseWhere" is the c_iscycle condition
          [baseWhere removeLastObject];

          // replace the date range
          if (r)
            {
              if (dateSqlString)
                [baseWhere removeLastObject];
              dateSqlString = [self _sqlStringRangeFrom: _startDate
                                                     to: endDate
                                                  cycle: YES];
              [baseWhere addObject: dateSqlString];
            }
          [baseWhere addObject: @"c_iscycle = 1"];
          where = [baseWhere componentsJoinedByString: @" AND "];
          qualifier = [EOQualifier qualifierWithQualifierFormat: where];
          records = [folder fetchFields: fields matchingQualifier: qualifier];
          if (records)
            {
              if (r)
                records = [self _flattenCycleRecords: records fetchRange: r];
	      if (ma)
                [ma addObjectsFromArray: records];
              else
                ma = [NSMutableArray arrayWithArray: records];
            }
        }

      if (!ma)
        {
          [self errorWithFormat: @"(%s): fetch failed!", __PRETTY_FUNCTION__];
          return nil;
        }

      currentLogin = [[context activeUser] login];
      if (![currentLogin isEqualToString: owner])
        {

          if (!_includeProtectedInformation)
            [self _fixupProtectedInformation: [ma objectEnumerator]
                                    inFields: _fields
                                     forUser: currentLogin];
        }

      // Add owner to each record. It will be used when generating freebusy.
      matchingRecords = [ma objectEnumerator];
      while ((currentRecord = [matchingRecords nextObject]))
        {
          [currentRecord setObject: ownerUser forKey: @"owner"];
        }

      if (rememberRecords)
        [self _rememberRecords: ma];
    }
  else
    ma = [NSMutableArray array];

  return ma;
}

#warning we should use the EOFetchSpecification for that!!! (see doPROPFIND:)

#warning components in calendar-data query are ignored

- (NSString *) _nodeTagForProperty: (NSString *) property
{
  NSString *namespace, *nodeName, *nsRep;
  NSRange nsEnd;

  nsEnd = [property rangeOfString: @"}"];
  namespace
    = [property substringFromRange: NSMakeRange (1, nsEnd.location - 1)];
  nodeName = [property substringFromIndex: nsEnd.location + 1];
  if ([namespace isEqualToString: XMLNS_CALDAV])
    nsRep = @"C";
  else
    nsRep = @"D";

  return [NSString stringWithFormat: @"%@:%@", nsRep, nodeName];
}

- (NSCalendarDate *) _getMaxStartDate
{
  NSCalendarDate *now, *rc;

  if (davCalendarStartTimeLimit > 0 && ![[context activeUser] isSuperUser])
    {
      now = [NSCalendarDate date];
      rc = [now addTimeInterval: -davTimeLimitSeconds];
    }
  else
    rc = nil;

  return rc;
}

- (void) _enforceTimeLimitOnFilter: (NSMutableDictionary *) filter
                     withStartDate: (NSCalendarDate *) startDate
                        andEndDate: (NSCalendarDate *) endDate
{
  NSCalendarDate *now;
  int interval, intervalStart, intervalEnd;

  if (davCalendarStartTimeLimit > 0 && ![[context activeUser] isSuperUser])
    {
      interval = ([endDate timeIntervalSinceDate: startDate] / 86400);
      if (interval > davCalendarStartTimeLimit)
        {
          now = [NSCalendarDate date];
          if ([now compare: startDate] == NSOrderedDescending
              && [now compare: endDate] == NSOrderedAscending)
            {
              intervalStart = [now timeIntervalSinceDate: startDate] / 86400;
              intervalEnd = [endDate timeIntervalSinceDate: now] / 86400;
              if (intervalStart > davCalendarStartTimeLimit / 2)
                {
                  startDate = [now addTimeInterval: -davTimeHalfLimitSeconds];
                  [filter setObject: startDate forKey: @"start"];
                }
              if (intervalEnd > davCalendarStartTimeLimit / 2)
                {
                  endDate = [now addTimeInterval: davTimeHalfLimitSeconds];
                  [filter setObject: endDate forKey: @"end"];
                }
            }
          else if ([now compare: endDate] == NSOrderedDescending)
            {
              startDate = [endDate addTimeInterval: -davTimeLimitSeconds];
              [filter setObject: startDate forKey: @"start"];
            }
          else if ([now compare: startDate] == NSOrderedAscending)
            {
              endDate = [startDate addTimeInterval: davTimeLimitSeconds];
              [filter setObject: endDate forKey: @"end"];
            }
        }
    }
}

- (void) _appendTimeRange: (id <DOMElement>) timeRangeElement
                 toFilter: (NSMutableDictionary *) filter
{
  NSCalendarDate *startDate, *endDate;

  startDate = [[timeRangeElement attribute: @"start"] asCalendarDate];
  if (!startDate)
    startDate = [NSCalendarDate distantPast];
  [filter setObject: startDate forKey: @"start"];

  endDate = [[timeRangeElement attribute: @"end"] asCalendarDate];
  if (!endDate)
    endDate = [NSCalendarDate distantFuture];
  [filter setObject: endDate forKey: @"end"];

  [self _enforceTimeLimitOnFilter: filter
                    withStartDate: startDate andEndDate: endDate];
}

- (void) _addDateRangeLimitToFilter: (NSMutableDictionary *) filter
{
  NSCalendarDate *now;

  now = [NSCalendarDate date];
  [filter setObject: [now addTimeInterval: davTimeHalfLimitSeconds]
             forKey: @"start"];
  [filter setObject: [now addTimeInterval: -davTimeHalfLimitSeconds]
             forKey: @"end"];
}

#warning This method lacks support for timeranges
- (void) _appendPropertyFilter: (id <DOMElement>) propFilter
		      toFilter: (NSMutableDictionary *) filter
{
  NSString *propName, *textMatch;
  id <DOMNodeList> matches;

  propName = [[propFilter attribute: @"name"] lowercaseString];
  matches = [propFilter getElementsByTagName: @"text-match"];
  if ([matches length])
    textMatch = [[matches objectAtIndex: 0] textValue];
  else
    {
      matches = [propFilter getElementsByTagName: @"is-not-defined"];
      if ([matches length])
	textMatch = @"NULL";
      else
	textMatch = @"";
    }

  [filter setObject: textMatch forKey: propName];
}

- (NSDictionary *) _parseCalendarFilter: (id <DOMElement>) filterElement
{
  NSMutableDictionary *filterData;
  id <DOMElement> parentNode;
  id <DOMNodeList> elements;
  NSString *componentName;
  NSCalendarDate *maxStart;

  parentNode = (id <DOMElement>) [filterElement parentNode];
  
  // This parses time-range filters. 
  //
  //   <C:filter>
  //   <C:comp-filter name="VCALENDAR">
  //     <C:comp-filter name="VEVENT">
  //       <C:time-range start="20060104T000000Z"
  //                     end="20060105T000000Z"/>
  //     </C:comp-filter>
  //   </C:comp-filter>
  // </C:filter>
  //
  //
  // We currently ignore filters based on just the component type.
  // For example, this is ignored:
  //
  // <c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  //     <d:prop>
  //         <d:getetag />
  //         <c:calendar-data />
  //     </d:prop>
  //     <c:filter>
  //         <c:comp-filter name="VCALENDAR" />
  //     </c:filter>
  // </c:calendar-query>
  //
  if ([[parentNode tagName] isEqualToString: @"comp-filter"]
      && [[parentNode attribute: @"name"] isEqualToString: @"VCALENDAR"])
    {
      componentName = [[filterElement attribute: @"name"] lowercaseString];
      filterData = [NSMutableDictionary dictionary];
      [filterData setObject: componentName forKey: @"name"];
      elements = [filterElement getElementsByTagName: @"time-range"];
      if ([elements length])
        [self _appendTimeRange: [elements objectAtIndex: 0]
		      toFilter: filterData];

      elements = [filterElement getElementsByTagName: @"prop-filter"];
      if ([elements length])
        [self _appendPropertyFilter: [elements objectAtIndex: 0]
                           toFilter: filterData];

      if (![filterData objectForKey: @"start"])
        {
          maxStart = [self _getMaxStartDate];
          if (maxStart)
            [self _addDateRangeLimitToFilter: filterData];
        }
      [filterData setObject: [NSNumber numberWithBool: NO] forKey: @"iscycle"];
    }
  else
    filterData = nil;

  return filterData;
}

- (NSDictionary *) _makeCyclicFilterFrom: (NSDictionary *) filter
{
  NSMutableDictionary *rc;
  NSNumber *start;

  rc = [NSMutableDictionary dictionaryWithDictionary: filter];
  start = [rc objectForKey: @"start"];
  if (start)
    [rc setObject: start forKey: @"cycleenddate"];
  [rc removeObjectForKey: @"start"];
  [rc removeObjectForKey: @"end"];
  [rc setObject: sharedYes forKey: @"iscycle"];

  return rc;
}

- (NSArray *) _parseCalendarFilters: (id <DOMElement>) parentNode
{
  id <DOMNodeList> children;
  id <DOMElement>element;
  NSMutableArray *filters;
  NSDictionary *filter;
  unsigned int count, max;

//   NSLog (@"parseCalendarFilter: %@", [NSDate date]);

  filters = [NSMutableArray array];
  children = [parentNode getElementsByTagName: @"comp-filter"];
  max = [children length];
  for (count = 0; count < max; count++)
    {
      element = [children objectAtIndex: count];
      filter = [self _parseCalendarFilter: element];
      if (filter)
        {
          [filters addObject: filter];
          [filters addObject: [self _makeCyclicFilterFrom: filter]];
        }
    }
//   NSLog (@"/parseCalendarFilter: %@", [NSDate date]);

  return filters;
}

- (NSString *) _additionalFilterKey: (NSString *) key
                              value: (NSString *) value
{
  NSString *filterString;

  if ([value length])
    {
      if ([value isEqualToString: @"NULL"])
        filterString = [NSString stringWithFormat: @"(%@ = '')", key];
      else
        filterString
          = [NSString stringWithFormat: @"(%@ like '%%%@%%')", key, value];
    }
  else
    filterString = [NSString stringWithFormat: @"(%@ != '')", key];

  return filterString;
}

/* This method enables the mapping between comp-filter attributes and SQL
   fields in the quick table. Probably unused most of the time but should be
   completed one day for full CalDAV compliance. */
- (NSString *) _composeAdditionalFilters: (NSDictionary *) filter
{
  NSString *additionalFilter;
  NSEnumerator *keys;
  NSString *currentKey, *keyField, *filterString;
  static NSArray *fields = nil;
  NSMutableArray *filters;
  NSCalendarDate *cEndDate;
  NSNumber *cycle;

#warning the list of fields should be taken from the .ocs description file
  if (!fields)
    {
      fields = [NSArray arrayWithObject: @"c_uid"];
      [fields retain];
    }

  filters = [NSMutableArray array];
  keys = [[filter allKeys] objectEnumerator];
  while ((currentKey = [keys nextObject]))
    {
      keyField = [NSString stringWithFormat: @"c_%@", currentKey];
      if ([fields containsObject: keyField])
        {
          filterString
            = [self _additionalFilterKey: keyField
                                   value: [filter objectForKey: currentKey]];
          [filters addObject: filterString];
        }
    }

  // Exception for iscycle
  cycle = [filter objectForKey: @"iscycle"];
  if (cycle)
    {
      filterString = [NSString stringWithFormat: @"(c_iscycle = '%d')", 
			       [cycle intValue]];
      [filters addObject: filterString];

      if ([cycle intValue])
        {
          cEndDate = [filter objectForKey: @"cycleenddate"];
          if (cEndDate)
            {
              filterString = [NSString stringWithFormat: 
                                         @"(c_cycleenddate = NULL OR c_cycleenddate >= %d)",
                                       (int) [cEndDate timeIntervalSince1970]];
              [filters addObject: filterString];
            }
        }
    }

  if ([filters count])
    additionalFilter = [filters componentsJoinedByString: @" AND "];
  else
    additionalFilter = nil;

  return additionalFilter;
}

- (NSString *) davCalendarColor
{
  NSString *color;

  color = [[self calendarColor] uppercaseString];

//   return color;
  return [NSString stringWithFormat: @"%@FF", color];
}

- (NSException *) setDavCalendarColor: (NSString *) newColor
{
  NSException *error;
  NSString *realColor;

  if ([newColor length] == 9
      && [newColor hasPrefix: @"#"])
    {
      realColor = [newColor substringToIndex: 7];
      [self setCalendarColor: realColor];
      error = nil;
    }
  else
    error = [NSException exceptionWithHTTPStatus: 400
			 reason: @"Bad color format (should be '#XXXXXXXX')."];

  return error;
}

- (NSString *) davCalendarOrder
{
  unsigned int order;

  order = [[container subFolders] indexOfObject: self];

  return [NSString stringWithFormat: @"%d", order+1];
}

- (NSException *) setDavCalendarOrder: (NSString *) newColor
{
  /* we fail silently */
  return nil;
}

- (NSString *) davCalendarTimeZone
{
  SOGoUser *ownerUser;
  NSString *ownerTimeZone;
  iCalCalendar *tzCal;
  iCalTimeZone *tz;
  NSString *prodID;

  ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
  ownerTimeZone = [[ownerUser userDefaults] timeZoneName];
  tz = [iCalTimeZone timeZoneForName: ownerTimeZone];

  tzCal = [iCalCalendar groupWithTag: @"vcalendar"];
  [tzCal setVersion: @"2.0"];
  prodID = [NSString stringWithFormat:
                       @"-//Inverse inc./SOGo %@//EN", SOGoVersion];
  [tzCal setProdID: prodID];
  [tzCal addChild: tz];

  return [tzCal versitString];
}

- (NSException *) setDavCalendarTimeZone: (NSString *) newTimeZone
{
  /* we fail silently */
  return nil;
}

- (void) _appendComponentProperties: (NSDictionary *) properties
                    matchingFilters: (NSArray *) filters
                         toResponse: (WOResponse *) response
{
  NSArray *apts;
  NSMutableArray *fields;
  NSDictionary *currentFilter;
  NSEnumerator *filterList;
  NSString *additionalFilters, *baseURL, *currentField;
  NSMutableString *buffer;
  NSString **propertiesArray;
  NSEnumerator *addFields;
  unsigned int count, max, propertiesCount;

  fields = [NSMutableArray arrayWithObjects: @"c_name", @"c_component", nil];
  addFields = [[properties allValues] objectEnumerator];
  while ((currentField = [addFields nextObject]))
    if ([currentField length])
      [fields addObjectUniquely: currentField];
  baseURL = [self davURLAsString];

  propertiesArray = [[properties allKeys] asPointersOfObjects];
  propertiesCount = [properties count];

//   NSLog (@"start");
  filterList = [filters objectEnumerator];
  while ((currentFilter = [filterList nextObject]))
    {
      additionalFilters = [self _composeAdditionalFilters: currentFilter];
      /* TODO: we should invoke bareFetchField:... twice and compute the
         recurrent events properly instead of using _makeCyclicFilterFrom: */
      apts = [self bareFetchFields: fields
                              from: [currentFilter objectForKey: @"start"]
                                to: [currentFilter objectForKey: @"end"]
                             title: [currentFilter objectForKey: @"title"]
                         component: [currentFilter objectForKey: @"name"]
                 additionalFilters: additionalFilters];
//       NSLog(@"adding properties");
      max = [apts count];
      buffer = [NSMutableString stringWithCapacity: max * 512];
      for (count = 0; count < max; count++)
        [self appendObject: [apts objectAtIndex: count]
                properties: propertiesArray
                     count: propertiesCount
               withBaseURL: baseURL
                  toBuffer: buffer];
//       NSLog(@"done 1");
      [response appendContentString: buffer];
//       NSLog(@"done 2");
    }
//   NSLog (@"stop");

  NSZoneFree (NULL, propertiesArray);
}

/* This table is meant to match SQL fields to the properties that requires
   them. The fields may NOT be processed directly. This list is not complete
   but is at least sufficient for processing requests from Lightning. */
- (NSDictionary *) davSQLFieldsTable
{
  static NSMutableDictionary *davSQLFieldsTable = nil;

  if (!davSQLFieldsTable)
    {
      davSQLFieldsTable = [[super davSQLFieldsTable] mutableCopy];
      [davSQLFieldsTable setObject: @"c_content"
                            forKey: @"{" XMLNS_CALDAV  @"}calendar-data"];
    }

  return davSQLFieldsTable;
}

- (id) davCalendarQuery: (id) queryContext
{
  WOResponse *r;
  id <DOMDocument> document;
  id <DOMElement> documentElement, propElement;

  r = [context response];
  [r prepareDAVResponse];
  [r appendContentString: @"<D:multistatus xmlns:D=\"DAV:\""
                @" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">"];

  document = [[context request] contentAsDOMDocument];
  documentElement = (id <DOMElement>) [document documentElement];
  propElement = [(NGDOMNodeWithChildren *) documentElement
                    firstElementWithTag: @"prop" inNamespace: XMLNS_WEBDAV];

  [self _appendComponentProperties: [self parseDAVRequestedProperties: propElement]
                   matchingFilters: [self _parseCalendarFilters: documentElement]
                        toResponse: r];
  [r appendContentString:@"</D:multistatus>"];

  return r;
}

- (WOResponse *) davCalendarMultiget: (WOContext *) queryContext
{
  return [self performMultigetInContext: queryContext
                            inNamespace: @"urn:ietf:params:xml:ns:caldav"];
}

- (NSString *) additionalWebdavSyncFilters
{
  NSCalendarDate *startDate;
  NSString *filter;
  NSMutableArray *filters;
  int startDateSecs;

  filters = [NSMutableArray arrayWithCapacity: 8];
  startDate = [self _getMaxStartDate];
  if (startDate)
    {
      startDateSecs = (int) [startDate timeIntervalSince1970];
      filter = [NSString stringWithFormat: @"(c_enddate = NULL"
                         @" OR (c_enddate >= %d AND c_iscycle = 0)"
                         @" OR (c_cycleenddate >= %d AND c_iscycle = 1))",
                         startDateSecs, startDateSecs];
      [filters addObject: filter];
    }

  if (![self showCalendarTasks])
    [filters addObject: @"c_component != 'vtodo'"];

  return [filters componentsJoinedByString: @" AND "];
}

- (Class) objectClassForContent: (NSString *) content
{
  iCalCalendar *calendar;
  NSArray *elements;
  NSString *firstTag;
  Class objectClass;

  objectClass = Nil;

  calendar = [iCalCalendar parseSingleFromSource: content];
  if (calendar)
    {
      elements = [calendar allObjects];
      if ([elements count])
        {
          firstTag = [[[elements objectAtIndex: 0] tag] uppercaseString];
          if ([firstTag isEqualToString: @"VEVENT"])
            objectClass = [SOGoAppointmentObject class];
          else if ([firstTag isEqualToString: @"VTODO"])
            objectClass = [SOGoTaskObject class];
        }
    }

  return objectClass;
}

- (BOOL) requestNamedIsHandledLater: (NSString *) name
{
  return [name isEqualToString: @"OPTIONS"];
}

- (id) lookupName: (NSString *)_key
        inContext: (id)_ctx
          acquire: (BOOL)_flag
{
  id obj;
  NSString *url;
  BOOL handledLater;
  WORequest *rq;

  /* first check attributes directly bound to the application */
  handledLater = [self requestNamedIsHandledLater: _key];
  if (handledLater)
    obj = nil;
  else
    {
      obj = [super lookupName:_key inContext:_ctx acquire:NO];
      if (!obj)
        {
          rq = [_ctx request];
	  if ([self isValidContentName:_key]
              && [rq handledByDefaultHandler])
            {
	      url = [[rq uri] urlWithoutParameters];
	      if ([url hasSuffix: @"AsTask"])
		obj = [SOGoTaskObject objectWithName: _key
				      inContainer: self];
	      else if ([url hasSuffix: @"AsAppointment"])
		obj = [SOGoAppointmentObject objectWithName: _key
					     inContainer: self];
	      [obj setIsNew: YES];
            }
        }
      if (!obj)
        obj = [NSException exceptionWithHTTPStatus:404 /* Not Found */];
    }

  if (obj)
    [[SOGoCache sharedCache] registerObject: obj
			     withName: _key
			     inContainer: container];

  return obj;
}

- (NSDictionary *) freebusyResponseForRecipient: (iCalPerson *) recipient
				       withUser: (SOGoUser *) user
				andCalendarData: (NSString *) calendarData
{
  NSDictionary *response;
  NSMutableArray *content;

  content = [NSMutableArray array];

  [content addObject: davElementWithContent (@"recipient",
                                             XMLNS_CALDAV, [recipient email])];
  if (user)
    {
      [content addObject: davElementWithContent (@"request-status", XMLNS_CALDAV,
						 @"2.0;Success")];
      [content addObject: davElementWithContent (@"calendar-data", XMLNS_CALDAV,
                                                 [calendarData safeStringByEscapingXMLString])];
    }
  else
      [content addObject:
		 davElementWithContent (@"request-status", XMLNS_CALDAV,
					@"3.7;Invalid Calendar User")];
  response = davElementWithContent (@"response", XMLNS_CALDAV, content);

  return response;
}

- (NSDictionary *) caldavFreeBusyRequestOnRecipient: (iCalPerson *) recipient
                                            withUID: (NSString *) uid
                                       andOrganizer: (iCalPerson *) organizer
					       from: (NSCalendarDate *) start
						 to: (NSCalendarDate *) to
{
  SOGoUser *user;
  NSString *login, *contactId, *calendarData;
  SOGoFreeBusyObject *freebusy;

  login = [recipient uid];
  if ([login length])
    {
      user = [SOGoUser userWithLogin: login];
      freebusy = [[user homeFolderInContext: context]
		       freeBusyObject: @"freebusy.ifb"
                            inContext: context];
      calendarData = [freebusy contentAsStringWithMethod: @"REPLY"
                                                  andUID: uid
                                            andOrganizer: organizer
                                              andContact: nil
                                                    from: start to: to];
    }
  else if ((contactId = [recipient contactIDInContext: context]))
    {
      user = [context activeUser];
      freebusy = [[user homeFolderInContext: context]
		       freeBusyObject: @"freebusy.ifb"
                            inContext: context];
      calendarData = [freebusy contentAsStringWithMethod: @"REPLY"
                                                  andUID: uid
                                            andOrganizer: organizer
                                              andContact: contactId
                                                    from: start to: to];      
    }
  else
    {
      user = nil;
      calendarData = nil;
    }

  return [self freebusyResponseForRecipient: recipient
                                   withUser: user
                            andCalendarData: calendarData];
}

- (NSDictionary *) caldavFreeBusyRequest: (iCalFreeBusy *) freebusy
{
  NSDictionary *responseElement;
  NSMutableArray *elements;
  NSString *uid;
  iCalPerson *recipient, *organizer;
  NSEnumerator *allRecipients;
  NSCalendarDate *startDate, *endDate;

  elements = [NSMutableArray array];
  [freebusy fillStartDate: &startDate andEndDate: &endDate];
  uid = [freebusy uid];
  organizer = [freebusy organizer];
  allRecipients = [[freebusy attendees] objectEnumerator];
  while ((recipient = [allRecipients nextObject]))
    [elements addObject: [self caldavFreeBusyRequestOnRecipient: recipient 
                                                        withUID: uid
                                                   andOrganizer: organizer
                                                           from: startDate
                                                             to: endDate]];
  responseElement = davElementWithContent (@"schedule-response",
					   XMLNS_CALDAV, elements);

  return responseElement;
}

#warning we should merge this code with the code from the iTIP interpreter in MailPartViewer
- (NSDictionary *) caldavEventRequest: (iCalEvent *) event
			  withContent: (NSString *) iCalString
				 from: (NSString *) originator
				   to: (NSArray *) recipients
{
  NSDictionary *responseElement;
  NSArray *elements;
  NSString *method, *filename;
  SOGoAppointmentObject *apt;
  
  filename = [NSString stringWithFormat: @"%@.ics", [event uid]];
  apt = [SOGoAppointmentObject objectWithName: filename
			       andContent: iCalString
			       inContainer: self];
  method = [[event parent] method];
  if ([method isEqualToString: @"REQUEST"])
    elements = [apt postCalDAVEventRequestTo: recipients  from: originator];
  else if ([method isEqualToString: @"REPLY"])
    elements = [apt postCalDAVEventReplyTo: recipients  from: originator];
  else if ([method isEqualToString: @"CANCEL"])
    elements = [apt postCalDAVEventCancelTo: recipients  from: originator];
  else
    elements = nil;

  if (elements)
    responseElement = davElementWithContent (@"schedule-response",
					     XMLNS_CALDAV, elements);
  else
    responseElement = nil;

  return responseElement;
}

- (WOResponse *) _caldavScheduleResponse: (NSDictionary *) tags
{
  WOResponse *response;

  response = [context response];
  if (tags)
    {
      // WARNING
      // don't touch unless you're going to re-test caldav sync 
      // with an iPhone AND lightning
      [response setStatus: 200];
      [response appendContentString: @"<?xml version=\"1.0\""
                @" encoding=\"utf-8\"?>"];
      [response setHeader: @"application/xml; charset=utf-8"
                   forKey: @"Content-Type"];
      [response appendContentString:
		  [tags asWebDavStringWithNamespaces: nil]];
    }
  else
    [response setStatus: 415];

  return response;
}

- (WOResponse *) caldavScheduleRequest: (NSString *) iCalString
				  from: (NSString *) originator
				    to: (NSArray *) recipients
{
  NSString *tag;
  iCalCalendar *calendar;
  iCalEntityObject *element;
  NSDictionary *tags;

#warning needs to handle errors
  calendar = [iCalCalendar parseSingleFromSource: iCalString];
  element = [[calendar allObjects] objectAtIndex: 0];
  tag = [[element tag] uppercaseString];
  if ([tag isEqualToString: @"VFREEBUSY"])
    tags = [self caldavFreeBusyRequest: (iCalFreeBusy *) element];
  else if ([tag isEqualToString: @"VEVENT"])
    tags = [self caldavEventRequest: (iCalEvent *) element
                        withContent: iCalString
                               from: originator to: recipients];
  else
    tags = nil;

  return [self _caldavScheduleResponse: tags];
}

- (id) davPOSTRequest: (WORequest *) request
      withContentType: (NSString *) cType
	    inContext: (WOContext *) localContext
{
  id obj;
  NSString *originator;
  NSArray *recipients;

  if ([cType hasPrefix: @"text/calendar"])
    {
      originator = [request headerForKey: @"originator"];

      if ([[originator lowercaseString] hasPrefix: @"mailto:"])
	originator = [originator substringFromIndex: 7];  

      recipients = [[request headerForKey: @"recipient"]
		     componentsSeparatedByString: @","];
      obj = [self caldavScheduleRequest: [request contentAsString]
		  from: originator to: [recipients trimmedComponents]];
    }
  else
    obj = [super davPOSTRequest: request withContentType: cType
		 inContext: localContext];

  return obj;
}

- (NSArray *) groupDavResourceType
{
  return [NSArray arrayWithObjects: @"vevent-collection",
		  @"vtodo-collection", nil];
}

- (NSArray *) davResourceType
{
  NSMutableArray *colType;
  NSArray *gdRT, *gdVEventCol, *gdVTodoCol;
  WORequest *request;

  colType = [NSMutableArray arrayWithCapacity: 10];
  [colType addObject: @"collection"];
  [colType addObject: [NSArray arrayWithObjects: @"calendar", XMLNS_CALDAV, nil]];

  /* iPhone compatibility: we can only return a caldav "calendar"
     resourcetype. Anything else will prevent the iPhone from querying the
     collection. */
  request = [context request];
  if (!([request isIPhone] || [request isICal4]))
    {
      gdRT = (NSArray *) [self groupDavResourceType];
      gdVEventCol = [NSArray arrayWithObjects: [gdRT objectAtIndex: 0],
                  XMLNS_GROUPDAV, nil];
      [colType addObject: gdVEventCol];
      if ([self showCalendarTasks])
        {
          gdVTodoCol = [NSArray arrayWithObjects: [gdRT objectAtIndex: 1],
                                XMLNS_GROUPDAV, nil];
          [colType addObject: gdVTodoCol];
        }
      if ([nameInContainer isEqualToString: @"personal"])
        [colType addObject: [NSArray arrayWithObjects: @"schedule-outbox",
                                     XMLNS_CALDAV, nil]];
    }

  return colType;
}

- (SOGoWebDAVValue *) davCalendarComponentSet
{
  NSMutableArray *components;

  if (!componentSet)
    {
      components = [[NSMutableArray alloc] initWithCapacity: 2];
      /* Totally hackish.... we use the "n1" prefix because we know our
         extensions will assign that one to ..:caldav but we really need to
         handle element attributes */
      [components addObject: [SOGoWebDAVValue
                               valueForObject: @"<n1:comp name=\"VEVENT\"/>"
                                   attributes: nil]];

      // See bugs #2878 and #2879
      [components addObject: [SOGoWebDAVValue
                               valueForObject: @"<n1:comp name=\"VFREEBUSY\"/>"
                                   attributes: nil]];

      if ([self showCalendarTasks])
        [components addObject: [SOGoWebDAVValue
                                 valueForObject: @"<n1:comp name=\"VTODO\"/>"
                                     attributes: nil]];
      componentSet
        = [davElementWithContent (@"supported-calendar-component-set",
                                  XMLNS_CALDAV,
                                  components)
                                 asWebDAVValue];
      [componentSet retain];
      [components release];
    }

  return componentSet;
}

- (NSString *) davDescription
{
  return @"";
}

/*
  RFC5842 states:

  3.1.  DAV:resource-id Property

   The DAV:resource-id property is a REQUIRED property that enables
   clients to determine whether two bindings are to the same resource.
   The value of DAV:resource-id is a URI, and may use any registered URI
   scheme that guarantees the uniqueness of the value across all
   resources for all time (e.g., the urn:uuid: URN namespace defined in
   [RFC4122] or the opaquelocktoken: URI scheme defined in [RFC4918]).

   <!ELEMENT resource-id (href)>

   ...

   so we must STRIP any username prefix, to make the ID global.
   
*/
- (NSString *) davResourceId
{
  NSString *name, *prefix;

  prefix = [NSString stringWithFormat: @"%@_", [self ownerInContext: context]];
  name = [self nameInContainer];
  
  if ([name hasPrefix: prefix])
    {
      name = [name substringFromIndex: [prefix length]];
    }
  
  return [NSString stringWithFormat: @"urn:uuid:%@:calendars:%@",
                   [self ownerInContext: context], name];
}

- (NSArray *) davScheduleCalendarTransparency
{
  const NSString *opacity;

  opacity = ([self includeInFreeBusy] ? @"opaque" : @"transparent");

  return [NSArray arrayWithObject: [NSArray arrayWithObjects: opacity,
                                            XMLNS_CALDAV,
                                            nil]];
}

- (NSException *) setDavScheduleCalendarTransparency: (id) newName
{
  NSException *error;

  error = nil;

  if ([newName rangeOfString: @"opaque"].location != NSNotFound)
    [self setIncludeInFreeBusy: YES];
  else if ([newName rangeOfString: @"transparent"].location != NSNotFound)
    [self setIncludeInFreeBusy: NO];
  else
    error = [NSException exceptionWithHTTPStatus: 400
                                          reason: @"Bad transparency value."];

  return error;
}

- (NSString *) davCalendarShowAlarms
{
  return [self davBooleanForResult: [self showCalendarAlarms]];
}

- (NSException *) setDavCalendarShowAlarms: (id) newBoolean
{
  NSException *error;

  if ([self isValidDAVBoolean: newBoolean])
    {
      [self setShowCalendarAlarms: [self resultForDAVBoolean: newBoolean]];
      error = nil;
    }
  else
    error = [NSException exceptionWithHTTPStatus: 400
                                          reason: @"Bad boolean value."];

  return error;
}

- (NSString *) davNotifyOnPersonalModifications
{
  return [self davBooleanForResult: [self notifyOnPersonalModifications]];
}

- (NSException *) setDavNotifyOnPersonalModifications: (NSString *) newBoolean
{
  NSException *error;

  if ([self isValidDAVBoolean: newBoolean])
    {
      [self setNotifyOnPersonalModifications:
              [self resultForDAVBoolean: newBoolean]];
      error = nil;
    }
  else
    error = [NSException exceptionWithHTTPStatus: 400
                                          reason: @"Bad boolean value."];

  return error;
}

- (NSString *) davNotifyOnExternalModifications
{
  return [self davBooleanForResult: [self notifyOnExternalModifications]];
}

- (NSException *) setDavNotifyOnExternalModifications: (NSString *) newBoolean
{
  NSException *error;

  if ([self isValidDAVBoolean: newBoolean])
    {
      [self setNotifyOnExternalModifications:
              [self resultForDAVBoolean: newBoolean]];
      error = nil;
    }
  else
    error = [NSException exceptionWithHTTPStatus: 400
                                          reason: @"Bad boolean value."];

  return error;
}

- (NSString *) davNotifyUserOnPersonalModifications
{
  return [self davBooleanForResult: [self notifyUserOnPersonalModifications]];
}

- (NSException *) setDavNotifyUserOnPersonalModifications: (NSString *) newBoolean
{
  NSException *error;

  if ([self isValidDAVBoolean: newBoolean])
    {
      [self setNotifyUserOnPersonalModifications:
              [self resultForDAVBoolean: newBoolean]];
      error = nil;
    }
  else
    error = [NSException exceptionWithHTTPStatus: 400
                                          reason: @"Bad boolean value."];

  return error;
}

- (NSString *) davNotifiedUserOnPersonalModifications
{
  return [self notifiedUserOnPersonalModifications];
}

- (NSException *) setDavNotifiedUserOnPersonalModifications: (NSString *) theUser
{
  [self setNotifiedUserOnPersonalModifications: theUser];

  return nil;
}

/* vevent UID handling */

- (NSString *) resourceNameForEventUID: (NSString *) uid
                              inFolder: (GCSFolder *) folder
{
  static NSArray *nameFields = nil;
  EOQualifier *qualifier;
  NSArray *records;
  NSString *filename;
  unsigned int count;

  filename = nil;

  if (!nameFields)
    nameFields = [[NSArray alloc] initWithObjects: @"c_name", nil];

  if (uid && folder)
    {
      qualifier = [EOQualifier qualifierWithQualifierFormat: @"c_uid = %@",
			       [uid asSafeSQLString]];
      records = [folder fetchFields: nameFields matchingQualifier: qualifier];
      count = [records count];
      if (count)
	{
	  filename = [[records objectAtIndex:0] valueForKey: @"c_name"];
	  if (count > 1)
	    [self errorWithFormat:
		    @"The storage contains more than file with UID '%@'",
		  uid];
	}
    }

  return filename;
}

- (NSString *) resourceNameForEventUID: (NSString *) uid
{
  /* caches UIDs */
  GCSFolder *folder;
  NSString  *rname;

  rname = nil;
  if (uid)
    {
      if (!uidToFilename)
	uidToFilename = [NSMutableDictionary new];
      rname = [uidToFilename objectForKey: uid];
      if (!rname)
	{
	  folder = [self ocsFolder];
	  rname = [self resourceNameForEventUID: uid inFolder: folder];
	  if (rname)
	    [uidToFilename setObject: rname forKey: uid];
	}
    }

  return rname;
}

- (NSArray *) subscriptionRoles
{
  return [NSArray arrayWithObjects:
		  SOGoRole_ObjectCreator,
		  SOGoRole_ObjectEraser,
		  SOGoCalendarRole_PublicResponder,
		  SOGoCalendarRole_PublicModifier,
		  SOGoCalendarRole_PublicViewer,
		  SOGoCalendarRole_PublicDAndTViewer,
		  SOGoCalendarRole_PrivateResponder,
		  SOGoCalendarRole_PrivateModifier,
		  SOGoCalendarRole_PrivateViewer,
		  SOGoCalendarRole_PrivateDAndTViewer,
		  SOGoCalendarRole_ConfidentialResponder,
		  SOGoCalendarRole_ConfidentialModifier,
		  SOGoCalendarRole_ConfidentialViewer,
		  SOGoCalendarRole_ConfidentialDAndTViewer, nil];
}

- (NSString *) roleForComponentsWithAccessClass: (iCalAccessClass) accessClass
					forUser: (NSString *) uid
{
  NSString *accessRole, *ownerLogin, *prefix, *currentRole, *suffix;
  NSEnumerator *acls;
  NSMutableDictionary *userRoles;

  accessRole = nil;

  if (accessClass == iCalAccessPublic)
    prefix = @"Public";
  else if (accessClass == iCalAccessPrivate)
    prefix = @"Private";
  else
    prefix = @"Confidential";

  userRoles = [aclMatrix objectForKey: uid];
  if (!userRoles)
    {
      userRoles = [NSMutableDictionary dictionaryWithCapacity: 3];
      [aclMatrix setObject: userRoles forKey: uid];
    }
  
  accessRole = [userRoles objectForKey: prefix];
  if (!accessRole)
    {
      ownerLogin = [self ownerInContext: context];
      if ([ownerLogin isEqualToString: uid])
	accessRole = @"";
      else
	{
	  acls = [[self aclsForUser: uid] objectEnumerator];
	  currentRole = [acls nextObject];
	  while (currentRole && !accessRole)
	    if ([currentRole hasPrefix: prefix])
	      {
		suffix = [currentRole substringFromIndex: [prefix length]];
		accessRole = [NSString stringWithFormat: @"Component%@", suffix];
	      }
	    else
	      currentRole = [acls nextObject];
	  if (!accessRole)
	    accessRole = @"";
	}
      [userRoles setObject: accessRole forKey: prefix];
    }

  return accessRole;
}

- (void) initializeQuickTablesAclsInContext: (WOContext *) localContext
{
  NSString *login, *role, *permission;
  iCalAccessClass currentClass;
  unsigned int permStrIndex;

  [super initializeQuickTablesAclsInContext: localContext];
  /* We assume "userCanAccessAllObjects" will be set after calling the super method. */
  if (!userCanAccessAllObjects)
    {
      login = [[localContext activeUser] login];
      permStrIndex = [@"Component" length];
    }

  for (currentClass = 0; currentClass < iCalAccessClassCount; currentClass++)
    {
      if (userCanAccessAllObjects)
        userCanAccessObjectsClassifiedAs[currentClass] = YES;
      else
        {
          role = [self roleForComponentsWithAccessClass: currentClass
                                                forUser: login];
          if ([role length])
            {
              permission = [role substringFromIndex: permStrIndex];
              userCanAccessObjectsClassifiedAs[currentClass]
                = ([permission isEqualToString: @"Viewer"]
                   || [permission isEqualToString: @"DAndTViewer"]
                   || [permission isEqualToString: @"Modifier"]
                   || [permission isEqualToString: @"Responder"]);
            }
        }
    }
}

- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) _startDate
                                  to: (NSCalendarDate *) _endDate
{
  static NSArray *infos = nil; // TODO: move to a plist file
  
  if (!infos)
    infos = [[NSArray alloc] initWithObjects: @"c_content", @"c_partmails", @"c_partstates",
                             @"c_isopaque", @"c_status", @"c_cycleinfo", @"c_orgmail", nil];

  // We MUST include the protected information when checking for freebusy info as
  // we rely on the c_partmails/c_partstates fields for many operations.
  return [self fetchFields: infos
	       from: _startDate to: _endDate
	       title: nil
               component: @"vevent"
	       additionalFilters: nil
	       includeProtectedInformation: YES];
}

- (NSArray *) fetchCoreInfosFrom: (NSCalendarDate *) _startDate
                              to: (NSCalendarDate *) _endDate
			   title: (NSString *) title
                       component: (id) _component
{
  return [self fetchCoreInfosFrom: _startDate to: _endDate title: title
	       component: _component additionalFilters: nil];
}

- (NSArray *) fetchCoreInfosFrom: (NSCalendarDate *) _startDate
                              to: (NSCalendarDate *) _endDate
			   title: (NSString *) title
                       component: (id) _component
	       additionalFilters: (NSString *) filters
{
  static NSArray *infos = nil; // TODO: move to a plist file

  if (!infos)
    infos = [[NSArray alloc] initWithObjects: @"c_name", @"c_content",
			     @"c_creationdate", @"c_lastmodified",
			     @"c_version", @"c_component", @"c_title",
			     @"c_location", @"c_orgmail", @"c_status",
			     @"c_category", @"c_classification", @"c_isallday",
			     @"c_isopaque", @"c_participants", @"c_partmails",
			     @"c_partstates", @"c_sequence", @"c_priority",
			     @"c_cycleinfo", @"c_iscycle",  @"c_nextalarm", @"c_description", nil];

  return [self fetchFields: infos from: _startDate to: _endDate title: title
               component: _component
	       additionalFilters: filters
	       includeProtectedInformation: NO];
}

- (NSArray *) fetchAlarmInfosFrom: (NSNumber *) _startUTCDate
			       to: (NSNumber *) _endUTCDate
{
  static NSArray *nameFields = nil;
  EOQualifier *qualifier;
  GCSFolder *folder;
  NSArray *records;
  NSString *sql;

  if (!nameFields)
    nameFields = [[NSArray alloc] initWithObjects: @"c_name", @"c_nextalarm", @"c_iscycle", nil];
  
  folder = [self ocsFolder];
  if (!folder)
    {
      [self errorWithFormat:@"(%s): missing folder for fetch!",
            __PRETTY_FUNCTION__];
      return nil;
    }

  sql = [NSString stringWithFormat: @"((c_nextalarm <= %u) AND (c_nextalarm >= %u)) OR ((c_nextalarm > 0) AND (c_nextalarm <= %u) AND (c_enddate > %u))",
                  [_endUTCDate unsignedIntValue], [_startUTCDate unsignedIntValue], [_startUTCDate unsignedIntValue], [_startUTCDate unsignedIntValue]];
  qualifier = [EOQualifier qualifierWithQualifierFormat: sql];
  records = [folder fetchFields: nameFields matchingQualifier: qualifier];
  
  return records;
}

/* URL generation */

- (NSString *) baseURLForAptWithUID: (NSString *)_uid
                          inContext: (id)_ctx
{
  // TODO: who calls this?
  NSString *url;
  
  if ([_uid length] == 0)
    return nil;
  
  url = [self baseURLInContext:_ctx];
  if (![url hasSuffix: @"/"])
    url = [url stringByAppendingString: @"/"];
  
  // TODO: this should run a query to determine the uid!
  return [url stringByAppendingString:_uid];
}

- (NSString *) _baseCalDAVURL
{
  NSString *davURL;

  if (!baseCalDAVURL)
    {
      davURL = [[self realDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        baseCalDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        baseCalDAVURL = davURL;
      [baseCalDAVURL retain];
    }

  return baseCalDAVURL;
}

- (NSString *) _basePublicCalDAVURL
{
  NSString *davURL;

  if (!basePublicCalDAVURL)
    {
      davURL = [[self publicDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
	basePublicCalDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        basePublicCalDAVURL = davURL;
      [basePublicCalDAVURL retain];
    }

  return basePublicCalDAVURL;
}

- (NSString *) calDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _baseCalDAVURL]];
}

- (NSString *) webDavICSURL
{
  return [NSString stringWithFormat: @"%@.ics", [self _baseCalDAVURL]];
}

- (NSString *) webDavXMLURL
{
  return [NSString stringWithFormat: @"%@.xml", [self _baseCalDAVURL]];
}

- (NSString *) publicCalDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _basePublicCalDAVURL]];
}

- (NSString *) publicWebDavICSURL
{
  return [NSString stringWithFormat: @"%@.ics", [self _basePublicCalDAVURL]];
}

- (NSString *) publicWebDavXMLURL
{
  return [NSString stringWithFormat: @"%@.xml", [self _basePublicCalDAVURL]];
}

/* folder management */
- (BOOL) create
{
  BOOL rc;
  SOGoUserSettings *userSettings;
  NSMutableDictionary *calendarSettings;
  SOGoUser *ownerUser;

  rc = [super create];
  if (rc)
    {
      ownerUser = [SOGoUser userWithLogin: [self ownerInContext: context]];
      userSettings = [ownerUser userSettings];
      calendarSettings = [userSettings objectForKey: @"Calendar"];
      if (!calendarSettings)
	{
	  calendarSettings = [NSMutableDictionary dictionary];
	  [userSettings setObject: calendarSettings forKey: @"Calendar"];
	}
      [userSettings synchronize];
    }

  return rc;
}

- (void) removeFolderSettings: (NSMutableDictionary *) moduleSettings
                withReference: (NSString *) reference
{
  NSMutableArray *refArray;
  NSMutableDictionary *refDict;

  refDict = [moduleSettings objectForKey: @"FreeBusyExclusions"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"FolderColors"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"FolderShowAlarms"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"FolderShowTasks"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"FolderSynchronize"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"NotifyOnExternalModifications"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"NotifyOnPersonalModifications"];
  [refDict removeObjectForKey: reference];

  refDict = [moduleSettings objectForKey: @"NotifyUserOnPersonalModifications"];
  [refDict removeObjectForKey: reference];

  refArray = [moduleSettings objectForKey: @"FoldersOrder"];
  [refArray removeObject: nameInContainer];

  refArray = [moduleSettings objectForKey: @"InactiveFolders"];
  [refArray removeObject: nameInContainer];

  [super removeFolderSettings: moduleSettings
                withReference: reference];
}

- (id) lookupHomeFolderForUID: (NSString *) _uid
                    inContext: (id)_ctx
{
  // TODO: DUP to SOGoGroupFolder
  NSException *error = nil;
  NSArray     *path;
  id          ctx, result;

  if (![_uid isNotNull])
    return nil;

  /* create subcontext, so that we don't destroy our environment */
  
  if ((ctx = [context createSubContext]) == nil) {
    [self errorWithFormat:@"could not create SOPE subcontext!"];
    return nil;
  }
  
  /* build path */
  
  path = _uid != nil ? [NSArray arrayWithObjects:&_uid count:1] : nil;
  
  /* traverse path */
  
  result = [[ctx application] traversePathArray:path inContext:ctx
			      error:&error acquire:NO];
  if (error != nil) {
    [self errorWithFormat: @"folder lookup failed (c_uid=%@): %@",
            _uid, error];
    return nil;
  }
  
  [self debugWithFormat:@"Note: got folder for uid %@ path %@: %@",
	  _uid, [path componentsJoinedByString:@"=>"], result];

  return result;
}

//
// This method returns an array containing all the calendar folders
// of a specific user, excluding her/his subscriptions.
//
- (NSArray *) lookupCalendarFoldersForUID: (NSString *) theUID
{
  NSArray *aFolders;
  SOGoUser *theUser;
  NSEnumerator *e;
  NSMutableArray *aUserFolders;
  SOGoAppointmentFolders *aParent;
  SOGoFolder *aFolder;

  aUserFolders = [NSMutableArray arrayWithCapacity: 16];

  theUser = [SOGoUser userWithLogin: theUID];
  aParent = [theUser calendarsFolderInContext: context];

  if ([aParent isKindOfClass: [NSException class]])
    return nil;

  aFolders = [aParent subFolders];
  e = [aFolders objectEnumerator];
  while ((aFolder = [e nextObject]))
    {
      if (![aFolder isSubscription])
	[aUserFolders addObject: aFolder];
    }

  return aUserFolders;
}

- (NSArray *) lookupCalendarFoldersForUIDs: (NSArray *) _uids
                                 inContext: (id)_ctx
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray *folders;
  NSEnumerator *e;
  NSString *uid, *ownerLogin;
  SOGoUser *user;
  id folder;

  ownerLogin = [self ownerInContext: context];

  if ([_uids count] == 0) return nil;
  folders = [NSMutableArray arrayWithCapacity:16];
  e = [_uids objectEnumerator];
  while ((uid = [e nextObject]))
    {
      if ([uid isEqualToString: ownerLogin])
	folder = self;
      else
	{
          user = [SOGoUser userWithLogin: uid];
	  folder = [user personalCalendarFolderInContext: context];
	  if (![folder isNotNull])
	    [self logWithFormat:@"Note: did not find folder for uid: '%@'", uid];
	}

      if (folder)
	[folders addObject: folder];
    }

  return folders;
}

- (NSArray *) lookupFreeBusyObjectsForUIDs: (NSArray *) _uids
                                 inContext: (id) _ctx
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray *objs;
  NSEnumerator   *e;
  NSString       *uid;
  
  if ([_uids count] == 0) return nil;
  objs = [NSMutableArray arrayWithCapacity:16];
  e    = [_uids objectEnumerator];
  while ((uid = [e nextObject]))
    {
      id obj;
    
      obj = [self lookupHomeFolderForUID:uid inContext:nil];
      if ([obj isNotNull])
	{
	  obj = [obj lookupName: @"freebusy.ifb" inContext: nil acquire: NO];
	  if ([obj isKindOfClass: [NSException class]])
	    obj = nil;
	}
      if (![obj isNotNull])
	[self logWithFormat: @"Note: did not find freebusy.ifb for uid: '%@'",
	      uid];
    
      /* Note: intentionally add 'null' folders to allow a mapping */
      if (!obj)
	obj = [NSNull null];
      [objs addObject: obj];
    }

  return objs;
}

- (NSArray *) uidsFromICalPersons: (NSArray *) _persons
{
  /* Note: can return NSNull objects in the array! */
  NSMutableArray    *uids;
  SOGoUserManager *um;
  unsigned          i, count;
  iCalPerson *person;
  NSString   *email;
  NSString   *uid;
  
  if (_persons)
    {
      count = [_persons count];
      uids  = [NSMutableArray arrayWithCapacity:count + 1];
      um    = [SOGoUserManager sharedUserManager];
  
      for (i = 0; i < count; i++)
	{
	  person = [_persons objectAtIndex:i];
	  email  = [person rfc822Email];
	  if ([email isNotNull])
	    uid = [um getUIDForEmail:email];
	  else
	    uid = nil;
	  
	  if (!uid)
	    uid = (NSString *) [NSNull null];
	  [uids addObject: uid];
	}
    }
  else
    uids = nil;

  return uids;
}

- (NSArray *) lookupCalendarFoldersForICalPerson: (NSArray *) _persons
				       inContext: (id) _ctx
{
  /* Note: can return NSNull objects in the array! */
  NSArray *uids, *folders;

  uids = [self uidsFromICalPersons: _persons];
  if (uids)
    folders = [self lookupCalendarFoldersForUIDs: uids
		    inContext: _ctx];
  else
    folders = nil;
  
  return folders;
}

/* folder type */

- (NSString *) folderType
{
  return @"Appointment";
}

- (BOOL) isActive
{
  SOGoUserSettings *settings;
  NSArray *inactiveFolders;

  settings = [[context activeUser] userSettings];
  inactiveFolders
    = [[settings objectForKey: @"Calendar"] objectForKey: @"InactiveFolders"];

  return (![inactiveFolders containsObject: nameInContainer]);
}

- (BOOL) isWebCalendar
{
  return ([self isKindOfClass: [SOGoWebAppointmentFolder class]]);
}

- (NSString *) importComponent: (iCalEntityObject *) event
                      timezone: (iCalTimeZone *) timezone
{
  SOGoAppointmentObject *object;
  NSMutableString *content;
  NSString *uid;

  // We first look if the event has any / or + in its UID. If that's the case
  // we generate a new UID based on a GUID
  uid = [event uid];

  if ([uid rangeOfCharacterFromSet: [NSCharacterSet characterSetWithCharactersInString: @"+/"]].location != NSNotFound)
    {
      uid = [self globallyUniqueObjectId];
      [event setUid: uid];
    }
  else
    {
      // We also look if there's an event with the same UID in our calendar. If not,
      // let's reuse what is in the event, otherwise generate a new GUID and use it.
      object = [self lookupName: uid
                      inContext: context
                        acquire: NO];

      if (object && ![object isKindOfClass: [NSException class]])
        {
          uid = [self globallyUniqueObjectId];
          [event setUid: uid];
        }
    }

  // If the UID isn't ending with the ".ics" extension, let's add it to avoid
  // confusing broken CalDAV client (like Nokia N9 and Korganizer) that relies
  // on this (see #2308)
  if (![[uid lowercaseString] hasSuffix: @".ics"])
    uid = [NSString stringWithFormat: @"%@.ics", uid];

  object = [SOGoAppointmentObject objectWithName: uid
                                    inContainer: self];
  [object setIsNew: YES];
  content = [NSMutableString stringWithString: @"BEGIN:VCALENDAR\n"];
  [content appendFormat: @"PRODID:-//Inverse inc./SOGo %@//EN\n", SOGoVersion];

  if (timezone)
    [content appendFormat: @"%@\n",  [timezone versitString]];
  [content appendFormat: @"%@\nEND:VCALENDAR", [event versitString]];
  
  return ([object saveCalendar: [iCalCalendar parseSingleFromSource: content]] == nil) ? uid : nil;
}

/**
 * Import all components of a vCalendar.
 * @param calendar the calendar to import
 * @return the number of components imported
 */
- (int) importCalendar: (iCalCalendar *) calendar
{
  NSArray *vtimezones;
  NSMutableArray *components;
  NSMutableDictionary *timezones, *uids;
  NSString *tzId, *uid, *originalUid;
  iCalEntityObject *element;
  iCalTimeZone *timezone;
  iCalCalendar *masterCalendar;
  iCalEvent *event;
  NSAutoreleasePool *pool;

  int imported, count, i;

  imported = 0;

  if (calendar)
    {
      // Build a hash with the timezones includes in the calendar
      vtimezones = [calendar timezones];
      count = [vtimezones count];
      timezones = [NSMutableDictionary dictionaryWithCapacity: count];
      for (i = 0; i < count; i++)
        {
          timezone = (iCalTimeZone *)[vtimezones objectAtIndex: i];
          [timezones setValue: timezone
                       forKey: [timezone tzId]];
        }

      // Parse events/todos/journals and import them
      uids = [NSMutableDictionary dictionary];
      components = [[calendar events] mutableCopy];
      [components autorelease];
      [components addObjectsFromArray: [calendar todos]];
      // [components addObjectsFromArray: [calendar journals]];
      // [components addObjectsFromArray: [calendar freeBusys]];
      count = [components count];

      pool = [[NSAutoreleasePool alloc] init];

      for (i = 0; i < count; i++)
        {
          if (i % 10 == 0)
            {
              DESTROY(pool);
              pool = [[NSAutoreleasePool alloc] init];
            }
          
          timezone = nil;
          element = [components objectAtIndex: i];

          if ([element isKindOfClass: iCalEventK])
            {
              event = (iCalEvent *)element;
              timezone = [event adjustInContext: self->context withTimezones: timezones];

              if ([event recurrenceId])
                {
                  // Event is an occurrence of a repeating event
                  if ((uid = [uids valueForKey: [event uid]]))
                    {
                      SOGoAppointmentObject *master = [self lookupName: uid
                                                             inContext: context
                                                               acquire: NO];
                      if (master)
                        {
                          // Associate the occurrence to the master event and skip the actual import process
                          masterCalendar = [master calendar: NO secure: NO];
                          [masterCalendar addToEvents: event];
                          if (timezone)
                            [masterCalendar addTimeZone: timezone];
                          [master saveCalendar: masterCalendar];
                          continue;
                        }
                    }
                }
            }
          originalUid = [element uid];
          if ((uid = [self importComponent: element
                                  timezone: timezone]))
            {
              imported++;
              [uids setValue: uid  forKey: originalUid];
            }
        }
      
      DESTROY(pool);
    }
  
  return imported;
}

/* acls */

/* Compare two permissions to set first the highest access right, if unknown, then
   do nothing */
static NSComparisonResult _comparePermissions (id perm1, id perm2, void *context)
{
  static NSDictionary *permMap = nil;
  NSNumber *num_1, *num_2;

  if (!permMap)
    {
      NSMutableArray *numberObjs;
      NSUInteger i, max = 16;

      numberObjs = [NSMutableArray arrayWithCapacity: max];
      for (i = 0; i < max; i++)
        [numberObjs addObject: [NSNumber numberWithInteger: i]];

      /* Build the map to compare easily */
      permMap = [[NSDictionary alloc] initWithObjects: numberObjs
                                              forKeys: [NSArray arrayWithObjects:
                                                                  SOGoRole_ObjectEraser,
                                                                  SOGoRole_ObjectCreator,
                                                                  SOGoRole_ObjectEditor,
                                                                  SOGoCalendarRole_ConfidentialModifier,
                                                                  SOGoCalendarRole_ConfidentialResponder,
                                                                  SOGoCalendarRole_ConfidentialViewer,
                                                                  SOGoCalendarRole_ConfidentialDAndTViewer,
                                                                  SOGoCalendarRole_PrivateModifier,
                                                                  SOGoCalendarRole_PrivateResponder,
                                                                  SOGoCalendarRole_PrivateViewer,
                                                                  SOGoCalendarRole_PrivateDAndTViewer,
                                                                  SOGoCalendarRole_PublicModifier,
                                                                  SOGoCalendarRole_PublicResponder,
                                                                  SOGoCalendarRole_PublicViewer,
                                                                  SOGoCalendarRole_PublicDAndTViewer,
                                                                  SOGoCalendarRole_FreeBusyReader, nil]];
      [permMap retain];
    }

  num_1 = [permMap objectForKey: perm1];
  if (!num_1)
    num_1 = [NSNumber numberWithInteger: 255];
  num_2 = [permMap objectForKey: perm2];
  if (!num_2)
    num_2 = [NSNumber numberWithInteger: 255];

  return [num_1 compare: num_2];
}

- (NSArray *) aclsForUser: (NSString *) uid
          forObjectAtPath: (NSArray *) objectPathArray
{
  NSMutableArray *aclsForUser;
  NSArray *superAcls;

  superAcls = [super aclsForUser: uid forObjectAtPath: objectPathArray];
  if ([uid isEqualToString: [self defaultUserID]])
    {
      if (superAcls)
        {
          aclsForUser = [superAcls mutableCopy];
          [aclsForUser autorelease];
        }
      else
        aclsForUser = [NSMutableArray array];
      [aclsForUser addObject: SoRole_Authenticated];
    }
  else
    {
      /* Sort setting the highest access right first, so in the case
         of a user member of several groups, the highest access right
         is checked first, for instance, in
         [SOGoAppointmentFolder:roleForComponentsWithAccessClass:forUser] */
      aclsForUser = (NSMutableArray *) [superAcls sortedArrayUsingFunction: _comparePermissions
                                                                   context: NULL];
    }

  return aclsForUser;
}

/* caldav-proxy */
- (SOGoAppointmentProxyPermission) proxyPermissionForUserWithLogin: (NSString *) login
{
  SOGoAppointmentProxyPermission permission;
  NSArray *roles;
  static NSArray *readRoles = nil;
  static NSArray *writeRoles = nil;

  if (!readRoles)
    {
      readRoles = [NSArray arrayWithObjects:
                             SOGoCalendarRole_ConfidentialViewer,
                           SOGoCalendarRole_ConfidentialDAndTViewer,
                           SOGoCalendarRole_PrivateViewer,
                           SOGoCalendarRole_PrivateDAndTViewer,
                           SOGoCalendarRole_PublicViewer,
                           SOGoCalendarRole_PublicDAndTViewer,
                           nil];
      [readRoles retain];
    }
  if (!writeRoles)
    {
      writeRoles = [NSArray arrayWithObjects:
                              SOGoRole_ObjectCreator,
                            SOGoRole_ObjectEraser,
                            SOGoCalendarRole_ConfidentialModifier,
                            SOGoCalendarRole_ConfidentialResponder,
                            SOGoCalendarRole_PrivateModifier,
                            SOGoCalendarRole_PrivateResponder,
                            SOGoCalendarRole_PublicModifier,
                            SOGoCalendarRole_PublicResponder,
                            nil];
      [writeRoles retain];
    }

  permission = SOGoAppointmentProxyPermissionNone;
  roles = [self aclsForUser: login];
  if ([roles count])
    {
      if ([roles firstObjectCommonWithArray: readRoles])
        permission = SOGoAppointmentProxyPermissionRead;
      if ([roles firstObjectCommonWithArray: writeRoles])
        permission = SOGoAppointmentProxyPermissionWrite;
    }

  return permission;
}

- (NSArray *) aclUsersWithProxyWriteAccess: (BOOL) write
{
  NSMutableArray *users;
  NSArray *aclUsers;
  NSString *aclUser;
  SOGoAppointmentProxyPermission permission;
  int count, max;

  permission = (write
                ? SOGoAppointmentProxyPermissionWrite
                : SOGoAppointmentProxyPermissionRead);
  aclUsers = [self aclUsers];
  max = [aclUsers count];
  users = [NSMutableArray arrayWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      aclUser = [aclUsers objectAtIndex: count];
      if ([self proxyPermissionForUserWithLogin: aclUser]
          == permission)
        [users addObject: aclUser];
    }

  return users;
}

- (NSNumber *) activeTasks
{
  NSArray *tasksList;
  NSMutableArray *fields;
  NSNumber *activeTasks;
  
  fields = [NSMutableArray arrayWithObjects: @"c_component", @"c_status", nil];
  
  tasksList = [self bareFetchFields: fields
                               from: nil
                                 to: nil
                              title: nil
                          component: @"vtodo"
                  additionalFilters: @"c_status != 1 AND c_status != 3"];
  
  activeTasks = [NSNumber numberWithInt:[tasksList count]];

  return activeTasks;
}

- (void) findEntityForClosestAlarm: (id *) theEntity
                          timezone: (NSTimeZone *) theTimeZone
                         startDate: (NSCalendarDate **) theStartDate
                           endDate: (NSCalendarDate **) theEndDate
{
  // If the event is recurring, we MUST find the right occurence.
  if ([*theEntity hasRecurrenceRules])
    {
      NSCalendarDate *startDate, *endDate;
      NSMutableDictionary *quickRecord;
      NSCalendarDate *start, *end;
      NGCalendarDateRange *range;
      NSMutableArray *alarms;
      iCalDateTime *date;
      iCalTimeZone *tz;
      
      BOOL b, isEvent;

      isEvent = [*theEntity isKindOfClass: [iCalEvent class]];
      b = NO;

      if (isEvent)
        b = [*theEntity isAllDay];
      
      // We build a fake "quick record". Our record must include some mandatory info, like @"c_startdate" and @"c_enddate"
      quickRecord = [NSMutableDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: b], @"c_isallday",
                                             [NSNumber numberWithBool: [*theEntity isRecurrent]], @"c_iscycle",
                                         nil];
      startDate = [*theEntity startDate];
      endDate = (isEvent ? [*theEntity endDate] : [*theEntity due]);
      
      if ([startDate isNotNull])
        {
          if (b)
            {
              // An all-day event usually doesn't have a timezone associated to its
              // start date; however, if it does, we convert it to GMT.
              date = (iCalDateTime*) [*theEntity uniqueChildWithTag: @"dtstart"];
              tz = [(iCalDateTime*) date timeZone];
              if (tz)
                startDate = [tz computedDateForDate: startDate];
            }
          [quickRecord setObject: [*theEntity quickRecordDateAsNumber: startDate
                                                             withOffset: 0
                                                              forAllDay: b]
                          forKey: @"c_startdate"];
        }
      
      if ([endDate isNotNull])
        {
          if (b)
            {
              // An all-day event usually doesn't have a timezone associated to its
              // end date; however, if it does, we convert it to GMT.
              date = (isEvent ? (iCalDateTime*) [*theEntity uniqueChildWithTag: @"dtend"] : (iCalDateTime*) [*theEntity uniqueChildWithTag: @"due"]);
              tz = [(iCalDateTime*) date timeZone];
              if (tz)
                endDate = [tz computedDateForDate: endDate];
            }
          [quickRecord setObject: [*theEntity quickRecordDateAsNumber: endDate
                                                             withOffset: ((b) ? -1 : 0)
                                                              forAllDay: b]
                          forKey: @"c_enddate"];
        }
      
      
      if ([*theEntity isRecurrent])
        {
          NSCalendarDate *date;
          
          date = [*theEntity lastPossibleRecurrenceStartDate];
          if (!date)
            {
              /* this could also be *nil*, but in the end it makes the fetchspecs
                 more complex - thus we set it to a "reasonable" distant future */
              date = iCalDistantFuture;
            }
          [quickRecord setObject: [*theEntity quickRecordDateAsNumber: date
                                                             withOffset: 0 forAllDay: NO]
                          forKey: @"c_cycleenddate"];
          [quickRecord setObject: [*theEntity cycleInfo] forKey: @"c_cycleinfo"];
        }
      
      alarms = [NSMutableArray array];
      start = [NSCalendarDate date];
      end = [start addYear:1 month:0 day:0 hour:0 minute:0 second:0];
      range = [NGCalendarDateRange calendarDateRangeWithStartDate: start
                                                          endDate: end];
      
      [self flattenCycleRecord: quickRecord
                      forRange: range
                     intoArray: alarms
                  withCalendar: [*theEntity parent]];
      
      if ([alarms count])
        {
          NSDictionary *anAlarm;
          id o;
          
          // Take the first alarm since it's the 'closest' one
          anAlarm = [alarms objectAtIndex: 0];
          
          // We grab the last one and we use that info. The logic is simple.
          // 1. grab the RECURRENCE-ID, if found in our master event, use that
          // 2. if not found, use the master's event info but adjust the start/end date
          if ((o = [[*theEntity parent] eventWithRecurrenceID: [anAlarm objectForKey: @"c_recurrence_id"]]))
            {
              *theEntity = o;
              *theStartDate = [*theEntity startDate];
              *theEndDate = [*theEntity endDate];
            }
          else
            {
              *theStartDate = [NSCalendarDate dateWithTimeIntervalSince1970: [[anAlarm objectForKey: @"c_startdate"] intValue]];
              *theEndDate = [NSCalendarDate dateWithTimeIntervalSince1970: [[anAlarm objectForKey: @"c_enddate"] intValue]];
            }
          
          [*theStartDate setTimeZone: theTimeZone];
          [*theEndDate setTimeZone: theTimeZone];
        }
    } // if ([event hasRecurrenceRules]) ...
}

@end /* SOGoAppointmentFolder */
