/* NSString+DAV.h - this file is part of SOGo
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

#ifndef NSSTRING_DAV_H
#define NSSTRING_DAV_H

#import <Foundation/NSString.h>

@class NSMutableDictionary;

@interface NSString (SOGoWebDAVExtensions)

- (NSString *)
 asWebDavStringWithNamespaces: (NSMutableDictionary *) namespaces;
- (NSMutableDictionary *) asWebDAVTuple;
- (NSMutableDictionary *) asWebDAVTupleWithContent: (id) content;


- (NSString *) davMethodToObjC;
- (NSString *) davSetterName;
- (NSDictionary *) asDavInvocation;

- (NSString *) removeOutsideTags;

@end

#endif /* NSSTRING_DAV_H */
