/* NGVCardPhoto.h - this file is part of NGCards
 *
 * Copyright (C) 2010-2016 Inverse inc.
 *
 * NGCards is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * NGCards is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with NGCards; see the file COPYING.  If not, write to the
 * Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 */

#ifndef NGVCARDPHOTO_H
#define NGVCARDPHOTO_H

#import "CardElement.h"

@class NSData;
@class NSString;

@interface NGVCardPhoto : CardElement

- (BOOL) isInline;

- (NSString *) type;

- (NSData *) decodedContent;

@end

#endif /* NGVCARDPHOTO_H */
