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
// $Id: UIxCalInlineAptView.h 1031 2007-03-07 22:52:32Z wolfgang $

#ifndef UIXCALINLINEAPTVIEW_H
#define UIXCALINLINEAPTVIEW_H

#import <NGObjWeb/WOComponent.h>

@interface UIxCalInlineAptView : WOComponent
{
  NSDictionary *appointment;
  id formatter;
  id tooltipFormatter;
  id url;
  id style;
  id queryDictionary;
  id referenceDate;
  int dayStartHour;
  int dayEndHour;
  BOOL canAccess;
}

@end

#endif /* UIXCALINLINEAPTVIEW_H */
