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
// $Id$


#import "NGLogAppender.h"
#import "NGLogEvent.h"


@implementation NGLogAppender

- (void)appendLogEvent:(NGLogEvent *)_event {
    [self subclassResponsibility:_cmd];
}

- (NSString *)formattedEvent:(NGLogEvent *)_event {
    return [NSString stringWithFormat:@"[%@] %@",
        [self localizedNameOfLogLevel:[_event level]],
        [_event message]];
}

- (NSString *)localizedNameOfLogLevel:(NGLogLevel)_level {
    NSString *name;

    switch (_level) {
        case NGLogLevelDebug:
            name = @"DEBUG";
            break;
        case NGLogLevelInfo:
            name = @"INFO";
            break;
        case NGLogLevelWarn:
            name = @"WARN";
            break;
        case NGLogLevelError:
            name = @"ERROR";
            break;
        case NGLogLevelFatal:
            name = @"FATAL";
            break;
        default:
            name = @"";
            break;
    }
    return name;
}

@end
