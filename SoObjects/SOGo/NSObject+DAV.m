/* NSObject+DAV.m - this file is part of SOGo
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

#import <Foundation/NSBundle.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/SoSelectorInvocation.h>
#import <NGObjWeb/SoObject+SoDAV.h>

#import <SaxObjC/XMLNamespaces.h>

#import <NGExtensions/NSObject+Logs.h>

#import "NSArray+DAV.h"
#import "NSString+DAV.h"
#import "SOGoWebDAVValue.h"

#import "SOGoObject.h"

#import "NSObject+DAV.h"

static NSMutableDictionary *setterMap = nil;
static NSMutableDictionary *getterMap = nil;
static NSDictionary *reportMap = nil;

SEL SOGoSelectorForPropertyGetter (NSString *property)
{
  SEL propSel;
  NSValue *propPtr;
  NSDictionary *map;
  NSString *methodName;

  if (!getterMap)
    getterMap = [NSMutableDictionary new];
  propPtr = [getterMap objectForKey: property];
  if (propPtr)
    propSel = [propPtr pointerValue];
  else
    {
      map = [SOGoObject defaultWebDAVAttributeMap];
      methodName = [map objectForKey: property];
      if (methodName)
	{
	  propSel = NSSelectorFromString (methodName);
	  if (propSel)
	    [getterMap setObject: [NSValue valueWithPointer: propSel]
		       forKey: property];
	}
      else
        propSel = NULL;
    }

  return propSel;
}

SEL SOGoSelectorForPropertySetter (NSString *property)
{
  SEL propSel;
  NSValue *propPtr;
  NSDictionary *map;
  NSString *methodName;

  if (!setterMap)
    setterMap = [NSMutableDictionary new];
  propPtr = [setterMap objectForKey: property];
  if (propPtr)
    propSel = [propPtr pointerValue];
  else
    {
      map = [SOGoObject defaultWebDAVAttributeMap];
      methodName = [map objectForKey: property];
      if (methodName)
	{
	  propSel = NSSelectorFromString ([methodName davSetterName]);
	  if (propSel)
	    [setterMap setObject: [NSValue valueWithPointer: propSel]
		       forKey: property];
	}
      else
        propSel = NULL;
    }

  return propSel;
}

@implementation NSObject (SOGoWebDAVExtensions)

- (void) loadReportMAP
{
  NSBundle *bundle;
  NSString *filename;

  bundle = [NSBundle bundleForClass: [SOGoObject class]];
  filename = [bundle pathForResource: @"DAVReportMap" ofType: @"plist"];
  if (filename
      && [[NSFileManager defaultManager] fileExistsAtPath: filename])
    reportMap = [[NSDictionary alloc] initWithContentsOfFile: filename];
  else
    [self logWithFormat: @"DAV REPORT map not found!"];
}

- (NSString *)
 asWebDavStringWithNamespaces: (NSMutableDictionary *) namespaces
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (SOGoWebDAVValue *) asWebDAVValue
{
  return [SOGoWebDAVValue
	   valueForObject: [self asWebDavStringWithNamespaces: nil]
	   attributes: nil];
}

- (SEL) davPropertySelectorForKey: (NSString *) key
{
  static NSMutableDictionary *attrSelectorMap = nil;
  NSDictionary *attrMap;
  NSString *methodName;
  NSValue *methodValue;
  SEL propertySel;

  methodValue = [attrSelectorMap objectForKey: key];
  if (!methodValue)
    {
      if (!attrSelectorMap)
        attrSelectorMap = [NSMutableDictionary new];
      attrMap = [[self class] defaultWebDAVAttributeMap];
      methodName = [attrMap objectForKey: key];
      if (methodName)
        propertySel = NSSelectorFromString (methodName);
      else
        propertySel = NULL;
      methodValue = [NSValue valueWithPointer: propertySel];
      [attrSelectorMap setObject: methodValue forKey: key];
    }

  return [methodValue pointerValue];
}

- (NSString *) davReportSelectorForKey: (NSString *) key
{
  NSString *methodName, *objcMethod, *resultName;
  SEL reportSel;

  resultName = nil;

  if (!reportMap)
    [self loadReportMAP];

  methodName = [reportMap objectForKey: key];
  if (methodName)
    {
      objcMethod = [NSString stringWithFormat: @"%@:", methodName];
      reportSel = NSSelectorFromString (objcMethod);
      if ([self respondsToSelector: reportSel])
	resultName = objcMethod;
    }

  return resultName;
}

- (SoSelectorInvocation *) davReportInvocationForKey: (NSString *) key
{
  NSString *objCMethod;
  SoSelectorInvocation *invocation;

  objCMethod = [self davReportSelectorForKey: key];
  if (objCMethod)
    {
      invocation = [[SoSelectorInvocation alloc]
		      initWithSelectorNamed: objCMethod
                        addContextParameter: YES];
      [invocation autorelease];
    }
  else
    invocation = nil;

  return invocation;
}

- (SOGoWebDAVValue *) davSupportedReportSet
{
  NSDictionary *currentValue;
  NSEnumerator *reportKeys;
  NSMutableArray *reportSet;
  NSString *currentKey;

  reportSet = [NSMutableArray array];

  if (!reportMap)
    [self loadReportMAP];

  reportKeys = [[reportMap allKeys] objectEnumerator];
  while ((currentKey = [reportKeys nextObject]))
    if ([self davReportSelectorForKey: currentKey])
      {
	currentValue = davElementWithContent(@"report",
                                             @"DAV:",
                                             [currentKey asDavInvocation]);
	[reportSet addObject: davElementWithContent(@"supported-report",
						    @"DAV:", currentValue)];
      }

  return [davElementWithContent (@"supported-report-set", @"DAV:", reportSet)
				asWebDAVValue];
}

- (NSDictionary *) responseForURL: (NSString *) url
                withProperties200: (NSArray *) properties200
                 andProperties404: (NSArray *) properties404
{
  static NSString *statusStrings[] = { @"HTTP/1.1 200 OK",
                                       @"HTTP/1.1 201 Created",
                                       @"HTTP/1.1 404 Not Found" };
  NSString *status;
  NSDictionary *responseElement;
  NSMutableArray *elements;

  elements = [NSMutableArray arrayWithCapacity: 3];

  [elements addObject: davElementWithContent (@"href", XMLNS_WEBDAV,
                                              url)];
  if ([properties200 count])
    {
      status = statusStrings[HTTPStatus200];
      [elements addObject: [properties200 asDAVPropstatWithStatus: status]];
    }
  if ([properties404 count])
    {
      status = statusStrings[HTTPStatus404];
      [elements addObject: [properties404 asDAVPropstatWithStatus: status]];
    }

  responseElement = davElementWithContent (@"response", XMLNS_WEBDAV,
                                           elements);

  return responseElement;
}

@end
