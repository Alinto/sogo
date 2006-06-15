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

#ifndef __Mailer_SOGoDraftsFolder_H__
#define __Mailer_SOGoDraftsFolder_H__

#include <SoObjects/Mailer/SOGoMailBaseObject.h>

/*
  SOGoDraftsFolder
    Parent object: SOGoMailAccount
    Child objects: SOGoDraftObject's
  
  The SOGoDraftsFolder is used for composing new messages. It is necessary
  because we can't cache objects in a session. So the contents of the drafts
  folder are some kind of "mail creation transaction".
*/

@interface SOGoDraftsFolder : SOGoMailBaseObject
{
}

/* new objects */

- (NSString *)makeNewObjectNameInContext:(id)_ctx;
- (NSString *)newObjectBaseURLInContext:(id)_ctx;
- (id)newObjectInContext:(id)_ctx;

@end

#endif /* __Mailer_SOGoDraftsFolder_H__ */
