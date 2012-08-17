/* MAPIApplication.h - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#ifndef MAPIAPPLICATION_H
#define MAPIAPPLICATION_H

#import <NGObjWeb/SoApplication.h>

@class MAPIStoreUserContext;

@interface MAPIApplication : SoApplication
{
  MAPIStoreUserContext *userContext;
}

- (id) authenticatorInContext: (id) context;

- (void) setUserContext: (MAPIStoreUserContext *) newContext;

@end

extern MAPIApplication *MAPIApp;

#endif /* MAPIAPPLICATION_H */
