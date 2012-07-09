/* SOGoToolUserPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc.
 *
 * Author: Ludovic Marcotte  <lmarcotte@inverse.ca>
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

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSieveManager.h>

#import "SOGoTool.h"

typedef enum
{
  UserPreferencesUnknown = -1,
  UserPreferencesGet = 0,
  UserPreferencesSet = 1,
  UserPreferencesUnset = 2,
} SOGoUserPreferencesCommand;

@interface SOGoToolUserPreferences : SOGoTool
@end

@implementation SOGoToolUserPreferences

+ (void) initialize
{
}

+ (NSString *) command
{
  return @"user-preferences";
}

+ (NSString *) description
{
  return @"set user defaults / settings in the database";
}

- (void) usage
{
  fprintf (stderr, "user-preferences get|set|unset defaults|settings user [authname:authpassword] key [value|-f filename]\n\n"
	   "       user       the user of whom to set the defaults/settings key/value\n"
	   "       value      the JSON-formatted value of the key\n\n"
	   "  Examples:\n"
           "       sogo-tool user-preferences get defaults janedoe SOGoLanguage\n"
           "       sogo-tool user-preferences unset settings janedoe Mail\n"
           "       sogo-tool user-preferences set defaults janedoe SOGoTimeFormat '{\"SOGoTimeFormat\":\"%%I:%%M %%p\"}'\n");
}

//
// possible values are: get | set | unset
//
- (SOGoUserPreferencesCommand) _cmdFromString: (NSString *) theString
{
  if ([theString length] > 2)
    {
      if ([theString caseInsensitiveCompare: @"get"] == NSOrderedSame)
	return UserPreferencesGet;
      else if  ([theString caseInsensitiveCompare: @"set"] == NSOrderedSame)
	return UserPreferencesSet;
      else if ([theString caseInsensitiveCompare: @"unset"] == NSOrderedSame)
	return UserPreferencesUnset;    }

  return UserPreferencesUnknown;
}

// If we got any of those keys for "defaults", we regenerate the Sieve script
//
// Forward
// SOGoSieveFilters
// Vacation
//
- (BOOL) _updateSieveScripsForkey: (NSString *) theKey
                          manager: (SOGoSieveManager *) theManager
			    login: (NSString *) theLogin
			 authname: (NSString *) theAuthName
			 password: (NSString *) thePassword
{
  if ([theKey caseInsensitiveCompare: @"Forward"] == NSOrderedSame ||
      [theKey caseInsensitiveCompare: @"SOGoSieveFilters"] == NSOrderedSame ||
      [theKey caseInsensitiveCompare: @"Vacation"] == NSOrderedSame)
    {
      if ([theAuthName length] == 0 || [thePassword length] == 0)
	{
	  NSLog(@"To update Sieve scripts, you must provide the \"authname:password\" parameter");
	  return NO;
	}
      
      return [theManager updateFiltersForLogin: theLogin
			 authname: theAuthName
			 password: thePassword
			 account: nil];
    }
  
  return YES;
}
		       


- (BOOL) run
{
  NSString *userId, *type, *key;
  SOGoUserPreferencesCommand cmd;
  id o;
  
  NSRange r;
  BOOL rc;
  int max;
  
  max = [arguments count];
  rc = NO;

  if (max > 3)
    {
      SOGoDefaultsSource *source;
      SOGoSieveManager *manager;
      SOGoUser *user;

      cmd = [self _cmdFromString: [arguments objectAtIndex: 0]];

      if (cmd != UserPreferencesUnknown)
	{
	  type = [arguments objectAtIndex: 1];
	  userId = [arguments objectAtIndex: 2];
	  key = [arguments objectAtIndex: 3];

	  user = [SOGoUser userWithLogin: userId];
	  manager = [SOGoSieveManager sieveManagerForUser: user];

	  if ([type caseInsensitiveCompare: @"defaults"] == NSOrderedSame)
	    source = [user userDefaults];
	  else
	    source = [user userSettings];

	  if (cmd == UserPreferencesGet)
	    {
	      o = [source objectForKey: key];

	      if (o)
		printf("%s: %s\n", [key UTF8String], [[o jsonRepresentation] UTF8String]);
	      else
		NSLog(@"Value for key \"%@\" not found in %@", key, type);

	      rc = YES;
	    }
	  else
	    {
	      NSString *authname, *authpwd, *value;
              NSData *data;
              int i;
              
	      authname = @"";
	      authpwd = @"";
	      value = @"";
 
	      if (max > 4)
		{
		  r = [[arguments objectAtIndex: 3] rangeOfString: @":"];
                  if (r.location == NSNotFound)
                    {
                      i = 3;
                    }
                  else
                    {
                      authname = [[arguments objectAtIndex: 3] substringToIndex: r.location];
                      authpwd = [[arguments objectAtIndex: 3] substringFromIndex: r.location+1];
                      i = 4;
                    }

                  key = [arguments objectAtIndex: i++];

		  if (max > i)
                    {
                      value = [arguments objectAtIndex: i++];
                      if ([value caseInsensitiveCompare: @"-f"] == NSOrderedSame)
                        {
                          if (max > i)
                            {
                              data = [NSData dataWithContentsOfFile: [arguments objectAtIndex: i]];
                              value = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
                              [value autorelease];
                            }
                        }
                    }
		}
	      else
		{
		  if (cmd == UserPreferencesUnset)
		    {
		      key = [arguments objectAtIndex: 3];
		    }
		  else
		    {
		      key = [arguments objectAtIndex: 3];
		      value = [arguments objectAtIndex: 4];
		    }
		}
	      
	      if (cmd == UserPreferencesUnset)
		[source removeObjectForKey: key];
	      else
		{
		  o = [value objectFromJSONString];
		  
		  //
		  // We support setting only "values" - for example, setting :
		  //
		  // SOGoDayStartTime to 9:00
		  //
		  // Values in JSON must be a dictionary so we must support passing:
		  // 
		  // key == SOGoDayStartTime
		  // value == '{"SOGoDayStartTime":  "09:00"}'
		  //
		  // to achieve what we want.
		  //
		  if (o && [o count] == 1)
		    {
		      [source setObject: [[o allValues] lastObject] forKey: key];
		    }
		  //
		  // We also support passing values that are already dictionaries so in this
		  // case, we simply set it to the passed key.
		  //
		  else if (o)
		    {
		      [source setObject: o  forKey: key];
		    }
		  else
		    NSLog(@"Invalid JSON input - no changes performed in the database. The supplied value was: %@", value);
		}
		  
	      [source synchronize];
	      rc = [self _updateSieveScripsForkey: key
			 manager: manager
			 login: userId
			 authname: authname
			 password: authpwd];
	    }
	}
    }

  if (!rc)
    {
      [self usage];
    }

  return rc;
}

@end
