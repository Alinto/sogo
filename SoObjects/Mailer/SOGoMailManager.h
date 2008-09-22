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

#ifndef __Mailer_SOGoMailManager_H__
#define __Mailer_SOGoMailManager_H__

#include <NGImap4/NGImap4ConnectionManager.h>

/*
  NGImap4ConnectionManager(SOGoMailManager)
  
  Legacy methods, the methods were used prior the move to NGImap4.
*/

@class NSException;
@class NSString;
@class NSURL;

@interface NGImap4ConnectionManager (SOGoMailManager)

- (NSException *) copyMailURL: (NSURL *) srcurl
		  toFolderURL: (NSURL *) desturl
		     password: (NSString *) pwd;

@end

#endif /* __Mailer_SOGoMailManager_H__ */
