/* SOGoIEConditional.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2013 Inverse inc.
 *
 * Author: Inverse <info@inverse.ca>
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

#ifndef SOGOIECONDITIONAL_H
#define SOGOIECONDITIONAL_H

#import <NGObjWeb/WODynamicElement.h>

@class WOContext;
@class WOElement;
@class WOResponse;

@interface SOGoIEConditional : WODynamicElement
{
  WOElement *template;
  WOAssociation *lte; // int
}

- (void) appendToResponse: (WOResponse *) _response
		inContext: (WOContext *) _ctx;

@end

#endif /* SOGOIECONDITIONAL_H */
