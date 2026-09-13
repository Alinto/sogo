/* UIxMailPopupView.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse inc.
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

#import <NGImap4/NGSieveClient.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoSieveManager.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/WOContext+SOGo.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>

#import <SOGoUI/UIxComponent.h>

@interface UIxMailPopupView : UIxComponent
{
  NGSieveClient *client;
}

@end

@implementation UIxMailPopupView

//
// Used by wox template
//
- (BOOL) isSieveScriptsEnabled
{
  return [[[context activeUser] domainDefaults] sieveScriptsEnabled];
}

//
// Used by wox template
//
- (NSString *) sieveCapabilities
{
  static NSArray *capabilities = nil;

  if (!capabilities)
    {
      if ([self isSieveScriptsEnabled] && [self _sieveClient])
        capabilities = [[self _sieveClient] capabilities];
      else
        capabilities = [NSArray array];
      [capabilities retain];
    }

  return [capabilities jsonRepresentation];
}

//
// Used by wox template
//
- (BOOL) isVacationEnabled
{
  return [[[context activeUser] domainDefaults] vacationEnabled];
}

//
// Used internally
//
- (NSString *) defaultEmailAddresses
{
  return [[[[context activeUser] allEmails] uniqueObjects] jsonRepresentation];
}

/* mail forward */

//
// Used by templates
//
- (BOOL) isForwardEnabled
{
  return [[[context activeUser] domainDefaults] forwardEnabled];
}

- (NSString *) forwardConstraints
{
  SOGoDomainDefaults *dd;

  dd = [[context activeUser] domainDefaults];

  return [NSString stringWithFormat: @"%d", [dd forwardConstraints]];
}

- (NSString *) forwardConstraintsDomains
{
  NSMutableArray *domains;
  SOGoDomainDefaults *dd;

  dd = [[context activeUser] domainDefaults];
  domains = [NSMutableArray array];
  [domains addObjectsFromArray: [dd forwardConstraintsDomains]];

  return [domains jsonRepresentation];
}

/* mail notifications */
//
// Used by templates
//
- (BOOL) isNotificationEnabled
{
  return [[[context activeUser] domainDefaults] notificationEnabled];
}

//
// Used internally
//
- (id) _sieveClient
{
  SOGoMailAccount *account;
  SOGoMailAccounts *folder;
  SOGoSieveManager *manager;

  if (!client)
    {
      folder = [[[context activeUser] homeFolderInContext: context] mailAccountsFolder: @"Mail" inContext: context];
      account = [folder lookupName: @"0" inContext: context acquire: NO];
      manager = [SOGoSieveManager sieveManagerForUser: [context activeUser]];
      client = [[manager clientForAccount: account] retain];
    }

  return client;
}

@end
