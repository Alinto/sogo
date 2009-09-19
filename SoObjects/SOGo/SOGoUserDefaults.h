/*
  Copyright (C) 2008-2009 Inverse inc.
  Copyright (C) 2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef	__SOGoUserDefaults_H_
#define	__SOGoUserDefaults_H_

#import <Foundation/NSObject.h>

/*
  SOGoUserDefaults
  
  An object with the same API like NSUserDefaults which retrieves profile
  information for users in the database.

  It does NOT store values internally but rather uses an external
  mutable dictionary for this (generally coming from SOGoCache)
*/

@class NSString, NSURL, NSUserDefaults, NSArray, NSDictionary;
@class NSData, NSCalendarDate, NSMutableDictionary;

@interface SOGoUserDefaults :  NSObject
{
  NSURL    *url;
  NSString *uid;
  NSString *fieldName;
  NSMutableDictionary *values;

  struct
  {
    int modified: 1;
    int isNew: 1;
    int ready: 1;
  } defFlags;
}

- (id) initWithTableURL: (NSURL *) theURL
		    uid: (NSString *) theUID
	      fieldName: (NSString *) theFieldName;

/* value access */
- (void) setValues: (NSDictionary *) theValues;
- (NSDictionary *) values;

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

- (NSString *) jsonRepresentation;

- (BOOL) fetchProfile;

/* saving changes */

- (BOOL) synchronize;

@end

#endif /* __SOGoUserDefaults_H__ */
