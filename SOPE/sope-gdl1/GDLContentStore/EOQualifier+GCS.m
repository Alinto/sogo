/*
  Copyright (C) 2004-2007 SKYRIX Software AG

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

#include "EOQualifier+GCS.h"
#include "common.h"

@implementation EOQualifier(GCS)

- (void)_appendAndQualifier:(EOAndQualifier *)_q 
  toString:(NSMutableString *)_ms
{
  // TODO: move to EOQualifier category
  NSArray *qs;
  unsigned i, count;
  
  qs = [_q qualifiers];
  if ((count = [qs count]) == 0)
    return;
  
  for (i = 0; i < count; i++) {
    if (i != 0) [_ms appendString:@" AND "];
    if (count > 1) [_ms appendString:@"("];
    [[qs objectAtIndex:i] _gcsAppendToString:_ms];
    if (count > 1) [_ms appendString:@")"];
  }
}
- (void)_appendOrQualifier:(EOAndQualifier *)_q 
  toString:(NSMutableString *)_ms
{
  // TODO: move to EOQualifier category
  NSArray *qs;
  unsigned i, count;
  
  qs = [_q qualifiers];
  if ((count = [qs count]) == 0)
    return;
  
  for (i = 0; i < count; i++) {
    if (i != 0) [_ms appendString:@" OR "];
    if (count > 1) [_ms appendString:@"("];
    [[qs objectAtIndex:i] _gcsAppendToString:_ms];
    if (count > 1) [_ms appendString:@")"];
  }
}
- (void)_appendKeyValueQualifier:(EOKeyValueQualifier *)_q 
  toString:(NSMutableString *)_ms
{
  id val;
  NSString *qKey, *qOperator, *qValue, *qFormat;
  BOOL isCI;

  qKey = [_q key];

  if ((val = [_q value])) {
    SEL op = [_q selector];

    if ([val isNotNull]) {
      isCI = NO;

      if (sel_eq(op, EOQualifierOperatorEqual))
	qOperator = @"=";
      else if (sel_eq(op, EOQualifierOperatorNotEqual))
	qOperator = @"!=";
      else if (sel_eq(op, EOQualifierOperatorLessThan))
	qOperator = @"<";
      else if (sel_eq(op, EOQualifierOperatorGreaterThan))
	qOperator = @">";
      else if (sel_eq(op, EOQualifierOperatorLessThanOrEqualTo))
	qOperator = @"<=";
      else if (sel_eq(op, EOQualifierOperatorGreaterThanOrEqualTo))
	qOperator = @">=";
      else if (sel_eq(op, EOQualifierOperatorLike))
	qOperator = @"LIKE";
      else if (sel_eq(op, EOQualifierOperatorCaseInsensitiveLike)) {
	isCI = YES;
	qOperator = @"LIKE";
      }
      else {
	[self errorWithFormat:@"%s: unsupported operation for null: %@",
	      __PRETTY_FUNCTION__, NSStringFromSelector(op)];
      }

      if ([val isKindOfClass:[NSNumber class]])
	qValue = [val stringValue];
      else if ([val isKindOfClass:[NSString class]]) {
	qValue = [NSString stringWithFormat: @"'%@'", val];
      }
      else {
	[self errorWithFormat:@"%s: unsupported value class: %@",
	      __PRETTY_FUNCTION__, NSStringFromClass([val class])];
      }
    }
    else {
      if (sel_eq(op, EOQualifierOperatorEqual)) {
	qOperator = @"IS";
	qValue = @"NULL";
      }
      else if (sel_eq(op, EOQualifierOperatorEqual)) {
	qOperator = @"IS NOT";
	qValue = @"NULL";
      }
      else {
	[self errorWithFormat:@"%s: invalid operation for null: %@",
	      __PRETTY_FUNCTION__, NSStringFromSelector(op)];
      }
    }
  }
  else {
    qOperator = @"IS";
    qValue = @"NULL";
  }

  if (isCI)
    qFormat = @"UPPER(%@) %@ UPPER(%@)";
  else
    qFormat = @"%@ %@ %@";

  [_ms appendFormat: qFormat, qKey, qOperator, qValue];
}

- (void)_appendQualifier:(EOQualifier *)_q toString:(NSMutableString *)_ms {
  if (_q == nil) return;
  
  if ([_q isKindOfClass:[EOAndQualifier class]])
    [self _appendAndQualifier:(id)_q toString:_ms];
  else if ([_q isKindOfClass:[EOOrQualifier class]])
    [self _appendOrQualifier:(id)_q toString:_ms];
  else if ([_q isKindOfClass:[EOKeyValueQualifier class]])
    [self _appendKeyValueQualifier:(id)_q toString:_ms];
  else
    [self errorWithFormat:@"unknown qualifier: %@", _q];
}

- (void)_gcsAppendToString:(NSMutableString *)_ms {
  [self _appendQualifier:self toString:_ms];
}

@end /* EOQualifier(GCS) */
