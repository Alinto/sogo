/* UIxPreferences.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2013 Inverse inc.
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

#ifndef UIXPREFERENCES_H
#define UIXPREFERENCES_H

#import <SOGoUI/UIxComponent.h>

@class NSString;

@class SOGoMailLabel;
@class SOGoUser;

@interface UIxPreferences : UIxComponent
{
  id item;
  SOGoUser *user;
  
  // Calendar categories
  NSString *category;
  NSArray *calendarCategories;
  NSDictionary *calendarCategoriesColors;
  
  NSArray *contactsCategories;
  NSString *defaultCategoryColor;
  NSCalendarDate *today;

  // Mail labels/tags
  SOGoMailLabel *label;
  NSArray *mailLabels;
  
  // Sieve filtering
  NSArray *daysOfWeek, *daysBetweenResponsesList;
  NSArray *sieveFilters;
  NSMutableDictionary *vacationOptions, *forwardOptions;

  BOOL mailCustomFromEnabled;
  BOOL hasChanged;

  
}

- (NSString *) userLongDateFormat;

@end

#endif /* UIXPREFERENCES_H */
