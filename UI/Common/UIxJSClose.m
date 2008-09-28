/* UIxJSClose.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSString.h>

#import "UIxJSClose.h"

@implementation UIxJSClose

- (id) init
{
  if ((self = [super init]))
    refreshMethod = nil;

  return self;
}

- (void) dealloc
{
  if (refreshMethod)
    [refreshMethod release];
  [super dealloc];
}

- (NSString *) doctype
{
  return (@"<?xml version=\"1.0\"?>\n"
          @"<!DOCTYPE html"
          @" PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\""
          @" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">");
}

- (void) setRefreshMethod: (NSString *) method
{
  if (refreshMethod)
    [refreshMethod release];
  refreshMethod = method;
  if (refreshMethod)
    [refreshMethod retain];
}

- (NSString *) refreshMethod
{
  return refreshMethod;
}

- (BOOL) hasRefreshMethod
{
  return (refreshMethod != nil);
}

@end
