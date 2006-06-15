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


#ifndef	__NGLogging_H_
#define	__NGLogging_H_

/*
  NGLogging is a somewhat more sophisticated logging framework, modeled
  apparently similar to log4j - without some of its bloat. The current
  idea is to replace the default logging used throughout OGo (-logWithFormat:,
  -debugWithFormat:, NSLog()) with the new logging framework to get rid of
  stdout only logging.
*/


#import <Foundation/Foundation.h>

#include "NSObject+ExtendedLogging.h"
#include "NGLogger.h"


#endif	/* __NGLogging_H_ */
