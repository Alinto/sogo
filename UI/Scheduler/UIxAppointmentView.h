// $Id: UIxAppointmentView.h 768 2005-07-15 00:13:01Z helge $

#ifndef __SOGo_UIxAppointmentView_H__
#define __SOGo_UIxAppointmentView_H__

#include <SOGoUI/UIxComponent.h>

@class NSCalendarDate;
@class iCalEvent;
@class iCalPerson;
@class SOGoDateFormatter;

@interface UIxAppointmentView : UIxComponent
{
  iCalEvent* appointment;
  iCalPerson* attendee;
  SOGoDateFormatter *dateFormatter;
  id item;
}

- (iCalEvent *) appointment;

/* permissions */
- (BOOL) canAccessApt;
- (BOOL) canEditApt;
  
- (SOGoDateFormatter *) dateFormatter;
- (NSCalendarDate *) startTime;
- (NSCalendarDate *) endTime;
  
- (NSString *) attributesTabLink;
- (NSString *) participantsTabLink;

- (NSString *) completeHrefForMethod: (NSString *) _method
		       withParameter: (NSString *) _param
			      forKey: (NSString *) _key;

@end

#endif /* __SOGo_UIxAppointmentView_H__ */
