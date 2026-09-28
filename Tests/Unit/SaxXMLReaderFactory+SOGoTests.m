/* SaxXMLReaderFactory+SOGoTests.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2011 Inverse inc
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

#import <Foundation/NSArray.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSPathUtilities.h>

#import <SaxObjC/SaxXMLReaderFactory.h>

@interface SaxXMLReaderFactory (SOGoTests)

- (NSArray *) saxReaderSearchPathes;
- (NSString *) libraryDriversSubDir;

@end

@implementation SaxXMLReaderFactory (SOGoTests)

- (NSArray *) saxReaderSearchPathes
{
  NSMutableArray *pathes;
  NSArray *args, *libraryPaths;
  NSEnumerator *e;
  NSString *exedir, *libraryPath;

  args = [[NSProcessInfo processInfo] arguments];
  exedir = [[args objectAtIndex: 0] stringByDeletingLastPathComponent];
  pathes = [NSMutableArray array];
  [pathes addObject: [NSString stringWithFormat: @"%@/%@",
                                exedir,
                                @"../../../SOPE/NGCards/versitCardsSaxDriver/"]];

  /* Keep the standard SaxDrivers locations reachable so that parsers
     for other MIME types (eg. text/html through libxml) stay loadable */
  e = [NSStandardLibraryPaths() objectEnumerator];
  while ((libraryPath = [e nextObject]))
    [pathes addObject: [libraryPath stringByAppendingPathComponent:
                                   [self libraryDriversSubDir]]];

  return pathes;
}

@end
