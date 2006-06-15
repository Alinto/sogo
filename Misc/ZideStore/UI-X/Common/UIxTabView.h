/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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
// $Id: UIxTabView.h 32 2004-06-14 14:41:46Z znek $

#ifndef __UIxTabView_H__
#define __UIxTabView_H__

/*
  This is a library private header !
*/

#include <NGObjWeb/WODynamicElement.h>

/*
  Does not support tab-head-creation from nested components !!!

  hh: Why not ??? -> Because selection is manipulated in sub-elements

  UIxTabView creates element-IDs like

    .h.*.$key.  for the tab-items   (head-mode)
    .b.$key...  for the tab-content (content-mode) (new, hh)

  !!! UIxTabView JavaScript can't handle duplicate tab-keys !!!
*/

@interface UIxTabView : WODynamicElement
{
  WOAssociation *selection;

  /* config: */
  WOAssociation *headerStyle;
  WOAssociation *bodyStyle;
  WOAssociation *tabStyle;
  WOAssociation *selectedTabStyle;

  /* old config: */
  WOAssociation *bgColor;
  WOAssociation *nonSelectedBgColor;
  WOAssociation *leftCornerIcon;
  WOAssociation *rightCornerIcon;
  
  WOAssociation *tabIcon;
  WOAssociation *leftTabIcon;
  WOAssociation *selectedTabIcon;
  
  WOAssociation *asBackground;
  WOAssociation *width;
  WOAssociation *height;
  WOAssociation *activeBgColor;
  WOAssociation *inactiveBgColor;

  WOAssociation *fontColor;
  WOAssociation *fontSize;
  WOAssociation *fontFace;

  id            template;
}

@end

@interface UIxTabItem : WODynamicElement
{
  WOAssociation *key;
  WOAssociation *label;

  WOAssociation *href;
  WOAssociation *isScript;

  WOAssociation *action;
  WOAssociation *icon;

  /* config: */
  WOAssociation *tabStyle;
  WOAssociation *selectedTabStyle;

  /* old config */
  WOAssociation *tabIcon;
  WOAssociation *leftTabIcon;
  WOAssociation *selectedTabIcon;

  WOAssociation *asBackground;
  WOAssociation *width;
  WOAssociation *height;
  WOAssociation *activeBgColor;
  WOAssociation *inactiveBgColor;
  
  id            template;
}

@end

@interface UIxTabItemInfo : NSObject
{
@public
  NSString *label;
  NSString *icon;
  NSString *key;
  NSString *uri;
  NSString *tabIcon;
  NSString *leftIcon;
  NSString *selIcon;
  NSString *tabStyle;
  NSString *selectedTabStyle;

  int      asBackground; // 0 -> not set, 1 -> YES, else -> NO
  NSString *width;
  NSString *height;
  NSString *activeBg;
  NSString *inactiveBg;

  BOOL     isScript;
}
@end

#endif /* __UIxTabView_H__ */
