/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var contactSelectorAction = 'calendars-contacts';

function uixEarlierDate(date1, date2) {
  // can this be done in a sane way?
  if (date1 && date2) {
    if (date1.getYear()  < date2.getYear()) return date1;
    if (date1.getYear()  > date2.getYear()) return date2;
    // same year
    if (date1.getMonth() < date2.getMonth()) return date1;
    if (date1.getMonth() > date2.getMonth()) return date2;
    // same month
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

        var startHour, startMinute, endHour, endMinute;
        var matches;
    
        matches = document.forms[0]['startTime_time'].value.match(/([0-9]+):([0-9]+)/);
        if (matches) {
            startHour = parseInt(matches[1]);
            startMinute = parseInt(matches[2]);
            matches = document.forms[0]['dueTime_time'].value.match(/([0-9]+):([0-9]+)/);
            if (matches) {
                endHour = parseInt(matches[1]);
                endMinute = parseInt(matches[2]);

                if (startHour > endHour) {
                    alert(labels.validate_endbeforestart);
                    return false;
                }
                else if (startHour == endHour) {
                    if (startMinute > endMinute) {
                        alert(labels.validate_endbeforestart);
                        return false;
                    }
                }
            }
            else {
                alert(labels.validate_invalid_enddate);
                return false;
            }
        }
        else {
            alert(labels.validate_invalid_startdate);
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
    $("detailsButton").innerHTML = _("Show Details");
  } else {
    div.style.visibility = 'visible;';
    window.resizeBy(0, (div.clientHeight + buttonsHeight));
    $("detailsButton").innerHTML = _("Hide Details");
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
                              + ResourcesURL + '/abcard.png" />'
                              + contactName + '</li>');
        }
      else
        log ("match... ignoring contact");
    }

  return false;
}

function onTimeControlCheck(checkBox) {
    if (checkBox) {
        var inputs = checkBox.parentNode.getElementsByTagName("input");
        var selects = checkBox.parentNode.getElementsByTagName("select");
        for (var i = 0; i < inputs.length; i++)
            if (inputs[i] != checkBox)
                inputs[i].disabled = !checkBox.checked;
        for (var i = 0; i < selects.length; i++)
            if (selects[i] != checkBox)
                selects[i].disabled = !checkBox.checked;
	if (checkBox.id == "startDateCB")
            $("reminderList").disabled = !checkBox.checked;
    }
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
	var date = window.timeWidgets[which]['date'].inputAsDate();
        var time = window.timeWidgets[which]['time'].value.split(":");
        date.setHours(time[0]);
        date.setMinutes(time[1]);

	return date;
};

this._getShadowDate = function(which) {
	var date = window.timeWidgets[which]['date'].getAttribute("shadow-value").asDate();
        var time = window.timeWidgets[which]['time'].getAttribute("shadow-value").split(":");
        date.setHours(time[0]);
        date.setMinutes(time[1]);
   
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
	window.timeWidgets[which]['date'].setInputAsDate(newDate);
        window.timeWidgets[which]['time'].value = newDate.getDisplayHoursString();
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
	window.timeWidgets['start']['time'].updateShadowValue();
};
   
this.initTimeWidgets = function (widgets) {
	this.timeWidgets = widgets;
   
	widgets['start']['date'].observe("change", this.onAdjustDueTime, false);
	widgets['start']['time'].observe("time:change", this.onAdjustDueTime, false);
        widgets['start']['time'].addInterface(SOGoTimePickerInterface);
        widgets['due']['time'].addInterface(SOGoTimePickerInterface);
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
  if (statusList) {
      statusList.observe("change", onStatusListChange);
  }
}

function onTaskEditorLoad() {
    assignCalendar('startTime_date');
    assignCalendar('dueTime_date');
    assignCalendar('statusTime_date');
    
    if (readOnly == false) {
        var widgets = {'start': {'date': $("startTime_date"),
                                 'time': $("startTime_time")},
                       'due':   {'date': $("dueTime_date"),
                                 'time': $("dueTime_time")}};
        initTimeWidgets(widgets);
    }

    // Enable or disable the reminder list
    onTimeControlCheck($("startDateCB"));

    initializeStatusLine();
}

document.observe("dom:loaded", onTaskEditorLoad);
