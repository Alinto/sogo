/* NSDictionary+Mail.m - this file is part of SOGo
 *
 * Copyright (C) 2013-2017 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <NGExtensions/NSString+misc.h>

#import "NSDictionary+Mail.h"

@implementation NSDictionary (SOGoExtension)

- (NSString *) filename
{
  NSDictionary *parameters;
  NSString *filename;

  filename = nil;
  parameters = [[self objectForKey: @"disposition"]
                    objectForKey: @"parameterList"];

  if (parameters)
    {
      filename = [parameters objectForKey: @"filename"];


      // We might have something like filename*=UTF-8''foobar
      // See RFC2231 for details. If it was folded before, it will
      // be unfolded when we get here.
      if (!filename)
        {
          filename = [parameters objectForKey: @"filename*"];
          
          if (filename)
            {
              NSRange r;
              
              filename = [filename stringByUnescapingURL];
              
              // We skip up to the language
              r = [filename rangeOfString: @"'"];
              
              if (r.length)
                {
                  r = [filename rangeOfString: @"'"  options: 0  range: NSMakeRange(r.location+1, [filename length]-r.location-1)];
                  
                  if (r.length)
                    filename = [filename substringFromIndex: r.location+1];
                }
            }
        }
    }

  if (!filename)
    filename = [[self objectForKey: @"parameterList"]
                 objectForKey: @"name"];

  return filename;
}

@end
