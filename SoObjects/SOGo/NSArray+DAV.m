/* NSArray+DAV.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2013 Inverse inc.
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

#import "NSObject+DAV.h"

#import "NSArray+DAV.h"

@implementation NSArray (SOGoWebDAVExtensions)

- (NSString *)
 asWebDavStringWithNamespaces: (NSMutableDictionary *) namespaces
{
  NSMutableString *webdavString;
  unsigned int count, max;
  NSObject *child;

  webdavString = [NSMutableString string];
  max = [self count];
  for (count = 0; count < max; count++)
    {
      child = [self objectAtIndex: count];
      [webdavString appendString:
                      [child asWebDavStringWithNamespaces: namespaces]];
    }

  return webdavString;
}

- (NSDictionary *) asDAVPropstatWithStatus: (NSString *) status
{
  NSMutableArray *propstat;

  propstat = [NSMutableArray arrayWithCapacity: 2];
  [propstat addObject: davElementWithContent (@"prop", XMLNS_WEBDAV,
                                              self)];
  [propstat addObject: davElementWithContent (@"status", XMLNS_WEBDAV,
                                              status)];

  return davElementWithContent (@"propstat", XMLNS_WEBDAV, propstat);
}

@end
