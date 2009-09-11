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

#ifndef _SOGoDAVAuthenticator_H__
#define _SOGoDAVAuthenticator_H__

#import <NGObjWeb/SoHTTPAuthenticator.h>

#import "SOGoAuthenticator.h"

/*
  SOGoDAVAuthenticator
  
  This just overrides the login/pwd check method and always returns YES since
  the password is already checked in Apache.
*/

@class NSUserDefaults;
@class NSString;

@class SOGoUser;

@interface SOGoDAVAuthenticator : SoHTTPAuthenticator <SOGoAuthenticator>
{
  NSString *authMethod;
}

+ (id) sharedSOGoDAVAuthenticator;

- (SOGoUser *) userInContext: (WOContext *) _ctx;
- (NSString *) passwordInContext: (WOContext *) context;

@end

#endif /* _SOGoDAVAuthenticator_H__ */
