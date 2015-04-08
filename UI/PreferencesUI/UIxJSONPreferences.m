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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoUserProfile.h>
#import <Mailer/SOGoMailLabel.h>

#import <SOGoUI/UIxComponent.h>
#import <UI/Common/WODirectAction+SOGo.h>

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

  if (![[defaults source] objectForKey: @"SOGoShortDateFormat"])
    [[defaults source] setObject: @"default"  forKey: @"SOGoShortDateFormat"];

  if (![[defaults source] objectForKey: @"SOGoLongDateFormat"])
    [[defaults source] setObject: @"default"  forKey: @"SOGoLongDateFormat"];

  if (![[defaults source] objectForKey: @"SOGoFirstWeekOfYear"])
    [[defaults source] setObject: [defaults firstWeekOfYear] forKey: @"SOGoFirstWeekOfYear"];
  
  if (![[defaults source] objectForKey: @"SOGoSelectedAddressBook"])
    [[defaults source] setObject: @"personal" forKey: @"SOGoSelectedAddressBook"];
  
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
      SOGoMailLabel *label;
      NSArray *labels;
      id v;
      
      int i;
      
      v = [defaults mailLabelsColors];
      
      labels = [SOGoMailLabel labelsFromDefaults: v  component: self];
      v = [NSMutableDictionary dictionary];
      for (i = 0; i < [labels count]; i++)
        {
          label = [labels objectAtIndex: i];
          [v setObject: [NSArray arrayWithObjects: [label label], [label color], nil]
                forKey: [label name]];
        }
 
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
  id v;

  settings = [[context activeUser] userSettings];

  // We sanitize PreventInvitationsWhitelist if we need to, this is due to the fact
  // that SOGo <= 2.2.17 used to store it as a JSON *string* within the JSON-blob -
  // sorry about this engineering brain fart!
  v = [[settings objectForKey: @"Calendar"] objectForKey: @"PreventInvitationsWhitelist"];

  if (v && [v isKindOfClass: [NSString class]])
    {
      [[settings objectForKey: @"Calendar"] setObject: [v objectFromJSONString]
                                               forKey: @"PreventInvitationsWhitelist"];
    }

  return [self _makeResponse: [[settings source] values]];
}

@end
