/*
 Copyright (C) 2005 SKYRIX Software AG
 
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

function uixEarlierDate(date1, date2) {
  // can this be done in a sane way?
  if (date1.getYear()  < date2.getYear()) return date1;
  if (date1.getYear()  > date2.getYear()) return date2;
  // same year
  if (date1.getMonth() < date2.getMonth()) return date1;
  if (date1.getMonth() > date2.getMonth()) return date2;
  // same month
  if (date1.getDate() < date2.getDate()) return date1;
  if (date1.getDate() > date2.getDate()) return date2;
  // same day
  return null;
}

function validateAptEditor() {
  var e, startdate, enddate, tmpdate;
      
  e = document.getElementById('summary');
  if (e.value.length == 0) {
    if (!confirm(labels.validate_notitle))
      return false;
  }

  e = document.getElementById('startTime_date');
  if (e.value.length != 10) {
    alert(labels.validate_invalid_startdate);
    return false;
  }
  startdate = calendar_startTime_date.prs_date(e.value);
  if (startdate == null) {
    alert(labels.validate_invalid_startdate);
    return false;
  }
      
  e = document.getElementById('endTime_date');
  if (e.value.length != 10) {
    alert(labels.validate_invalid_enddate);
    return false;
  }
  enddate = calendar_endTime_date.prs_date(e.value);
  if (enddate == null) {
    alert(labels.validate_invalid_enddate);
    return false;
  }
  
  tmpdate = uixEarlierDate(startdate, enddate);
  if (tmpdate == enddate) {
    alert(labels.validate_endbeforestart);
    return false;
  }
  else if (tmpdate == null /* means: same date */) {
    // TODO: check time
    var start, end;
    
    start = document.forms[0]['startTime_time_hour'].value;
    end   = document.forms[0]['endTime_time_hour'].value;
    if (start > end) {
      alert(labels.validate_endbeforestart);
      return false;
    }
    else if (start == end) {
      start = document.forms[0]['startTime_time_minute'].value;
      end   = document.forms[0]['endTime_time_minute'].value;
      if (start > end) {
	alert(labels.validate_endbeforestart);
	return false;
      }
    }
  }

  return true;
}

function submitMeeting(thisForm) {
  var action = document.getElementById('jsaction');
  action.setAttribute("name", "save:method");
  action.setAttribute("value", "save");

  thisForm.submit();
  opener.window.location.reload();
  window.close();
}
