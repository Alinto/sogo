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

#include <NGObjWeb/WODirectAction.h>

@interface SOGoICalFilePublish : WODirectAction
{
}

@end

#include "SOGoICalHTTPHandler.h"
#include <SoObjects/Appointments/SOGoAppointmentFolder.h>
#include <SoObjects/Appointments/SOGoAppointmentObject.h>
#include <SOGo/SOGoAppointment.h>
#include <NGCards/NGCards.h>
#include <NGCards/iCalRenderer.h>
#include <SaxObjC/SaxObjC.h>
#include "common.h"

@implementation SOGoICalFilePublish

static BOOL debugOn = YES;
static id<NSObject,SaxXMLReader> parser = nil;
static SaxObjectDecoder          *sax   = nil;

+ (void)initialize {
  if (parser == nil) {
    parser = [[[SaxXMLReaderFactory standardXMLReaderFactory] 
		createXMLReaderForMimeType:@"text/calendar"]
	        retain];
    if (parser == nil)
      NSLog(@"ERROR: did not find a parser for text/calendar!");
  }
  if (sax == nil) {
    sax = [[SaxObjectDecoder alloc] initWithMappingNamed:@"NGCards"];
    if (sax == nil)
      NSLog(@"ERROR: could not create the iCal SAX handler!");
  }
  
  [parser setContentHandler:sax];
  [parser setErrorHandler:sax];
}

/* clientObject */

- (id)clientObject {
  return [[super clientObject] aptFolderInContext:[self context]];
}

/* change sets */

- (void)extractNewVEvents:(NSArray **)_new updatedVEvents:(NSArray **)_updated
  andDeletedUIDs:(NSArray **)_deleted
  whenComparingOldUIDs:(NSArray *)_old withNewVEvents:(NSArray *)_pub
{
  unsigned i, count;
  
  if (_new     != NULL ) *_new     = nil;
  if (_updated != NULL ) *_updated = nil;
  if (_deleted != NULL ) *_deleted = nil;
  
  /* scan old array for changes */
  
  for (i = 0, count = [_old count]; i < count; i++) {
    id obj;
    
    obj = [_old objectAtIndex:i];
    if (![obj isNotNull]) continue;
    
    if ([_pub containsObject:obj]) {
      /* updated object, in both sets */
      if (_updated == NULL) continue;
      if (*_updated == nil) *_updated = [NSMutableArray arrayWithCapacity:16];
      [(NSMutableArray *)*_updated addObject:obj];
    }
    else {
      /* deleted object, only in old set */
      if (_deleted == NULL) continue;
      if (*_deleted == nil) *_deleted = [NSMutableArray arrayWithCapacity:4];
      [(NSMutableArray *)*_deleted addObject:obj];
    }
  }

  /* scan new array for new objects */

  for (i = 0, count = [_pub count]; i < count; i++) {
    id obj;
    
    obj = [_pub objectAtIndex:i];
    if (![obj isNotNull]) continue;
    
    if ([_old containsObject:obj]) /* already processed */
      continue;
    
    if (_new == NULL) continue;
    if (*_new == nil) *_new = [NSMutableArray arrayWithCapacity:16];
    [(NSMutableArray *)*_new addObject:obj];
  }
}

/* operation */

- (NSException *)publishVToDos:(NSArray *)_todos {
  // TODO: work on tasks folder?
  
  if ([_todos count] == 0)
    return nil;
  
#if 1
  return [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
		      reason:@"server does not support vtodo PUTs!"];
#else
  return nil /* means: OK */;
#endif
}

- (NSException *)writeNewVEvents:(NSArray *)_events {
  SOGoAppointmentFolder *folder;
  iCalRenderer *renderer;
  NSException *error;
  unsigned i, count;
  
  if ((folder = [self clientObject]) == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"did not find clientObject?!"];
  }

  renderer = [iCalRenderer sharedICalendarRenderer];
  
  for (i = 0, count = [_events count]; i < count; i++) {
    SOGoAppointmentObject *object;
    iCalEvent *event;
    NSString  *ical;
    
    event = [_events objectAtIndex:i];
    ical  = [renderer iCalendarStringForEvent:event];

    if (![ical isNotNull] && ([ical length] == 0)) {
      [self logWithFormat:@"ERROR: got no ical representation of event: %@",
	      event];
      continue;
    }
    
    object = [folder lookupName:[event uid] inContext:[self context]
		     acquire:NO];
    if (![object isNotNull]) {
      // TODO: what to do?
      [self logWithFormat:@"ERROR: could not lookup event: %@", [event uid]];
      continue;
    }
    
    if ((error = [object saveContentString:ical]) != nil) /* failed, abort */
      return error;
  }
  return nil; // TODO: fake OK
}

