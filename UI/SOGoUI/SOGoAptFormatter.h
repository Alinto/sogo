/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: SOGoAptFormatter.h 797 2005-07-18 15:15:32Z znek $


#ifndef	__SOGoAptFormatter_H_
#define	__SOGoAptFormatter_H_


#include <Foundation/Foundation.h>


@interface SOGoAptFormatter : NSFormatter
{
  NSTimeZone *tz;
  SEL        formatAction;
  NSString   *privateTitle;
  NSString   *titlePlaceholder;
  BOOL       omitsEndDate;
}

- (id)initWithDisplayTimeZone:(NSTimeZone *)_tz;

- (void)setTooltip;
- (void)setSingleLineFullDetails;
- (void)setFullDetails;
- (void)setTitleOnly;
- (void)setShortTitleOnly;
- (void)setOmitsEndDate;

- (void)setPrivateTooltip;
- (void)setPrivateDetails;
- (void)setPrivateTitleOnly;
- (void)setPrivateSuppressAll;

- (void)setPrivateTitle:(NSString *)_privateTitle;
- (NSString *)privateTitle;

- (void)setTitlePlaceholder:(NSString *)_titlePlaceholder;
- (NSString *)titlePlaceholder;

- (NSString *)stringForObjectValue:(id)_obj
  referenceDate:(NSCalendarDate *)_refDate;

@end

#endif	/* __SOGoAptFormatter_H_ */
