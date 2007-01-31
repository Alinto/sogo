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

#import <Foundation/Foundation.h>

@class EOQualifier, NSString, EOSortOrdering;

@interface iCal3Tool : NSObject
{
  EOQualifier *qualifier;
  NSString    *entityName;
  NSArray     *sortOrderings;
}

- (int)runWithArguments:(NSArray *)_args;

@end

#include <NGCards/iCalDataSource.h>
#include <NGCards/iCalObject.h>
#include <EOControl/EOQualifier.h>
#include <EOControl/EOSortOrdering.h>
#include "common.h"

@implementation iCal3Tool

- (id)init {
  if ((self = [super init])) {
    NSUserDefaults *ud;
    id tmp;
    
    /* collect options */
    ud = [NSUserDefaults standardUserDefaults];

    self->entityName = [[ud stringForKey:@"entity"] copy];
    
    if ((tmp = [ud objectForKey:@"qualifier"]) != nil) {
      self->qualifier = [[EOQualifier alloc] initWithPropertyList:tmp 
					     owner:nil];
    }

    if ((tmp = [ud objectForKey:@"sort"]) != nil) {
      tmp = [[EOSortOrdering alloc] initWithPropertyList:tmp owner:nil];
      if (tmp != nil) {
	self->sortOrderings = [[NSArray alloc] initWithObjects:&tmp count:1];
	[tmp release]; tmp = nil;
      }
    }
  }
  return self;
}
- (void)dealloc {
  [self->sortOrderings release];
  [self->qualifier     release];
  [self->entityName    release];
  [super dealloc];
}

/* run */

- (void)printObject:(id)_object {
  printf("object: %s\n", [[_object description] cString]);
}

- (int)runWithArguments:(NSArray *)_args {
  NSEnumerator *args;
  NSString     *arg;
  
  /* begin processing */
  
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
      iCalDataSource       *ds;
      EOFetchSpecification *fspec;
      NSArray    *objs;
      iCalObject *obj;
      
      /* setup fetch specification */
      
      fspec = [[[EOFetchSpecification alloc] init] autorelease];
      [fspec setEntityName:self->entityName];
      [fspec setQualifier:self->qualifier];
      
      /* setup datasource */
      
      ds = [iCalDataSource alloc]; // keep gcc happy
      ds = [[ds initWithPath:arg] autorelease];
      [ds setFetchSpecification:fspec];

      /* perform fetch */
      
      if ((objs = [ds fetchObjects]) == nil) {
	/* fetch failed */
	
	NSLog(@"fetch on ical file failed: %@", arg);
      }
      else {
	/* process results */
	NSEnumerator *e;
	
	e = [objs objectEnumerator];
	while ((obj = [e nextObject])) {
	  [self printObject:obj];
	}
      }
    }
    [pool2 release];
  }
  return 0;
}

@end /* iCal3Tool */

int main(int argc, char **argv, char **env)  {
  NSAutoreleasePool *pool;
  iCal3Tool *tool;
  int rc;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  if ((tool = [[iCal3Tool alloc] init])) {
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
