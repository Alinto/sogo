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
// $Id: UIxCalInlineAptView.m 885 2005-07-21 16:41:34Z znek $

#include <NGObjWeb/NGObjWeb.h>

@interface UIxCalInlineAptView : WOComponent
{
  id   appointment;
  id   formatter;
  id   tooltipFormatter;
  id   url;
  id   style;
  id   queryDictionary;
  id   referenceDate;
  BOOL canAccess;
}

@end

#include "common.h"
#include <SOGoUI/SOGoAptFormatter.h>
#include <SOGo/SOGoUser.h>
#include <NGObjWeb/WOContext+SoObjects.h>

@implementation UIxCalInlineAptView

- (void)dealloc {
  [self->appointment      release];
  [self->formatter        release];
  [self->tooltipFormatter release];
  [self->url              release];
  [self->style            release];
  [self->queryDictionary  release];
  [self->referenceDate    release];
  [super dealloc];
}

- (void)setAppointment:(id)_appointment {
  ASSIGN(self->appointment, _appointment);
}
- (id)appointment {
  return self->appointment;
}

- (void)setFormatter:(id)_formatter {
  ASSIGN(self->formatter, _formatter);
}
- (id)formatter {
  return self->formatter;
}

- (void)setTooltipFormatter:(id)_tooltipFormatter {
  ASSIGN(self->tooltipFormatter, _tooltipFormatter);
}
- (id)tooltipFormatter {
  return self->tooltipFormatter;
}

- (void)setUrl:(id)_url {
  ASSIGN(self->url, _url);
}
- (id)url {
  return self->url;
}

- (void)setStyle:(id)_style {
  NSMutableString *ms;
  NSNumber        *prio;
  NSString        *s;
  NSString        *email;

  if (_style) {
    ms = [NSMutableString stringWithString:_style];
  }
  else {
    ms = (NSMutableString *)[NSMutableString string];
  }
  if ((prio = [self->appointment valueForKey:@"priority"])) {
    [ms appendFormat:@" apt_prio%@", prio];
  }
  email = [[[self context] activeUser] email];
  if ((s = [self->appointment valueForKey:@"orgmail"])) {
    if ([s rangeOfString:email].length > 0) {
      [ms appendString:@" apt_organizer"];
    }
    else {
      [ms appendString:@" apt_other"];
    }
  }
  if ((s = [self->appointment valueForKey:@"partmails"])) {
    if ([s rangeOfString:email].length > 0) {
      [ms appendString:@" apt_participant"];
    }
    else {
      [ms appendString:@" apt_nonparticipant"];
    }
  }
  ASSIGNCOPY(self->style, ms);
}
- (id)style {
  return self->style;
}

- (void)setQueryDictionary:(id)_queryDictionary {
  ASSIGN(self->queryDictionary, _queryDictionary);
}
- (id)queryDictionary {
  return self->queryDictionary;
}

- (void)setReferenceDate:(id)_referenceDate {
  ASSIGN(self->referenceDate, _referenceDate);
}
- (id)referenceDate {
  return self->referenceDate;
}

- (void)setCanAccess:(BOOL)_canAccess {
  self->canAccess = _canAccess;
}
- (BOOL)canAccess {
  return self->canAccess;
}

/* helpers */

- (NSString *)title {
  return [self->formatter stringForObjectValue:self->appointment
                          referenceDate:[self referenceDate]];
}

- (NSString *)tooltip {
  return [self->tooltipFormatter stringForObjectValue:self->appointment
                                 referenceDate:[self referenceDate]];
}

@end
