/* SOGoAptMailReminder.m - this file is part of SOGo

 */

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSCharacterSet.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>

#import "SOGoAptMailReminder.h"

static SOGoUserManager *um = nil;
static NSCharacterSet *wsSet = nil;

@implementation SOGoAptMailReminder

+ (void) initialize
{
  if (!um)
    um = [SOGoUserManager sharedUserManager];

  if (!wsSet)
    wsSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
}

- (id) init
{
  if ((self = [super init]))
    {
      attendees = nil;
      currentRecipient = nil;
      calendarName = nil;
    }

  return self;
}

- (void) dealloc
{
  [attendees release];
  [calendarName release];
  [super dealloc];
}

- (void) setupValues
{
  NSString *formattedDate;

  [super setupValues];

  formattedDate = [self aptStartDate];
  if (![formattedDate length])
    // Task with a due date
    formattedDate = [self aptEndDate];
  if ([formattedDate length])
    [values setObject: formattedDate
               forKey: @"StartDate"];
}

- (NSString *) getBody
{
  NSString *body;

  if (!values)
    [self setupValues];

  body = [[self generateResponse] contentAsString];

  return [body stringByTrimmingCharactersInSet: wsSet];
}

- (void) setAttendees: (NSArray *) theAttendees
{
  ASSIGN (attendees, theAttendees);
}

- (NSArray *) attendees
{
  return attendees;
}

- (void) setCurrentRecipient: (iCalPerson *) newCurrentRecipient
{
  ASSIGN (currentRecipient, newCurrentRecipient);
}

- (iCalPerson *) currentRecipient
{
  return currentRecipient;
}

- (void) setCalendarName: (NSString *) theCalendarName
{
  ASSIGN (calendarName, theCalendarName);
}

- (NSString *) calendarName
{
  return calendarName;
}

- (NSString *) aptSummary
{
  NSString *s;

  if (!values)
    [self setupValues];

  s = [self labelForKey: @"Reminder: \"%{Summary}\" - %{StartDate}"
              inContext: context];

  return [values keysWithFormat: s];
}

- (NSString *) getSubject
{
  return [[[self aptSummary] stringByTrimmingCharactersInSet: wsSet] asQPSubjectString: @"utf-8"];
}

- (NSString *) _formattedUserDate: (NSCalendarDate *) date
{
  SOGoDateFormatter *formatter;
  SOGoUser *currentUser;

  currentUser = [context activeUser];
  formatter = [currentUser dateFormatterInContext: context];

  if ([apt isKindOfClass: [iCalEvent class]] && [(iCalEvent*)apt isAllDay])
    return [formatter formattedDate: date];
  else
    return [formatter formattedDateAndTime: date];
}

- (NSString *) aptStartDate
{
  return [self _formattedUserDate: [self newStartDate]];
}

- (NSString *) aptEndDate
{
  return [self _formattedUserDate: [self newEndDate]];
}

- (iCalPerson *) organizer
{
  return [apt organizer];
}

@end
