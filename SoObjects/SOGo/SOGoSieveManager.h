/* SOGoSieveManager.h - this file is part of SOGo
 *
 * Copyright (C) 2010-2019 Inverse inc.
 *
 * Author: Inverse <info@inverse.ca>
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

#ifndef SOGOSIEVEMANAGER_H
#define SOGOSIEVEMANAGER_H


@class NSDictionary;
@class NSMutableArray;
@class NSString;
@class NGSieveClient;
@class SOGoMailAccount;
@class SOGoUser;

@interface SOGoSieveManager : NSObject
{
  SOGoUser *user;
  NSMutableArray *requirements;
  NSString *scriptError;
}

+ (id) sieveManagerForUser: (SOGoUser *) user;
- (id) initForUser: (SOGoUser *) newUser;

- (NSString *) sieveScriptWithRequirements: (NSMutableArray *) newRequirements
                                 delimiter: (NSString *) delimiter;
- (NSString *) lastScriptError;

- (NGSieveClient *) clientForAccount: (SOGoMailAccount *) theAccount;
- (NGSieveClient *) clientForAccount: (SOGoMailAccount *) theAccount
                        withUsername: (NSString *) theUsername
                         andPassword: (NSString *) thePassword;

- (BOOL) hasActiveExternalSieveScripts: (NGSieveClient *) client;

- (BOOL) updateFiltersForAccount: (SOGoMailAccount *) theAccount;
- (BOOL) updateFiltersForAccount: (SOGoMailAccount *) theAccount
                    withUsername: (NSString *) theUsername
                     andPassword: (NSString *) thePassword
                 forceActivation: (BOOL) forceActivation;

@end

#endif /* SOGOSIEVEMANAGER_H */
