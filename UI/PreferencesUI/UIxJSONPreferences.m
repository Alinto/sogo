/* UIxJSONPreferences.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2015 Inverse inc.
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

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoUserProfile.h>
#import <Mailer/SOGoMailLabel.h>

#import <SOGoUI/UIxComponent.h>

#import "UIxJSONPreferences.h"

@implementation UIxJSONPreferences

- (WOResponse *) _makeResponse: (SOGoUserProfile *) profile
{
  WOResponse *response;

  response = [context response];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [profile jsonRepresentation]];

  return response;
}

- (WOResponse *) jsonDefaultsAction
{
  SOGoUserDefaults *defaults;
  NSArray *categoryLabels;

  defaults = [[context activeUser] userDefaults];

  if (![[defaults source] objectForKey: @"SOGoLongDateFormat"])
    [[defaults source] setObject: @"default"  forKey: @"SOGoLongDateFormat"];

  // Populate default calendar categories, based on the user's preferred language
  if (![defaults calendarCategories])
    {
      categoryLabels = [[[self labelForKey: @"calendar_category_labels"]
                         componentsSeparatedByString: @","]
                         sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
      
      [defaults setCalendarCategories: categoryLabels];
    }
  
  // Populate default contact categories, based on the user's preferred language
  if (![defaults contactsCategories])
    {
      categoryLabels = [[[self labelForKey: @"contacts_category_labels"]
                       componentsSeparatedByString: @","]
                          sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
      
      if (!categoryLabels)
        categoryLabels = [NSArray array];

      [defaults setContactsCategories: categoryLabels];
    }
      
  // Populate default mail lablels, based on the user's preferred language
  if (![[defaults source] objectForKey: @"SOGoMailLabelsColors"])
    {
      NSDictionary *v;
      
       v = [defaults mailLabelsColors];

       // TODO - translate + refactor to not pass self since it's not a component
       //[defaults setMailLabelsColors: [SOGoMailLabel labelsFromDefaults: v  component: self]];
       [defaults setMailLabelsColors: v];
    }

  
  [defaults synchronize];
  
  return [self _makeResponse: [defaults source]];
}

- (WOResponse *) jsonSettingsAction
{
  SOGoUserSettings *settings;

  settings = [[context activeUser] userSettings];

  return [self _makeResponse: [settings source]];
}

@end
