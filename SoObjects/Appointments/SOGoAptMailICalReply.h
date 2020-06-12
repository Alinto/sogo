/* SOGoAptMailICalReply.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2020 Inverse inc.
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

#ifndef SOGOAPTMAILICALREPLY_H
#define SOGOAPTMAILICALREPLY_H

#import "SOGoAptMailNotification.h"

@class NSString;

@class iCalPerson;

/*
 * NOTE: We inherit from SoComponent in order to get the correct
 *       resourceManager required for this product
 */
@interface SOGoAptMailICalReply : SOGoAptMailNotification
{
  iCalPerson *attendee;
}

- (void) setAttendee: (iCalPerson *) newAttendee;
- (iCalPerson *) attendee;

/* Content Generation */

- (NSString *) getSubject;
- (NSString *) getBody;

@end

#endif /* SOGOAPTMAILICALREPLY_H */
