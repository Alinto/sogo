// $Id: UIxTaskView.h 768 2005-07-15 00:13:01Z helge $

#ifndef __SOGo_UIxTaskView_H__
#define __SOGo_UIxTaskView_H__

#include <SOGoUI/UIxComponent.h>

@class NSCalendarDate;
@class iCalToDo;
@class iCalPerson;
@class SOGoDateFormatter;

@interface UIxTaskView : UIxComponent
{
  iCalToDo* task;
  iCalPerson* attendee;
  SOGoDateFormatter *dateFormatter;
  id item;
}

- (iCalToDo *) task;

/* permissions */
- (BOOL)canAccessApt;
- (BOOL)canEditApt;
  
- (SOGoDateFormatter *)dateFormatter;
- (NSCalendarDate *)startTime;
- (NSCalendarDate *)endTime;
  
- (NSString *)attributesTabLink;
- (NSString *)participantsTabLink;

- (NSString *)completeHrefForMethod:(NSString *)_method
  withParameter:(NSString *)_param
  forKey:(NSString *)_key;

@end

#endif /* __SOGo_UIxTaskView_H__ */
