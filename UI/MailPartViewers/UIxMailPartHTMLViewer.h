/* UIxMailPartHTMLViewer.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2013 Inverse inc.
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

#ifndef UIXMAILPARTHTMLVIEWER_H
#define UIXMAILPARTHTMLVIEWER_H

#import "UIxMailPartViewer.h"

@interface UIxMailPartHTMLViewer : UIxMailPartViewer <SaxErrorHandler>
{
  id handler;
  NSException *ex;
  BOOL rawContent;
}

- (NSString *) flatContentAsString;
- (void)activateRawContent;

@end

@interface UIxMailPartExternalHTMLViewer : UIxMailPartViewer
{
  id handler;
  NSException *ex;
}

- (NSString *) flatContentAsString;

@end

#endif /* UIXMAILPARTHTMLVIEWER_H */
