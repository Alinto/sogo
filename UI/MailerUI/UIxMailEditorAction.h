/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __UIxMailEditorAction_H__
#define __UIxMailEditorAction_H__

#include <NGObjWeb/WODirectAction.h>

/*
  UIxMailEditorAction
  
  This action implements the backend for the various buttons which invoke the
  mail editor. The mail editor itself only works on a SOGoDraftObject which
  needs to be created in advance.
*/

@class NSException;
@class WOResponse;
@class SOGoDraftObject, SOGoDraftsFolder;

@interface UIxMailEditorAction : WODirectAction
{
  SOGoDraftObject *newDraft;
}

/* errors */

- (id)didNotFindDraftsError;
- (id)couldNotCreateDraftError:(SOGoDraftsFolder *)_draftsFolder;
- (id)didNotFindMailError;

/* creating new draft object */

- (NSException *)_setupNewDraft;
- (WOResponse *)redirectToEditNewDraft;

/* state */

- (void)reset;

@end

#endif /* __UIxMailEditorAction_H__ */
