/*
  Copyright (C) 2000-2005 SKYRIX Software AG

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

#include "WOContext+Agenor.h"
#include "common.h"

@implementation WOContext(Agenor)

static EOQualifier *internetDetectQualifier = nil;

static EOQualifier *getInternetDetectQualifier(void) {
  static BOOL didCheck = NO;
  NSUserDefaults *ud;
  NSString *s;
  
  if (didCheck) return internetDetectQualifier;
  
  ud = [NSUserDefaults standardUserDefaults];
  
  if ((s = [ud stringForKey:@"SOGoInternetDetectQualifier"]) != nil) {
    internetDetectQualifier = 
      [[EOQualifier qualifierWithQualifierFormat:s] retain];
    if (internetDetectQualifier == nil)
      NSLog(@"ERROR: could not parse qualifier: '%@'", s);
  }
  if (internetDetectQualifier == nil)
    NSLog(@"Note: no 'SOGoInternetDetectQualifier' configured.");
  else {
    NSLog(@"Note: detect Internet access using: %@", 
	  internetDetectQualifier);
  }

  didCheck = YES;
  return internetDetectQualifier;
}

- (BOOL)isAccessFromIntranet {
  id<EOQualifierEvaluation> q;
  NSNumber  *bv;
  WORequest *rq;
  BOOL ok;
  
  if ((bv = [self objectForKey:@"_agenorUnrestricedAccess"]) != nil)
    return [bv boolValue];

  if ((rq = [self request]) == nil) {
    [self logWithFormat:@"ERROR: got no request for context!"];
    return NO;
  }
  

  if ((q = (id)getInternetDetectQualifier()) == nil)
    /* if no qualifier is set, allow access */
    ok = YES;
  else
    /* is Internet request? */
    ok = [q evaluateWithObject:[rq headers]] ? NO : YES;
  
  bv = [NSNumber numberWithBool:ok];
  [self setObject:bv forKey:@"_agenorUnrestricedAccess"];
  return ok;
}

@end /*  WOContext(Agenor) */
