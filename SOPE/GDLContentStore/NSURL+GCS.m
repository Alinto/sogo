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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "NSURL+GCS.h"

@implementation NSURL(GCS)

- (NSString *)gcsPathComponent:(unsigned)_idx {
  NSString *p;
  NSArray  *pcs;
  unsigned len;
  
  p = [self path];
  if ([p length] == 0)
    return nil;
  
  pcs = [p componentsSeparatedByString:@"/"];
  if ((len = [pcs count]) == 0)
    return nil;
  if (len <= _idx)
    return  nil;
  return [pcs objectAtIndex:_idx];
}

- (NSString *)gcsDatabaseName {
  return [self gcsPathComponent:1];
}
- (NSString *)gcsTableName {
  return [[self path] lastPathComponent];
}

@end /* NSURL(GCS) */
