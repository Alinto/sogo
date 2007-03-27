/*
  Copyright (C) 2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef	__AgenorUserDefaults_H_
#define	__AgenorUserDefaults_H_

#import <Foundation/NSObject.h>

/*
  AgenorUserDefaults
  
  An object with the same API like NSUserDefaults which retrieves profile
  information for users in the database.
*/

@class NSString, NSURL, NSUserDefaults, NSArray, NSDictionary, NSData;
@class NSCalendarDate, NSMutableDictionary;

@interface AgenorUserDefaults :  NSObject
{
  NSUserDefaults *parent;
  NSURL    *url;
  NSString *uid;
  NSString *fieldName;
  
  NSArray *fieldNames;
  NSMutableDictionary *values;
  NSCalendarDate *lastFetch;

  struct
  {
    int modified: 1;
    int isNew: 1;
    int reserved: 30;
  } defFlags;
}

- (id) initWithTableURL: (NSURL *) url
		    uid: (NSString *) uid
	      fieldName: (NSString *) fieldName;

/* value access */

- (void) setObject: (id) value
	    forKey: (NSString *) key;
- (id) objectForKey: (NSString *) key;
- (void) removeObjectForKey: (NSString *) key;

/* typed accessors */

- (NSArray *) arrayForKey: (NSString *)key;
- (NSDictionary *) dictionaryForKey: (NSString *)key;
- (NSData *) dataForKey: (NSString *)key;
- (NSString *) stringForKey: (NSString *)key;
- (BOOL) boolForKey: (NSString *) key;
- (float) floatForKey: (NSString *) key;
- (int) integerForKey: (NSString *) key;

- (void) setBool: (BOOL) value   forKey: (NSString *) key;
- (void) setFloat: (float) value forKey: (NSString *) key;
- (void) setInteger: (int) value forKey: (NSString *) key;

/* saving changes */

- (BOOL) synchronize;

@end

#endif /* __AgenorUserDefaults_H__ */
