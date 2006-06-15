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


#ifndef	__NSObject_ExtendedLogging_H_
#define	__NSObject_ExtendedLogging_H_


#import <Foundation/Foundation.h>


typedef enum {
    NGLogLevelAll = 0,
    NGLogLevelDebug = 1,
    NGLogLevelInfo = 2,
    NGLogLevelWarn = 3,
    NGLogLevelError = 4,
    NGLogLevelFatal = 5,
    NGLogLevelOff = 6
} NGLogLevel;


@interface NSObject (NGExtendedLogging)

- (id)sharedLogger;
- (id)logger;

- (void)logDebugWithFormat:(NSString *)_fmt, ...;
- (void)logInfoWithFormat:(NSString *)_fmt, ...;
- (void)logWarnWithFormat:(NSString *)_fmt, ...;
- (void)logErrorWithFormat:(NSString *)_fmt, ...;
- (void)logFatalWithFormat:(NSString *)_fmt, ...;

- (BOOL)isLogDebugEnabled;
- (BOOL)isLogInfoEnabled;
- (BOOL)isLogWarnEnabled;
- (BOOL)isLogErrorEnabled;
- (BOOL)isLogFatalEnabled;

- (void)logLevel:(NGLogLevel)_level withFormat:(NSString *)_fmt, ...;

@end

#endif	/* __NSObject_ExtendedLogging_H_ */
