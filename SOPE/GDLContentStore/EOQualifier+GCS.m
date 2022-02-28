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

#import <Foundation/NSValue.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <GDLAccess/EOAdaptor.h>
#import <GDLAccess/EOAttribute.h>
#import <GDLAccess/EOSQLExpression.h>

#import "EOQualifier+GCS.h"

#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ >= 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
#  define sel_eq(__A__,__B__) sel_isEqual(__A__,__B__)
#endif

@implementation EOQualifier(GCS)

- (void) _appendAndQualifier: (EOAndQualifier *) _q
                 withAdaptor: (EOAdaptor *) _adaptor
                    toString: (NSMutableString *) _ms
{
  NSArray *qs;
  unsigned i, count;
  
  qs = [_q qualifiers];
  if ((count = [qs count]) == 0)
    return;
  
  for (i = 0; i < count; i++) {
    if (i != 0) [_ms appendString:@" AND "];
    if (count > 1) [_ms appendString:@"("];
    [[qs objectAtIndex:i] appendSQLToString: _ms
                                withAdaptor: _adaptor];
    if (count > 1) [_ms appendString:@")"];
  }
}
- (void) _appendOrQualifier: (EOAndQualifier *) _q
                withAdaptor: (EOAdaptor *) _adaptor
                   toString: (NSMutableString *) _ms
{
  NSArray *qs;
  unsigned i, count;
  
  qs = [_q qualifiers];
  if ((count = [qs count]) == 0)
    return;
  
  for (i = 0; i < count; i++) {
    if (i != 0) [_ms appendString:@" OR "];
    if (count > 1) [_ms appendString:@"("];
    [[qs objectAtIndex:i] appendSQLToString: _ms
                                withAdaptor: _adaptor];
    if (count > 1) [_ms appendString:@")"];
  }
}

- (void) _appendNotQualifier: (EONotQualifier *) _q
                 withAdaptor: (EOAdaptor *) _adaptor
                    toString:(NSMutableString *) _ms
{
  [_ms appendString:@" NOT ("];
  [[_q qualifier] appendSQLToString: _ms
                        withAdaptor: _adaptor];
  [_ms appendString:@")"];
}

- (void) _appendKeyValueQualifier: (EOKeyValueQualifier *) _q
                      withAdaptor: (EOAdaptor *) _adaptor
                         toString: (NSMutableString *) _ms
{
  id val;
  EOAttribute *attribute;
  NSString *qKey, *qOperator, *qValue, *qFormat;
  BOOL isCI;

  qKey = [_q key];
  isCI = NO;

  SEL op = [_q selector];

  val = [_q value];
  if (val && [val isNotNull]) {
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
      qOperator = @"=";
    }
    
    if ([val isKindOfClass: [NSNumber class]])
      qValue = [val stringValue];
    else if ([val isKindOfClass: [NSString class]]) {
      if ([(EOKeyValueQualifier *)self formatted])
        {
          qValue = val;
        }
      else
        {
          if (_adaptor)
            {
              // Assume qualifier applies to a varchar column type
              attribute = [EOAttribute new];
              [attribute setExternalType: @"varchar"];
              [attribute autorelease];

              if (sel_isEqual([_q selector], EOQualifierOperatorLike) ||
                  sel_isEqual([_q selector], EOQualifierOperatorCaseInsensitiveLike))
                {
                  qValue = [[_adaptor expressionClass] sqlPatternFromShellPattern: val];
                  qValue = [_adaptor formatValue: qValue
                                    forAttribute: attribute];
                }
              else
                qValue = [_adaptor formatValue: val
                                  forAttribute: attribute];
            }
          else
            // No adaptor provided, don't parse value
            qValue = [NSString stringWithFormat: @"'%@'", val];
        }
    }
    else {
      qValue = @"NULL";
      [self errorWithFormat:@"%s: unsupported value class: %@",
	    __PRETTY_FUNCTION__, NSStringFromClass([val class])];
    }
  }
  else {
    if (sel_eq(op, EOQualifierOperatorEqual)) {
      qOperator = @"IS";
      qValue = @"NULL";
    }
    else if (sel_eq(op, EOQualifierOperatorNotEqual)) {
      qOperator = @"IS NOT";
      qValue = @"NULL";
    }
    else {
      qOperator = @"IS";
      qValue = @"NULL";
      [self errorWithFormat:@"%s: invalid operation for null: %@",
	    __PRETTY_FUNCTION__, NSStringFromSelector(op)];
    }
  }

  if (isCI)
    qFormat = @"UPPER(%@) %@ UPPER(%@)";
  else
    qFormat = @"%@ %@ %@";

  [_ms appendFormat: qFormat, qKey, qOperator, qValue];
}

- (void) _appendQualifier: (EOQualifier *) _q
              withAdaptor: (EOAdaptor *) _adaptor
                 toString: (NSMutableString *) _ms
{
  if (_q == nil) return;
  
  if ([_q isKindOfClass: [EOAndQualifier class]])
    [self _appendAndQualifier: (id)_q
                  withAdaptor: _adaptor
                     toString: _ms];
  else if ([_q isKindOfClass: [EOOrQualifier class]])
    [self _appendOrQualifier: (id)_q
                 withAdaptor: _adaptor
                    toString: _ms];
  else if ([_q isKindOfClass: [EOKeyValueQualifier class]])
    [self _appendKeyValueQualifier: (id)_q
                       withAdaptor: _adaptor
                          toString: _ms];
  else if ([_q isKindOfClass: [EONotQualifier class]])
    [self _appendNotQualifier: (id)_q
                  withAdaptor: (EOAdaptor *) _adaptor
                     toString: _ms];
  else
    [self errorWithFormat:@"unknown qualifier: %@", _q];
}

- (void) appendSQLToString: (NSMutableString *) _ms
{
  [self _appendQualifier: self
             withAdaptor: nil
                toString: _ms];
}

- (void) appendSQLToString: (NSMutableString *) _ms
               withAdaptor: (EOAdaptor *) _adaptor
{
  [self _appendQualifier: self
             withAdaptor: _adaptor
                toString: _ms];
}

@end /* EOQualifier(GCS) */
