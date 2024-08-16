/*
  Copyright (C) 2008-2017 Inverse inc.

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


#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "NSObject+Utilities.h"
#import "NSString+Utilities.h"

#import "SOGoCache.h"

#import "SOGoUserProfile.h"

@implementation SOGoUserProfile

+ (id) userProfileWithType: (SOGoUserProfileType) newProfileType
                    forUID: (NSString *) newUID
{
  id userProfile;

  userProfile = [self new];
  [userProfile autorelease];
  [userProfile setProfileType: newProfileType];
  [userProfile setUID: newUID];

  return userProfile;
}

- (id) init
{
  if ((self = [super init]))
    {
      uid = nil;
      values = nil;
      defFlags.ready = NO;
      defFlags.isNew = NO;
    }

  return self;
}

- (void) dealloc
{
  [values release];
  [uid release];
  [super dealloc];
}

/* accessors */

- (void) setProfileType: (SOGoUserProfileType) newProfileType
{
  profileType = newProfileType;
}

- (NSString *) profileTypeName
{
  NSString *profileTypeName;

  switch (profileType)
    {
    case SOGoUserProfileTypeDefaults:
      profileTypeName = @"defaults profile";
      break;
    case SOGoUserProfileTypeSettings:
      profileTypeName = @"settings profile";
      break;
    default:
      profileTypeName = @"<unknown profile type>";
    }

  return profileTypeName;
}

- (void) setUID: (NSString *) newUID
{
  ASSIGN (uid, newUID);
}

- (NSString *) uid
{
  return uid;
}


/* subclass methods */

- (BOOL) storeJSONProfileInDB: (NSString *) jsonRepresentation
{
  [self subclassResponsibility: _cmd];

  return NO;
}

- (NSString *) fetchJSONProfileFromDB
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (unsigned long long)getCDefaultsSize
{
  unsigned long long ret = 0;

  [self subclassResponsibility: _cmd];

  return ret;
}

/* operation */

- (NSString *) _convertPListToJSON: (NSString *) plistValue
{
  NSData *plistData;
  NSDictionary *plist;
  NSString *jsonValue, *error;

  plistData = [plistValue dataUsingEncoding: NSUTF8StringEncoding];
  plist = [NSPropertyListSerialization propertyListFromData: plistData
                                           mutabilityOption: NSPropertyListMutableContainers
                                                     format: NULL
                                           errorDescription: &error];
  if (plist)
    {
      [self logWithFormat: @"database value for %@"
                  @" (uid: '%@') is a plist", [self profileTypeName], uid];
      jsonValue = [plist jsonRepresentation];
    }
  else
    {
      [self errorWithFormat: @"failed to parse property list value for %@"
                  @" (error: %@): %@", [self profileTypeName], error, plistValue];
      jsonValue = nil;
    }

  if (!jsonValue)
    jsonValue = @"{}";

  return jsonValue;
}

- (NSString *) jsonRepresentation
{
  SOGoCache *cache;
  NSString *jsonValue;

  cache = [SOGoCache sharedCache];
  if (profileType == SOGoUserProfileTypeDefaults)
    jsonValue = [cache userDefaultsForLogin: uid];
  else
    jsonValue = [cache userSettingsForLogin: uid];
  if ([jsonValue length])
    {
      defFlags.ready = YES;
      defFlags.isNew = NO;
    }
  else
    {
      jsonValue = [self fetchJSONProfileFromDB];
      if ([jsonValue length])
        {
          if (![jsonValue isJSONString])
            jsonValue = [self _convertPListToJSON: jsonValue];
          if (profileType == SOGoUserProfileTypeDefaults)
            [cache setUserDefaults: jsonValue forLogin: uid];
          else
            [cache setUserSettings: jsonValue forLogin: uid];
        }
      else
        jsonValue = @"{}";
    }

  return jsonValue;
}

- (void) primaryFetchProfile
{
  NSString *jsonValue;

  defFlags.modified = NO;
  [values release];
  jsonValue = [self jsonRepresentation];
  values = [jsonValue objectFromJSONString];
  if (values)
    [values retain];
  else
    [self errorWithFormat: @"failure parsing json string: '%@'", jsonValue];
}

- (BOOL) _isReadyOrRetry
{
  BOOL rc;

  if (defFlags.ready)
    rc = YES;
  else
    {
      [self primaryFetchProfile];
      rc = defFlags.ready;
    }

  return rc;
}

- (BOOL) primaryStoreProfile
{
  NSString *jsonRepresentation;
  SOGoCache *cache;
  BOOL rc;

  jsonRepresentation = [values jsonRepresentation];
  if (jsonRepresentation)
    {
      rc = [self storeJSONProfileInDB: jsonRepresentation];
      if (rc)
        {
          cache = [SOGoCache sharedCache];
          if (profileType == SOGoUserProfileTypeDefaults)
            [cache setUserDefaults: jsonRepresentation
                          forLogin: uid];
          else
            [cache setUserSettings: jsonRepresentation
                          forLogin: uid];
        }
    }
 else
   {
     [self errorWithFormat: @"Unable to convert (%@) to a JSON string for"
                   @" type: %@ and login: %@", values, [self profileTypeName], uid];
     rc = NO;
   }

  return rc;
}

- (void) fetchProfile
{
  if (!values)
    [self primaryFetchProfile];
}

/* value access */
- (void) setValues: (NSDictionary *) theValues
{
  if ([self _isReadyOrRetry])
    {
      [values release];
      values = [[NSMutableDictionary alloc] init];
      [values addEntriesFromDictionary: theValues];
      defFlags.modified = YES;
    }
}

- (NSDictionary *) values
{
  NSDictionary *returnValues;

  if ([self _isReadyOrRetry])
    returnValues = values;
  else
    returnValues = nil;

  return returnValues;
}

- (void) setObject: (id) value
	    forKey: (NSString *) key
{ 
  id old;

  if ([self _isReadyOrRetry])
    {  
      /* check whether the value is actually modified */
      if (!defFlags.modified)
        {
          old = [values objectForKey: key];
          if (old == value || [old isEqual: value]) /* value didn't change */
            return;

#warning Note that this work-around only works for first-level objects.
          /* we need to this because our typed accessors convert to strings */
          // TODO: especially problematic with bools
          if ([value isKindOfClass: [NSString class]]) {
            if (![old isKindOfClass: [NSString class]])
              if ([[old description] isEqualToString: value])
                return;
          }
        }

      /* set in hash and mark as modified */
      if (value)
        [values setObject: value forKey: key];
      else
        [values removeObjectForKey: key];
      
      defFlags.modified = YES;
    }
}

- (void) removeObjectForKey: (NSString *) key
{
  [self setObject: nil forKey: key];
}

- (id) objectForKey: (NSString *) key
{
  return [[self values] objectForKey: key];
}

/* saving changes */
- (BOOL) dirty
{
  return defFlags.modified;
}

- (BOOL) synchronize
{
  BOOL rc;
//   if (!defFlags.modified) /* was not modified */
//     return YES;

  rc = NO;

  /* ensure fetched data (more or less guaranteed by modified!=0) */
  [self fetchProfile];
  if (values)
    {
      /* store */
      if ([self primaryStoreProfile])
        {
          rc = YES;
          // /* refetch */
          // [self primaryFetchProfile];
        }
      else
        {
          [self primaryFetchProfile];
          return NO;
        }
    }

  return rc;
}

- (NSString *) description
{
  return [values description];
}

@end
