/* UIxPreferences.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2019 Inverse inc.
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
#import <NGImap4/NGSieveClient.h>

@class NSString;

@class SOGoUser;

@interface UIxPreferences : UIxComponent
{
  id item;
  SOGoUser *user;
  NGSieveClient *client;

  // Addressbook
  NSMutableDictionary *addressBooksIDWithDisplayName;

  NSCalendarDate *today;

  // Sieve filtering
  NSArray *daysOfWeek, *daysBetweenResponsesList;
  NSArray *sieveFilters;
  NSMutableDictionary *vacationOptions, *forwardOptions, *notificationOptions;

  BOOL mailCustomFromEnabled;
  BOOL forwardEnabled;
  BOOL hasChanged;
}

- (BOOL) _isSieveServerAvailable;
- (id) _sieveClient;
- (NSString *) _vacationTextForTemplate: (NSString *) templateFilePath;
- (void) _updateAuxiliaryAccount: (NSMutableDictionary *) newAccount;

@end

#endif /* UIXPREFERENCES_H */
