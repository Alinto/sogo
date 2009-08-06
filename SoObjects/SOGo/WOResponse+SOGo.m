/* WOResponse+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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

#import <SaxObjC/XMLNamespaces.h>

#import "NSDictionary+DAV.h"
#import "NSObject+DAV.h"

#import "WOResponse+SOGo.h"

@implementation WOResponse (SOGoSOPEUtilities)

- (void) appendDAVError: (NSDictionary *) errorCondition
{
  NSDictionary *error;  

  error = davElementWithContent (@"error", XMLNS_WEBDAV, errorCondition);

  [self setStatus: 403];
  [self appendContentString: @"<?xml version=\"1.0\""
            @" encoding=\"utf-8\"?>\r\n"];
  [self appendContentString: [error asWebDavStringWithNamespaces: nil]];
}

@end
