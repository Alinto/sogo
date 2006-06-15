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

#include "UIxMailEditorAction.h"

#include <SoObjects/Mailer/SOGoDraftsFolder.h>
#include <SoObjects/Mailer/SOGoDraftObject.h>
#include <SoObjects/Mailer/SOGoMailAccount.h>
#include <SoObjects/Mailer/SOGoMailObject.h>
#include "common.h"

@implementation UIxMailEditorAction

- (void)dealloc {
  [self->newDraft release];
  [super dealloc];
}

/* caches */

- (void)reset {
  [self->newDraft release]; self->newDraft = nil;
}

/* lookups */

- (SOGoDraftsFolder *)draftsFolder {
  /* 
     Note: we cannot use acquisition to find the nearest drafts folder, because
           the IMAP4 server might contains an own Drafts folder.
  */
  SOGoDraftsFolder *drafts;
  id client;
  
  client = [self clientObject];
  drafts = [[client mailAccountFolder]
	            lookupName:@"Drafts" inContext:[self context] acquire:NO];
  return drafts;
}

/* errors */

- (id)didNotFindDraftsError {
  // TODO: make a nice error page
  return [@"did not find drafts folder in object: "
	   stringByAppendingString:[[self clientObject] description]];
}
- (id)couldNotCreateDraftError:(SOGoDraftsFolder *)_draftsFolder {
  return [@"could not create a new draft in folder: "
	   stringByAppendingString:[_draftsFolder description]];
}
- (id)didNotFindMailError {
  return [NSException exceptionWithHTTPStatus:404 /* Not Found */
		      reason:@"Did not find mail for operation!"];
}

/* compose */

- (id)composeAction {
  SOGoDraftsFolder *drafts;
  WOResponse *r;
  NSString   *url;
  id accountFolder;
  
  drafts = [self draftsFolder];
  if (![drafts isNotNull])
    return [self didNotFindDraftsError];
  if ([drafts isKindOfClass:[NSException class]])
    return drafts;
  
  url = [drafts newObjectBaseURLInContext:[self context]];
  if (![url isNotNull])
    return [self couldNotCreateDraftError:drafts];
  
  if (![url hasSuffix:@"/"]) url = [url stringByAppendingString:@"/"];
  url = [url stringByAppendingString:@"edit"];
  
  /* attach mail-account info */
  
  accountFolder = [[self clientObject] valueForKey:@"mailAccountFolder"];
  if (![accountFolder isExceptionOrNull]) {
    url = [url stringByAppendingString:@"?account="];
    url = [url stringByAppendingString:[accountFolder nameInContainer]];
  }
  
  /* perform redirect */
  
  [self debugWithFormat:@"compose on %@: %@", drafts, url];
  
  r = [[self context] response];
  [r setStatus:302 /* moved */];
  [r setHeader:url forKey:@"location"];
  [self reset];
  return r;
}

/* creating new draft object */

- (id)newDraftObject {
  SOGoDraftsFolder *drafts;
  
  drafts = [self draftsFolder];
  if (![drafts isNotNull])
    return [self didNotFindDraftsError];
  if ([drafts isKindOfClass:[NSException class]])
    return drafts;

  return [drafts newObjectInContext:[self context]];
}

- (NSException *)_setupNewDraft {
  SOGoDraftObject *tmp;
  
  /* create draft object */
  
  if ([(tmp = [self newDraftObject]) isKindOfClass:[NSException class]])
    return (NSException *)tmp;
  if (![tmp isNotNull]) { /* Note: should never happen? */
    [self logWithFormat:@"WARNING: got no new draft object and no error!"];
    return [self didNotFindDraftsError]; // TODO: not exact
  }
  
  ASSIGN(self->newDraft, tmp);
  //[self debugWithFormat:@"NEW DRAFT: %@", self->newDraft];
  
  return nil;
}

- (WOResponse *)redirectToEditNewDraft {
  WOResponse *r;
  NSString   *url;
  
  if (![self->newDraft isNotNull]) {
    [self logWithFormat:@"ERROR(%s): missing new draft (already -reset?)",
	    __PRETTY_FUNCTION__];
    return nil;
  }
  
  url = [self->newDraft baseURLInContext:[self context]];
  if (![url hasSuffix:@"/"]) url = [url stringByAppendingString:@"/"];
  url = [url stringByAppendingString:@"edit"];
  
  // TODO: debug log
  [self logWithFormat:@"compose on %@", url];
  
  r = [[self context] response];
  [r setStatus:302 /* moved */];
  [r setHeader:url forKey:@"location"];
  [self reset];
  return r;
}

@end /* UIxMailEditorAction */
