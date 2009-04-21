/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

var contactSelectorAction = 'calendars-contacts';

function uixEarlierDate(date1, date2) {
  // can this be done in a sane way?
  //   cuicui = 'year';
  if (date1 && date2) {
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
  }
  // same day
  return null;
}

function validateDate(date, label) {
  var result, dateValue;

  dateValue = date.calendar.prs_date(date.value);
  if (date.value.length != 10 || !dateValue) {
    alert(label);
    result = false;
  } else
    result = dateValue;

  return result;
}

function validateTaskEditor() {
  var e, startdate, enddate, tmpdate;

  e = document.getElementById('summary');
  if (e.value.length == 0
      && !confirm(labels.validate_notitle))
    return false;

  e = document.getElementById('startTime_date');
  if (!e.disabled) {
    startdate = validateDate(e, labels.validate_invalid_startdate);
    if (!startdate)
      return false;
  }

  e = document.getElementById('dueTime_date');
  if (!e.disabled) {
    enddate = validateDate(e, labels.validate_invalid_enddate);
    if (!enddate)
      return false;
  }
	
  if (startdate && enddate) {
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
      end = parseInt(document.forms[0]['dueTime_time_hour'].value);
      
      if (start > end) {
        alert(labels.validate_endbeforestart);
        return false;
      }
      else if (start == end) {
        start = parseInt(document.forms[0]['startTime_time_minute'].value);
        end = parseInt(document.forms[0]['dueTime_time_minute'].value);
        if (start > end) {
          alert(labels.validate_endbeforestart);
          return false;
        }
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

function addContact(tag, fullContactName, contactId, contactName, contactEmail) {
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

function onTimeControlCheck(checkBox) {
  var inputs = checkBox.parentNode.getElementsByTagName("input");
  var selects = checkBox.parentNode.getElementsByTagName("select");
  for (var i = 0; i < inputs.length; i++)
    if (inputs[i] != checkBox)
      inputs[i].disabled = !checkBox.checked;
  for (var i = 0; i < selects.length; i++)
    if (selects[i] != checkBox)
      selects[i].disabled = !checkBox.checked;
	if (checkBox.id == "dueDateCB")
		$("reminderList").disabled = !checkBox.checked;
}

function saveEvent(sender) {
  if (validateTaskEditor())
    document.forms['editform'].submit();

  return false;
}

function startDayAsShortString() {
  return dayAsShortDateString($('startTime_date'));
}

function dueDayAsShortString() {
  return dayAsShortDateString($('dueTime_date'));
}

this._getDate = function(which) {
	var date = window.timeWidgets[which]['date'].valueAsDate();
	date.setHours( window.timeWidgets[which]['hour'].value );
	date.setMinutes( window.timeWidgets[which]['minute'].value );
   
	return date;
};

this._getShadowDate = function(which) {
	var date = window.timeWidgets[which]['date'].getAttribute("shadow-value").asDate();
	var intValue = parseInt(window.timeWidgets[which]['hour'].getAttribute("shadow-value"));
	date.setHours(intValue);
	intValue = parseInt(window.timeWidgets[which]['minute'].getAttribute("shadow-value"));
	date.setMinutes(intValue);
	//   window.alert("shadow: " + date);
   
	return date;
};

this.getStartDate = function() {
	return this._getDate('start');
};

this.getDueDate = function() {
	return this._getDate('due');
};
   
this.getShadowStartDate = function() {
	return this._getShadowDate('start');
};

this.getShadowDueDate = function() {
	return this._getShadowDate('due');
};

this._setDate = function(which, newDate) {
	window.timeWidgets[which]['date'].setValueAsDate(newDate);
	window.timeWidgets[which]['hour'].value = newDate.getHours();
	var minutes = newDate.getMinutes();
	if (minutes % 15)
		minutes += (15 - minutes % 15);
	window.timeWidgets[which]['minute'].value = minutes;
};

this.setStartDate = function(newStartDate) {
	this._setDate('start', newStartDate);
};

this.setDueDate = function(newDueDate) {
	//   window.alert(newDueDate);
	this._setDate('due', newDueDate);
};

this.onAdjustTime = function(event) {
	onAdjustDueTime(event);
};

this.onAdjustDueTime = function(event) {
  if (!window.timeWidgets['due']['date'].disabled) {
		var dateDelta = (window.getStartDate().valueOf()
										 - window.getShadowStartDate().valueOf());
		var newDueDate = new Date(window.getDueDate().valueOf() + dateDelta);
		window.setDueDate(newDueDate);
	}
	window.timeWidgets['start']['date'].updateShadowValue();
	window.timeWidgets['start']['hour'].updateShadowValue();
	window.timeWidgets['start']['minute'].updateShadowValue();
};
   
this.initTimeWidgets = function (widgets) {
	this.timeWidgets = widgets;
   
	widgets['start']['date'].observe("change", this.onAdjustDueTime, false);
	widgets['start']['hour'].observe("change", this.onAdjustDueTime, false);
	widgets['start']['minute'].observe("change", this.onAdjustDueTime, false);
};
   
function onStatusListChange(event) {
	var value = $("statusList").value;
	var statusTimeDate = $("statusTime_date");
	var statusPercent = $("statusPercent");
   
	if (value == "WONoSelectionString") {
		statusTimeDate.disabled = true;
		statusPercent.disabled = true;
		statusPercent.value = "";
	}
	else if (value == "0") {
		statusTimeDate.disabled = true;
		statusPercent.disabled = false;
	}
	else if (value == "1") {
		statusTimeDate.disabled = true;
		statusPercent.disabled = false;
	}
	else if (value == "2") {
		statusTimeDate.disabled = false;
		statusPercent.disabled = false;
		statusPercent.value = "100";
	}
	else if (value == "3") {
		statusTimeDate.disabled = true;
		statusPercent.disabled = true;
	}
	else {
		statusTimeDate.disabled = true;
	}
}

function initializeStatusLine() {
  var statusList = $("statusList");
  statusList.observe("mouseup", onStatusListChange, false);
}

function onTaskEditorLoad() {
	assignCalendar('startTime_date');
	assignCalendar('dueTime_date');
	assignCalendar('statusTime_date');

	var widgets = {'start': {'date': $("startTime_date"),
													 'hour': $("startTime_time_hour"),
													 'minute': $("startTime_time_minute")},
								 'due':   {'date': $("dueTime_date"),
													 'hour': $("dueTime_time_hour"),
													 'minute': $("dueTime_time_minute")}};
	initTimeWidgets(widgets);
	
	// Enable or disable the reminder list
	onTimeControlCheck($("dueDateCB"));

  initializeStatusLine();
}

document.observe("dom:loaded", onTaskEditorLoad);
