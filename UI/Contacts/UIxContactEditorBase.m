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

#include <Contacts/SOGoContactObject.h>
#include <Contacts/SOGoContactFolder.h>
#include "common.h"

#include "UIxContactEditorBase.h"

@implementation UIxContactEditorBase

- (id)init {
  if ((self = [super init])) {
    self->snapshot = [[NSMutableDictionary alloc] initWithCapacity:16];
  }
  return self;
}

- (void)dealloc {
  [self->snapshot      release];
  [self->anaisCN      release];
  [self->errorText     release];
  [super dealloc];
}

/* accessors */

- (NSMutableDictionary *) snapshot
{
  NSString *email;

  email = [self queryParameterForKey:@"contactEmail"];

  if ([email length] > 0
      && ![[self->snapshot objectForKey: @"mail"] length])
    [self->snapshot setObject: email forKey: @"mail"];

  return self->snapshot;
}

- (void)setErrorText:(NSString *)_txt {
  ASSIGNCOPY(self->errorText, _txt);
}
- (NSString *)errorText {
  return self->errorText;
}

- (BOOL)hasErrorText {
  return [self->errorText length] > 0 ? YES : NO;
}


- (void)setAnaisCN:(NSString *)_txt {
  ASSIGNCOPY(self->anaisCN, _txt);
}
- (NSString *)anaisCN {
  return self->anaisCN;
}


/* load/store content format */

- (void)_fixupSnapshot {
  // TODO: perform sanity checking, eg build CN on demand
  NSString *cn, *gn, *sn;
  
  cn = [self->snapshot objectForKey:@"cn"];
  gn = [self->snapshot objectForKey:@"givenName"];
  sn = [self->snapshot objectForKey:@"sn"];
  
  if (![sn isNotNull] || [sn length] == 0)
    sn = nil;
  if (![cn isNotNull] || [cn length] == 0)
    cn = nil;
  
  if (sn == nil) {
    if (cn == nil)
      sn = @"[noname]";
    else {
      // TODO: need a better name parser here
      NSRange r;
      
      r = [cn rangeOfString:@" "];
      sn = (r.length > 0)
	? [cn substringFromIndex:(r.location + r.length)]
	: cn;
    }
    [self->snapshot setObject:sn forKey:@"sn"];
  }
  if ([self->anaisCN length] > 0 )
    cn = self->anaisCN;
  else if (sn == nil && gn == nil)
    cn = @"[noname]";
  else if (sn == nil)
    cn = gn;
  else if (gn == nil)
    cn = sn;
  else
    cn = [[gn stringByAppendingString:@" "] stringByAppendingString:sn];
  [self->snapshot setObject:cn forKey:@"cn"];
}

- (void)saveValuesIntoRecord:(NSMutableDictionary *)_record {
  [self _fixupSnapshot];
  [_record addEntriesFromDictionary:[self snapshot]];
}

/* helper */

- (NSString *)_completeURIForMethod:(NSString *)_method {
  // TODO: this is a DUP of UIxAppointmentEditor
  NSString *uri;
  NSRange r;
    
  uri = [[[self context] request] uri];
    
  /* first: identify query parameters */
  r = [uri rangeOfString:@"?" options:NSBackwardsSearch];
  if (r.length > 0)
    uri = [uri substringToIndex:r.location];
    
  /* next: append trailing slash */
  if (![uri hasSuffix:@"/"])
    uri = [uri stringByAppendingString:@"/"];
  
  /* next: append method */
  uri = [uri stringByAppendingString:_method];
    
  /* next: append query parameters */
  return [self completeHrefForMethod:uri];
}

/* actions */

- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c{
  return YES;
}

- (void) initSnapshot
{
  NGVCard *vCard;
  
  /* load iCalendar file */
  
  vCard = [[self clientObject] vCard];
  if (vCard)
//   if ([c length] == 0) /* a new contact */
//     c = [self contentStringTemplate];
    {
//       [self setContent: record];
//       [self loadValuesFromContentString: record];
    }
}

- (id <WOActionResults>) defaultAction
{
  // TODO: very similiar to apt-editor (apt editor would need to use std names
  [self initSnapshot];
 
  return self;
}

- (NSString *) viewActionName
{
  /* this is overridden in the mail based contacts UI to redirect to tb.edit */
  return @"";
}

- (NSString *) editActionName
{
  /* this is overridden in the mail based contacts UI to redirect to tb.edit */
  return @"edit";
}

- (id) saveAction
{
//   NSException *ex;
//   NSString *uri;
//   NSDictionary *record;
//   NSMutableDictionary *newRecord;
  
//   if ([[self clientObject] 
//         respondsToSelector: @selector (saveContentString:)])
//     {
//       if (contentString)
//         {
//           record = [contentString propertyList];
//           if (record)
//             {
//               newRecord = [[record mutableCopy] autorelease];
//               [self saveValuesIntoRecord: newRecord];
//               ex = [[self clientObject] saved];
//               if (ex)
//                 {
//                   [self setErrorText: [ex reason]];

//                   return self;
//                 }
//               else
//                 {
//                   uri = [self viewActionName];
//                   if ([uri length] <= 0)
//                     uri = @"..";

//                   return [self redirectToLocation: [self _completeURIForMethod: uri]];
//                 }
//             }
//           else
//             {
//               [self setErrorText: @"Invalid property list data ..."]; // localize
//               return self;
//             }
//         }
//       else
//         {
//           [self setErrorText: @"Missing object content!"]; // localize
//           return self;
//         }
//     }
//   else
    return [NSException exceptionWithHTTPStatus: 400 /* Bad Request */
                        reason: @"method cannot be invoked on "
                        @"the specified object"];
}

- (id) writeAction
{
  NSString *email, *url;

  [self initSnapshot];
  email = [snapshot objectForKey: @"mail"];
  url = ((email)
         ? [NSString stringWithFormat: @"Mail/compose?mailto=%@",
                   email]
         : @"Mail/compose");
  return
    [self redirectToLocation: [self relativePathToUserFolderSubPath: url]];
}

- (id)newAction {
  // TODO: this is almost a DUP of UIxAppointmentEditor
  /*
    This method creates a unique ID and redirects to the "edit" method on the
    new ID.
    It is actually a folder method and should be defined on the folder.
    
    Note: 'clientObject' is the SOGoAppointmentFolder!
          Update: remember that there are group folders as well.
  */
  NSString *uri, *objectId, *nextMethod;
  
  objectId = [[[self clientObject] class] globallyUniqueObjectId];
  if ([objectId length] == 0) {
    return [NSException exceptionWithHTTPStatus:500 /* Internal Error */
			reason:@"could not create a unique ID"];
  }
  
  nextMethod = [NSString stringWithFormat:@"../%@/%@", 
			   objectId, [self editActionName]];
  uri = [self _completeURIForMethod:nextMethod];
  return [self redirectToLocation:uri];
}

@end /* UIxContactEditorBase */
