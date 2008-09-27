/* WODirectAction+SOGo.h - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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

#ifndef WODIRECTACTION_SOGO_H
#define WODIRECTACTION_SOGO_H

#import <NGObjWeb/WODirectAction.h>

@class NSString;
@class WOResponse;

@interface WODirectAction (SOGoExtension)

- (WOResponse *) responseWithStatus: (unsigned int) status;
- (WOResponse *) responseWithStatus: (unsigned int) status
			  andString: (NSString *) contentString;
- (WOResponse *) responseWithStatus: (unsigned int) status
	      andJSONRepresentation: (NSObject *) contentObject;
- (WOResponse *) responseWith204;
- (WOResponse *) redirectToLocation: (NSString *) newLocation;

- (NSString *) labelForKey: (NSString *) _str;

@end

#endif /* WODIRECTACTION_SOGO_H */
