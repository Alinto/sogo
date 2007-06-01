/* SOGoPermissions.h - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#ifndef SOGOPERMISSIONS_H
#define SOGOPERMISSIONS_H

#import <Foundation/NSString.h>

#import <NGObjWeb/SoPermissions.h>

extern NSString *SOGoRole_ObjectCreator;
extern NSString *SOGoRole_ObjectEraser;
extern NSString *SOGoRole_ObjectReader;
extern NSString *SOGoRole_ObjectViewer;
extern NSString *SOGoRole_ObjectEditor;

extern NSString *SOGoRole_FolderCreator;
extern NSString *SOGoRole_FolderEraser;
extern NSString *SOGoRole_FolderViewer;

extern NSString *SOGoRole_AuthorizedSubscriber;
extern NSString *SOGoRole_None;
extern NSString *SOGoRole_FreeBusy;
extern NSString *SOGoRole_FreeBusyLookup;

extern NSString *SOGoMailRole_SeenKeeper;
extern NSString *SOGoMailRole_Writer;
extern NSString *SOGoMailRole_Poster;
extern NSString *SOGoMailRole_Expunger;
extern NSString *SOGoMailRole_Creator;
extern NSString *SOGoMailRole_Administrator;

extern NSString *SOGoCalendarRole_Organizer;
extern NSString *SOGoCalendarRole_Participant;

extern NSString *SOGoCalendarRole_PublicViewer;
extern NSString *SOGoCalendarRole_PublicDAndTViewer;
extern NSString *SOGoCalendarRole_PublicModifier;
extern NSString *SOGoCalendarRole_PublicResponder;
extern NSString *SOGoCalendarRole_PrivateViewer;
extern NSString *SOGoCalendarRole_PrivateDAndTViewer;
extern NSString *SOGoCalendarRole_PrivateModifier;
extern NSString *SOGoCalendarRole_PrivateResponder;
extern NSString *SOGoCalendarRole_ConfidentialViewer;
extern NSString *SOGoCalendarRole_ConfidentialDAndTViewer;
extern NSString *SOGoCalendarRole_ConfidentialModifier;
extern NSString *SOGoCalendarRole_ConfidentialResponder;

extern NSString *SOGoCalendarRole_ComponentViewer;
extern NSString *SOGoCalendarRole_ComponentDAndTViewer;
extern NSString *SOGoCalendarRole_ComponentModifier;
extern NSString *SOGoCalendarRole_ComponentResponder;

extern NSString *SOGoPerm_AccessObject;
extern NSString *SOGoPerm_ReadAcls;
extern NSString *SOGoPerm_FreeBusyLookup;

extern NSString *SOGoCalendarPerm_ViewWholePublicRecords;
extern NSString *SOGoCalendarPerm_ViewDAndTOfPublicRecords;
extern NSString *SOGoCalendarPerm_ModifyPublicRecords;
extern NSString *SOGoCalendarPerm_RespondToPublicRecords;
extern NSString *SOGoCalendarPerm_ViewWholePrivateRecords;
extern NSString *SOGoCalendarPerm_ViewDAndTOfPrivateRecords;
extern NSString *SOGoCalendarPerm_ModifyPrivateRecords;
extern NSString *SOGoCalendarPerm_RespondToPrivateRecords;
extern NSString *SOGoCalendarPerm_ViewWholeConfidentialRecords;
extern NSString *SOGoCalendarPerm_ViewDAndTOfConfidentialRecords;
extern NSString *SOGoCalendarPerm_ModifyConfidentialRecords;
extern NSString *SOGoCalendarPerm_RespondToConfidentialRecords;

extern NSString *SOGoCalendarPerm_ViewAllComponent;
extern NSString *SOGoCalendarPerm_ViewDAndT;
extern NSString *SOGoCalendarPerm_ModifyComponent;
extern NSString *SOGoCalendarPerm_RespondToComponent;

#endif /* SOGOPERMISSIONS_H */
