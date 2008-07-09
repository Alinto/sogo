/* WORequest+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <NGObjWeb/SoObjectRequestHandler.h>
#import <NGObjWeb/WOApplication.h>

#import <DOM/DOMProtocols.h>

#import "WORequest+SOGo.h"

@implementation WORequest (SOGoSOPEUtilities)

- (BOOL) handledByDefaultHandler
{
#warning this should be changed someday
  return (![requestHandlerKey isEqualToString: @"dav"]);
}

- (NSArray *) _propertiesOfElement: (id <DOMElement>) startElement
			  underTag: (NSString *) tag
{
  id <DOMNodeList> list;
  id <DOMElement> tagElement;
  NSObject <DOMNode> *currentNode;
  NSMutableArray *properties;
  unsigned int count, max;

  properties = nil;

  list = [startElement getElementsByTagName: tag];
  if ([list length])
    {
      tagElement = [list objectAtIndex: 0];
      list = [tagElement getElementsByTagName: @"prop"];
      if ([list length])
	{
	  tagElement = [list objectAtIndex: 0];
	  properties = [NSMutableArray array];
	  list = [tagElement childNodes];
	  max = [list length];
	  for (count = 0; count < max; count++)
	    {
	      currentNode = [list objectAtIndex: count];
	      if ([currentNode conformsToProtocol: @protocol (DOMElement)])
		[properties addObject: currentNode];
	    }
	}
    }

  return properties;
}

- (NSDictionary *) davPatchedPropertiesWithTopTag: (NSString *) topTag
{
  NSMutableDictionary *patchedProperties;
  NSArray *props;
  id <DOMDocument> element;
  id <DOMElement> startElement;
  NSObject <DOMNodeList> *list;

  patchedProperties = nil;
  if (!topTag)
    topTag = @"propertyupdate";
  element = [self contentAsDOMDocument];
  list = [element getElementsByTagName: topTag];
  if ([list length])
    {
      startElement = [list objectAtIndex: 0];
      patchedProperties = [NSMutableDictionary dictionary];
      props = [self _propertiesOfElement: startElement
		    underTag: @"set"];
      if (props)
	[patchedProperties setObject: props forKey: @"set"];
      props = [self _propertiesOfElement: startElement
		    underTag: @"remove"];
      if (props)
	[patchedProperties setObject: props forKey: @"remove"];
    }

  return patchedProperties;
}

@end
