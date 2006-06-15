/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: UIxMailAddressbook.m 825 2005-07-19 12:47:20Z znek $


#include <SOGoUI/UIxComponent.h>


@interface UIxMailAddressbook : UIxComponent
{

}

- (NSString *)contactsPath;
- (NSString *)anaisPath;

@end

#include "common.h"

@implementation UIxMailAddressbook

- (NSString *)contactsPath {
  return [[self userFolderPath]
                stringByAppendingPathComponent:@"Contacts/select"];
}

- (NSString *)anaisPath {
  return @"/anais/Admin/Autres/aideFonc.php";
}

- (id)defaultAction {
  NSString *path = [self contactsPath];
  path = [path stringByAppendingString:@"?callback=addAddress"];
  return [self redirectToLocation:path];
}

- (id)anaisAction {
  NSString *path, *param;
    

    param = @"?m_fonc=addAddress&m_data=datawebmail&m_type=Pour&m_nom=,&m_champ=mail,uid,sn,cn,dn&m_agenda0#mon_etiquette";
    path  = [[self anaisPath] stringByAppendingString:param];
    return [self redirectToLocation:path];
}

@end /* UIxMailAddressbook */
