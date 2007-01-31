/*
  Copyright (C) 2005 Helge Hess

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

#import <Foundation/Foundation.h>
#import <NGCards/NGVCard.h>

@interface vcsparsetest : NSObject
{
}

- (int)runWithArguments:(NSArray *)_args;

@end

@implementation vcsparsetest

- (id)init {
  if ((self = [super init])) {
  }
  return self;
}

- (void)dealloc {
  [super dealloc];
}

/* parsing */

- (id)parseFile:(NSString *)_path {
  if ([_path length] == 0) return nil;
  return [NGVCard parseVCardsFromSource:[NSURL fileURLWithPath:_path]];
}

- (void)printParsedObject: (NSArray *)_cards
{
  NSEnumerator *cardObjects;
  NGVCard *card;

  cardObjects = [_cards objectEnumerator];
  card = [cardObjects nextObject];
  while (card)
    {
      NSLog (@"-------s\n%@\ne-------", [card versitString]);
      card = [cardObjects nextObject];
    }

#if 0
  NSLog(@"  subcomponents: %@", [_object subComponents]);
  
  printf("%s", [[_object icalString] cString]);
#endif
}

/* run */

- (int)runWithArguments:(NSArray *)_args {
  NSEnumerator      *args;
  NSString          *arg;
  
  args = [_args objectEnumerator];
  [args nextObject]; // process name ...

  while ((arg = [args nextObject])) {
    NSAutoreleasePool *pool2;

    if ([arg hasPrefix:@"-"]) { /* consume defaults */
      [args nextObject];
      continue;
    }
    
    pool2 = [[NSAutoreleasePool alloc] init];
    {    
      NSArray *cards;
      
      NS_DURING
	cards = [self parseFile:arg];
      NS_HANDLER
	abort();
      NS_ENDHANDLER;
      
      if (!cards)
	NSLog(@"could not parse file: '%@'", arg);
      else
	[self printParsedObject:cards];
    }
    [pool2 release];
  }
  return 0;
}

@end /* vcsparsetest */

int main(int argc, char **argv, char **env)  {
  NSAutoreleasePool *pool;
  vcsparsetest *tool;
  int rc;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  if ((tool = [[vcsparsetest alloc] init]) != nil) {
    NS_DURING
      rc = [tool runWithArguments:[[NSProcessInfo processInfo] arguments]];
    NS_HANDLER
      abort();
    NS_ENDHANDLER;
    
    [tool release];
  }
  else
    rc = 1;
  
  [pool release];
  return rc;
}
