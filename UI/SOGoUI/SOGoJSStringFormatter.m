/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

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
// $Id: SOGoJSStringFormatter.m 415 2004-10-20 15:47:45Z znek $


#import "SOGoJSStringFormatter.h"

@implementation SOGoJSStringFormatter

static NSCharacterSet *quotesSet = nil;
static NSCharacterSet *squoteSet = nil;
static NSCharacterSet *dquoteSet = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if(didInit)
    return;
  
  didInit   = YES;
  quotesSet = \
    [[NSCharacterSet characterSetWithCharactersInString:@"'\""] retain];
  squoteSet = \
    [[NSCharacterSet characterSetWithCharactersInString:@"'"] retain];
  dquoteSet = \
    [[NSCharacterSet characterSetWithCharactersInString:@"\""] retain];
}

+ (id)sharedFormatter {
  static id sharedInstance = nil;
  if(!sharedInstance) {
    sharedInstance = [[self alloc] init];
  }
  return sharedInstance;
}

- (NSString *)stringByEscapingQuotesInString:(NSString *)_s {
  return [_s stringByEscapingCharactersFromSet:quotesSet
             usingStringEscaping:self];
}

- (NSString *)stringByEscapingSingleQuotesInString:(NSString *)_s {
  return [_s stringByEscapingCharactersFromSet:squoteSet
             usingStringEscaping:self];
}

- (NSString *)stringByEscapingDoubleQuotesInString:(NSString *)_s {
  return [_s stringByEscapingCharactersFromSet:dquoteSet
             usingStringEscaping:self];
}

- (NSString *)stringByEscapingString:(NSString *)_s {
  if([_s isEqualToString:@"'"]) {
    return @"&amp;apos;";
  }
  return @"&amp;quot;";
}

@end
