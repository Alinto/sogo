/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import "IcalResponse.h"

@implementation IcalResponse

- (void)_initContent {
  [self appendLine:@"BEGIN:VCALENDAR"];
  [self appendLine:@"VERSION:2.0"];
  [self appendLine:@"PRODID:-//skyrix42/scheduler/skyaptd v.1.0//"];
}

- (id)init {
  if ((self = [super init])) {
    self->content    = [[NSMutableString alloc] initWithCapacity:0xFFFF];
    self->isFinished = NO;
    [self _initContent];
  }
  return self;
}
- (id)initWithCapacity:(unsigned)_capacity {
  if ((self = [super init])) {
    self->content    = [[NSMutableString alloc] initWithCapacity:_capacity];
    self->isFinished = NO;
    [self _initContent];
  }
  return self;
}

- (void)dealloc {
  [self->content release];
  [super dealloc];
}


- (BOOL)appendLine:(NSString *)_line {
  if (self->isFinished) {
    //NSLog(@"WARNING[%s]: already finished!", __PRETTY_FUNCTION__);
    return NO;
  }
  // limit length to 75 chars
  while ([_line length] > 75) {
    [self appendLine:[_line substringToIndex:75]];
    _line = [@" " stringByAppendingString:[_line substringFromIndex:75]];
  }

  [self->content appendString:_line];
  [self->content appendString:@"\r\n"];
  
  return YES;
}

- (BOOL)appendLine:(NSString *)_line forAttribute:(NSString *)_attr {
  _line = [NSString stringWithFormat:@"%@:%@", _attr, _line];
  return [self appendLine:_line];
}


- (void)finish {
  if (self->isFinished) return;
  [self appendLine:@"END:VCALENDAR"];
  self->isFinished = YES;
}

- (NSString *)asString {
  [self finish];
  return [[self->content copy] autorelease];
}

@end /* IcalResponse */
