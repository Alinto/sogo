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
// $Id: UIxContactView.m 932 2005-08-01 13:17:55Z helge $


#include <SOGoUI/UIxComponent.h>

@interface UIxContactView : UIxComponent
{
}

- (BOOL)isDeletableClientObject;

@end

#include <Contacts/SOGoContactObject.h>
#include "common.h"

@implementation UIxContactView

/* accessors */

- (NSString *)tabSelection {
  NSString *selection;
    
  selection = [self queryParameterForKey:@"tab"];
  if (selection == nil)
    selection = @"attributes";
  return selection;
}

/* hrefs */

- (NSString *)completeHrefForMethod:(NSString *)_method
  withParameter:(NSString *)_param
  forKey:(NSString *)_key
{
  NSString *href;

  [self setQueryParameter:_param forKey:_key];
  href = [self completeHrefForMethod:[self ownMethodName]];
  [self setQueryParameter:nil forKey:_key];
  return href;
}

- (NSString *)attributesTabLink {
  return [self completeHrefForMethod:[self ownMethodName]
	       withParameter:@"attributes"
	       forKey:@"tab"];
}
- (NSString *)debugTabLink {
  return [self completeHrefForMethod:[self ownMethodName]
	       withParameter:@"debug"
	       forKey:@"tab"];
}

/* action */

- (id<WOActionResults>)defaultAction {
  if ([[self clientObject] vCard] == nil) {
    return [NSException exceptionWithHTTPStatus:404 /* Not Found */
			reason:@"could not locate contact"];
  }
  return self;
}

- (BOOL) isDeletableClientObject
{
  return [[self clientObject] respondsToSelector: @selector(delete)];
}

- (id) deleteAction
{
  NSException *ex;
  id url;

  if (![self isDeletableClientObject]) {
    /* return 400 == Bad Request */
    return [NSException exceptionWithHTTPStatus:400
                        reason:@"method cannot be invoked on "
                               @"the specified object"];
  }

  if ((ex = [[self clientObject] delete]) != nil) {
    // TODO: improve error handling
    [self debugWithFormat:@"failed to delete: %@", ex];
    return ex;
  }

  url = [[[self clientObject] container] baseURLInContext:[self context]];
  return [self redirectToLocation:url];
}

@end /* UIxContactView */
