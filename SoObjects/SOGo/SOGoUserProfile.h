/*
  Copyright (C) 2008-2015 Inverse inc.

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


/*
  SOGoUserDefaults
  
  An object with the same API like NSUserDefaults which retrieves profile
  information for users in the database.

  It does NOT store values internally but rather uses an external
  mutable dictionary for this (generally coming from SOGoCache)
*/

@class NSString, NSUserDefaults, NSArray, NSDictionary;
@class NSData, NSCalendarDate, NSMutableDictionary;

typedef enum _SOGoUserProfileType {
  SOGoUserProfileTypeDefaults, /* configurable user preferences */
  SOGoUserProfileTypeSettings /* user environment state */
} SOGoUserProfileType;

@interface SOGoUserProfile : NSObject
{
  NSString *uid;
  NSMutableDictionary *values;
  SOGoUserProfileType profileType;

  struct
  {
    BOOL modified;
    BOOL isNew;
    BOOL ready;
  } defFlags;
}

+ (id) userProfileWithType: (SOGoUserProfileType) newProfileType
                    forUID: (NSString *) theUID;

- (void) setProfileType: (SOGoUserProfileType) newProfileType;
- (NSString *) profileTypeName;

- (void) setUID: (NSString *) newUID;
- (NSString *) uid;

- (unsigned long long)getCDefaultsSize;

/* value access */
- (void) setValues: (NSDictionary *) theValues;
- (NSDictionary *) values;

- (void) setObject: (id) value
	    forKey: (NSString *) key;
- (id) objectForKey: (NSString *) key;
- (void) removeObjectForKey: (NSString *) key;

- (NSString *) jsonRepresentation;

- (void) fetchProfile;

/* saving changes */

- (BOOL) dirty;
- (BOOL) synchronize;

@end

#endif /* __SOGoUserDefaults_H__ */
