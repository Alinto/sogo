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


#import "NGLogSyslogAppender.h"
#import "NGLogEvent.h"
#include <syslog.h>
#include <stdarg.h>


@interface NGLogSyslogAppender (PrivateAPI)
- (int)syslogLevelForLogLevel:(NGLogLevel)_level;
@end

@implementation NGLogSyslogAppender


static NSString *defaultSyslogIdentifier = nil;


+ (void)initialize {
  NSUserDefaults *ud;
  static BOOL isInitialized = NO;

  if(isInitialized)
    return;

  ud = [NSUserDefaults standardUserDefaults];
  defaultSyslogIdentifier =
    [[ud stringForKey:@"NGLogSyslogIdentifier"] retain];

  isInitialized = YES;
}

+ (id)sharedAppender {
  static id sharedAppender = nil;
  if(sharedAppender == nil) {
    sharedAppender = [[self alloc] init];
  }
  return sharedAppender;
}

- (id)init {
    return [self initWithIdentifier:defaultSyslogIdentifier];
}

- (id)initWithIdentifier:(NSString *)_ident {
  if((self = [super init])) {
    #warning ** default flags?
    openlog([_ident cString], LOG_PID | LOG_NDELAY, LOG_USER);
  }
  return self;
}

- (void)dealloc {
  closelog();
  [super dealloc];
}

- (void)appendLogEvent:(NGLogEvent *)_event {
  NSString *formattedMsg;
  int level;

  formattedMsg = [self formattedEvent:_event];
  level = [self syslogLevelForLogLevel:[_event level]];
  syslog(level, [formattedMsg cString]);
}

- (int)syslogLevelForLogLevel:(NGLogLevel)_level {
    int level;
    
    switch (_level) {
        case NGLogLevelDebug:
            level = LOG_DEBUG;
            break;
        case NGLogLevelInfo:
            level = LOG_INFO;
            break;
        case NGLogLevelWarn:
            level = LOG_WARNING;
            break;
        case NGLogLevelError:
            level = LOG_ERR;
            break;
        case NGLogLevelFatal:
            level = LOG_ALERT; // LOG_EMERG is broadcast to all users...
            break;
        default:
            level = LOG_NOTICE;
            break;
    }
    return level;
}

@end
