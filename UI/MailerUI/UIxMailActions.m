/* UIxMailActions.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>

#import <SoObjects/Mailer/SOGoDraftObject.h>
#import <SoObjects/Mailer/SOGoDraftsFolder.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserSettings.h>
#import <SoObjects/SOGo/SOGoUserDefaults.h>

#import "../Common/WODirectAction+SOGo.h"

#import "UIxMailActions.h"

@implementation UIxMailActions

- (WOResponse *) replyToAll: (BOOL) toAll
{
  SOGoMailAccount *account;
  SOGoMailObject *co;
  SOGoDraftsFolder *folder;
  SOGoDraftObject *newMail;
  NSString *newLocation;

  co = [self clientObject];
  account = [co mailAccountFolder];
  folder = [account draftsFolderInContext: context];
  newMail = [folder newDraft];
  [newMail fetchMailForReplying: co toAll: toAll];

  newLocation = [NSString stringWithFormat: @"%@/edit",
			  [newMail baseURLInContext: context]];

  return [self redirectToLocation: newLocation];
}

- (WOResponse *) replyAction
{
  return [self replyToAll: NO];
}

- (WOResponse *) replyToAllAction
{
  return [self replyToAll: YES];
}

- (WOResponse *) forwardAction
{
  SOGoMailAccount *account;
  SOGoMailObject *co;
  SOGoDraftsFolder *folder;
  SOGoDraftObject *newMail;
  SOGoUserDefaults *ud;
  NSString *newLocation;
  BOOL htmlComposition;

  co = [self clientObject];
  account = [co mailAccountFolder];
  folder = [account draftsFolderInContext: context];
  newMail = [folder newDraft];
  ud = [[context activeUser] userDefaults];
  htmlComposition = [[ud mailComposeMessageType] isEqualToString: @"html"];

  [newMail setIsHTML: htmlComposition];
  [newMail fetchMailForForwarding: co];

  newLocation = [NSString stringWithFormat: @"%@/edit",
			  [newMail baseURLInContext: context]];

  return [self redirectToLocation: newLocation];
}

/* active message */

- (id) markMessageUnflaggedAction 
{
  id response;

  response = [[self clientObject] removeFlags: @"\\Flagged"];
  if (!response)
    response = [self responseWith204];
  
  return response;
}

- (id) markMessageFlaggedAction 
{
  id response;

  response = [[self clientObject] addFlags: @"\\Flagged"];
  if (!response)
    response = [self responseWith204];
  
  return response;
}


- (id) markMessageUnreadAction 
{
  id response;
 
  response = [[self clientObject] removeFlags: @"seen"];
  if (!response)
    response = [self responseWith204];
        
  return response;
}

- (id) markMessageReadAction 
{
  id response;

  response = [[self clientObject] addFlags: @"seen"];
  if (!response)
    response = [self responseWith204];
  
  return response;
}

- (void) collapseAction: (BOOL) isCollapsing
{
  SOGoMailObject *co;
  WORequest *request;
  NSMutableDictionary *moduleSettings, *threadsCollapsed, *content;
  NSMutableArray *mailboxThreadsCollapsed;
  NSString *msguid, *keyForMsgUIDs;
  SOGoUserSettings *us;

  request = [context request];
  content = [[request contentAsString] objectFromJSONString];
  keyForMsgUIDs = [content objectForKey:@"currentMailbox"];
  msguid = [content objectForKey:@"msguid"];

  co = [self clientObject];
  us = [[context activeUser] userSettings];
  if (!(moduleSettings = [us objectForKey: @"Mail"]))
    [us setObject:[NSMutableDictionary dictionnary] forKey: @"Mail"];

  if (isCollapsing)
    {
      // Check if the module threadsCollapsed is created in the userSettings
      if ((threadsCollapsed = [moduleSettings objectForKey:@"threadsCollapsed"]))
        {
          // Check if the currentMailbox already have other threads saved and add the new collapsed thread
          if ((mailboxThreadsCollapsed = [threadsCollapsed objectForKey:keyForMsgUIDs]))
            {
              if (![mailboxThreadsCollapsed containsObject:msguid])
                [mailboxThreadsCollapsed addObject:msguid];
            }
          else
            {
              mailboxThreadsCollapsed = [NSMutableArray arrayWithObject:msguid];
              [threadsCollapsed setObject:mailboxThreadsCollapsed forKey:keyForMsgUIDs];
            }
        }
      else
        {
          // Created the module threadsCollapsed and add the new collapsed thread
          mailboxThreadsCollapsed = [NSMutableArray arrayWithObject:msguid];
          threadsCollapsed = [NSMutableDictionary dictionaryWithObject:mailboxThreadsCollapsed forKey:keyForMsgUIDs];
          [moduleSettings setObject:threadsCollapsed forKey: @"threadsCollapsed"];
        }
    }
  else
    {
      // Check if the module threadsCollapsed is created in the userSettings
      if ((threadsCollapsed = [moduleSettings objectForKey:@"threadsCollapsed"]))
        {
          // Check if the currentMailbox already have other threads saved and remove the uncollapsed thread
          if ((mailboxThreadsCollapsed = [threadsCollapsed objectForKey:keyForMsgUIDs]))
            {
              [mailboxThreadsCollapsed removeObject:msguid];
              if ([mailboxThreadsCollapsed count] == 0)
                [threadsCollapsed removeObjectForKey:keyForMsgUIDs];
            }
        }
    // TODO : Manage errors
    }
  [us synchronize];
}

- (id) markMessageCollapseAction
{
  [self collapseAction: YES];
  
  return [self responseWith204];
}

- (id) markMessageUncollapseAction
{
  [self collapseAction: NO];
  
  return [self responseWith204];
}

/* SOGoDraftObject */
- (WOResponse *) editAction
{
  SOGoMailAccount *account;
  SOGoMailObject *co;
  SOGoDraftsFolder *folder;
  SOGoDraftObject *newMail;
  NSString *newLocation;

  co = [self clientObject];
  account = [co mailAccountFolder];
  folder = [account draftsFolderInContext: context];
  newMail = [folder newDraft];
  [newMail fetchMailForEditing: co];
  [newMail storeInfo];

  newLocation = [NSString stringWithFormat: @"%@/edit",
			  [newMail baseURLInContext: context]];

  return [self redirectToLocation: newLocation];
}

- (id) deleteAction
{
  SOGoDraftObject *draft;
  NSException *error;
  id response;

  draft = [self clientObject];
  error = [draft delete];
  if (error)
    response = error;
  else
    response = [self responseWith204];

  return response;
}

- (WOResponse *) deleteAttachmentAction
{
  WOResponse *response;
  NSString *filename;

  filename = [[context request] formValueForKey: @"filename"];
  if ([filename length] > 0)
    {
      response = [self responseWith204];
      [[self clientObject] deleteAttachmentWithName: filename];
    }
  else
    {
      response = [self responseWithStatus: 500];
      [response appendContentString: @"How did you end up here?"];
    }

  return response;
}

@end
