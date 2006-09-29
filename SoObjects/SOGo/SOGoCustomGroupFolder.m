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
// $Id: SOGoCustomGroupFolder.m 115 2004-06-30 11:57:37Z helge $

#include "SOGoCustomGroupFolder.h"
#include "common.h"

@implementation SOGoCustomGroupFolder

static NSString *SOGoUIDSeparator = @",";

- (id)initWithUIDs:(NSArray *)_uids inContainer:(id)_container {
  if ((self = [self initWithName:nil inContainer:_container])) {
    self->uids = [_uids copy];
  }
  return self;
}

- (void)dealloc {
  [self->uids release];
  [super dealloc];
}

/* accessors */

- (NSArray *)unescapeURLComponents:(NSArray *)_parts {
// #warning TODO: implement URL UID unescaping if necessary
  // TODO: who calls this for what?
  // Note: remember URL encoding!
  return _parts;
}

- (NSArray *)uids {
  NSArray  *a;
  NSString *s;
  
  if (self->uids != nil)
    return self->uids;
  
  s = [self nameInContainer];
  if (![s hasPrefix:@"_custom_"]) {
    [self logWithFormat:@"WARNING: incorrect custom group folder name: '%@'",
	    s];
    return nil;
  }
  
  s = [s substringFromIndex:8];
  a = [s componentsSeparatedByString:SOGoUIDSeparator];
  a = [self unescapeURLComponents:a];
  self->uids = [a copy];
  
  if ([self->uids count] < 2)
    [self debugWithFormat:@"Note: less than two custom group members!"];
  
  return self->uids;
}

/* display name */

- (NSString *)davDisplayName {
  NSArray  *a;
  unsigned count;
  
  a = [self uids];
  if ((count = [a count]) == 0)
    return @"empty";
  if (count == 1)
    return [a objectAtIndex:0];
  
  if (count < 6) {
    NSMutableString *ms;
    unsigned i;
    
    ms = [NSMutableString stringWithCapacity:64];
    for (i = 0; i < count; i++) {
      if (i != 0) [ms appendString:@"|"];
      [ms appendString:[a objectAtIndex:i]];
      if ([ms length] > 60) {
	ms = nil;
	break;
      }
    }
    if (ms != nil) return ms;
  }
  
  // TODO: localize 'members' (UI component task?)
  return [NSString stringWithFormat:@"Members: %d", count];
}

@end /* SOGoCustomGroupFolder */
