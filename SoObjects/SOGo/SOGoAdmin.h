/*
  Copyright (C) 2023 Alinto

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __SOGoAdmin_H__
#define __SOGoAdmin_H__

#import <Foundation/Foundation.h>

@class NSObject;
@class NSException;
@class NSString;

@interface SOGoAdmin : NSObject
{
  
}

+ (id)sharedInstance;

- (BOOL)isConfigured;
- (NSString *)getMotd;
- (NSException *)deleteMotd;
- (NSException *)saveMotd:(NSString *)motd;

@end

#endif /* __SOGoAdmin_H__ */
