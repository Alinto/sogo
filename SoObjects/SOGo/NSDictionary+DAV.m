/* NSDictionary+DAV.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import "NSDictionary+DAV.h"

@implementation NSDictionary (SOGoWebDAVExtensions)

- (NSString *) _namespaceDecl: (NSDictionary *) namespaces
{
  NSMutableString *decl;
  NSEnumerator *keys;
  NSString *key;

  decl = [NSMutableString string];
  keys = [[namespaces allKeys] objectEnumerator];
  while ((key = [keys nextObject]))
    [decl appendFormat: @" xmlns:%@=\"%@\"",
	  [namespaces objectForKey: key], key];

  return decl;
}

- (NSString *) _newTagInNamespaces: (NSMutableDictionary *) namespaces
			     forNS: (NSString *) newNS
{
  NSString *newTag;

  newTag = [NSString stringWithFormat: @"n%d", [namespaces count]];
  [namespaces setObject: newTag forKey: newNS];

  return newTag;
}

#warning this method could probably be optimized to speedup the rendering\
  of thousands of records
- (NSString *)
 asWebDavStringWithNamespaces: (NSMutableDictionary *) namespaces
{
  NSDictionary *attributes;
  NSMutableString *webdavString;
  NSString *nsTag, *ns, *subString, *element;
  BOOL firstLevel;

  if (!namespaces)
    {
      firstLevel = YES;
      namespaces = [NSMutableDictionary new];
      [namespaces setObject: @"D" forKey: @"DAV:"];
    }
  else
    firstLevel = NO;

  webdavString = [NSMutableString string];
  ns = [self objectForKey: @"ns"];
  nsTag = [namespaces objectForKey: ns];
  if (!nsTag)
    nsTag = [self _newTagInNamespaces: namespaces forNS: ns];

  element = [NSString stringWithFormat: @"%@:%@",
		      nsTag, [self objectForKey: @"method"]];
  [webdavString appendFormat: @"<%@", element];
  subString = [[self objectForKey: @"content"]
		asWebDavStringWithNamespaces: namespaces];
  if (firstLevel)
    {
      [webdavString appendString: [self _namespaceDecl: namespaces]];
      [namespaces release];
    }

  attributes = [self objectForKey: @"attributes"];

  if (attributes)
    {
      NSArray *keys;
      int i;

      keys = [attributes allKeys];

      for (i = 0; i < [keys count]; i++)
        {
          [webdavString appendFormat: @" %@=\"%@\"", [keys objectAtIndex: i], [attributes objectForKey: [keys objectAtIndex: i]]];
        }
    }

  if (subString)
    [webdavString appendFormat: @">%@</%@>", subString, element];
  else
    [webdavString appendString: @"/>"];

  return webdavString;
}

@end
