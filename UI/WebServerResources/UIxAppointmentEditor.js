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

// var cuicui = '';

function uixEarlierDate(date1, date2) {
  // can this be done in a sane way?
//   cuicui = 'year';
  if (date1.getYear()  < date2.getYear()) return date1;
  if (date1.getYear()  > date2.getYear()) return date2;
  // same year
//   cuicui += '/month';
  if (date1.getMonth() < date2.getMonth()) return date1;
  if (date1.getMonth() > date2.getMonth()) return date2;
//   // same month
//   cuicui += '/date';
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
  startdate = e.calendar.prs_date(e.value);
  if (startdate == null) {
    alert(labels.validate_invalid_startdate);
    return false;
  }
      
  e = document.getElementById('endTime_date');
  if (e.value.length != 10) {
    alert(labels.validate_invalid_enddate);
    return false;
  }
  enddate = e.calendar.prs_date(e.value);
  if (enddate == null) {
    alert(labels.validate_invalid_enddate);
    return false;
  }
//   cuicui = '';
  tmpdate = uixEarlierDate(startdate, enddate);
  if (tmpdate == enddate) {
//     window.alert(cuicui);
    alert(labels.validate_endbeforestart);
    return false;
  }
  else if (tmpdate == null /* means: same date */) {
    // TODO: check time
    var start, end;
    
    start = parseInt(document.forms[0]['startTime_time_hour'].value);
    end = parseInt(document.forms[0]['endTime_time_hour'].value);

    if (start > end) {
      alert(labels.validate_endbeforestart);
      return false;
    }
    else if (start == end) {
      start = parseInt(document.forms[0]['startTime_time_minute'].value);
      end = parseInt(document.forms[0]['endTime_time_minute'].value);
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

  if (validateAptEditor()) {
    thisForm.submit();
    window.opener.setTimeout('refreshAppointments();', 200);
    window.close();
  }
}

function toggleDetails() {
  var div = $("details");

  var buttonsDiv = $("buttons");
  var wHeight = 0;
  if (!window._fullHeight) {
    var minHeight = (buttonsDiv.offsetTop + 2 * buttonsDiv.clientHeight);
    window._fullHeight = minHeight + div.clientHeight;
    window._hiddenHeight = minHeight;
  }

  if (div.style.visibility) {
    div.style.visibility = null;
    buttonsDiv.top = (window._hiddenHeight + buttonsDiv.clientHeight) + 'px;';
    window.resizeTo(document.body.clientWidth, window._hiddenHeight);
    $("detailsButton").innerHTML = labels["Show Details"];
  } else {
    div.style.visibility = 'visible;';
    buttonsDiv.top = null;
    window.resizeTo(document.body.clientWidth, window._fullHeight);
    $("detailsButton").innerHTML = labels["Hide Details"];
  }

  return false;
}

function toggleCycleVisibility(node, className, hiddenValue) {
  var containers = document.getElementsByClassName(className);
  var newVisibility = ((node.value == hiddenValue) ? null : 'visible;');
  for (var i = 0; i < containers.length; i++)
    containers[i].style.visibility = newVisibility;
}
