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
// $Id: UIxCalParticipationStatusView.m 759 2005-07-14 16:26:32Z znek $

#include <NGObjWeb/NGObjWeb.h>

@interface UIxCalParticipationStatusView : WOComponent
{
  int partStat;
}

- (NSString *)participationStatus;

@end

#include <NGCards/NGCards.h> /* for iCalPersonPartStat */
#include "common.h"

@implementation UIxCalParticipationStatusView

- (void)setPartStat:(id)_partStat {
  self->partStat = [_partStat intValue];
}
- (int)partStat {
  return self->partStat;
}

- (NSString *)participationStatus {
  switch (self->partStat) {
    case iCalPersonPartStatNeedsAction:
      return @"NEEDS-ACTION";
    case iCalPersonPartStatAccepted:
      return @"ACCEPTED";
    case iCalPersonPartStatDeclined:
      return @"DECLINED";
    case iCalPersonPartStatTentative:
      return @"TENTATIVE";
    case iCalPersonPartStatDelegated:
      return @"DELEGATED";
  }
  return @"OTHER";
}

- (NSString *)participationStatusLabel {
  return [NSString stringWithFormat:@"partStat_%@",
                                    [self participationStatus]];
}

@end
