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
}

- (void) setItem: (NSString *) newItem
{
    ASSIGN(item, newItem);
}

- (NSString *) item
{
    return item;
}

- (NSArray *) mailAccountsList
{
    SOGoMailAccount *co, *accountFolder;
    SOGoMailAccounts *accountsFolder;
    SOGoUserFolder *userFolder;
    NSString *userName, *option, *lookup;
    NSArray *folders;
    NSMutableArray *mailboxes;
    NSDictionary *mailAccount;
    int nbMailboxes, nbMailAccounts, i, j;
    
    
    userFolder = [[context activeUser] homeFolderInContext: context];
    accountsFolder = [userFolder lookupName: @"Mail" inContext: context acquire: NO];
    nbMailAccounts = [[accountsFolder mailAccounts] count];
  
    mailboxes = [[NSMutableArray alloc] init];
    for (i = 0; i < nbMailAccounts; i++)
      {
        mailAccount = [[[accountsFolder mailAccounts] objectAtIndex:i] objectForKey:@"name"]; // Keys on this account = (name, port, encryption, mailboxes, serverName, identities, userName)
        userName = [[[accountsFolder mailAccounts] objectAtIndex:i] objectForKey:@"userName"];
        lookup = [NSString stringWithFormat:@"%i", i];
        accountFolder = [accountsFolder lookupName:lookup inContext: context acquire: NO];
        folders = [accountFolder allFoldersMetadata];
        nbMailboxes = [folders count];
        [mailboxes addObject:mailAccount];
        for (j = 0; j < nbMailboxes; j++)
          {
            option = [NSString stringWithFormat:@"%@%@", userName, [[folders objectAtIndex:j] objectForKey:@"displayName"]];
            [mailboxes addObject:option];
          }
      }
    return mailboxes;
    [mailboxes release];
}

//
// The objective here is to return the parent view layout and select the print
// layout corresponding. Default print view: list view
/*
- (NSString *) mailAccountSelected
{
    SOGoUser *activeUser;
    NSString *parentView;
    
    activeUser = [context activeUser];
    us = [activeUser userSettings];
    parentView = [[us objectForKey:@"Calendar"] objectForKey:@"View" ];
    
    if ([parentView isEqualToString:@"dayview"])
        return @"Daily";
    
    else if ([parentView isEqualToString:@"weekview"])
        return @"Weekly";
    
    else if ([parentView isEqualToString:@"multicolumndayview"])
        return @"Multi-Columns";
    
    else
        return @"LIST";
}
*/

@end