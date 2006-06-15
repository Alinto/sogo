/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

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
// $Id: SOGoAppointment+UIx.m 365 2004-10-06 10:53:34Z znek $


#include "SOGoAppointment+UIx.h"
#include "common.h"

@implementation SOGoAppointment (UIx)

- (NSString *)priorityLabelKey {
    NSString *prio;
    
    prio = [self priority];
    if(!prio) {
        prio = @"0";
    }
    else {
        NSRange r;
        
        r = [prio rangeOfString:@";"];
        if(r.length > 0) {
            prio = [prio substringToIndex:r.location];
        }
    }
    return [NSString stringWithFormat:@"prio_%@", prio];
}

@end
