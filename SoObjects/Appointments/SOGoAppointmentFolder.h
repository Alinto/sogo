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

#ifndef __Appointments_SOGoAppointmentFolder_H__
#define __Appointments_SOGoAppointmentFolder_H__

#include <SOGo/SOGoFolder.h>

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

@class NSString, NSArray, NSCalendarDate, NSException, NSMutableDictionary;
@class GCSFolder;

@interface SOGoAppointmentFolder : SOGoFolder
{
  NSMutableDictionary *uidToFilename;
}

/* selection */

- (NSArray *) calendarUIDs;

/* vevent UID handling */

- (NSString *) resourceNameForEventUID: (NSString *) _uid;
- (Class) objectClassForResourceNamed: (NSString *) c_name;

/* fetching */

- (NSArray *) fetchFields: (NSArray *) _fields
               fromFolder: (GCSFolder *) _folder
                     from: (NSCalendarDate *) _startDate
                       to: (NSCalendarDate *) _endDate
                component: (id) _component;

- (NSArray * ) fetchFields: (NSArray *) _fields
                      from: (NSCalendarDate *) _startDate
                        to: (NSCalendarDate *) _endDate
                 component: (id) _component;

- (NSArray *) fetchCoreInfosFrom: (NSCalendarDate *) _startDate
                              to: (NSCalendarDate *) _endDate
                       component: (id) _component;

- (NSArray *) fetchFreebusyInfosFrom: (NSCalendarDate *) _startDate
                                  to: (NSCalendarDate *) _endDate;

- (void) deleteEntriesWithIds: (NSArray *) ids;

/* URL generation */

- (NSString *) baseURLForAptWithUID: (NSString *) _uid
                          inContext: (id) _ctx;

/* folder management */

- (id) lookupHomeFolderForUID: (NSString *) _uid
                    inContext: (id) _ctx;

- (NSArray *) lookupCalendarFoldersForUIDs: (NSArray *) _uids
                                 inContext: (id) _ctx;
- (NSArray *) lookupFreeBusyObjectsForUIDs: (NSArray *) _uids
                                 inContext: (id) _ctx;

- (NSArray *) uidsFromICalPersons: (NSArray *) _persons;
- (NSArray *) lookupCalendarFoldersForICalPerson: (NSArray *) _persons
                                       inContext: (id) _ctx;

- (id) lookupGroupFolderForUIDs: (NSArray *) _uids
                      inContext: (id) _ctx;
- (id) lookupGroupCalendarFolderForUIDs: (NSArray *) _uids
                              inContext: (id) _ctx;

/* bulk fetches */

- (NSArray *) fetchAllSOGoAppointments;

@end

#endif /* __Appointments_SOGoAppointmentFolder_H__ */
