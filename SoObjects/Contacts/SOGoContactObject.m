/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#import <NGiCal/NGVCard.h>

#import "common.h"
#import "SOGoContactObject.h"
#import "NSDictionary+Contact.h"

@implementation SOGoContactObject

- (void)dealloc {
  [self->record release];
  [super dealloc];
}

/* content */

- (id)record {
  if (self->record == nil) {
    NSString *s;
    
    s = [self contentAsString];
    
    if ([s hasPrefix:@"BEGIN:VCARD"]) {
      NSArray *v;
      
      v = [NGVCard parseVCardsFromSource:s];
      if ([v count] == 0) {
	[self errorWithFormat:@"Could not parse vCards from content!"];
	return nil;
      }
      
      self->record = [[v objectAtIndex:0] retain];
    }
    else
      self->record = [[s propertyList] copy];
    
    if (self->record == nil)
      self->record = [[NSNull null] retain];
  }
  return [self->record isNotNull] ? self->record : nil;
}

- (BOOL)isVCardRecord {
  return [[self record] isKindOfClass:[NGVCard class]];
}

- (NGVCard *)vCard {
  return [[self record] isKindOfClass:[NGVCard class]]
    ? [self record]
    : nil;
}

/* key value coding */

- (id)valueForKey:(NSString *)_key {
  id value;
  
  if ((value = [[self record] valueForKey:_key]) != nil)
    return value;

  return [super valueForKey:_key];
}

/* DAV */

- (NSString *)davDisplayName {
  NSString *n;
  
  if ((n = [self valueForKey:@"cn"]))
    return n;
  
  return [self nameInContainer];
}

/* specialized actions */

- (NSException *) saveRecord: (id) _record
{
  if ([_record isKindOfClass:[NGVCard class]]) {
    // TODO: implement a vCard generator
    return [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
			reason:@"Saving vCards is not supported yet."];
  }

//   return [self saveContentString: [_record description]];
  return
    [self saveContentString: [_record vcardContentFromSOGoContactRecord]];
}

- (NSException *)patchField:(NSString *)_fname value:(NSString *)_value
  inContext:(id)_ctx
{
  NSMutableDictionary *md;

  if ([self isVCardRecord]) {
    return [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
			reason:@"Changing vCards is not supported yet."];
  }
  
  if ([_fname length] == 0) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"missing form field name"];
  }
  
  if ((md = [[[self record] mutableCopy] autorelease]) == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"did not find contact record"];
  }
  
  [md setObject:[_value isNotNull] ? _value : @"" forKey:_fname];
  
  return [self saveRecord:md];
}

- (id)patchOneFieldAction:(id)_ctx {
  /* 
     expects: fieldname\nfieldvalue
     
     TODO: should be extended to properly parse XML.
  */
  NSArray *fields;
  NSException *error;
  
  fields = [[[(WOContext *)_ctx request] contentAsString] 
	     componentsSeparatedByString:@"\n"];

  if ([fields count] < 2) {
    return [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			reason:@"missing form fields"];
  }
  
  error = [self patchField:[fields objectAtIndex:0] 
		value:[fields objectAtIndex:1]
		inContext:_ctx];
  if (error != nil)
    return error;
  
  return [(WOContext *)_ctx response];
}

/* message type */

- (NSString *)outlookMessageClass {
  return @"IPM.Contact";
}

@end /* SOGoContactObject */
