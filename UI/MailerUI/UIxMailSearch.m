/* UIxMailSearch.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2014 Inverse inc.
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

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoMailAccounts.h>
#import <SOGo/SOGoUserFolder.h>

#import <UIxMailSearch.h>

@implementation UIxMailSearch

- (id) init
{
  item = nil;
  
  return self;
}

- (void) dealloc
{
  [item release];
  [super dealloc];
}

- (void) setItem: (id) newItem
{
  ASSIGN(item, newItem);
}

- (id) item
{
  return item;
}

- (NSString *) currentFolderDisplayName
{
  return [[item allValues] lastObject];
}

- (NSString *) currentFolderPath
{
  return [[item allKeys] lastObject];
}

- (NSArray *) mailAccountsList
{
  NSDictionary *accountName, *mailbox;
  NSString *userName, *aString;
  SOGoMailAccounts *mAccounts;
  SOGoMailAccount *mAccount;
  NSArray *accountFolders;
  NSMutableArray *mailboxes;

  int nbMailboxes, nbMailAccounts, i, j;
  
  // Number of accounts linked with the current user
  mAccounts = [self clientObject];
  nbMailAccounts = [[mAccounts mailAccounts] count];

  mailboxes = [NSMutableArray array];
  for (i = 0; i < nbMailAccounts; i++)
    {
      accountName = [[[mAccounts mailAccounts] objectAtIndex:i] objectForKey:@"name"]; // Keys on this account = (name, port, encryption, mailboxes, serverName, identities, userName)
      userName = [[[mAccounts mailAccounts] objectAtIndex:i] objectForKey:@"userName"];
  
      aString = [NSString stringWithFormat:@"%i", i];
      mAccount = [mAccounts lookupName:aString inContext: context acquire: NO];
      accountFolders = [mAccount allFoldersMetadata];
  
      // Number of mailboxes inside the current account
      nbMailboxes = [accountFolders count];
      [mailboxes addObject: [NSDictionary dictionaryWithObject: accountName  forKey: accountName]];

      for (j = 0; j < nbMailboxes; j++)
        {
          mailbox = [NSDictionary dictionaryWithObject: [NSString stringWithFormat:@"%@%@", userName, [[accountFolders objectAtIndex:j] objectForKey: @"displayName"]]
                                                forKey: [[accountFolders objectAtIndex:j] objectForKey: @"path"]];
          [mailboxes addObject: mailbox];
        }
    }

  return mailboxes;
}

@end
