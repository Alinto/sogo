/* WODirectAction+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2012 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSBundle.h>

#import <NGObjWeb/SoObjects.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>

#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserDefaults.h>

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
  WOResponse *response;

  response = [self responseWithStatus: status
                            andString: [contentObject jsonRepresentation]];
  [response setHeader: @"application/json" forKey: @"content-type"];

  return response;
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
  NSString *bundleId, *userLanguage, *label;
  NSArray *paths;
  NSBundle *bundle;
  NSDictionary *strings;
  SOGoUserDefaults *ud;
  static NSMutableDictionary *bundlesCache = nil;
  NSMutableDictionary *languagesCache;

  if (!bundlesCache)
    bundlesCache = [NSMutableDictionary new];

  bundle = [NSBundle bundleForClass: [self class]];
  if (!bundle)
    bundle = [NSBundle mainBundle];

  bundleId = [bundle executablePath];
  languagesCache = [bundlesCache objectForKey: bundleId];
  if (!languagesCache)
    {
      languagesCache = [NSMutableDictionary new];
      [bundlesCache setObject: languagesCache forKey: bundleId];
      [languagesCache release];
    }

  ud = [[context activeUser] userDefaults];
  userLanguage = [ud language];
  strings = [languagesCache objectForKey: userLanguage];
  if (!strings)
    {
      paths = [bundle pathsForResourcesOfType: @"strings"
                                  inDirectory: [NSString stringWithFormat: @"%@.lproj",
                                                         userLanguage]
                              forLocalization: userLanguage];
      if ([paths count] > 0)
        {
          strings = [NSDictionary
                      dictionaryFromStringsFile: [paths objectAtIndex: 0]];
          if (strings)
            [languagesCache setObject: strings forKey: userLanguage];
        }
    }

  label = [strings objectForKey: key];
  if (!label)
    label = key;
  
  return label;
}

- (WOResourceManager *) pageResourceManager
{
  WOResourceManager *rm;
  
  if ((rm = [[context page] resourceManager]) == nil)
    rm = [[WOApplication application] resourceManager];

  return rm;
}

- (NSString *) urlForResourceFilename: (NSString *) filename
{
  static NSMutableDictionary *pageToURL = nil;
  NSString *url;
  WOComponent *page;
  WOResourceManager *rm;
  NSBundle *pageBundle;

  if (filename)
    {
      if (!pageToURL)
        pageToURL = [[NSMutableDictionary alloc] initWithCapacity: 32];

      url = [pageToURL objectForKey: filename];
      if (!url)
        {
          rm = [self pageResourceManager];
          page = [context page];
          pageBundle = [NSBundle bundleForClass: [page class]];
          url = [rm urlForResourceNamed: filename
                    inFramework: [pageBundle bundlePath]
                    languages: nil
                    request: [context request]];
          if (!url)
            url = @"";
          else
            if ([url hasPrefix: @"http"])
              url = [url hostlessURL];
          [pageToURL setObject: url forKey: filename];
        }

//   NSLog (@"url for '%@': '%@'", filename, url);
    }
  else
    url = @"";

  return url;
}

@end
