/* UIxMailActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>

#import <SoObjects/Mailer/SOGoDraftObject.h>
#import <SoObjects/Mailer/SOGoDraftsFolder.h>
#import <SoObjects/Mailer/SOGoMailAccount.h>
#import <SoObjects/Mailer/SOGoMailObject.h>

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
  return [self replyToAll: NO];
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

- (id) trashAction
{
  id response;

  response = [[self clientObject] trashInContext: context];
  if (!response)
    {
      response = [context response];
      [response setStatus: 204];
    }

  return response;
}

- (id) moveAction
{
  NSString *destinationFolder;
  id response;

  destinationFolder = [[context request] formValueForKey: @"tofolder"];
  if ([destinationFolder length] > 0)
    {
      response = [[self clientObject] moveToFolderNamed: destinationFolder
				      inContext: context];
      if (!response)
        {
	  response = [context response];
	  [response setStatus: 204];
        }
    }
  else
    response = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
			    reason: @"No destination folder given"];

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
    {
      response = [context response];
      [response setStatus: 204];
    }

  return response;
}

- (WOResponse *) deleteAttachmentAction
{
  WOResponse *response;
  NSString *filename;

  response = [context response];

  filename = [[context request] formValueForKey: @"filename"];
  if ([filename length] > 0)
    {
      [[self clientObject] deleteAttachmentWithName: filename];
      [response setStatus: 204];
    }
  else
    {
      [response setStatus: 500];
      [response appendContentString: @"How did you end up here?"];
    }

  return response;
}

@end
