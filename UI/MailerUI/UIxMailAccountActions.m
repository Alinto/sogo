/* UIxMailAccountActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
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
#import <NGObjWeb/WORequest.h>
#import <NGImap4/NSString+Imap4.h>
#import <NGExtensions/NSString+misc.h>

#import <Mailer/SOGoMailAccount.h>
#import <Mailer/SOGoDraftObject.h>
#import <Mailer/SOGoDraftsFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>

#import "UIxMailAccountActions.h"

@implementation UIxMailAccountActions

- (WOResponse *) listMailboxesAction
{
  SOGoMailAccount *co;
  NSArray *folders;
  NSDictionary *data;

  co = [self clientObject];

  folders = [co allFoldersMetadata: SOGoMailStandardListing];

  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         folders, @"mailboxes",
                       [co getInboxQuota], @"quotas",
                       nil];

  return [self responseWithStatus: 200
	    andJSONRepresentation: data];
}

- (WOResponse *) listAllMailboxesAction
{
  SOGoMailAccount *co;
  NSArray *folders;
  NSDictionary *data;

  co = [self clientObject];

  folders = [co allFoldersMetadata: SOGoMailSubscriptionsManagementListing];

  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         folders, @"mailboxes",
                       nil];

  return [self responseWithStatus: 200
	    andJSONRepresentation: data];
}

/* compose */

- (WOResponse *) composeAction
{
  NSString *value, *signature, *nl;
  SOGoDraftObject *newDraftMessage;
  NSMutableDictionary *headers;
  NSDictionary *data;
  NSString *accountName, *mailboxName, *messageName;
  SOGoDraftsFolder *drafts;
  id mailTo;
  BOOL save;

  drafts = [[self clientObject] draftsFolderInContext: context];
  newDraftMessage = [drafts newDraft];
  headers = [NSMutableDictionary dictionary];
  
  save = NO;

  value = [[self request] formValueForKey: @"mailto"];
  if ([value length] > 0)
    {
      mailTo = [[value stringByUnescapingURL] objectFromJSONString];
      if (mailTo && [mailTo isKindOfClass: [NSArray class]])
        {
          [headers setObject: (NSArray *) mailTo forKey: @"to"];
          save = YES;
        }
    }

  value = [[self request] formValueForKey: @"subject"];
  if ([value length] > 0)
    {
      [headers setObject: [value stringByUnescapingURL] forKey: @"subject"];
      save = YES;
    }

  if (save)
    [newDraftMessage setHeaders: headers];

  signature = [[self clientObject] signature];
  if ([signature length])
    {
      nl = ([[[[context activeUser] userDefaults] mailComposeMessageType] isEqualToString: @"html"] ? @"<br/>" : @"\n");

      [newDraftMessage
        setText: [NSString stringWithFormat: @"%@%@-- %@%@", nl, nl, nl, signature]];
      save = YES;
    }
  if (save)
    [newDraftMessage storeInfo];

  accountName = [[self clientObject] nameInContainer];
  mailboxName = [drafts absoluteImap4Name]; // Ex: /INBOX/Drafts/
  mailboxName = [mailboxName substringWithRange: NSMakeRange(1, [mailboxName length] -2)];
  messageName = [newDraftMessage nameInContainer];
  data = [NSDictionary dictionaryWithObjectsAndKeys:
                         accountName, @"accountId",
                       mailboxName, @"mailboxPath",
                       messageName, @"draftId", nil];

  return [self responseWithStatus: 201
                        andString: [data jsonRepresentation]];
}

- (WOResponse *) _performDelegationAction: (SEL) action
{
  SOGoMailAccount *co;
  WOResponse *response;
  NSString *uid;

  co = [self clientObject];
  if ([[co nameInContainer] isEqualToString: @"0"])
    {
      uid = [[context request] formValueForKey: @"uid"];
      if ([uid length] > 0)
        {
          [co performSelector: action
                   withObject: [NSArray arrayWithObject: uid]];
          response = [self responseWith204];
        }
      else
        response = [self responseWithStatus: 500
                                  andString: @"Missing 'uid' parameter."];
    }
  else
    response = [self responseWithStatus: 403
                              andString: @"This action cannot be performed on secondary accounts."];

  return response;
}

- (WOResponse *) addDelegateAction
{
  return [self _performDelegationAction: @selector (addDelegates:)];
}

- (WOResponse *) removeDelegateAction
{
  return [self _performDelegationAction: @selector (removeDelegates:)];
}

@end
