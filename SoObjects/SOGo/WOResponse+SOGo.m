/* WOResponse+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2014 Inverse inc.
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

- (void) prepareDAVResponse
{
  [self setStatus: 207];
  [self setContentEncoding: NSUTF8StringEncoding];
  [self setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
  [self setHeader: @"no-cache" forKey: @"pragma"];
  [self setHeader: @"no-cache" forKey: @"cache-control"];
  [self appendContentString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n"];
}

- (void) appendDAVError: (NSDictionary *) errorCondition
{
  NSDictionary *error;  

  error = davElementWithContent (@"error", XMLNS_WEBDAV, errorCondition);

  [self setStatus: 403];
  [self appendContentString: [error asWebDavStringWithNamespaces: nil]];
}

@end
