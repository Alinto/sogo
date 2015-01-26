/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2007-2014 Inverse inc.

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

#ifndef __Appointments_SOGoAppointmentFolder_H__
#define __Appointments_SOGoAppointmentFolder_H__

/*
  SOGoAppointmentFolder
    Parent object: the SOGoUserFolder
    Child objects: SOGoAppointmentObject
    
  The SOGoAppointmentFolder maps to an GCS folder of type 'appointment', that
  is, a content folder containing iCalendar files (and a proper quicktable).
  
  Important:
  The folder assumes a 1:1 mapping between the vevent UID field and the
  resource name in the content store. In other words, you are not allowed to
  create two different vevent-files with the same uid in the store.
*/

#import "SOGo/SOGoGCSFolder.h"

#import <NGCards/iCalEntityObject.h>

@class NSArray;
@class NSCalendarDate;
@class NSException;
@class NSMutableDictionary;
@class NSString;
@class NSTimeZone;
@class GCSFolder;
@class iCalCalendar;
@class iCalTimeZone;
@class NGCalendarDateRange;
@class SOGoWebDAVValue;

typedef enum {
  SOGoAppointmentProxyPermissionNone = 0,
  SOGoAppointmentProxyPermissionRead = 1,
  SOGoAppointmentProxyPermissionWrite = 2,
} SOGoAppointmentProxyPermission;

@interface SOGoAppointmentFolder : SOGoGCSFolder
{
  NSTimeZone *timeZone;
  NSMutableDictionary *uidToFilename;
  NSMutableDictionary *aclMatrix;
  NSMutableArray *stripFields;
  NSString *baseCalDAVURL, *basePublicCalDAVURL;
  int davCalendarStartTimeLimit;
  int davTimeLimitSeconds;
  int davTimeHalfLimitSeconds;
  BOOL userCanAccessObjectsClassifiedAs[iCalAccessClassCount];
  SOGoWebDAVValue *componentSet;
}

- (BOOL) isActive;
- (BOOL) isWebCalendar;

- (NSString *) calendarColor;
- (void) setCalendarColor: (NSString *) newColor;

/* selection */

- (NSArray *) calendarUIDs;

- (NSNumber *) activeTasks;

/* vevent UID handling */

- (NSString *) resourceNameForEventUID: (NSString *) _uid;

/* fetching */
- (NSArray *) bareFetchFields: (NSArray *) fields
                         from: (NSCalendarDate *) startDate
                           to: (NSCalendarDate *) endDate 
                        title: (NSString *) title
                    component: (NSString *) component
            additionalFilters: (NSString *) filters;

- (NSArray *)    fetchFields: (NSArray *) _fields
			from: (NSCalendarDate *) _startDate
			  to: (NSCalendarDate *) _endDate
		       title: (NSString *) title
		   component: (id) _component
	   additionalFilters: (NSString *) filters
 includeProtectedInformation: (BOOL) _includeProtectedInformation;
  
- (NSArray *) fetchCoreInfosFrom: (NSCalendarDate *) _startDate
                              to: (NSCalendarDate *) _endDate
			   title: (NSString *) title
                       component: (id) _component;
- (NSArray *) fetchCoreInfosFrom: (NSCalendarDate *) _startDate
                              to: (NSCalendarDate *) _endDate
			   title: (NSString *) title
                       component: (id) _component
	       additionalFilters: (NSString *) filters;

- (NSArray *) fetchFreeBusyInfosFrom: (NSCalendarDate *) _startDate
                                  to: (NSCalendarDate *) _endDate;

- (NSArray *) fetchAlarmInfosFrom: (NSNumber *) _startUTCDate
			       to: (NSNumber *) _endUTCDate;

- (void) flattenCycleRecord: (NSDictionary *) theRecord
                   forRange: (NGCalendarDateRange *) theRange
                  intoArray: (NSMutableArray *) theRecords
               withCalendar: (iCalCalendar *) calendar;

/* URL generation */

- (NSString *) baseURLForAptWithUID: (NSString *) _uid
                          inContext: (id) _ctx;

- (NSString *) calDavURL;
- (NSString *) webDavICSURL;
- (NSString *) webDavXMLURL;
- (NSString *) publicCalDavURL;
- (NSString *) publicWebDavICSURL;
- (NSString *) publicWebDavXMLURL;

/* folder management */

- (id) lookupHomeFolderForUID: (NSString *) _uid
                    inContext: (id) _ctx;

- (NSArray *) lookupCalendarFoldersForUID: (NSString *) theUID;
- (NSArray *) lookupCalendarFoldersForUIDs: (NSArray *) _uids
                                 inContext: (id) _ctx;
- (NSArray *) lookupFreeBusyObjectsForUIDs: (NSArray *) _uids
                                 inContext: (id) _ctx;

- (NSArray *) uidsFromICalPersons: (NSArray *) _persons;
- (NSArray *) lookupCalendarFoldersForICalPerson: (NSArray *) _persons
                                       inContext: (id) _ctx;

/* bulk fetches */

- (NSString *) aclSQLListingFilter;

- (NSString *) roleForComponentsWithAccessClass: (iCalAccessClass) accessClass
					forUser: (NSString *) uid;

- (BOOL) showCalendarAlarms;
- (void) setShowCalendarAlarms: (BOOL) new;

- (BOOL) showCalendarTasks;
- (void) setShowCalendarTasks: (BOOL) new;

- (NSString *) syncTag;
- (void) setSyncTag: (NSString *) newSyncTag;

- (BOOL) synchronizeCalendar;
- (void) setSynchronizeCalendar: (BOOL) new;

- (BOOL) includeInFreeBusy;
- (void) setIncludeInFreeBusy: (BOOL) newInclude;

- (BOOL) notifyOnPersonalModifications;
- (void) setNotifyOnPersonalModifications: (BOOL) b;
- (BOOL) notifyOnExternalModifications;
- (void) setNotifyOnExternalModifications: (BOOL) b;
- (BOOL) notifyUserOnPersonalModifications;
- (void) setNotifyUserOnPersonalModifications: (BOOL) b;
- (NSString *) notifiedUserOnPersonalModifications;
- (void) setNotifiedUserOnPersonalModifications: (NSString *) theUser;

- (NSString *) importComponent: (iCalEntityObject *) event
                      timezone: (iCalTimeZone *) timezone;

- (int) importCalendar: (iCalCalendar *) calendar;

/* caldav proxy */

- (SOGoAppointmentProxyPermission)
     proxyPermissionForUserWithLogin: (NSString *) login;

- (NSArray *) aclUsersWithProxyWriteAccess: (BOOL) write;

- (void) findEntityForClosestAlarm: (id *) theEntity
                          timezone: (NSTimeZone *) theTimeZone
                         startDate: (NSCalendarDate **) theStartDate
                           endDate: (NSCalendarDate **) theEndDate;

@end

#endif /* __Appointments_SOGoAppointmentFolder_H__ */
