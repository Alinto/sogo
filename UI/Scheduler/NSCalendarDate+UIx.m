/*
  Copyright (C) 2004 SKYRIX Software AG

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
// $Id: UIxAppointmentEditor.m 181 2004-08-11 15:13:25Z helge $

#include "NSCalendarDate+UIx.h"
#include "common.h"

@implementation NSCalendarDate(UIx)

- (NSCalendarDate *)dayOfWeeK:(unsigned)_day 
  offsetFromSunday:(unsigned)_offset
{
  unsigned dayOfWeek, distance;
    
  /* perform "locale" correction */
  dayOfWeek = (7 + [self dayOfWeek] - _offset) % 7;

  _day = (_day % 7);
  if(_day == dayOfWeek)
    return self;

  distance = _day - dayOfWeek;
  return [self dateByAddingYears:0 months:0 days:distance];
}

/* this implies that monday is the start of week! */

- (NSCalendarDate *)sundayOfWeek {
  return [self dayOfWeeK:6 offsetFromSunday:1];
}

@end /* NSCalendarDate(UIx) */
