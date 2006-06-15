// $Id: UIxAppointmentView.h 69 2004-06-28 18:50:52Z znek $

#ifndef __ZideStoreUI_UIxAppointmentView_H__
#define __ZideStoreUI_UIxAppointmentView_H__

#include <Common/UIxComponent.h>

@interface UIxAppointmentView : UIxComponent
{
    NSString *tabSelection;
    id appointment;
    id attendee;
}

- (id)appointment;

- (NSString *)attributesTabLink;
- (NSString *)participantsTabLink;

- (NSString *)completeHrefForMethod:(NSString *)_method
              withParameter:(NSString *)_param
              forKey:(NSString *)_key;

@end

#endif /* __ZideStoreUI_UIxAppointmentView_H__ */
