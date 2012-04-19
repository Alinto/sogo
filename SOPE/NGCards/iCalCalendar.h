/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGCards_iCalCalendar_H__
#define __NGCards_iCalCalendar_H__

#import "CardGroup.h"

@class NSString;
@class NSMutableArray;
@class NSArray;
@class NSEnumerator;
@class NSMutableDictionary;

@class iCalEvent;
@class iCalToDo;
@class iCalJournal;
@class iCalFreeBusy;
@class iCalEntityObject;
@class iCalTimeZone;

@interface iCalCalendar : CardGroup
// {
//   NSString *version;
//   NSString *calscale;
//   NSString *prodId;
//   NSString *method;

//   NSMutableArray *todos;
//   NSMutableArray *events;
//   NSMutableArray *journals;
//   NSMutableArray *freeBusys;
//   NSMutableDictionary *timezones;
// }

/* accessors */

- (void) setMethod: (NSString *)_method;
- (NSString *) method;

- (void) setCalscale: (NSString *) _calscale;
- (NSString *) calscale;

- (void) setVersion: (NSString *) _version;
- (NSString *) version;

- (void) setProdID: (NSString *) _prodid;
- (NSString *) prodId;

- (void) setMethod: (NSString *) _method;
- (NSString *) method;

- (NSArray *) events;
- (NSArray *) todos;
- (NSArray *) journals;
- (NSArray *) freeBusys;
- (NSArray *) timezones;

- (void) addToEvents: (iCalEvent *) _event;

- (BOOL) addTimeZone: (iCalTimeZone *) iTZ;
- (iCalTimeZone *) timeZoneWithId: (NSString *) tzId;

/* collection */

- (NSArray *) allObjects;

@end

#endif /* __NGCards_iCalCalendar_H__ */
