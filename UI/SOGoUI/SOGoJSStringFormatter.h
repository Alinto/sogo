/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

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
// $Id: SOGoJSStringFormatter.h 415 2004-10-20 15:47:45Z znek $


#ifndef	__SOGoJSStringFormatter_H_
#define	__SOGoJSStringFormatter_H_


#import <Foundation/Foundation.h>
#include <NGExtensions/NSString+Escaping.h>

@interface SOGoJSStringFormatter : NSObject <NGStringEscaping>
{
}

+ (id)sharedFormatter;

- (NSString *)stringByEscapingQuotesInString:(NSString *)_s;
- (NSString *)stringByEscapingSingleQuotesInString:(NSString *)_s;
- (NSString *)stringByEscapingDoubleQuotesInString:(NSString *)_s;

@end

#endif	/* __SOGoJSStringFormatter_H_ */
