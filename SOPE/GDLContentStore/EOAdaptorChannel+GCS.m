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

#import "EOAdaptorChannel+GCS.h"

@implementation EOAdaptorChannel(GCS)

- (BOOL) tableExistsWithName: (NSString *) tableName
{
  NSException *ex;
  NSString *sql;
  BOOL didOpen;

  didOpen = NO;
  if (![self isOpen]) {
    if (![self openChannel])
      return NO;
    didOpen = YES;
  }

  sql = [NSString stringWithFormat: @"SELECT 1 FROM %@ WHERE 1 = 2",
                  tableName];
  ex = [self evaluateExpressionX: sql];
  [self cancelFetch];
  
  if (didOpen) [self closeChannel];

  return (ex == nil);
}

- (void) dropTables: (NSArray *) tableNames
{
  unsigned int count, max;
  NSString *sql;

  max = [tableNames count];
  for (count = 0; count < max; count++)
    {
      sql = [NSString stringWithFormat: @"DROP TABLE %@",
		      [tableNames objectAtIndex: count]];
      [self evaluateExpressionX: sql];
    }
}

@end /* EOAdaptorChannel(GCS) */
