/* UIxContactFolderProperties.m - this file is part of SOGo
 *
 * Copyright (C) 2014 Inverse inc.
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

#import <SOGo/SOGoSystemDefaults.h>

#import "UIxContactFolderProperties.h"

@implementation UIxContactFolderProperties

- (id) init
{
  if ((self = [super init]))
    {
      addressBook = [self clientObject];
      baseCardDAVURL = nil;
      basePublicCardDAVURL = nil;
    }

  return self;
}

- (void) dealloc
{
  [baseCardDAVURL release];
  [basePublicCardDAVURL release];
  [super dealloc];
}

- (NSString *) addressBookName
{
  return [addressBook displayName];
}

- (NSString *) _baseCardDAVURL
{
  NSString *davURL;

  if (!baseCardDAVURL)
    {
      davURL = [[addressBook realDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        baseCardDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        baseCardDAVURL = davURL;
      [baseCardDAVURL retain];
    }

  return baseCardDAVURL;
}

- (NSString *) cardDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _baseCardDAVURL]];
}

- (NSString *) _basePublicCardDAVURL
{
  NSString *davURL;
  
  if (!basePublicCardDAVURL)
    {
      davURL = [[addressBook publicDavURL] absoluteString];
      if ([davURL hasSuffix: @"/"])
        basePublicCardDAVURL = [davURL substringToIndex: [davURL length] - 1];
      else
        basePublicCardDAVURL = davURL;
      [basePublicCardDAVURL retain];
    }
  
  return basePublicCardDAVURL;
}

- (NSString *) publicCardDavURL
{
  return [NSString stringWithFormat: @"%@/", [self _basePublicCardDAVURL]];
}

- (BOOL) isPublicAccessEnabled
{
  // NOTE: This method is the same found in Common/UIxAclEditor.m
  return [[SOGoSystemDefaults sharedSystemDefaults]
           enablePublicAccess];
}

@end
