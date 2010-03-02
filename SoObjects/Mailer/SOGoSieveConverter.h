/* SOGoSieveConverter.h - this file is part of SOGo
 *
 * Copyright (C) 2010 Wolfgang Sourdeau
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

#ifndef SOGOSIEVECONVERTER_H
#define SOGOSIEVECONVERTER_H

#import <Foundation/NSObject.h>

@class NSDictionary;
@class NSMutableArray;
@class NSString;

@class SOGoUser;

@interface SOGoSieveConverter : NSObject
{
  SOGoUser *user;
  NSMutableArray *requirements;
  NSString *scriptError;
}

+ (id) sieveConverterForUser: (SOGoUser *) user;
- (id) initForUser: (SOGoUser *) newUser;

- (NSString *) sieveScriptWithRequirements: (NSMutableArray *) newRequirements;
- (NSString *) lastScriptError;

@end

#endif /* SOGOSIEVECONVERTER_H */
