// $Id: UIxCalMonthView.h 163 2004-08-02 12:59:28Z znek $

#ifndef __SOGo_UIxCalMonthViewOld_H__
#define __SOGo_UIxCalMonthViewOld_H__

#include "UIxCalView.h"

/*
  UIxCalMonthView
  
  Abstract superclass for views which display months.
*/

@interface UIxCalMonthViewOld : UIxCalView

- (NSCalendarDate *) startOfMonth;

- (NSDictionary *) prevMonthQueryParameters;
- (NSDictionary *) nextMonthQueryParameters;

@end

#endif /* __SOGo_UIxCalMonthViewOld_H__ */
