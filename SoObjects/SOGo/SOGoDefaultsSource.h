/* SOGoDefaultsSource.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2015 Inverse inc.
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

/* A proxy to a NSUserDefauts intance (or compatible) and to a parent
   source. */

#ifndef SOGODEFAULTSSOURCE_H
#define SOGODEFAULTSSOURCE_H

#import <Foundation/NSObject.h>

@class NSArray;
@class NSData;
@class NSDictionary;
@class NSString;

extern NSString *SOGoDefaultsSourceInvalidSource;
extern NSString *SOGoDefaultsSourceUnmutableSource;

@interface SOGoDefaultsSource : NSObject
{
  id source;
  SOGoDefaultsSource *parentSource;
  BOOL isMutable;
}

+ (id) defaultsSourceWithSource: (id) newSource
                andParentSource: (SOGoDefaultsSource *) newParentSource;

- (void) setSource: (id) newSource;
- (id) source;

- (void) setParentSource: (SOGoDefaultsSource *) newParentSource;

/* db management */
- (BOOL) migrate;
- (BOOL) migrateOldDefaultsWithDictionary: (NSDictionary *) migratedKeys;

- (BOOL) synchronize;

/* accessors */
- (void) setObject: (id) value forKey: (NSString *) key;
- (id) objectForKey: (NSString *) objectKey;
- (void) removeObjectForKey: (NSString *) key;

- (void) setBool: (BOOL) value forKey: (NSString *) key;
- (BOOL) boolForKey: (NSString *) key;
- (BOOL) boolForKey: (NSString *) key andDict: (NSDictionary*) _dict;

- (void) setFloat: (float) value forKey: (NSString *) key;
- (float) floatForKey: (NSString *) key;

- (NSArray *) arrayForKey: (NSString *) key;
- (NSArray *) stringArrayForKey: (NSString *) key;

- (void) setInteger: (int) value forKey: (NSString *) key;
- (int) integerForKey: (NSString *) key;

- (NSDictionary *) dictionaryForKey: (NSString *) key;
- (NSData *) dataForKey: (NSString *) key;
- (NSString *) stringForKey: (NSString *) key;

@end

#endif /* SOGODEFAULTSSOURCE_H */
