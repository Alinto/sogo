// $Id: UIxCalView.h 84 2004-06-29 22:34:55Z znek $

#ifndef __ZideStoreUI_UIxCalView_H__
#define __ZideStoreUI_UIxCalView_H__

#include <Common/UIxComponent.h>

@class NSArray, NSCalendarDate;
@class SxAptManager, SxAptSetIdentifier;

@interface UIxCalView : UIxComponent
{
  NSArray *appointments;
  id      appointment;
  NSCalendarDate *currentDay;
}

/* accessors */

- (NSArray *)appointments;
- (id)appointment;

- (NSDictionary *)aptTypeDict;
- (NSString *)aptTypeLabel;
- (NSString *)aptTypeIcon;
- (NSString *)shortTextForApt;
- (NSString *)shortTitleForApt;

/* related to current day */
- (void)setCurrentDay:(NSCalendarDate *)_day;
- (NSCalendarDate *)currentDay;
- (NSString *)currentDayName;
- (NSArray *)allDayApts;
- (BOOL)hasDayInfo;
- (BOOL)hasHoldidayInfo;

    
- (BOOL)showFullNames;
- (BOOL)showAMPMDates;
- (NSCalendarDate *)referenceDateForFormatter;
    
/* URLs */

- (NSString *)appointmentViewURL;

/* backend */

- (SxAptManager *)aptManager;
- (SxAptSetIdentifier *)aptSetID;

/* fetching */

- (NSCalendarDate *)startDate;
- (NSCalendarDate *)endDate;
- (NSArray *)fetchGIDs;
- (NSArray *)fetchCoreInfos;

/* date selection */
- (NSDictionary *)todayQueryParameters;
- (NSDictionary *)currentDayQueryParameters;
- (NSDictionary *)queryParametersBySettingSelectedDate:(NSCalendarDate *)_date;
- (void)setSelectedDateQueryParameter:(NSCalendarDate *)_newDate
        inDictionary:(NSMutableDictionary *)_qp;

@end

#endif /* __ZideStoreUI_UIxCalView_H__ */
