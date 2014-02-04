/*
  Copyright (C) 2005 SKYRIX Software AG

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

#import <Foundation/NSValue.h>

#import "UIxMailSizeFormatter.h"

@implementation UIxMailSizeFormatter

+ (id) sharedMailSizeFormatter
{
  static UIxMailSizeFormatter *fmt = nil; // THREAD
  if (fmt == nil) fmt = [[self alloc] init];
  return fmt;
}

/* formatting */

- (NSString *) stringForSize: (unsigned int) size
{
  char buf[128];

  if (size > 1024*1024)
    sprintf(buf, "%.1f MiB", ((double)size / 1024 / 1024));
  else if (size > 1024*100)
    sprintf(buf, "%d KiB", (size / 1024));
  else if (size > 1024)
    sprintf(buf, "%.1f KiB", ((double)size / 1024));
  else
    sprintf(buf, "%d B", size);
  
  return [NSString stringWithCString:buf];
}

- (NSString *) stringForObjectValue: (id) _object
{
  return [self stringForSize:[_object unsignedIntValue]];
}

@end /* UIxMailSizeFormatter */
