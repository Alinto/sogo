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
#include <SaxObjC/SaxObjC.h>

@interface iCal2Tool : NSObject
{
  id<NSObject,SaxXMLReader> parser;
  SaxObjectDecoder *sax;
}

- (int)runWithArguments:(NSArray *)_args;

@end

@implementation iCal2Tool

- (id)init {
  if ((self = [super init])) {
    self->parser =
      [[[SaxXMLReaderFactory standardXMLReaderFactory] 
	                     createXMLReaderForMimeType:@"text/calendar"]
                             retain];
    if (self->parser == nil) {
      NSLog(@"%s: did not find a parser for text/calendar !",
	    __PRETTY_FUNCTION__);
      [self release];
      return nil;
    }
    
    /* ensure that NGCards.xmap can be found ! (Library/SaxMappings) */
    self->sax = [[SaxObjectDecoder alloc] initWithMappingNamed:@"NGCards"];
    if (self->sax == nil) {
      NSLog(@"could not create the iCal SAX handler !");
      [self release];
      return nil;
    }
    
    [self->parser setContentHandler:self->sax];
    [self->parser setErrorHandler:self->sax];
  }
  return self;
}
- (void)dealloc {
  [self->sax    release];
  [self->parser release];
  [super dealloc];
}

/* parsing */

- (id)parseFile:(NSString *)_path {
  if ([_path length] == 0) return nil;
  
  _path = [@"file://" stringByAppendingString:_path];
  
  [self->parser parseFromSystemId:_path];
  
  return [self->sax rootObject];
}

- (void)printParsedObject:(id)_object {
  NSLog(@"component: %@",       _object);
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
      id component;
      
      NS_DURING
	component = [self parseFile:arg];
      NS_HANDLER
	abort();
      NS_ENDHANDLER;
      
      if (component == nil)
	NSLog(@"could not parse file: '%@'", arg);
      else
	[self printParsedObject:component];
    }
    [pool2 release];
  }
  return 0;
}

@end /* iCal2Tool */

int main(int argc, char **argv, char **env)  {
  NSAutoreleasePool *pool;
  iCal2Tool *tool;
  int rc;

#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  pool = [[NSAutoreleasePool alloc] init];
  
  if ((tool = [[iCal2Tool alloc] init])) {
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
