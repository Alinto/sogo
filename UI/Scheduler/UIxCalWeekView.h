// $Id: UIxCalWeekView.h 191 2004-08-12 16:28:32Z helge $

#ifndef __SOGo_UIxCalWeekView_H__
#define __SOGo_UIxCalWeekView_H__

#include "UIxCalView.h"

@class NSDictionary;

@interface UIxCalWeekView : UIxCalView
{
}

/* Query Parameters */

- (NSDictionary *)prevWeekQueryParameters;
- (NSDictionary *)nextWeekQueryParameters;
    
@end

#endif /* __SOGo_UIxCalWeekView_H__ */
