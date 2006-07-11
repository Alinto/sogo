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
#include "../Common/UIxPageFrame.h"

@interface UIxMailMainFrame : UIxPageFrame
{
  NSString *rootURL;
  NSString *userRootURL;
  struct {
    int hideFolderTree:1;
    int hideFrame:1; /* completely disables all the frame around the comp. */
    int reserved:30;
  } mmfFlags;
}

- (NSString *)rootURL;
- (NSString *)userRootURL;
- (NSString *)calendarRootURL;

@end

@interface UIxMailPanelFrame : UIxMailMainFrame
@end

#include "common.h"
#include <NGObjWeb/SoComponent.h>

@implementation UIxMailMainFrame

static NSString *treeRootClassName = nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  treeRootClassName = [[ud stringForKey:@"SOGoMailTreeRootClass"] copy];
  if (treeRootClassName)
    NSLog(@"Note: use class '%@' as root for mail tree.", treeRootClassName);
  else
    treeRootClassName = @"SOGoMailAccounts";
}

- (void)dealloc {
  [self->rootURL     release];
  [self->userRootURL release];
  [super dealloc];
}

/* accessors */

- (NSString *)treeRootClassName {
  return treeRootClassName;
}

- (void)setHideFolderTree:(BOOL)_flag {
   self->mmfFlags.hideFolderTree = _flag ? 1 : 0;
}
- (BOOL)hideFolderTree {
  return self->mmfFlags.hideFolderTree ? YES : NO;
}

- (void)setHideFrame:(BOOL)_flag {
   self->mmfFlags.hideFrame = _flag ? 1 : 0;
}
- (BOOL)hideFrame {
  return self->mmfFlags.hideFrame ? YES : NO;
}

- (NSString *)pageFormURL {
  NSString *u;
  NSRange  r;
  
  u = [[[self context] request] uri];
  if ((r = [u rangeOfString:@"?"]).length > 0) {
    /* has query parameters */
    // TODO: this is ugly, create reusable link facility in SOPE
    // TODO: remove 'search' and 'filterpopup', preserve sorting
    NSMutableString *ms;
    NSArray  *qp;
    unsigned i, count;
    
    qp    = [[u substringFromIndex:(r.location + r.length)] 
	        componentsSeparatedByString:@"&"];
    count = [qp count];
    ms    = [NSMutableString stringWithCapacity:count * 12];
    
    for (i = 0; i < count; i++) {
      NSString *s;
      
      s = [qp objectAtIndex:i];
      
      /* filter out */
      if ([s hasPrefix:@"search="]) continue;
      if ([s hasPrefix:@"filterpopup="]) continue;
      
      if ([ms length] > 0) [ms appendString:@"&"];
      [ms appendString:s];
    }
    
    if ([ms length] == 0) {
      /* no other query params */
      u = [u substringToIndex:r.location];
    }
    else {
      u = [u substringToIndex:r.location + r.length];
      u = [u stringByAppendingString:ms];
    }
    return u;
  }
  return [u hasSuffix:@"/"] ? @"view" : @"#";
}

- (BOOL)showLinkBanner {
  return YES;
}

- (NSString *)bannerToolbarStyle {
  return nil;
}

- (NSString *)bannerConsumeStyle {
  return nil;
}

/* URL generation */
// TODO: I think all this should be done by the clientObject?!
// TODO: is the stuff below necessary at all in the mailer frame?

- (NSString *)rootURL {
  WOContext *ctx;
  NSArray   *traversalObjects;

  if (self->rootURL != nil)
    return self->rootURL;

  ctx = [self context];
  traversalObjects = [ctx objectTraversalStack];
  self->rootURL = [[[traversalObjects objectAtIndex:0]
                                      rootURLInContext:ctx]
                                      copy];
  return self->rootURL;
}

- (NSString *)userRootURL {
  WOContext *ctx;
  NSArray   *traversalObjects;

  if (self->userRootURL)
    return self->userRootURL;

  ctx = [self context];
  traversalObjects = [ctx objectTraversalStack];
  self->userRootURL = [[[[traversalObjects objectAtIndex:1]
                                           baseURLInContext:ctx]
                                           stringByAppendingString:@"/"]
                                           retain];
  return self->userRootURL;
}

- (NSString *)calendarRootURL {
  return [[self userRootURL] stringByAppendingString:@"Calendar/"];
}
- (NSString *)contactsRootURL {
  return [[self userRootURL] stringByAppendingString:@"Contacts/"];
}

/* error handling */

- (BOOL)hasErrorText {
  return [[[[self context] request] formValueForKey:@"error"] length] > 0
    ? YES : NO;
}
- (NSString *)errorText {
  return [[[self context] request] formValueForKey:@"error"];
}

- (NSString *)errorAlertJavaScript {
  NSString *errorText;
  
  if ([(errorText = [self errorText]) length] == 0)
    return nil;
  
  // TODO: proper JavaScript escaping
  errorText = [errorText stringByEscapingHTMLString];
  errorText = [errorText stringByReplacingString:@"\"" withString:@"'"];
  
  return [NSString stringWithFormat:
		     @"<script language=\"JavaScript\">"
		     @"alert(\"%@\");"
		     @"</script>", errorText];
}

@end /* UIxMailMainFrame */

@implementation UIxMailPanelFrame

- (BOOL)hideFolderTree {
  return YES;
}
- (BOOL)showLinkBanner {
  return NO;
}

@end /* UIxMailPanelFrame */
