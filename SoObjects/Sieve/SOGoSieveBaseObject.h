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

#ifndef __Sieve_SOGoSieveBaseObject_H__
#define __Sieve_SOGoSieveBaseObject_H__

#include <SOGo/SOGoObject.h>

/*
  SOGoSieveBaseObject
  
  Common base class for Sieve SoObjects.
*/

@class NSString, NSArray, NSURL;
@class NGSieveClient;
@class NGImap4ConnectionManager;
@class SOGoMailAccount;

@interface SOGoSieveBaseObject : SOGoObject
{
  NGSieveClient *sieveClient;
}

/* hierarchy */

- (SOGoMailAccount *)mailAccountFolder;

/* IMAP4 */

- (NGImap4ConnectionManager *)mailManager;
- (NSURL *)imap4URL;
- (NSString *)imap4Password;
- (void)flushMailCaches;

/* Sieve */

- (NGSieveClient *)sieveClient;

@end

#endif /* __Sieve_SOGoSieveBaseObject_H__ */
