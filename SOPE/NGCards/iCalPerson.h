/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGCards_iCalPerson_H__
#define __NGCards_iCalPerson_H__

#import "CardElement.h"

typedef enum {
  iCalPersonPartStatNeedsAction  = 0, /* NEEDS-ACTION (DEFAULT) */
  iCalPersonPartStatAccepted     = 1, /* ACCEPTED               */
  iCalPersonPartStatDeclined     = 2, /* DECLINED               */
  /* up to here defined for VJOURNAL                            */
  iCalPersonPartStatTentative    = 3, /* TENTATIVE              */
  iCalPersonPartStatDelegated    = 4, /* DELEGATED              */
  /* up to here defined for VEVENT                              */
  iCalPersonPartStatCompleted    = 5, /* COMPLETED              */
  iCalPersonPartStatInProcess    = 6, /* IN-PROCESS             */
  /* up to there defined for VTODO                              */
  
  /* these are also defined for VJOURNAL, VEVENT and VTODO      */
  iCalPersonPartStatExperimental = 7, /* x-name                 */
  iCalPersonPartStatOther        = 8  /* iana-token             */
} iCalPersonPartStat;

@interface iCalPerson : CardElement

/* accessors */

- (void)setCn:(NSString *)_s;
- (NSString *)cn;
- (NSString *)cnWithoutQuotes;

- (void)setEmail:(NSString *)_s;
- (NSString *)email;
- (NSString *)rfc822Email; /* email without 'mailto:' prefix */

- (void)setRsvp:(NSString *)_s;
- (NSString *)rsvp;

// - (void)setXuid:(NSString *)_s;
// - (NSString *)xuid;

- (void)setRole:(NSString *)_s;
- (NSString *)role;

- (void)setPartStat:(NSString *)_s;
- (NSString *)partStat;
- (NSString *)partStatWithDefault;

- (void) setDelegatedTo: (NSString *) newDelegate;
- (NSString *) delegatedTo;

- (void) setDelegatedFrom: (NSString *) newDelegatee;
- (NSString *) delegatedFrom;

- (void) setSentBy: (NSString *) newDelegatee;
- (NSString *) sentBy;

- (void)setParticipationStatus:(iCalPersonPartStat)_status;
- (iCalPersonPartStat)participationStatus;

- (BOOL)isEqualToPerson:(iCalPerson *)_other;
- (BOOL)hasSameEmailAddress:(iCalPerson *)_other;

@end

#endif /* __NGCards_iCalPerson_H__ */
