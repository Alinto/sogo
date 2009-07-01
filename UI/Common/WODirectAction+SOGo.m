/* WODirectAction+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>

#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "WODirectAction+SOGo.h"

@implementation WODirectAction (SOGoExtension)

- (WOResponse *) responseWithStatus: (unsigned int) status
{
  WOResponse *response;

  response = [context response];
  [response setStatus: status];
  [response setHeader: @"text/plain; charset=utf-8" 
	    forKey: @"content-type"];

  return response;
}

- (WOResponse *) responseWithStatus: (unsigned int) status
			  andString: (NSString *) contentString
{
  WOResponse *response;

  response = [self responseWithStatus: status];
  [response appendContentString: contentString];

  return response;
}

- (WOResponse *) responseWithStatus: (unsigned int) status
	      andJSONRepresentation: (NSObject *) contentObject;
{
  return [self responseWithStatus: status
	       andString: [contentObject jsonRepresentation]];
}

- (WOResponse *) responseWith204
{
  WOResponse *response;

  response = [self responseWithStatus: 204];

  return response;
}

- (WOResponse *) redirectToLocation: (NSString *) newLocation
{
  WOResponse *response;

  response = [self responseWithStatus: 302];
  [response setHeader: newLocation forKey: @"location"];

  return response;
}

- (NSString *) labelForKey: (NSString *) key
{
  NSString *userLanguage, *label;
  NSArray *paths;
  NSBundle *bundle;
  NSDictionary *strings;

  bundle = [NSBundle bundleForClass: [self class]];
  if (!bundle)
    bundle = [NSBundle mainBundle];

  userLanguage = [[context activeUser] language];
  paths = [bundle pathsForResourcesOfType: @"strings"
		  inDirectory: [NSString stringWithFormat: @"%@.lproj",
					 userLanguage]
		  forLocalization: userLanguage];
  if ([paths count] > 0)
    {
      strings = [NSDictionary
		  dictionaryFromStringsFile: [paths objectAtIndex: 0]];
      label = [strings objectForKey: key];
      if (!label)
	label = key;
    }
  else
    label = key;
  
  return label;
}
@end
