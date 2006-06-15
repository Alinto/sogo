// $Id: UIxCalMonthView.h 163 2004-08-02 12:59:28Z znek $

#ifndef __SOGo_UIxCalMonthView_H__
#define __SOGo_UIxCalMonthView_H__

#include "UIxCalView.h"

/*
  UIxCalMonthView
  
  Abstract superclass for views which display months.
*/

@interface UIxCalMonthView : UIxCalView
{
}

- (NSCalendarDate *)startOfMonth;

- (NSDictionary *)prevMonthQueryParameters;
- (NSDictionary *)nextMonthQueryParameters;

@end

#endif /* __SOGo_UIxCalMonthView_H__ */
