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

#include "iCalDataSource.h"
#include "iCalObject.h"
#include "iCalCalendar.h"
#include <SaxObjC/SaxObjC.h>
#include "common.h"

@interface NSObject(suppressCapitalizedKeyWarning)
+ (void)suppressCapitalizedKeyWarning;
@end

@implementation iCalDataSource

// THREAD
static id<NSObject,SaxXMLReader> parser = nil;
static SaxObjectDecoder *sax = nil;

- (void)_setupGlobals {
  if (parser == nil ) {
    SaxXMLReaderFactory *factory = 
      [SaxXMLReaderFactory standardXMLReaderFactory];
    parser = [[factory createXMLReaderForMimeType:@"text/calendar"] retain];
    if (parser == nil)
      [self logWithFormat:@"ERROR: found no SAX driver for 'text/calendar'!"];
  }
  if (sax == nil && parser != nil) {
    NSBundle *bundle;
    NSString *p;
    
#if COCOA_Foundation_LIBRARY
    /* otherwise we get warning on "X-WR-TIMEZONE" etc */
    [NSClassFromString(@"NSKeyBinding") suppressCapitalizedKeyWarning];
#endif
    
    bundle = [NSBundle bundleForClass:[self class]];
    if ((p = [bundle pathForResource:@"NGiCal" ofType:@"xmap"]))
      sax = [[SaxObjectDecoder alloc] initWithMappingAtPath:p];
    else
      sax = [[SaxObjectDecoder alloc] initWithMappingNamed:@"NGiCal"];
    
    [parser setContentHandler:sax];
    [parser setErrorHandler:sax];
  }
}


- (id)initWithURL:(NSURL *)_url entityName:(NSString *)_ename {
  [self _setupGlobals];
  if ((self = [super init])) {
    self->url        = [_url copy];
    self->entityName = [_ename copy];
  }
  return self;
}
- (id)initWithPath:(NSString *)_path entityName:(NSString *)_ename {
  NSURL *lurl;
  
  lurl = [[[NSURL alloc] initFileURLWithPath:_path] autorelease];
  return [self initWithURL:lurl entityName:_ename];
}

- (id)initWithURL:(NSURL *)_url {
  return [self initWithURL:_url entityName:nil];
}
- (id)initWithPath:(NSString *)_path {
  return [self initWithPath:_path entityName:nil];
}
- (id)init {
  return [self initWithURL:nil];
}

- (void)dealloc {
  [self->fetchSpecification release];
  [self->url                release];
  [self->entityName         release];
  [super dealloc];
}

/* accessors */

- (void)setFetchSpecification:(EOFetchSpecification *)_fspec {
  if ([self->fetchSpecification isEqual:_fspec])
    return;
  
  ASSIGNCOPY(self->fetchSpecification, _fspec);

  [self postDataSourceChangedNotification];
}
- (EOFetchSpecification *)fetchSpecification {
  return self->fetchSpecification;
}

/* fetching */

- (id)_parseCalendar {
  id cal;
  
  if (parser == nil) {
    [self logWithFormat:@"ERROR: missing iCalendar parser!"];
    return nil;
  }
  if (sax == nil) {
    [self logWithFormat:@"ERROR: missing SAX handler!"];
    return nil;
  }
  
  [parser parseFromSource:self->url];
  cal = [sax rootObject];
  
  return cal;
}

- (NSArray *)objectsForEntityNamed:(NSString *)ename inCalendar:(id)_cal {
  if ([ename isEqualToString:@"vevent"])
    return [_cal events];
  if ([ename isEqualToString:@"vtodo"])
    return [_cal todos];
  if ([ename isEqualToString:@"vjournal"])
    return [_cal journals];
  if ([ename isEqualToString:@"vfreebusy"])
    return [_cal freeBusys];
  
  [self logWithFormat:@"unknown calendar entity '%@'", ename];
  return nil;
}

- (NSArray *)objectsFromCalendar:(id)_cal {
  NSString *ename;
  
  ename = [self->fetchSpecification entityName];
  if ([ename length] == 0)
    ename = self->entityName;

  if ([ename length] == 0)
    return [_cal allObjects];
  
  if ([_cal isKindOfClass:[NSDictionary class]]) {
    /*
      This happens with Mozilla Calendar which posts one vcalendar
      entry (with method 'PUBLISH') per event.
    */
    NSMutableArray *ma;
    NSArray  *calendars;
    unsigned i, count;
    
    if (![[(NSDictionary *)_cal objectForKey:@"tag"] 
	   isEqualToString:@"iCalendar"]) {
      [self logWithFormat:
	      @"ERROR: calendar (entity=%@) passed in as a dictionary: %@", 
	      _cal];
    }
    
    if ((calendars=[(NSDictionary *)_cal objectForKey:@"subcomponents"])==nil)
      return nil;

    count = [calendars count];
    ma = [NSMutableArray arrayWithCapacity:(count + 1)];
    
    for (i = 0; i < count; i++) {
      NSArray *objects;
      
      objects = [self objectsForEntityNamed:ename 
		      inCalendar:[calendars objectAtIndex:i]];
      if ([objects count] == 0)
	continue;
      
      [ma addObjectsFromArray:objects];
    }
    return ma;
  }
  
  return [self objectsForEntityNamed:ename inCalendar:_cal];
}

- (NSArray *)fetchObjects {
  NSAutoreleasePool *pool;
  NSArray *result;
  id calendar;

  pool = [[NSAutoreleasePool alloc] init];
  
  if ((calendar = [self _parseCalendar]) == nil)
    return nil;
  
  if (self->fetchSpecification == nil) {
    result = [[self objectsFromCalendar:calendar] shallowCopy];
  }
  else {
    NSMutableArray *ma;
    NSEnumerator   *e;
    EOQualifier *q;
    NSArray     *sort;
    NSArray     *objects;
    iCalObject  *object;
    
    /* get objects */
    
    objects = [self objectsFromCalendar:calendar];
    
    /* first filter using qualifier */
    
    ma = [NSMutableArray arrayWithCapacity:[objects count]];
    q  = [self->fetchSpecification qualifier];
    e  = [objects objectEnumerator];
    while ((object = [e nextObject])) {
      if (q) {
	if (![(id<EOQualifierEvaluation>)q evaluateWithObject:object])
	  continue;
      }
      
      [ma addObject:object];
    }
    
    /* now sort */
    
    if ((sort = [self->fetchSpecification sortOrderings]))
      [ma sortUsingKeyOrderArray:sort];

    result = [ma shallowCopy];
  }
  
  [pool release];
  
  return [result autorelease];
}

@end /* iCalDataSource */
