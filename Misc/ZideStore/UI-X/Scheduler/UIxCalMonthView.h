// $Id: UIxCalMonthView.h 59 2004-06-22 13:40:19Z znek $

#ifndef __ZideStoreUI_UIxCalMonthView_H__
#define __ZideStoreUI_UIxCalMonthView_H__

#include "UIxCalView.h"

/*
  UIxCalMonthView
  
  Abstract superclass for views which display months.
*/

@interface UIxCalMonthView : UIxCalView
{
}

- (NSDictionary *)prevMonthQueryParameters;
- (NSDictionary *)nextMonthQueryParameters;

@end

#endif /* __ZideStoreUI_UIxCalMonthView_H__ */
