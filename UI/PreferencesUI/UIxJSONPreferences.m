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

- (WOResponse *) _makeResponse: (NSDictionary *) values
{
  WOResponse *response;

  response = [context response];
  [response setHeader: @"text/plain; charset=utf-8"
	    forKey: @"content-type"];
  [response appendContentString: [values jsonRepresentation]];

  return response;
}

- (WOResponse *) jsonDefaultsAction
{
  NSMutableDictionary *values;
  SOGoUserDefaults *defaults;
  NSArray *categoryLabels;
  BOOL dirty;
  
  defaults = [[context activeUser] userDefaults];
  dirty = NO;
  
  if (![[defaults source] objectForKey: @"SOGoLongDateFormat"])
    [[defaults source] setObject: @"default"  forKey: @"SOGoLongDateFormat"];

  // Populate default calendar categories, based on the user's preferred language
  if (![defaults calendarCategories])
    {
      categoryLabels = [[[self labelForKey: @"calendar_category_labels"]
                         componentsSeparatedByString: @","]
                         sortedArrayUsingSelector: @selector (localizedCaseInsensitiveCompare:)];
      
      [defaults setCalendarCategories: categoryLabels];
      dirty = YES;
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
      dirty = YES;
    }
      
  // Populate default mail lablels, based on the user's preferred language
  if (![[defaults source] objectForKey: @"SOGoMailLabelsColors"])
    {
      NSDictionary *v;
      
       v = [defaults mailLabelsColors];

       // TODO - translate + refactor to not pass self since it's not a component
       //[defaults setMailLabelsColors: [SOGoMailLabel labelsFromDefaults: v  component: self]];
       [defaults setMailLabelsColors: v];
       dirty = YES;
    }

  if (dirty)
    [defaults synchronize];

  // We inject our default mail account, something we don't want to do before we
  // call -synchronize on our defaults.
  values = [[[[defaults source] values] mutableCopy] autorelease];
  [[values objectForKey: @"AuxiliaryMailAccounts"] insertObject: [[[context activeUser] mailAccounts] objectAtIndex: 0]
                                                        atIndex: 0];
    
  return [self _makeResponse: values];
}

- (WOResponse *) jsonSettingsAction
{
  SOGoUserSettings *settings;

  settings = [[context activeUser] userSettings];

  return [self _makeResponse: [[settings source] values]];
}

@end
