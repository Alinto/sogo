/* NGImap4Connection+Monkeypatching.h - this file is part of SOGo
 *
 * Copyright (C) 2014 Jesús García Sáez
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#ifndef __OpenChange_NGImap4Connection_Monkeypatching_H__
#define __OpenChange_NGImap4Connection_Monkeypatching_H__

#import <Foundation/NSArray.h>
#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGExtensions/NGHashMap.h>


@interface NGImap4Connection (Monkeypatching)

- (NSArray *) fetchUIDs: (NSArray *) _uids
                  inURL: (NSURL *) _url
                  parts: (NSArray *) _parts;

- (void) _mergeDict: (NSDictionary *) source
               into: (NSMutableDictionary *) target;

- (void) _mergeNGHashMap: (NGMutableHashMap *) source
                    into: (NGMutableHashMap *) target;

@end


#endif // __OpenChange_NGImap4Connection_Monkeypatching_H__
