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
// $Id: UIxCalDayChartview.m 663 2005-07-05 18:13:24Z znek $


#include "UIxCalDayView.h"

@interface UIxCalDayChartview : UIxCalDayView
{

}

@end

#include "common.h"
#include <SOGoUI/SOGoAptFormatter.h>

@implementation UIxCalDayChartview

- (void)configureFormatters {
  [super configureFormatters];
  
  [self->aptFormatter setShortTitleOnly];
}

- (NSArray *)columns {
  static NSArray *columns = nil;
  if(columns == nil) {
    columns = [[NSArray arrayWithObject:@"0"] retain];
  }
  return columns;
}

- (BOOL)isPadColumn {
    return NO;
}

- (NSString *)shortTextForApt {
  if (![self canAccessApt])
    return @"";
  return [[self appointment] valueForKey:@"title"];
}

@end
