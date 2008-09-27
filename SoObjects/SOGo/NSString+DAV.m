/* NSString+DAV.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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

#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSString+misc.h>

#import "NSString+DAV.h"

@implementation NSString (SOGoWebDAVExtensions)

- (NSString *)
 asWebDavStringWithNamespaces: (NSMutableDictionary *) namespaces
{
  return [self stringByEscapingXMLString];
}

#warning we should use the same nomenclature as the webdav values...
- (NSDictionary *) asWebDAVTuple
{
  NSString *namespace, *nodeName;
  NSRange nsEnd;

  nsEnd = [self rangeOfString: @"}"];
  namespace = [self substringFromRange: NSMakeRange (1, nsEnd.location - 1)];
  nodeName = [self substringFromIndex: nsEnd.location + 1];

  return [NSDictionary dictionaryWithObjectsAndKeys: namespace, @"ns",
		       nodeName, @"method", nil];
}


@end
