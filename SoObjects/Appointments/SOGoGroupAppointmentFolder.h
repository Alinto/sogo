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
// $Id: SOGoAppointmentFolder.h 137 2004-07-02 17:42:14Z helge $

#ifndef __Appointments_SOGoGroupAppointmentFolder_H__
#define __Appointments_SOGoGroupAppointmentFolder_H__

#include "SOGoAppointmentFolder.h"

/*
  SOGoGroupAppointmentFolder
    Parent object: an SOGoGroupFolder (or subclass)
    Child objects: SOGoAppointmentObject
  
  Note: this is only a subclass of SOGoAppointmentFolder to inherit all the
        SOPE methods (it provides the same API). It is not an ocsFolder but
        rather looks up the "child" folders for aggregation using regular SOPE
        techniques.
        => hm, do we need "aspects" in SOPE? ;-)

  Note: this class retains appointment folders looked up, so watch out for
        reference cycles!
*/

@class NSMutableDictionary;

@interface SOGoGroupAppointmentFolder : SOGoAppointmentFolder
{
  NSMutableDictionary *uidToFolder;
}

@end

#endif /* __Appointments_SOGoGroupAppointmentFolder_H__ */
