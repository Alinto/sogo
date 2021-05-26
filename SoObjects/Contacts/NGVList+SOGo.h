/* NGVCard+SOGo.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2021 Inverse inc.
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

#ifndef NGVLIST_SOGO_H
#define NGVLIST_SOGO_H

#import <NGCards/NGVList.h>

@interface NGVList (SOGoExtensions)

- (CardElement *) elementWithTag: (NSString *) elementTag
                          ofType: (NSString *) type;

- (NSString *) ldifString;
- (void) updateFromLDIFRecord: (NSDictionary *) ldifRecord
                  inContainer: (id) container;
- (void) setCardReference: (NSString *) newCardReference
              inContainer: (id) container;
- (void) setCardReferences: (NSArray *) newCardReferences
               inContainer: (id) container;

@end

#endif /* NGVLIST_SOGO_H */
