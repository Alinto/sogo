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

#include <SOGoUI/UIxComponent.h>

@interface UIxMailAccountView : UIxComponent
{
  id inbox;
}

@end

#include <NGObjWeb/SoObject+SoDAV.h>
#include <SoObjects/Mailer/SOGoMailFolder.h>
#include "common.h"

@interface NSString(DotCutting)

- (NSString *)titleForSOGoIMAP4String;

@end

@interface SOGoMailFolder(UsedPrivates)
- (BOOL)isCreateAllowedInACL;
@end

@implementation UIxMailAccountView

static BOOL useAltNamespace = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  useAltNamespace = [ud boolForKey:@"SOGoSpecialFoldersInRoot"];
}

- (void)dealloc {
  [self->inbox release];
  [super dealloc];
}

/* notifications */

- (void)sleep {
  [super sleep];
  [self->inbox release]; self->inbox = nil;
}

/* title */

- (NSString *)objectTitle {
  return [[[self clientObject] nameInContainer] titleForSOGoIMAP4String];
}

- (NSString *)panelTitle {
  NSString *s;
  
  s = [self labelForKey:@"Mail Account"];
  s = [s stringByAppendingString:@": "];
  s = [s stringByAppendingString:[self objectTitle]];
  return s;
}

- (BOOL)showFolderCreateButton {
  if (!useAltNamespace) {
    /* in a regular configuration everything must be created below INBOX */
    return NO;
  }
  
  /* 
     A hack to manually check whether we have permission to create folders at
     the root level. We do this by checking the permissions on the INBOX
     folder (which is technically the root in Cyrus).
     
     See OGo bug #1472 for details.
  */
  
  if (self->inbox == nil) {
    id tmp;
    
    tmp = [[self clientObject] lookupName:@"INBOX" 
			       inContext:[self context]
			       acquire:NO];
    if ([tmp isKindOfClass:[NSException class]] || tmp == nil)
      tmp = [NSNull null];
    
    self->inbox = [tmp retain];
  }
  
  if (![self->inbox isNotNull]) {
    [self warnWithFormat:@"Found no INBOX folder!"];
    return NO;
  }
  
  return [self->inbox isCreateAllowedInACL];
}

- (NSString *) mailFolderName
{
  return [NSString stringWithFormat: @"/%@",
                   [[self clientObject] nameInContainer]];
}

/* error redirects */

- (id)redirectToViewWithError:(id)_error {
  // TODO: DUP to UIxMailListView
  // TODO: improve, localize
  // TODO: there is a bug in the treeview which preserves the current URL for
  //       the active object (displaying the error again)
  id url;
  
  if (![_error isNotNull])
    return [self redirectToLocation:@"view"];
  
  if ([_error isKindOfClass:[NSException class]])
    _error = [_error reason];
  else if ([_error isKindOfClass:[NSString class]])
    _error = [_error stringValue];
  
  url = [_error stringByEscapingURL];
  url = [@"view?error=" stringByAppendingString:url];
  return [self redirectToLocation:url];
}

/* actions */

- (id)createFolderAction {
  NSException *error;
  NSString    *folderName;
  id client;
  
  folderName = [[[self context] request] formValueForKey:@"name"];
  if ([folderName length] == 0) {
    error = [NSException exceptionWithHTTPStatus:400 /* Bad Request */
			 reason:@"missing 'name' query parameter!"];
    return [self redirectToViewWithError:error];
  }
  
  if ((client = [self clientObject]) == nil) {
    error = [NSException exceptionWithHTTPStatus:404 /* Not Found */
			 reason:@"did not find mail folder"];
    return [self redirectToViewWithError:error];
  }
  
  if ((error = [[self clientObject] davCreateCollection:folderName
				    inContext:[self context]]) != nil) {
    return [self redirectToViewWithError:error];
  }
  
  return [self redirectToLocation:[folderName stringByAppendingString:@"/"]];
}

@end /* UIxMailAccountView */
