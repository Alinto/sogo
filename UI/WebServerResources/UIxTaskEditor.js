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

var contactSelectorAction = 'scheduler-contacts';

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

function toggleDetails() {
  var div = $("details");
  var buttons = $("buttons");
  var buttonsHeight = buttons.clientHeight * 3;

  if (div.style.visibility) {
    div.style.visibility = null;
    window.resizeBy(0, -(div.clientHeight + buttonsHeight));
    $("detailsButton").innerHTML = labels["Show Details"];
  } else {
    div.style.visibility = 'visible;';
    window.resizeBy(0, (div.clientHeight + buttonsHeight));
    $("detailsButton").innerHTML = labels["Hide Details"];
  }

  return false;
}

function toggleCycleVisibility(node, nodeName, hiddenValue) {
  var spanNode = $(nodeName);
  var newVisibility = ((node.value == hiddenValue) ? null : 'visible;');
  spanNode.style.visibility = newVisibility;

  if (nodeName == 'cycleSelectionFirstLevel') {
    var otherSpanNode = $('cycleSelectionSecondLevel');
    if (!newVisibility)
      {
        otherSpanNode.superVisibility = otherSpanNode.style.visibility;
        otherSpanNode.style.visibility = null;
      }
    else
      {
        otherSpanNode.style.visibility = otherSpanNode.superVisibility;
        otherSpanNode.superVisibility = null;
      }
  }
}

function addContact(tag, fullContactName, contactId, contactName, contactEmail)
{
  var uids = $('uixselector-participants-uidList');
  log ("contactId: " + contactId);
  if (contactId)
    {
      var re = new RegExp("(^|,)" + contactId + "($|,)");

      log ("uids: " + uids);
      if (!re.test(uids.value))
        {
          log ("no match... realling adding");
          if (uids.value.length > 0)
            uids.value += ',' + contactId;
          else
            uids.value = contactId;

          log ('values: ' + uids.value);
          var names = $('uixselector-participants-display');
          names.innerHTML += ('<li onmousedown="return false;"'
                              + ' onclick="onRowClick(event);"><img src="'
                              + ResourcesURL + '/abcard.gif" />'
                              + contactName + '</li>');
        }
      else
        log ("match... ignoring contact");
    }

  return false;
}
