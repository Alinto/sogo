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

var contactSelectorAction = 'calendars-contacts';

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

  e = $('summary');
  if (e.value.length == 0) {
    if (!confirm(labels.validate_notitle.decodeEntities()))
      return false;
  }

  e = $('startTime_date');
  if (e.value.length != 10) {
    alert(labels.validate_invalid_startdate.decodeEntities());
    return false;
  }
  startdate = e.calendar.prs_date(e.value);
  if (startdate == null) {
    alert(labels.validate_invalid_startdate.decodeEntities());
    return false;
  }
      
  e = $('endTime_date');
  if (e.value.length != 10) {
    alert(labels.validate_invalid_enddate.decodeEntities());
    return false;
  }
  enddate = e.calendar.prs_date(e.value);
  if (enddate == null) {
    alert(labels.validate_invalid_enddate.decodeEntities());
    return false;
  }
//   cuicui = '';
  tmpdate = uixEarlierDate(startdate, enddate);
  if (tmpdate == enddate) {
//     window.alert(cuicui);
    alert(labels.validate_endbeforestart.decodeEntities());
    return false;
  }
  else if (tmpdate == null /* means: same date */) {
    // TODO: check time
    var start, end;
    
    start = parseInt(document.forms[0]['startTime_time_hour'].value);
    end = parseInt(document.forms[0]['endTime_time_hour'].value);

    if (start > end) {
      alert(labels.validate_endbeforestart.decodeEntities());
      return false;
    }
    else if (start == end) {
      start = parseInt(document.forms[0]['startTime_time_minute'].value);
      end = parseInt(document.forms[0]['endTime_time_minute'].value);
      if (start > end) {
	alert(labels.validate_endbeforestart.decodeEntities());
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

function saveEvent(sender) {
  if (validateAptEditor())
    document.forms['editform'].submit();

  return false;
}

function startDayAsShortString() {
  return $('startTime_date').valueAsShortDateString();
}

function endDayAsShortString() {
  return $('endTime_date').valueAsShortDateString();
}

this._getDate = function(which) {
  var date = window.timeWidgets[which]['date'].valueAsDate();
  date.setHours( window.timeWidgets[which]['hour'].value );
  date.setMinutes( window.timeWidgets[which]['minute'].value );

  return date;
}

this._getShadowDate = function(which) {
  var date = window.timeWidgets[which]['date'].getAttribute("shadow-value").asDate();
  var intValue = parseInt(window.timeWidgets[which]['hour'].getAttribute("shadow-value"));
  date.setHours(intValue);
  intValue = parseInt(window.timeWidgets[which]['minute'].getAttribute("shadow-value"));
  date.setMinutes(intValue);
//   window.alert("shadow: " + date);

  return date;
}

this.getStartDate = function() {
  return this._getDate('start');
}

this.getEndDate = function() {
  return this._getDate('end');
}

this.getShadowStartDate = function() {
  return this._getShadowDate('start');
}

this.getShadowEndDate = function() {
  return this._getShadowDate('end');
}

this._setDate = function(which, newDate) {
  window.timeWidgets[which]['date'].setValueAsDate(newDate);
  window.timeWidgets[which]['hour'].value = newDate.getHours();
  var minutes = newDate.getMinutes();
  if (minutes % 15)
    minutes += (15 - minutes % 15);
  window.timeWidgets[which]['minute'].value = minutes;
}

this.setStartDate = function(newStartDate) {
  this._setDate('start', newStartDate);
}

this.setEndDate = function(newEndDate) {
//   window.alert(newEndDate);
  this._setDate('end', newEndDate);
}

this.onAdjustEndTime = function(event) {
  var dateDelta = (window.getStartDate().valueOf()
                   - window.getShadowStartDate().valueOf());
//   window.alert(window.getEndDate().valueOf() + '  ' + dateDelta);
  var newEndDate = new Date(window.getEndDate().valueOf() + dateDelta);
  window.setEndDate(newEndDate);
  window.timeWidgets['start']['date'].updateShadowValue();
  window.timeWidgets['start']['hour'].updateShadowValue();
  window.timeWidgets['start']['minute'].updateShadowValue();
}

this.initTimeWidgets = function (widgets) {
  this.timeWidgets = widgets;

  widgets['start']['date'].addEventListener("change", this.onAdjustEndTime, false);
  widgets['start']['hour'].addEventListener("change", this.onAdjustEndTime, false);
  widgets['start']['minute'].addEventListener("change", this.onAdjustEndTime, false);
}
