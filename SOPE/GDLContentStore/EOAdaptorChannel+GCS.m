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

#include "EOAdaptorChannel+GCS.h"
#include "common.h"

@implementation EOAdaptorChannel(GCS)

- (BOOL)tableExistsWithName:(NSString *)_tableName {
  NSException *ex;
  NSString    *sql;
  BOOL        didOpen;
  
  didOpen = NO;
  if (![self isOpen]) {
    if (![self openChannel])
      return NO;
    didOpen = YES;
  }
  
  sql = @"SELECT COUNT(*) FROM ";
  sql = [sql stringByAppendingString:_tableName];
  sql = [sql stringByAppendingString:@" WHERE 1 = 2"];
  
  ex = [[[self evaluateExpressionX:sql] retain] autorelease];
  [self cancelFetch];
  
  if (didOpen) [self closeChannel];
  return ex != nil ? NO : YES;
}

@end /* EOAdaptorChannel(GCS) */
