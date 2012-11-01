/* SOGoSAML2Session.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>

#import "SOGoSAML2Session.h"

@implementation SOGoSAML2Session

+ (NSString *) metadataInContext: (WOContext *) context
{
  NSString *metadata, *serverURLString, *filename, *appName;
  NSBundle *bundle;
  NSURL *serverURL;

  bundle = [NSBundle bundleForClass: self];
  filename = [bundle pathForResource: @"SOGoSAML2Metadata" ofType: @"xml"];
  if (filename)
    {
      appName = [[WOApplication application] name];
      serverURL = [NSURL URLWithString: [NSString stringWithFormat: @"/%@/so",
                                                  appName]
                         relativeToURL: [context serverURL]];
      serverURLString = [serverURL absoluteString];
      metadata = [[NSString stringWithContentsOfFile: filename]
                   stringByReplacingString: @"%{base_url}"
                                withString: serverURLString];
    }
  else
    metadata = nil;

  return metadata;
}

@end
