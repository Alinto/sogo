/* SOGoGroup.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2012 Inverse inc.
 *
 * Author: Ludovic Marcotte <lmarcotte@inverse.ca>
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

#ifndef __SOGOGROUP_H__
#define __SOGOGROUP_H__

#import <Foundation/NSObject.h>

@class LDAPSource;
@class NSArray;
@class NSMutableArray;
@class NSString;
@class NGLdapEntry;

@protocol SOGoSource;

@interface SOGoGroup : NSObject
{
  @private 
    NSString *_identifier;
    NSString *_domain;
    NGLdapEntry *_entry;
    NSObject <SOGoSource> *_source;
    NSMutableArray *_members;
}

+ (id) groupWithIdentifier: (NSString *) theID
                  inDomain: (NSString *) domain;
+ (id) groupWithEmail: (NSString *) theEmail
             inDomain: (NSString *) domain;
+ (id) groupWithValue: (NSString *) theValue
    andSourceSelector: (SEL) theSelector
             inDomain: (NSString *) domain;

- (NSArray *) members;

- (BOOL) hasMemberWithUID: (NSString *) memberUID;

@end

#endif // __SOGOGROUP_H__
