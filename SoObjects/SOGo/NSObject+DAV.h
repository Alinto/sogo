/* NSObject+DAV.h - this file is part of SOGo
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

#ifndef NSOBJECT_DAV_H
#define NSOBJECT_DAV_H

#import <Foundation/NSDictionary.h>

@class NSMutableDictionary;
@class NSString;

@class SoSelectorInvocation;

@class SOGoWebDAVValue;

typedef enum _HTTPStatusCode {
  HTTPStatus200 = 0,
  HTTPStatus201,
  HTTPStatus404,
} HTTPStatusCode;

#define davElement(t,n) \
  [NSDictionary dictionaryWithObjectsAndKeys: t, @"method", n, @"ns", nil]

#define davElementWithContent(t,n,c) \
  [NSDictionary dictionaryWithObjectsAndKeys: t, @"method", \
		n, @"ns",				    \
		c, @"content", nil]

#define davElementWithAttributesAndContent(t,a,n,c)                      \
  [NSDictionary dictionaryWithObjectsAndKeys: t, @"method", \
		a, @"attributes",			    \
		n, @"ns",				    \
		c, @"content", nil]

SEL SOGoSelectorForPropertyGetter (NSString *property);
SEL SOGoSelectorForPropertySetter (NSString *property);

@interface NSObject (SOGoWebDAVExtensions)

- (NSString *)
 asWebDavStringWithNamespaces: (NSMutableDictionary *) namespaces;
- (SOGoWebDAVValue *) asWebDAVValue;

- (SOGoWebDAVValue *) davSupportedReportSet;

- (SEL) davPropertySelectorForKey: (NSString *) key;
- (NSString *) davReportSelectorForKey: (NSString *) key;
- (SoSelectorInvocation *) davReportInvocationForKey: (NSString *) key;

/* response helpers */
- (NSDictionary *) responseForURL: (NSString *) url
                withProperties200: (NSArray *) properties200
                 andProperties404: (NSArray *) properties404;

@end

#endif /* NSOBJECT_DAV_H */
