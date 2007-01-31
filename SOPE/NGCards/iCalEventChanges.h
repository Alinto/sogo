/*
 Copyright (C) 2004-2005 SKYRIX Software AG
 
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
//  Created by znek on 31.08.04.

#ifndef	__NGiCal_iCalEventChanges_H_
#define	__NGiCal_iCalEventChanges_H_

#include <Foundation/NSObject.h>

@class iCalEvent, NSArray, NSMutableArray;

@interface iCalEventChanges : NSObject
{
  NSMutableArray *insertedAttendees;
  NSMutableArray *deletedAttendees;
  NSMutableArray *updatedAttendees;
  NSMutableArray *insertedAlarms;
  NSMutableArray *deletedAlarms;
  NSMutableArray *updatedAlarms;
  NSMutableArray *updatedProperties;
}

+ (id)changesFromEvent:(iCalEvent *)_old toEvent:(iCalEvent *)_to;
- (id)initWithFromEvent:(iCalEvent *)_from toEvent:(iCalEvent *)_to;

- (BOOL)hasChanges;

- (BOOL)hasAttendeeChanges;
- (NSArray *)insertedAttendees;
- (NSArray *)deletedAttendees;
- (NSArray *)updatedAttendees;

- (BOOL)hasAlarmChanges;
- (NSArray *)insertedAlarms;
- (NSArray *)deletedAlarms;
- (NSArray *)updatedAlarms;

- (BOOL)hasPropertyChanges;
- (NSArray *)updatedProperties;

@end

#endif	/* __NGiCal_iCalEventChanges_H_ */
