/* SOGoAptMailReminder.h - this file is part of SOGo

 */

#ifndef SOGOAPTMAILRECEIPT_H
#define SOGOAPTMAILRECEIPT_H

#import "SOGoAptMailNotification.h"

@class NSArray;
@class NSString;
@class iCalPerson;


@interface SOGoAptMailReminder : SOGoAptMailNotification
{
  NSArray *attendees;
  iCalPerson *currentRecipient;
  NSString *calendarName;
}

- (void) setAttendees: (NSArray *) theAttendees;
- (void) setCalendarName: (NSString *) theCalendarName;

- (NSString *) aptSummary;
- (NSString *) aptStartDate;
- (NSString *) aptEndDate;
- (NSString *) calendarName;
- (iCalPerson *) organizer;

@end

#endif /* SOGOAPTMAILRECEIPT_H */
