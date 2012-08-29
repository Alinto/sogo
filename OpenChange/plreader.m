/* plreader.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* A format-agnostic property list dumper.
   Usage: plreader [filename] */

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSProcessInfo.h>

#import "NSObject+PropertyList.m"

static void
PLReaderDumpPListFile (NSString *filename)
{
  NSData *content;

  content = [NSData dataWithContentsOfFile: filename];
  OCDumpPListData (content);
}

int main()
{
  NSAutoreleasePool *p;
  NSProcessInfo *pi;
  NSArray *arguments;

  p = [NSAutoreleasePool new];
  pi = [NSProcessInfo processInfo];
  arguments = [pi arguments];
  if ([arguments count] > 1)
    PLReaderDumpPListFile ([arguments objectAtIndex: 1]);
  [p release];

  return 0;
}
