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
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>

#import <SoObjects/Mailer/SOGoDraftObject.h>
#import <SoObjects/Mailer/SOGoDraftsFolder.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailObject.h>
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
  NSString *newLocation;

  co = [self clientObject];
  account = [co mailAccountFolder];
  folder = [account draftsFolderInContext: context];
  newMail = [folder newDraft];
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

- (WOResponse *) addLabelAction
{
  WOResponse *response;
  SOGoMailObject *co;
  NSException *error;
  NSArray *flags;
  NSString *flag;

  flag = [[[self->context request] formValueForKey: @"flag"] fromCSSIdentifier];
  co = [self clientObject];
  flags = [NSArray arrayWithObject: flag];

  error = [co addFlags: flags];
  if (error)
    response = (WOResponse *) error;
  else
    response = [self responseWith204];

  return response;
}

- (WOResponse *) removeLabelAction
{
  WOResponse *response;
  SOGoMailObject *co;
  NSException *error;
  NSArray *flags;
  NSString *flag;

  flag = [[[self->context request] formValueForKey: @"flag"] fromCSSIdentifier];
  co = [self clientObject];
  flags = [NSArray arrayWithObject: flag];

  error = [co removeFlags: flags];
  if (error)
    response = (WOResponse *) error;
  else
    response = [self responseWith204];

  return response;
}

- (WOResponse *) removeAllLabelsAction
{
  NSMutableArray *flags;
  WOResponse *response;
  SOGoMailObject *co;
  NSException *error;
  NSDictionary *v;


  co = [self clientObject];

  v = [[[context activeUser] userDefaults] mailLabelsColors];

  // We always unconditionally remove the Mozilla tags
  flags = [NSMutableArray arrayWithObjects: @"$Label1", @"$Label2", @"$Label3",
                          @"$Label4", @"$Label5", nil];

  [flags addObjectsFromArray: [v allKeys]];

  error = [co removeFlags: flags];
  if (error)
    response = (WOResponse *) error;
  else
    response = [self responseWith204];

  return response;
}

@end
