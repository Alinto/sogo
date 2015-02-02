/* SOGoSession.h - this file is part of SOGo
 *
 * Copyright (C) 2010-2014 Inverse inc.
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

#ifndef SOGOSESSION_H
#define SOGOSESSION_H

#import <Foundation/NSObject.h>

@interface SOGoSession : NSObject

+ (NSString *) valueForSessionKey: (NSString *) theSessionKey;
+ (void) setValue: (NSString *) theValue
    forSessionKey: (NSString *) theSessionKey;
+ (void) deleteValueForSessionKey: (NSString *) theSessionKey;

+ (NSString *) generateKeyForLength: (unsigned int) theLength;
+ (NSString *) securedValue: (NSString *) theValue
		   usingKey: (NSString *) theKey;
+ (NSString *) valueFromSecuredValue: (NSString *) theValue
			    usingKey: (NSString *) theKey;
+ (void) decodeValue: (NSString *) theValue
	    usingKey: (NSString *) theKey
               login: (NSString **) theLogin
              domain: (NSString **) theDomain
            password: (NSString **) thePassword;

@end

#endif
