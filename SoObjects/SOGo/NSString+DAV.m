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

#import "NSArray+Utilities.h"

#import "NSString+DAV.h"

@implementation NSString (SOGoWebDAVExtensions)

- (NSString *)
 asWebDavStringWithNamespaces: (NSMutableDictionary *) namespaces
{
  return [self stringByEscapingXMLString];
}

- (NSString *) asDAVPropertyDescription
{
  NSArray *components;

  components = [[self componentsSeparatedByString: @"-"]
                 resultsOfSelector: @selector (capitalizedString)];

  return [components componentsJoinedByString: @" "];
}

#warning we should use the same nomenclature as the webdav values...
- (NSMutableDictionary *) asWebDAVTuple
{
  NSString *namespace, *nodeName;
  NSRange nsEnd;

  nsEnd = [self rangeOfString: @"}"];
  namespace = [self substringFromRange: NSMakeRange (1, nsEnd.location - 1)];
  nodeName = [self substringFromIndex: nsEnd.location + 1];

  return [NSMutableDictionary
           dictionaryWithObjectsAndKeys: namespace, @"ns",
           nodeName, @"method", nil];
}


- (NSString *) davMethodToObjC
{
  NSMutableString *newName;
  NSArray *components;

  newName = [NSMutableString stringWithString: @"dav"];
  components = [[self componentsSeparatedByString: @"-"]
                 resultsOfSelector: @selector (capitalizedString)];
  [newName appendString: [components componentsJoinedByString: @""]];

  return newName;
}

- (NSString *) davSetterName
{
  unichar firstLetter;
  NSString *firstString, *property, *davPrefix;

  property = [[self asDavInvocation] objectForKey: @"method"];
  if (!property)
    property = self;
  firstLetter = [property characterAtIndex: 0];
  firstString = [[NSString stringWithCharacters: &firstLetter length: 1]
		  uppercaseString];
  if ([property length] > 3
      && [[property substringWithRange: NSMakeRange (0, 3)]
           caseInsensitiveCompare: @"dav"] == NSOrderedSame)
    davPrefix = @"";
  else
    davPrefix = @"Dav";

  return [NSString stringWithFormat: @"set%@%@%@:", davPrefix,
		   firstString, [property substringFromIndex: 1]];
}

- (NSDictionary *) asDavInvocation
{
  NSMutableDictionary *davInvocation;
  NSRange nsEnclosing, methodEnclosing;
  unsigned int length;

  davInvocation = nil;
  if ([self hasPrefix: @"{"])
    {
      nsEnclosing = [self rangeOfString: @"}"];
      length = [self length];
      if (nsEnclosing.length > 0 && nsEnclosing.location < (length - 1))
	{
	  methodEnclosing = NSMakeRange (nsEnclosing.location + 1,
                                         length - nsEnclosing.location - 1);
	  nsEnclosing.length = nsEnclosing.location - 1;
	  nsEnclosing.location = 1;
	  davInvocation = [NSMutableDictionary dictionaryWithCapacity: 2];
	  [davInvocation setObject: [self substringWithRange: nsEnclosing]
			 forKey: @"ns"];
	  [davInvocation setObject: [self substringWithRange: methodEnclosing]
			 forKey: @"method"];
	}
    }

  return davInvocation;
}

- (NSMutableDictionary *) asWebDAVTupleWithContent: (id) content
{
  NSMutableDictionary *tuple;

  tuple = [self asWebDAVTuple];
  [tuple setObject: content forKey: @"content"];

  return tuple;
}

- (NSString *) removeOutsideTags
{
  NSString *newString;
  NSRange range;

  newString = nil;

  /* we extract the text between >XXX</, but in a bad way */
  range = [self rangeOfString: @">"];
  if (range.location != NSNotFound)
    {
      newString = [self substringFromIndex: range.location + 1];
      range = [newString rangeOfString: @"<" options: NSBackwardsSearch];
      if (range.location != NSNotFound)
        newString = [newString substringToIndex: range.location];
      else
        newString = nil;
    }
  else
    newString = nil;

  return newString;
}

@end
