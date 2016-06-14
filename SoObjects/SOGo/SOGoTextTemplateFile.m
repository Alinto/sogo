/* SOGoTextTemplateFile.m - this file is part of SOGo
 *
 * Copyright (C) 2016 Inverse inc.
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

#import <Foundation/NSData.h>
#import <Foundation/NSValue.h>

#import "NSDictionary+Utilities.h"
#import "SOGoUser.h"
#import "SOGoUserDefaults.h"

#import "SOGoTextTemplateFile.h"

@implementation SOGoTextTemplateFile

+ (id) textTemplateFromFile: (NSString *) file
{
  SOGoTextTemplateFile *newTemplate;
  newTemplate = [[self  alloc] initFromFile: file
                               withEncoding: NSUTF8StringEncoding];
  [newTemplate autorelease];
  return newTemplate;
}


- (id) init
{
  if ((self = [super init]))
    {
      _textTemplate = nil;
    }
  return self;
}

- (void) dealloc
{
  [_textTemplate release];
  [super dealloc];
}

- (id) initFromFile: (NSString *) file
       withEncoding: (NSStringEncoding) enc
{
  id ret;
  NSData *textTemplateData;

  ret = nil;
  if (file)
    {
      if ((self = [self init]))
        {
          textTemplateData = [NSData dataWithContentsOfFile: file];
          if (textTemplateData == nil)
            NSLog(@"Failed to load text template file: %@", file);
          else
            {
              _textTemplate = [[[NSString alloc] initWithData: textTemplateData
                                                     encoding: enc] retain];
              ret = self;
            }
        }
    }
  return ret;
}

- (NSString *) textForUser: (SOGoUser *) user
{
  NSDictionary *values, *variables;
  NSNumber *days;
  SOGoUserDefaults* ud;

  // username
  ud = [user userDefaults];

  // daysBetweenResponse
  values = [ud vacationOptions];
  days = [values objectForKey: @"daysBetweenResponse"];
  if ([days intValue] == 0)
    days = [NSNumber numberWithInt: 7];

  variables = [NSDictionary dictionaryWithObjectsAndKeys:
                              [user cn], @"username",
                            days, @"daysBetweenResponse", nil];

  return [variables keysWithFormat: _textTemplate];
}

@end