- (NSException *)updateVEvents:(NSArray *)_events {
  if ([_events count] == 0)
    return nil;
  
  [self logWithFormat:@"TODO: should update: %@", _events];
  return nil; // TODO: fake OK
}

- (NSException *)deleteUIDs:(NSArray *)_uids {
  if ([_uids count] == 0)
    return nil;
  
  [self logWithFormat:@"TODO: should delete UIDs: %@", 
	[_uids componentsJoinedByString:@", "]];
  return nil; // TODO: fake OK
}

- (NSException *)publishVEvents:(NSArray *)_events {
  // TODO: extract UIDs and compare sets
  NSException *ex;
  NSArray *availUIDs;
  NSArray *new, *updated, *deleted;
  
  [self debugWithFormat:@"publish %d events ...", [_events count]];
  
  /* find changeset */
  
  availUIDs = [[self clientObject] toOneRelationshipKeys];

  /* build changeset */
  
  [self extractNewVEvents:&new updatedVEvents:&updated andDeletedUIDs:&deleted
	whenComparingOldUIDs:availUIDs
	withNewVEvents:_events];
  
  /* process */
  
  if ([new count] > 0) {
    if ((ex = [self writeNewVEvents:new]) != nil)
      return ex;
  }
  
  if ([updated count] > 0) {
    if ((ex = [self updateVEvents:updated]) != nil)
      return ex;
  }
  
  if ([deleted count] > 0) {
    if ((ex = [self deleteUIDs:deleted]) != nil)
      return ex;
  }
  
  return nil /* means: OK */;
}

- (NSException *)publishICalCalendar:(iCalCalendar *)_iCal {
  NSException *ex;
  
  [self debugWithFormat:@"publish iCalCalendar: %@", _iCal];

  if ((ex = [self publishVEvents:[_iCal events]]) != nil)
    return ex;
  
  if ((ex = [self publishVToDos:[_iCal todos]]) != nil)
    return ex;
  
  return nil /* means: OK */;
}

- (NSException *)publishICalendarString:(NSString *)_ical {
  NSException *ex;
  id root;
  
  [parser parseFromSource:_ical];
  root = [[sax rootObject] retain]; /* retain to keep it around */
  [sax reset];
  
  if (![root isNotNull]) {
    [self debugWithFormat:@"invalid iCal input: %@", _ical];
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"could not parse iCal input?!"];
  }
  
  if ([root isKindOfClass:[NSException class]])
    return [root autorelease];
  
  if ([root isKindOfClass:[iCalCalendar class]]) {
    ex = [self publishICalCalendar:root];
  }
  else {
    ex = [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
		      reason:@"cannot deal with input"];
  }
  
  [root release]; root = nil;
  return ex /* means: OK */;
}

/* responses */

- (WOResponse *)publishOkResponse {
  WOResponse *r;
  
  r = [[self context] response];
  [r setStatus:200 /* OK */];
  return r;
}

/* actions */

- (id)defaultAction {
  /*
    Note: Apple iCal.app submits no content-type!
  */
  NSString *s;
  
  s = [[[self context] request] contentAsString];
  if ([s length] == 0) {
    [self debugWithFormat:@"missing content!"];
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"missing iCalendar content"];
  }
  
  if ([s hasPrefix:@"BEGIN:VCALENDAR"]) {
    NSException *e;
    
    if ((e = [self publishICalendarString:s]) == nil)
      return [self publishOkResponse];
    
    return e;
  }
  
  [self debugWithFormat:@"ERROR: cannot process input: %@", s];
  
  /* Fake successful publish ... */
  return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
		      reason:@"invalid input format"];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SOGoICalFilePublish */
