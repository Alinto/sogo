/* SOGoConstants.h - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Ludovic Marcotte <lmarcotte@inverse.ca>
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

#ifndef _SOGOCONSTANTS_H_
#define _SOGOCONSTANTS_H_

// This is a perfect copy of the OpenLDAP's
// LDAPPasswordPolicyError enum. We redeclare it
// so that we always include the ppolicy code 
// within SOGo.
typedef enum
{
  PolicyPasswordExpired = 0,
  PolicyAccountLocked = 1,
  PolicyChangeAfterReset = 2,
  PolicyPasswordModNotAllowed = 3,
  PolicyMustSupplyOldPassword = 4,
  PolicyInsufficientPasswordQuality = 5,
  PolicyPasswordTooShort = 6,
  PolicyPasswordTooYoung = 7,
  PolicyPasswordInHistory = 8,
  PolicyNoError = 65535,
} SOGoPasswordPolicyError;

// Domain defaults
extern NSString *SOGoPasswordChangeEnabled;

typedef enum
{
  EventCreated = 0,
  EventDeleted = 1,
  EventUpdated = 2,
} SOGoEventOperation;

#endif /* _SOGOCONSTANTS_H_ */
