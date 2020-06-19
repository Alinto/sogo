/* SOGoZipArchiver.h - this file is part of SOGo
 *
 * Copyright (C) 2020 Inverse inc.
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

#ifndef SOGOZIPARCHIVER_H
#define SOGOZIPARCHIVER_H

#include <zip.h>

@interface SOGoZipArchiver : NSObject
{
  /* we use zip instead of zip_t for backward compatibility */
  struct zip *z;
}

- (id) initFromFile: (NSString *) file;
+ (id) archiverAtPath: (NSString *) file;

- (BOOL) putFileWithName: (NSString *) filename andData: (NSData *) data;
- (BOOL) close;
@end

#endif /* SOGOZIPARCHIVER_H */
