/*
  Copyright (C) 2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/


#import <Foundation/NSObject.h>

@class NSArray;

@interface TestQuickExtract : NSObject

- (int)runWithArguments:(NSArray *)_args;

@end

#include <GDLContentStore/GCSFieldExtractor.h>
#include "common.h"

@implementation TestQuickExtract

- (int)usage:(NSArray *)_args {
  fprintf(stderr, "usage: %s <ExtractorClassName> <file1> <file2>\n",
	  [[_args objectAtIndex:0] cString]);
  return 1;
}

- (void)extractQuickInfoFromFileAtPath:(NSString *)_path
  usingExtractorClass:(Class)_clazz
{
  GCSFieldExtractor *extractor;
  NSString     *content;
  NSDictionary *quickInfo;

  if ((content = [NSString stringWithContentsOfFile:_path]) == nil) {
    fprintf(stderr, "ERROR: could not open file: %s\n", [_path cString]);
    return;
  }
  
  extractor = [[_clazz alloc] init];
  quickInfo = [[extractor extractQuickFieldsFromContent:content] retain];
  [extractor release]; extractor = nil;
  
  if ([quickInfo count] == 0) {
    fprintf(stderr, "ERROR: could not extract quickfields from file: %s\n",
	    [_path cString]);
    return;
  }
  
  printf("File: %s\n", [_path cString]);
  printf("**************************************************\n");
  printf("%s\n", [[quickInfo description] cString]);

  [quickInfo release];
}

- (void)extractQuickInfoFromFiles:(NSEnumerator *)_pathes
  usingExtractorClass:(Class)_clazz
{
  NSString *path;
  
  while ((path = [_pathes nextObject]) != nil)
    [self extractQuickInfoFromFileAtPath:path usingExtractorClass:_clazz];
}

- (int)runWithArguments:(NSArray *)_args {
  NSEnumerator *e;
  Class clazz;
  
  if ([_args count] < 3)
    return [self usage:_args];
  
  if ((clazz = NSClassFromString([_args objectAtIndex:1])) == Nil) {
    fprintf(stderr, "ERROR: did not find extractor class: %s\n",
	    [[_args objectAtIndex:1] cString]);
    return 2;
  }
  
  e = [_args objectEnumerator];
  [e nextObject]; // skip toolname
  [e nextObject]; // skip classname
  
  [self extractQuickInfoFromFiles:e usingExtractorClass:clazz];
  
  return 0;
}

@end /* TestQuickExtract */


int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  TestQuickExtract  *tool;
  int rc;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  tool = [[TestQuickExtract alloc] init];
  rc = [tool runWithArguments:
	       [[NSProcessInfo processInfo] argumentsWithoutDefaults]];
  [tool release];
  [pool release];
  return rc;
}
