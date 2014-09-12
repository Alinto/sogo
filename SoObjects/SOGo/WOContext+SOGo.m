/* WOContext+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
 *
 * Author: Francis Lachapelle <flachapelle@inverse.ca>
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
#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOSession.h>

#import "SOGoDomainDefaults.h"
#import "SOGoUser.h"
#import "SOGoUserDefaults.h"

#import "WOContext+SOGo.h"

@implementation WOContext (SOGoSOPEUtilities)

- (NSArray *) resourceLookupLanguages
{
  NSMutableArray *languages;
  NSArray *browserLanguages;
  SOGoUser *user;
  NSString *language, *theme;
  
  languages = [NSMutableArray array];
  user = [self activeUser];
  theme = [[self request] formValueForKey: @"theme"];

  if ([theme length] > 0)
    {
      if ([theme hasSuffix: @"/"])
        {
          // Remove trailing slash
          theme = [theme substringToIndex: [theme length] - 1];
        }
      [languages addObject: [NSString stringWithFormat: @"theme_%@", theme]];
      [self setObject: theme forKey: @"theme"];
    }

  if (!user || [[user login] isEqualToString: @"anonymous"])
    {
      browserLanguages = [[self request] browserLanguages];
      [languages addObjectsFromArray: browserLanguages];
    }
  else
    {
      language = [[user userDefaults] language];
      [languages addObject: language];
      language = [[user domainDefaults] language];
      [languages addObject: language];
    }

  return languages;
}

@end
