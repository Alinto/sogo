/* SOGoGroup.h - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
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
@class NSString;
@class NGLdapEntry;

@interface SOGoGroup : NSObject
{
  @private 
    NSString *_identifier;
    NGLdapEntry *_entry;
    LDAPSource *_source;
}

+ (id) groupWithIdentifier: (NSString *) theID;
+ (id) groupWithEmail: (NSString *) theEmail;
+ (id) groupWithValue: (NSString *) theValue
    andSourceSelector: (SEL) theSelector;

- (NSArray *) members;

@end

#endif // __SOGOGROUP_H__
