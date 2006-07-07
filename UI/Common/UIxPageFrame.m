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

#import <SOGoUI/UIxComponent.h>
#import <SOGo/SOGoUser.h>

@interface WOComponent (PopupExtension)

- (BOOL) isPopup;

@end

@interface UIxPageFrame : UIxComponent
{
  NSString *title;
  id       item;
}

@end

#include "common.h"
#include <NGObjWeb/SoComponent.h>

@implementation UIxPageFrame

- (void)dealloc {
  [self->item  release];
  [self->title release];
  [super dealloc];
}

/* accessors */

- (void)setTitle:(NSString *)_value {
  ASSIGNCOPY(self->title, _value);
}
- (NSString *)title {
  if ([self isUIxDebugEnabled])
    return self->title;

  return [self labelForKey:@"OpenGroupware.org"];
}

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (NSString *)ownerInContext {
  return [[self clientObject] ownerInContext:[self context]];
}

/* Help URL/target */

- (NSString *)helpURL {
  return [NSString stringWithFormat:@"help/%@.html", self->title];
}
- (NSString *)helpWindowTarget {
  return [NSString stringWithFormat:@"Help_%@", self->title];
}


/* notifications */

- (void)sleep {
  [self->item release]; self->item = nil;
  [super sleep];
}

/* URL generation */
// TODO: I think all this should be done by the clientObject?!

- (NSString *)relativeHomePath {
  return [self relativePathToUserFolderSubPath:@""];
}

- (NSString *)relativeCalendarPath {
  return [self relativePathToUserFolderSubPath:@"Calendar/"];
}

- (NSString *)relativeContactsPath {
  return [self relativePathToUserFolderSubPath:@"Contacts/"];
}

- (NSString *)relativeMailPath {
  return [self relativePathToUserFolderSubPath:@"Mail/"];
}

/* page based JavaScript */

- (WOResourceManager *)pageResourceManager {
  WOResourceManager *rm;
  
  if ((rm = [[[self context] page] resourceManager]) == nil)
    rm = [[WOApplication application] resourceManager];
  return rm;
}

- (BOOL) isPopup
{
  WOComponent *page;

  page = [[self context] page];

  return ([page respondsToSelector: @selector(isPopup)]
	  && [page isPopup]);
}

- (NSString *) pageJavaScriptURL
{
  static NSMutableDictionary *pageToURL = nil;
  WOResourceManager *rm;
  WOComponent *page;
  NSString    *jsname, *pageName;
  NSString    *url;
  
  page     = [[self context] page];
  pageName = NSStringFromClass([page class]);
  // TODO: does not seem to work! (gets reset): pageName = [page name];
  
  if ((url = [pageToURL objectForKey:pageName]) != nil)
    return [url isNotNull] ? url : nil;

  if (pageToURL == nil)
    pageToURL = [[NSMutableDictionary alloc] initWithCapacity:32];
  
  rm     = [self pageResourceManager];
  jsname = [pageName stringByAppendingString:@".js"];

  url = [rm urlForResourceNamed: jsname
	    inFramework: [[NSBundle bundleForClass: [page class]] bundlePath]
	    languages:nil
	    request:[[self context] request]];

  /* cache */
  [pageToURL setObject:(url ? url : (id)[NSNull null]) forKey:pageName];

  return url;
}

- (NSString *) productJavaScriptURL
{
  static NSMutableDictionary *pageToURL = nil;
  WOResourceManager *rm;
  WOComponent *page;
  NSString    *jsname, *pageName;
  NSString    *url;
  
  page     = [[self context] page];
  pageName = NSStringFromClass([page class]);
  // TODO: does not seem to work! (gets reset): pageName = [page name];
  
  if ((url = [pageToURL objectForKey:pageName]) != nil)
    return [url isNotNull] ? url : nil;

  if (pageToURL == nil)
    pageToURL = [[NSMutableDictionary alloc] initWithCapacity:32];
  
  rm     = [self pageResourceManager];
  jsname = [[page frameworkName] stringByAppendingString:@".js"];

  url = [rm urlForResourceNamed: jsname
	    inFramework: [[NSBundle bundleForClass: [page class]] bundlePath]
	    languages:nil
	    request:[[self context] request]];

  /* cache */
  [pageToURL setObject:(url ? url : (id)[NSNull null]) forKey:pageName];

  return url;
}

- (BOOL) hasPageSpecificJavaScript
{
  return ([[self pageJavaScriptURL] length] > 0);
}

- (BOOL) hasProductSpecificJavaScript
{
  return ([[self productJavaScriptURL] length] > 0);
}

@end /* UIxPageFrame */
