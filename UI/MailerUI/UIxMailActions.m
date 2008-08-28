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

#import <Foundation/NSArray.h>
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

- (id) trashAction
{
  id response;

  response = [[self clientObject] trashInContext: context];
  if (!response)
    response = [self responseWith204];

  return response;
}

- (id) moveAction
{
  NSString *destinationFolder;
  id response;

  destinationFolder = [[context request] formValueForKey: @"folder"];
  if ([destinationFolder length] > 0)
    {
      response = [[self clientObject] moveToFolderNamed: destinationFolder
				      inContext: context];
      if (!response)
	response = [self responseWith204];
    }
  else
    response = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
			    reason: @"No destination folder given"];

  return response;
}

- (id) copyAction
{
  NSString *destinationFolder;
  id response;

  destinationFolder = [[context request] formValueForKey: @"folder"];
  if ([destinationFolder length] > 0)
    {
      response = [[self clientObject] copyToFolderNamed: destinationFolder
				      inContext: context];
      if (!response)
	response = [self responseWith204];
    }
  else
    response = [NSException exceptionWithHTTPStatus: 500 /* Server Error */
			    reason: @"No destination folder given"];

  return response;
}

/* active message */

- (id) markMessageUnreadAction 
{
  id response;
  SOGoMailFolder *mailFolder;

  response = [[self clientObject] removeFlags: @"seen"];
  if (!response)
    {
      mailFolder = [[self clientObject] container];
      [mailFolder unselect];
      response = [self responseWith204];
    }
    
  return response;
}

- (id) markMessageReadAction 
{
  id response;
  SOGoMailFolder *mailFolder;

  response = [[self clientObject] addFlags: @"seen"];
  if (!response)
    {
      mailFolder = [[self clientObject] container];
      [mailFolder unselect];
      response = [self responseWith204];
    }

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

- (WOResponse *) _addLabel: (unsigned int) number
{
  WOResponse *response;
  SOGoMailObject *co;
  NSException *error;
  NSArray *flags;

  co = [self clientObject];
  flags = [NSArray arrayWithObject:
		     [NSString stringWithFormat: @"$Label%u", number]];
  error = [co addFlags: flags];
  if (error)
    response = (WOResponse *) error;
  else
    response = [self responseWith204];

  return response;
}

- (WOResponse *) _removeLabel: (unsigned int) number
{
  WOResponse *response;
  SOGoMailObject *co;
  NSException *error;
  NSArray *flags;

  co = [self clientObject];
  flags = [NSArray arrayWithObject:
		     [NSString stringWithFormat: @"$Label%u", number]];
  error = [co removeFlags: flags];
  if (error)
    response = (WOResponse *) error;
  else
    response = [self responseWith204];

  return response;
}

- (WOResponse *) addLabel1Action
{
  return [self _addLabel: 1];
}

- (WOResponse *) addLabel2Action
{
  return [self _addLabel: 2];
}

- (WOResponse *) addLabel3Action
{
  return [self _addLabel: 3];
}

- (WOResponse *) addLabel4Action
{
  return [self _addLabel: 4];
}

- (WOResponse *) addLabel5Action
{
  return [self _addLabel: 5];
}

- (WOResponse *) removeLabel1Action
{
  return [self _removeLabel: 1];
}

- (WOResponse *) removeLabel2Action
{
  return [self _removeLabel: 2];
}

- (WOResponse *) removeLabel3Action
{
  return [self _removeLabel: 3];
}

- (WOResponse *) removeLabel4Action
{
  return [self _removeLabel: 4];
}

- (WOResponse *) removeLabel5Action
{
  return [self _removeLabel: 5];
}

- (WOResponse *) removeAllLabelsAction
{
  WOResponse *response;
  SOGoMailObject *co;
  NSException *error;
  NSArray *flags;

  co = [self clientObject];
  flags = [NSArray arrayWithObjects: @"$Label1", @"$Label2", @"$Label3",
		   @"$Label4", @"$Label5", nil];
  error = [co removeFlags: flags];
  if (error)
    response = (WOResponse *) error;
  else
    response = [self responseWith204];

  return response;
}

@end
