/* WOResourceManager+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <Foundation/NSBundle.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSObject+Logs.h>

#import "SOGoSystemDefaults.h"

#import "WOResourceManager+SOGo.h"

@implementation WOResourceManager (SOGoExtensions)

- (NSString *) pathToLocaleForLanguageNamed: (NSString *) _name
{
  NSString *lpath;
  NSRange range;
  NSMutableArray *languages;

  languages = [NSMutableArray arrayWithObject: _name];

  // If the language has a CamelCase form, add the first part to the lookup languages.
  range = [_name rangeOfCharacterFromSet: [NSCharacterSet uppercaseLetterCharacterSet]
                                 options: NSBackwardsSearch
                                   range: NSMakeRange(1, [_name length] - 1)];
  if (range.location != NSNotFound && range.location > 0)
    [languages addObject: [_name substringToIndex: range.location]];

  lpath = [self pathForResourceNamed: @"Locale"
			 inFramework: nil
			   languages: languages];
  if (![lpath length])
    {
      NSBundle *bundle
          = [NSBundle bundleForClass: [SOGoSystemDefaults class]];
      NSString *ldir = [_name stringByAppendingPathExtension:@"lproj"];
      lpath = [bundle pathForResource: @"Locale" ofType: nil inDirectory: ldir];
      if (![lpath length])
        lpath = nil;
    }

  return lpath;
}

- (NSDictionary *) localeForLanguageNamed: (NSString *) _name
{
  NSString     *lpath;
  id           data;
  NSDictionary *locale;
  static NSMutableDictionary *localeLUT = nil;

  locale = nil;
  if ([_name length] > 0)
    {
      if (!localeLUT)
	localeLUT = [NSMutableDictionary new];

      locale = [localeLUT objectForKey: _name];
      if (!locale)
        {
          lpath = [self pathToLocaleForLanguageNamed:_name];
          if (lpath)
            {
              data = [NSData dataWithContentsOfFile: lpath];
              if (data)
                {
                  data = [[[NSString alloc] initWithData: data
                                            encoding: NSUTF8StringEncoding] autorelease];
                  locale = [data propertyList];
                  if (locale) 
                    [localeLUT setObject: locale forKey: _name];
                  else
                    [self logWithFormat:@"%s couldn't load locale with name:%@",
                          __PRETTY_FUNCTION__,
                          _name];
                }
              else
                [self logWithFormat:@"%s didn't find locale with name: %@",
                      __PRETTY_FUNCTION__,
                      _name];
            }
          else
            [self errorWithFormat:@"did not find locale for language: %@", _name];
        }
    }
  else
    [self errorWithFormat:@"%s: name parameter must not be nil!",
          __PRETTY_FUNCTION__];

  return locale;
}

@end
