/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#ifndef __Mailer_UIxMailPartLinkViewer_H__
#define __Mailer_UIxMailPartLinkViewer_H__

#import "UIxMailPartViewer.h"

/*
  UIxMailPartLinkViewer
  
  The generic viewer for all kinds of attachments. Renders a link to download
  the attachment.

  TODO: show info based on the 'bodyInfo' dictionary:
        { 
          bodyId = ""; 
          description = ""; 
          encoding = BASE64; 
          parameterList = { 
            "x-unix-mode" = 0666; 
             name = "IncoWEBOpenGroupwarepresentation.pdf"; 
          }; 
          size = 1314916; 
          subtype = PDF; type = application; 
        }
*/

@interface UIxMailPartLinkViewer : UIxMailPartViewer
{
}

@end

#endif /* __Mailer_UIxMailPartLinkViewer_H__ */
