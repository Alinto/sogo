/* SOGo+DAV.h - this file is part of SOGo
 *
 * Copyright (C) 2010-2016 Inverse inc.
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

#ifndef SOGO_DAV_H
#define SOGO_DAV_H

@class WOContext;
@class WOResponse;

#import "SOGo.h"

@interface SOGo (SOGoWebDAVExtensions)

- (WOResponse *) davPrincipalMatch: (WOContext *) localContext;
- (WOResponse *) davPrincipalSearchPropertySet: (WOContext *) localContext;

@end

#endif /* SOGO_DAV_H */
