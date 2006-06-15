// $Id: UIxCalWeekView.h 59 2004-06-22 13:40:19Z znek $

#ifndef __ZideStoreUI_UIxCalWeekView_H__
#define __ZideStoreUI_UIxCalWeekView_H__

#include "UIxCalView.h"

@interface UIxCalWeekView : UIxCalView
{
}

/* Query Parameters */

- (NSDictionary *)prevWeekQueryParameters;
- (NSDictionary *)nextWeekQueryParameters;
    
@end

#endif /* __ZideStoreUI_UIxCalWeekView_H__ */
