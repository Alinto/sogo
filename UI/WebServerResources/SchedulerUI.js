/* JavaScript for SOGoCalendar */

var listFilter = 'view_today';

var listOfSelection = null;
var selectedCalendarCell;
var calendarColorIndex = null;

var showCompletedTasks = 0;

var currentDay = '';
var currentView = "weekview";

var cachedDateSelectors = new Array();

var contactSelectorAction = 'calendars-contacts';

var eventsToDelete = new Array();
var calendarsOfEventsToDelete = new Array();

var usersRightsWindowHeight = 250;
var usersRightsWindowWidth = 502;

function newEvent(sender, type) {
   var day = sender.readAttribute("day");
   if (!day)
      day = currentDay;
   var hour = sender.readAttribute("hour");
   var folder = getSelectedFolder();
   var folderID = folder.readAttribute("id");
   var roles = folder.readAttribute("roles");
   if (roles) {
     roles = roles.split(",")
       if ($(roles).indexOf("PublicModifier") < 0)
	 folderID = "/personal";
   }
   var urlstr = ApplicationBaseURL + folderID + "/new" + type;
   var params = new Array();
   if (day)
      params.push("day=" + day);
   if (hour)
      params.push("hm=" + hour);
   if (params.length > 0)
      urlstr += "?" + params.join("&");
   window.open(urlstr, "", "width=490,height=470,resizable=0");
   
   return false; /* stop following the link */
}

function getSelectedFolder() {
  var folder;
  var list = $("calendarList");
  var nodes = list.getSelectedRows();
  if (nodes.length > 0)
    folder = nodes[0];
  else
    folder = list.down("li");

  return folder;
}

function onMenuNewEventClick(event) {
   newEvent(this, "event");
}

function onMenuNewTaskClick(event) {
   newEvent(this, "task");
}

function _editEventId(id, calendar) {
  var urlstr = ApplicationBaseURL + "/" + calendar + "/" + id + "/edit";
  var targetname = "SOGo_edit_" + id;
  var win = window.open(urlstr, "_blank",
                        "width=490,height=470,resizable=0");
  if (win)
    win.focus();
}

function editEvent() {
  if (listOfSelection) {
    var nodes = listOfSelection.getSelectedRows();

    if (nodes.length == 0) {
      window.alert(labels["Please select an event or a task."]);
      return false;
    }

    for (var i = 0; i < nodes.length; i++)
      _editEventId(nodes[i].getAttribute("id"),
                   nodes[i].calendar);
  } else if (selectedCalendarCell) {
    _editEventId(selectedCalendarCell[0].cname,
                 selectedCalendarCell[0].calendar);
  } else {
    window.alert(labels["Please select an event or a task."]);
  }

  return false; /* stop following the link */
}

function _batchDeleteEvents() {
  var events = eventsToDelete.shift();
  var calendar = calendarsOfEventsToDelete.shift();
  var urlstr = (ApplicationBaseURL + "/" + calendar
		+ "/batchDelete?ids=" + events.join('/'));
  document.deleteEventAjaxRequest = triggerAjaxRequest(urlstr,
                                                       deleteEventCallback,
                                                       events);
}

function deleteEvent() {
  if (listOfSelection) {
    var nodes = listOfSelection.getSelectedRows();

    if (nodes.length > 0) {
      var label = "";
      if (listOfSelection == $("tasksList"))
        label = labels["taskDeleteConfirmation"];
      else
        label = labels["eventDeleteConfirmation"];
      
      if (confirm(label)) {
        if (document.deleteEventAjaxRequest) {
          document.deleteEventAjaxRequest.aborted = true;
          document.deleteEventAjaxRequest.abort();
        }
        var sortedNodes = new Array();
        var calendars = new Array();

        for (var i = 0; i < nodes.length; i++) {
          var calendar = nodes[i].calendar;
          if (!sortedNodes[calendar]) {
	    sortedNodes[calendar] = new Array();
	    calendars.push(calendar);
          }
          sortedNodes[calendar].push(nodes[i].cname);
        }
        for (var i = 0; i < calendars.length; i++) {
          calendarsOfEventsToDelete.push(calendars[i]);
          eventsToDelete.push(sortedNodes[calendars[i]]);
        }
        _batchDeleteEvents();
      }
    } else {
      window.alert(labels["Please select an event or a task."]);
    }
  }
  else if (selectedCalendarCell) {
     var label = labels["eventDeleteConfirmation"];
     if (confirm(label)) {
        if (document.deleteEventAjaxRequest) {
           document.deleteEventAjaxRequest.aborted = true;
           document.deleteEventAjaxRequest.abort();
        }
        eventsToDelete.push([selectedCalendarCell[0].cname]);
        calendarsOfEventsToDelete.push(selectedCalendarCell[0].calendar);
        _batchDeleteEvents();
     }
  }
  else
    window.alert(labels["Please select an event or a task."]);

  return false;
}

function modifyEvent(sender, modification) {
  var currentLocation = '' + window.location;
  var arr = currentLocation.split("/");
  arr[arr.length-1] = modification;

  document.modifyEventAjaxRequest = triggerAjaxRequest(arr.join("/"),
                                                       modifyEventCallback,
                                                       modification);

  return false;
}

function closeInvitationWindow() {
  var closeDiv = document.createElement("div");
  document.body.appendChild(closeDiv);
  closeDiv.addClassName("javascriptPopupBackground");

  var closePseudoWin = document.createElement("div");
  document.body.appendChild(closePseudoWin);
  closePseudoWin.addClassName("javascriptMessagePseudoTopWindow");
  closePseudoWin.style.top = "0px;";
  closePseudoWin.style.left = "0px;";
  closePseudoWin.style.right = "0px;";
  closePseudoWin.appendChild(document.createTextNode(labels["closeThisWindowMessage"]));

  var calLink = document.createElement("a");
  closePseudoWin.appendChild(calLink);
  calLink.href = ApplicationBaseURL;
  calLink.appendChild(document.createTextNode(labels["Calendar"].toLowerCase()));
}

function modifyEventCallback(http) {
  if (http.readyState == 4) {
    if (http.status == 200) {
      var mailInvitation = queryParameters["mail-invitation"];
      if (mailInvitation && mailInvitation.toLowerCase() == "yes")
	closeInvitationWindow();
      else {
	window.opener.setTimeout("refreshEventsAndDisplay();", 100);
	window.setTimeout("window.close();", 100);
      }
    }
    else {
// 	 log("showing alert...");
      window.alert(labels["eventPartStatModificationError"]);
    }
    document.modifyEventAjaxRequest = null;
  }
}

function deleteEventCallback(http) {
  if (http.readyState == 4) {
    if (isHttpStatus204(http.status)) {
      var isTask = false;
      var nodes = http.callbackData;
      for (var i = 0; i < nodes.length; i++) {
	var node = $(nodes[i]);
	if (node) {
	  isTask = isTask || (node.parentNode.id == 'tasksList');
	  node.parentNode.removeChild(node);
	}
      }
      if (eventsToDelete.length)
	_batchDeleteEvents();
      else {
	document.deleteEventAjaxRequest = null;
	if (isTask)
	  refreshTasks();
	else {
	  refreshEvents();
	  changeCalendarDisplay();
	}
      }
    }
    else
      log ("deleteEventCallback Ajax error");
  }
}

function editDoubleClickedEvent(event) {
  _editEventId(this.cname, this.calendar);

  preventDefault(event);
  event.cancelBubble = true;
}

function onSelectAll() {
  var list = $("eventsList");
  list.selectRowsMatchingClass("eventRow");

  return false;
}

function onDaySelect(node) {
  var day = node.getAttribute('day');
  var needRefresh = (listFilter == 'view_selectedday'
                     && day != currentDay);

  var td = $(node).getParentWithTagName("td");
  var table = $(td).getParentWithTagName("table");

//   log ("table.selected: " + table.selected);

  if (document.selectedDate)
    document.selectedDate.deselect();

  td.select();
  document.selectedDate = td;

  changeCalendarDisplay( { "day": day } );
  currentDay = day;
  if (needRefresh)
    refreshEvents();

  return false;
}

function onDateSelectorGotoMonth(event) {
   var day = this.getAttribute("date");

   changeDateSelectorDisplay(day, true);

   Event.stop(event);
}

function onCalendarGotoDay(node) {
   var day = node.getAttribute("date");
   var needRefresh = (listFilter == 'view_selectedday'
                     && day != currentDay);
   
   changeDateSelectorDisplay(day);
   changeCalendarDisplay( { "day": day } );
   if (needRefresh)
     refreshEvents();
  
   return false;
}

function gotoToday() {
  changeDateSelectorDisplay('');
  changeCalendarDisplay();

  return false;
}

function setDateSelectorContent(content) {
  var div = $("dateSelectorView");

  div.innerHTML = content;
  if (currentDay.length > 0)
    restoreCurrentDaySelection(div);

  initDateSelectorEvents();
}

function dateSelectorCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
     document.dateSelectorAjaxRequest = null;
     var content = http.responseText;
     setDateSelectorContent(content);
     cachedDateSelectors[http.callbackData] = content;
  }
  else
    log ("dateSelectorCallback Ajax error");
}

function eventsListCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
     var div = $("eventsListView");

    document.eventsListAjaxRequest = null;
    var table = $("eventsList");
    lastClickedRow = -1; // from generic.js

    if (http.responseText.length > 0) {
      var data = http.responseText.evalJSON(true);
      for (var i = 0; i < data.length; i++) {
	var row = document.createElement("tr");
	table.tBodies[0].appendChild(row);
	$(row).addClassName("eventRow");
	row.setAttribute("id", escape(data[i][0]));
	row.cname = escape(data[i][0]);
	row.calendar = data[i][1];

	var startDate = new Date();
	startDate.setTime(data[i][4] * 1000);
	row.day = startDate.getDayString();
	row.hour = startDate.getHourString();
	Event.observe(row, "mousedown", onRowClick);
	Event.observe(row, "selectstart", listRowMouseDownHandler);
	Event.observe(row, "dblclick",
		      editDoubleClickedEvent.bindAsEventListener(row));
	Event.observe(row, "contextmenu",
		      onEventContextMenu.bindAsEventListener(row));
      
	var td = document.createElement("td");
	row.appendChild(td);
	Event.observe(td, "mousedown", listRowMouseDownHandler, true);
	td.appendChild(document.createTextNode(data[i][3]));

	td = document.createElement("td");
	row.appendChild(td);
	Event.observe(td, "mousedown", listRowMouseDownHandler, true);
	td.appendChild(document.createTextNode(data[i][10]));

	td = document.createElement("td");
	row.appendChild(td);
	Event.observe(td, "mousedown", listRowMouseDownHandler, true);
	td.appendChild(document.createTextNode(data[i][11]));
      
	td = document.createElement("td");
	row.appendChild(td);
	Event.observe(td, "mousedown", listRowMouseDownHandler, true);
	td.appendChild(document.createTextNode(data[i][6]));
      }

      if (sorting["attribute"] && sorting["attribute"].length > 0) {
	var sortHeader = $(sorting["attribute"] + "Header");
      
	if (sortHeader) {
	  var sortImages = $(table.tHead).getElementsByClassName("sortImage");
	  $(sortImages).each(function(item) {
	      item.remove();
	    });

	  var sortImage = createElement("img", "messageSortImage", "sortImage");
	  sortHeader.insertBefore(sortImage, sortHeader.firstChild);
	  if (sorting["ascending"])
	    sortImage.src = ResourcesURL + "/title_sortdown_12x12.png";
	  else
	    sortImage.src = ResourcesURL + "/title_sortup_12x12.png";
	}
      }
    }
  }
  else
    log ("eventsListCallback Ajax error");
}

function tasksListCallback(http) {
  var div = $("tasksListView");

  if (http.readyState == 4
      && http.status == 200) {
    document.tasksListAjaxRequest = null;
    var list = $("tasksList");
 
    if (http.responseText.length > 0) {
      var data = http.responseText.evalJSON(true);

      for (var i = 0; i < data.length; i++) {
	var listItem = document.createElement("li");
	list.appendChild(listItem);
	Event.observe(listItem, "mousedown", listRowMouseDownHandler);
	Event.observe(listItem, "click", onRowClick);
	Event.observe(listItem, "dblclick",
		      editDoubleClickedEvent.bindAsEventListener(listItem));
	listItem.setAttribute("id", data[i][0]);
	$(listItem).addClassName(data[i][5]);
	$(listItem).addClassName(data[i][6]);
	listItem.calendar = data[i][1];
	$(listItem).addClassName("calendarFolder" + data[i][1]);
	listItem.cname = escape(data[i][0]);
	var input = document.createElement("input");
	input.setAttribute("type", "checkbox");
	listItem.appendChild(input);
	Event.observe(input, "click", updateTaskStatus.bindAsEventListener(input), true);
	input.setAttribute("value", "1");
	if (data[i][2] == 1)
	  input.setAttribute("checked", "checked");
	$(input).addClassName("checkBox");
	listItem.appendChild(document.createTextNode(data[i][3]));
      }

      list.scrollTop = list.previousScroll;

      if (http.callbackData) {
	var selectedNodesId = http.callbackData;
	for (var i = 0; i < selectedNodesId.length; i++) {
	  // 	log(selectedNodesId[i] + " (" + i + ") is selected");
	  $(selectedNodesId[i]).select();
	}
      }
      else
	log ("tasksListCallback: no data");
    }
  }
  else
    log ("tasksListCallback Ajax error");
}

function restoreCurrentDaySelection(div) {
  var elements = $(div).getElementsByTagName("a");
  var day = null;
  var i = 9;
  while (!day && i < elements.length)
    {
      day = elements[i].day;
      i++;
    }

  if (day
      && day.substr(0, 6) == currentDay.substr(0, 6)) {
      for (i = 0; i < elements.length; i++) {
        day = elements[i].day;
        if (day && day == currentDay) {
          var td = $(elements[i]).getParentWithTagName("td");
          if (document.selectedDate)
            document.selectedDate.deselect();
          $(td).select();
          document.selectedDate = td;
        }
      }
    }
}

function changeDateSelectorDisplay(day, keepCurrentDay) {
  var url = ApplicationBaseURL + "dateselector";
  if (day)
    url += "?day=" + day;

  if (day != currentDay) {
    if (!keepCurrentDay)
      currentDay = day;

    var month = day.substr(0, 6);
    if (cachedDateSelectors[month]) {
//       log ("restoring cached selector for month: " + month);
      setDateSelectorContent(cachedDateSelectors[month]);
    }
    else {
//       log ("loading selector for month: " + month);
      if (document.dateSelectorAjaxRequest) {
        document.dateSelectorAjaxRequest.aborted = true;
        document.dateSelectorAjaxRequest.abort();
      }
      document.dateSelectorAjaxRequest
        = triggerAjaxRequest(url,
                             dateSelectorCallback,
                             month);
    }
  }
}

function changeCalendarDisplay(data, newView) {
  var url = ApplicationBaseURL + ((newView) ? newView : currentView);
  var day = null;
  var scrollEvent = null;

  if (data) {
    day = data['day'];
    scrollEvent = data['scrollEvent'];
  }

  if (!day)
    day = currentDay;

  if (day) {
    if (data) {
      var divs = $$('div.day[day='+day+']');
      if (divs.length) {
	// Don't reload the view if the event is present in current view
	
	// Deselect previous day
	var selectedDivs = $$('div.day.selectedDay');
	selectedDivs.each(function(div) {
	    div.removeClassName('selectedDay');
	  });
	
	// Select new day
	divs.each(function(div) {
	    div.addClassName('selectedDay');
	  });
	
	// Deselect day in date selector
	if (document.selectedDate)
	  document.selectedDate.deselect();
	
	// Select day in date selector
	var selectedLink = $$('table#dateSelectorTable a[day='+day+']');
	if (selectedLink.length > 0) {
	  selectedCell = selectedLink[0].up(1);
	  selectedCell.select();
	  document.selectedDate = selectedCell;
	}
	
	// Scroll to event
	scrollDayView(scrollEvent);	

	return false;
      }
    }
    url += "?day=" + day;
  }
//   if (newView)
//     log ("switching to view: " + newView);
//   log ("changeCalendarDisplay: " + url);

  selectedCalendarCell = null;

  if (document.dayDisplayAjaxRequest) {
//     log ("aborting day ajaxrq");
    document.dayDisplayAjaxRequest.aborted = true;
    document.dayDisplayAjaxRequest.abort();
  }
  document.dayDisplayAjaxRequest
     = triggerAjaxRequest(url, calendarDisplayCallback,
			  { "view": newView,
			    "day": day,
			    "scrollEvent": scrollEvent });

  return false;
}

function _ensureView(view) {
  if (currentView != view)
    changeCalendarDisplay(null, view);

  return false;
}

function onDayOverview() {
  return _ensureView("dayview");
}

function onMulticolumnDayOverview() {
  return _ensureView("multicolumndayview");
}

function onWeekOverview() {
  return _ensureView("weekview");
}

function onMonthOverview() {
  return _ensureView("monthview");
}

function scrollDayView(scrollEvent) {
  var divs;

  // Select event in calendar view
  if (scrollEvent) {
    divs = $$("div#calendarContent div." + eventClass(scrollEvent));
    selectCalendarEvent(divs[0]);
  }
  
  // Don't scroll if in month view
  if (currentView == "monthview")
    return;

  var offset = 0;
  var daysView = $("daysView");
  var hours =
    $(daysView.childNodesWithTag("div")[0]).childNodesWithTag("div");

  if (scrollEvent) {
    divs = $$("div#calendarContent div." + eventClass(scrollEvent));
    var classes = $w(divs[0].className);
    for (var i = 0; i < classes.length; i++) {
      if (classes[i].startsWith("starts")) {
	var starts = Math.floor(parseInt(classes[i].substr(6)) / 4);
	offset = hours[starts].offsetTop;
      }
    }
  }
  else
    // Scroll to 8 AM
    offset = hours[8].offsetTop;

  daysView.scrollTop = offset - 5;
}

function onClickableCellsDblClick(event) {
  newEvent(this, 'event');

  event.cancelBubble = true;
  event.returnValue = false;
}

function refreshCalendarEvents(scrollEvent) {
   var todayDate = new Date();
   var sd;
   var ed;
   if (currentView == "dayview") {
      if (currentDay)
	 sd = currentDay;
      else
	 sd = todayDate.getDayString();
      ed = sd;
   }
   else if (currentView == "weekview") {
      var startDate;
      if (currentDay)
	 startDate = currentDay.asDate();
      else
	 startDate = todayDate;
      startDate = startDate.beginOfWeek();
      sd = startDate.getDayString();
      var endDate = new Date();
      endDate.setTime(startDate.getTime());
      endDate.addDays(6);
      ed = endDate.getDayString();
   }
   else {
      var monthDate;
      if (currentDay)
	 monthDate = currentDay.asDate();
      else
	 monthDate = todayDate;
      monthDate.setDate(1);
      sd = monthDate.beginOfWeek().getDayString();

      var lastMonthDate = new Date();
      lastMonthDate.setTime(monthDate.getTime());
      lastMonthDate.setMonth(monthDate.getMonth() + 1);
      lastMonthDate.addDays(-1);
      ed = lastMonthDate.endOfWeek().getDayString();
   }
   if (document.refreshCalendarEventsAjaxRequest) {
      document.refreshCalendarEventsAjaxRequest.aborted = true;
      document.refreshCalendarEventsAjaxRequest.abort();
   }
   var url = ApplicationBaseURL + "eventslist?sd=" + sd + "&ed=" + ed;
   document.refreshCalendarEventsAjaxRequest
      = triggerAjaxRequest(url, refreshCalendarEventsCallback,
	                   {"startDate": sd, "endDate": ed,
			    "scrollEvent": scrollEvent});
}

function refreshCalendarEventsCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {

    if (http.responseText.length > 0) {
      var data = http.responseText.evalJSON(true);
//      log("refresh calendar events: " + data.length);
      for (var i = 0; i < data.length; i++)
	drawCalendarEvent(data[i],
			  http.callbackData["startDate"],
			  http.callbackData["endDate"]);
    }
    scrollDayView(http.callbackData["scrollEvent"]);
  }
  else
     log("AJAX error when refreshing calendar events");
}

function drawCalendarEvent(eventData, sd, ed) {
   var viewStartDate = sd.asDate();
   var viewEndDate = ed.asDate();

   var startDate = new Date();
   startDate.setTime(eventData[4] * 1000);
   var endDate = new Date();
   endDate.setTime(eventData[5] * 1000);

//    log ("s: " + startDate + "; e: " + endDate);

   var days = startDate.daysUpTo(endDate);

   var title;
   if (currentView == "monthview"
       && (eventData[7] == 0))
      title = startDate.getDisplayHoursString() + " " + eventData[3];
   else
      title = eventData[3];

//    log("title: " + title); 
//    log("viewS: " + viewStartDate);
   var startHour = null;
   var endHour = null;
   
   var siblings = new Array();
   for (var i = 0; i < days.length; i++)
      if (days[i].earlierDate(viewStartDate) == viewStartDate
	  && days[i].laterDate(viewEndDate) == viewEndDate) {
	 var starts;

// 	 log("day: " + days[i]);
	 if (i == 0) {
	    var quarters = (startDate.getUTCHours() * 4
			    + Math.floor(startDate.getUTCMinutes() / 15));
	    starts = quarters;
	    startHour = startDate.getDisplayHoursString();
	    endHour = endDate.getDisplayHoursString();
	 }
	 else
	    starts = 0;
	 
	 var ends;
	 var lasts;
	 if (i == days.length - 1) {
	    var quarters = (endDate.getUTCHours() * 4
			    + Math.ceil(endDate.getUTCMinutes() / 15));
	    ends = quarters;
	 }
	 else
	    ends = 96;
	 lasts = ends - starts;
	 if (!lasts)
	    lasts = 1;

 	 var eventDiv = newEventDIV(eventData[0], eventData[1], starts, lasts,
 				    null, null, title);
	 siblings.push(eventDiv);
	 eventDiv.siblings = siblings;
	 if (eventData[9].length > 0)
	   eventDiv.addClassName(eventData[9]);
	 var dayString = days[i].getDayString();
// 	 log("day: " + dayString);
	 var parentDiv = null;
	 if (currentView == "monthview") {
	    var dayDivs = $("monthDaysView").childNodesWithTag("div");
	    var j = 0; 
	    while (!parentDiv && j < dayDivs.length) {
	       if (dayDivs[j].getAttribute("day") == dayString)
		  parentDiv = dayDivs[j];
	       else
		  j++;
	    }
	 }
	 else {
	    if (eventData[7] == 0) {
	       var daysView = $("daysView");
	       var eventsDiv = $(daysView).childNodesWithTag("div")[1];
	       var dayDivs = $(eventsDiv).childNodesWithTag("div");
	       var j = 0; 
	       while (!parentDiv && j < dayDivs.length) {
		  if (dayDivs[j].getAttribute("day") == dayString)
		     parentDiv = dayDivs[j].childNodesWithTag("div")[0];
		  else
		     j++;
	       }
	    }
	    else {
	       var header = $("calendarHeader");
	       var daysDiv = $(header).childNodesWithTag("div")[1];
	       var dayDivs = $(daysDiv).childNodesWithTag("div");
	       var j = 0; 
	       while (!parentDiv && j < dayDivs.length) {
		  if (dayDivs[j].getAttribute("day") == dayString)
		     parentDiv = dayDivs[j];
		  else
		     j++;
	       }
	    }
	 }
	 if (parentDiv)
	   parentDiv.appendChild(eventDiv);
      }
}

function eventClass(cname) {
  return  escape(cname.replace(".", "-"));
}


function newEventDIV(cname, calendar, starts, lasts,
		     startHour, endHour, title) {
   var eventDiv = document.createElement("div");
   eventDiv.cname = escape(cname);
   eventDiv.calendar = calendar;
   $(eventDiv).addClassName("event");
   $(eventDiv).addClassName(eventClass(cname));
   $(eventDiv).addClassName("starts" + starts);
   $(eventDiv).addClassName("lasts" + lasts);
   for (var i = 1; i < 5; i++) {
      var shadowDiv = document.createElement("div");
      eventDiv.appendChild(shadowDiv);
      $(shadowDiv).addClassName("shadow");
      $(shadowDiv).addClassName("shadow" + i);
   }
   var innerDiv = document.createElement("div");
   eventDiv.appendChild(innerDiv);
   $(innerDiv).addClassName("eventInside");
   $(innerDiv).addClassName("calendarFolder" + calendar);

   var gradientDiv = document.createElement("div");
   innerDiv.appendChild(gradientDiv);
   $(gradientDiv).addClassName("gradient");
   var gradientImg = document.createElement("img");
   gradientDiv.appendChild(gradientImg);
   gradientImg.src = ResourcesURL + "/event-gradient.png";

   var textDiv = document.createElement("div");
   innerDiv.appendChild(textDiv);
   $(textDiv).addClassName("text");
   if (startHour) {
      var headerSpan = document.createElement("span");
      textDiv.appendChild(headerSpan);
      $(headerSpan).addClassName("eventHeader");
      headerSpan.appendChild(document.createTextNode(startHour + " - "
						     + endHour));
      textDiv.appendChild(document.createElement("br"));
   }
   textDiv.appendChild(document.createTextNode(title));

   Event.observe(eventDiv, "mousedown", listRowMouseDownHandler);
   Event.observe(eventDiv, "click",
		 onCalendarSelectEvent.bindAsEventListener(eventDiv));
   Event.observe(eventDiv, "dblclick",
		 editDoubleClickedEvent.bindAsEventListener(eventDiv));

   return eventDiv;
}

function calendarDisplayCallback(http) {
  var div = $("calendarView");

  if (http.readyState == 4
      && http.status == 200) {
    document.dayDisplayAjaxRequest = null;
    div.update(http.responseText);
    if (http.callbackData["view"])
      currentView = http.callbackData["view"];
    if (http.callbackData["day"])
      currentDay = http.callbackData["day"];

    var contentView;
    if (currentView == "monthview")
      contentView = $("calendarContent");
    else
      contentView = $("daysView");
    
    refreshCalendarEvents(http.callbackData.scrollEvent);
    
    var days = document.getElementsByClassName("day", contentView);
    if (currentView == "monthview")
      for (var i = 0; i < days.length; i++) {
        Event.observe(days[i], "click",
		      onCalendarSelectDay.bindAsEventListener(days[i]));
        Event.observe(days[i], "dblclick",
		      onClickableCellsDblClick.bindAsEventListener(days[i]));
      }
    else {
       var headerDivs = $("calendarHeader").childNodesWithTag("div"); 
       var headerDaysLabels = document.getElementsByClassName("day", headerDivs[0]);
       var headerDays = document.getElementsByClassName("day", headerDivs[1]);
       for (var i = 0; i < days.length; i++) {
	  headerDays[i].hour = "allday";
	  Event.observe(headerDaysLabels[i], "mousedown", listRowMouseDownHandler);
	  Event.observe(headerDays[i], "click",
			onCalendarSelectDay.bindAsEventListener(days[i]));
	  Event.observe(headerDays[i], "dblclick",
			onClickableCellsDblClick.bindAsEventListener(headerDays[i]));
	  Event.observe(days[i], "click",
			onCalendarSelectDay.bindAsEventListener(days[i]));
	  var clickableCells = document.getElementsByClassName("clickableHourCell",
							       days[i]);
	  for (var j = 0; j < clickableCells.length; j++)
	     Event.observe(clickableCells[j], "dblclick",
			   onClickableCellsDblClick.bindAsEventListener(clickableCells[j]));
       }
    }
  }
  else
    log ("calendarDisplayCallback Ajax error (" + http.readyState + "/" + http.status + ")");
}

function assignCalendar(name) {
  if (typeof(skycalendar) != "undefined") {
    var node = $(name);
      
    node.calendar = new skycalendar(node);
    node.calendar.setCalendarPage(ResourcesURL + "/skycalendar.html");
    var dateFormat = node.getAttribute("dateFormat");
    if (dateFormat)
      node.calendar.setDateFormat(dateFormat);
  }
}

function popupCalendar(node) {
   var nodeId = $(node).readAttribute("inputId");
   var input = $(nodeId);
   input.calendar.popup();

   return false;
}

function onEventContextMenu(event) {
  var topNode = $("eventsList");
  var menu = $("eventsListMenu");

  Event.observe(menu, "hideMenu",  onEventContextMenuHide);
  popupMenu(event, "eventsListMenu", this);
}

function onEventContextMenuHide(event) {
  var topNode = $("eventsList");

  if (topNode.menuSelectedEntry) {
    topNode.menuSelectedEntry.deselect();
    topNode.menuSelectedEntry = null;
  }
}

function onEventsSelectionChange() {
  listOfSelection = this;
  this.removeClassName("_unfocused");
  $("tasksList").addClassName("_unfocused");

  var rows = this.tBodies[0].getSelectedNodes();
  if (rows.length == 1) {
    var row = rows[0];
    changeCalendarDisplay( { "day": row.day,
	  "scrollEvent": row.getAttribute("id") } );
    changeDateSelectorDisplay(row.day);
  }
}

function onTasksSelectionChange() {
  listOfSelection = this;
  this.removeClassName("_unfocused");
  $("eventsList").addClassName("_unfocused");
}

function _loadEventHref(href) {
  if (document.eventsListAjaxRequest) {
    document.eventsListAjaxRequest.aborted = true;
    document.eventsListAjaxRequest.abort();
  }
  var url = ApplicationBaseURL + "/" + href;
  document.eventsListAjaxRequest
    = triggerAjaxRequest(url, eventsListCallback, href);

  var table = $("eventsList").tBodies[0];
  while (table.rows.length > 0)
     table.removeChild(table.rows[0]);

  return false;
}

function _loadTasksHref(href) {
  if (document.tasksListAjaxRequest) {
    document.tasksListAjaxRequest.aborted = true;
    document.tasksListAjaxRequest.abort();
  }
  url = ApplicationBaseURL + href;

  var tasksList = $("tasksList");
  var selectedIds;
  if (tasksList)
     selectedIds = tasksList.getSelectedNodesId();
  else
     selectedIds = null;
  document.tasksListAjaxRequest
    = triggerAjaxRequest(url, tasksListCallback, selectedIds);

  tasksList.previousScroll = tasksList.scrollTop;
  while (tasksList.childNodes.length)
     tasksList.removeChild(tasksList.childNodes[0]);

  return true;
}

function onHeaderClick(event) {
   var headerId = this.getAttribute("id");
  var newSortAttribute;
  if (headerId == "titleHeader")
    newSortAttribute = "title";
  else if (headerId == "startHeader")
    newSortAttribute = "start";
  else if (headerId == "endHeader")
    newSortAttribute = "end";
  else if (headerId == "locationHeader")
    newSortAttribute = "location";
  else
    newSortAttribute = "start";
  
   if (sorting["attribute"] == newSortAttribute)
    sorting["ascending"] = !sorting["ascending"];
  else {
    sorting["attribute"] = newSortAttribute;
    sorting["ascending"] = true;
  }
   refreshEvents();

  Event.stop(event);
}

function refreshCurrentFolder() {
  refreshEvents();
}

function refreshEvents() {
  var titleSearch;
  var value = search["value"];
  if (value && value.length)
    titleSearch = "&search=" + value;
  else
    titleSearch = "";
 
  return _loadEventHref("eventslist?asc=" + sorting["ascending"]
			+ "&sort=" + sorting["attribute"]
			+ "&day=" + currentDay
			+ titleSearch
			+ "&filterpopup=" + listFilter);
}

function refreshTasks() {
  return _loadTasksHref("taskslist?show-completed=" + showCompletedTasks);
}

function refreshEventsAndDisplay() {
  refreshEvents();
  changeCalendarDisplay();
}

function onListFilterChange() {
  var node = $("filterpopup");

  listFilter = node.value;
//   log ("listFilter = " + listFilter);

  return refreshEvents();
}

function selectMonthInMenu(menu, month) {
   var entries = menu.childNodes[1].childNodesWithTag("LI");
   for (i = 0; i < entries.length; i++) {
      var entry = entries[i];
      var entryMonth = entry.getAttribute("month");
      if (entryMonth == month)
	 entry.addClassName("currentMonth");
      else
	 entry.removeClassName("currentMonth");
   }
}

function selectYearInMenu(menu, month) {
  var entries = menu.childNodes[1].childNodes;
  for (i = 0; i < entries.length; i++) {
    var entry = entries[i];
    if (entry.tagName == "LI") {
      var entryMonth = entry.innerHTML;
      if (entryMonth == month)
        entry.addClassName("currentMonth");
      else
        entry.removeClassName("currentMonth");
    }
  }
}

function popupMonthMenu(event) {
  if (event.button == 0) {
    var id = this.getAttribute("id");
    if (id == "monthLabel")
       menuId = "monthListMenu";
    else
       menuId = "yearListMenu";

    var popup = $(menuId);
    if (id == "monthLabel")
      selectMonthInMenu(popup, this.getAttribute("month"));
    else
      selectYearInMenu(popup, this.innerHTML);

    popupToolbarMenu(this, menuId);
    Event.stop(event);
  }
}

function onMonthMenuItemClick(event) {
  var month = '' + this.getAttribute("month");
  var year = '' + $("yearLabel").innerHTML;

  changeDateSelectorDisplay(year + month + "01", true);
}

function onYearMenuItemClick(event) {
  var month = '' + $("monthLabel").getAttribute("month");;
  var year = '' + this.innerHTML;

  changeDateSelectorDisplay(year + month + "01", true);
}

function selectCalendarEvent(div) {
  // Select event in calendar view
  if (selectedCalendarCell)
     for (var i = 0; i < selectedCalendarCell.length; i++)
	selectedCalendarCell[i].deselect();

  for (var i = 0; i < div.siblings.length; i++)
     div.siblings[i].select();

  selectedCalendarCell = div.siblings;
}

function onCalendarSelectEvent() {
  var list = $("eventsList");

  selectCalendarEvent(this);

  // Select event in events list
  $(list.tBodies[0]).deselectAll();
  var row = $(this.cname);
  if (row) {
    var div = row.parentNode.parentNode.parentNode;
    div.scrollTop = row.offsetTop - (div.offsetHeight / 2);
    row.select();
  }
}

function onCalendarSelectDay(event) {
  var day;
  if (currentView == "multicolumndayview")
     day = this.getAttribute("day");
  else
     day = this.getAttribute("day");
  var needRefresh = (listFilter == 'view_selectedday'
                     && day != currentDay);

  if (currentView == 'weekview')
    changeWeekCalendarDisplayOfSelectedDay(this);
  else if (currentView == 'monthview')
    changeMonthCalendarDisplayOfSelectedDay(this);
  changeDateSelectorDisplay(day);

  if (listOfSelection) {
    listOfSelection.addClassName("_unfocused");
    listOfSelection = null;
  }

  if (needRefresh)
    refreshEvents();
}

function changeWeekCalendarDisplayOfSelectedDay(node) {
  var days = document.getElementsByClassName("day", node.parentNode);
  var headerDiv = $("calendarHeader").childNodesWithTag("div")[1];
  var headerDays = document.getElementsByClassName("day", headerDiv);

//   log ("days: " + days.length + "; headerDays: " + headerDays.length);
  for (var i = 0; i < days.length; i++)
     if (days[i] != node) {
// 	log("unselect day : " + i);
	headerDays[i].removeClassName("selectedDay");
	days[i].removeClassName("selectedDay");
     }
     else {
// 	log("selected day : " + i);
	headerDays[i].addClassName("selectedDay");
	days[i].addClassName("selectedDay");
     }
}

function findMonthCalendarSelectedCell(daysContainer) {
   var found = false;
   var i = 0;

   while (!found && i < daysContainer.childNodes.length) {
      var currentNode = daysContainer.childNodes[i];
      if (currentNode.tagName == 'DIV'
          && currentNode.hasClassName("selectedDay")) {
         daysContainer.selectedCell = currentNode;
         found = true;
      }
      else
         i++;
   }
}

function changeMonthCalendarDisplayOfSelectedDay(node) {
   var daysContainer = node.parentNode;
   if (!daysContainer.selectedCell)
      findMonthCalendarSelectedCell(daysContainer);
   
   if (daysContainer.selectedCell)
      daysContainer.selectedCell.removeClassName("selectedDay");
   daysContainer.selectedCell = node;
   node.addClassName("selectedDay");
}

function onShowCompletedTasks(event) {
   showCompletedTasks = (this.checked ? 1 : 0);

   return refreshTasks();
}

function updateTaskStatus(event) {
  var taskId = this.parentNode.getAttribute("id");
  var newStatus = (this.checked ? 1 : 0);
  var http = createHTTPClient();

  if (isSafari() && !isSafari3()) {
    newStatus = (newStatus ? 0 : 1);
  }
  
  url = (ApplicationBaseURL + this.parentNode.calendar
	 + "/" + taskId + "/changeStatus?status=" + newStatus);

  if (http) {
    // TODO: add parameter to signal that we are only interested in OK
    http.open("POST", url, false /* not async */);
    http.url = url;
    http.send("");
    if (isHttpStatus204(http.status))
      refreshTasks();
  } else
    log ("no http client?");

  return false;
}

function updateCalendarStatus(event) {
  var list = new Array();
  var newStatus = (this.checked ? 1 : 0);
  
  if (isSafari() && !isSafari3()) {
    newStatus = (newStatus ? 0 : 1);
    this.checked = newStatus;
  }

  var nodes = $("calendarList").childNodesWithTag("li");
  for (var i = 0; i < nodes.length; i++) {
    var input = $(nodes[i]).childNodesWithTag("input")[0];
    if (input.checked) {
       var folderId = nodes[i].getAttribute("id");
       var elems = folderId.split(":");
       if (elems.length > 1)
	  list.push(elems[0]);
       else
	  list.push(UserLogin);
    }
  }

//   if (!list.length) {
//      list.push(UserLogin);
//      nodes[0].childNodesWithTag("input")[0].checked = true;
//   }

//   ApplicationBaseURL = (UserFolderURL + "Groups/_custom_"
// 			+ list.join(",") + "/Calendar/");

  if (event) {
     var folderID = this.parentNode.getAttribute("id");
     var urlstr = URLForFolderID(folderID);
     if (newStatus)
       urlstr += "/activateFolder";
     else
       urlstr += "/deactivateFolder";
     //log("updateCalendarStatus: ajax request = " + urlstr + ", folderID = " + folderID);
     triggerAjaxRequest(urlstr, calendarStatusCallback, folderID);
  }
  else {
     updateCalendarsList();
     refreshEvents();
     refreshTasks();
     changeCalendarDisplay();
  }

  return false;
}

function calendarStatusCallback(http) {
  if (http.readyState == 4) {
    if (isHttpStatus204(http.status)) {
      refreshEvents();
      refreshTasks();
      changeCalendarDisplay();
    }
    else {
      var folder = $(http.callbackData);
      var input = folder.childNodesWithTag("input")[0];
      input.checked = (!input.checked);
    }
  }
  else
    log("calendarStatusCallback Ajax error");
}

function calendarEntryCallback(http) {
   if (http.readyState == 4) {
      var denied = !isHttpStatus204(http.status);
      var entry = $(http.callbackData);
      if (denied)
	 entry.addClassName("denied");
      else
	 entry.removeClassName("denied");
   }
}

function updateCalendarsList(method) {
  var list = $("calendarList").childNodesWithTag("li");
  for (var i = 0; i < list.length; i++) {
     var folderID = list[i].getAttribute("id");
     var url = URLForFolderID(folderID) + "/canAccessContent";
     triggerAjaxRequest(url, calendarEntryCallback, folderID);
  }
}

function addContact(tag, fullContactName, contactId, contactName, contactEmail) {
  var uids = $("uixselector-calendarsList-uidList");
//   log("addContact");
  if (contactId)
    {
      var re = new RegExp("(^|,)" + contactId + "($|,)");

      if (!re.test(uids.value))
        {
          if (uids.value.length > 0)
            uids.value += ',' + contactId;
          else
            uids.value = contactId;
          var names = $("calendarList");
          var listElems = names.childNodesWithTag("li");
          var colorDef = indexColor(listElems.length);
          names.appendChild(userCalendarEntry(contactId, colorDef));

        }
    }

  return false;
}

function validateBrowseURL(input) {
  var button = $("browseURLBtn");

  if (input.value.length) {
    if (!button.enabled)
      enableAnchor(button);
  } else if (!button.disabled)
    disableAnchor(button);
}

function browseURL(anchor, event) {
  if (event.button == 0) {
    var input = $("url");
    var url = input.value;
    if (url.length)
      window.open(url, '_blank');
  }

  return false;
}

function onCalendarsMenuPrepareVisibility() {
  var folders = $("calendarList");
  var selected = folders.getSelectedNodes();  

  if (selected.length > 0) {
    var folderOwner = selected[0].getAttribute("owner");
    var sharingOption = $(this).down("ul").childElements().last();
    // Disable the "Sharing" option when calendar is not owned by user
    if (folderOwner == UserLogin || IsSuperUser)
      sharingOption.removeClassName("disabled");
    else
      sharingOption.addClassName("disabled");
  }
}

function getMenus() {
   var menus = {};

   var dateMenu = new Array();
   for (var i = 0; i < 12; i++)
      dateMenu.push(onMonthMenuItemClick);
   menus["monthListMenu"] = dateMenu;

   dateMenu = new Array();
   for (var i = 0; i < 11; i++)
      dateMenu.push(onYearMenuItemClick);
   menus["yearListMenu"] = dateMenu;

   menus["eventsListMenu"] = new Array(onMenuNewEventClick, "-",
				       onMenuNewTaskClick,
				       editEvent, deleteEvent, "-",
				       onSelectAll, "-",
				       null, null);
   menus["calendarsMenu"] = new Array(onMenuModify,
				      "-",
				      onCalendarNew, onCalendarRemove,
				      "-", null, null, "-",
				      null, "-", onMenuSharing);
   menus["searchMenu"] = new Array(setSearchCriteria);

   var calendarsMenu = $("calendarsMenu");
   if (calendarsMenu)
     calendarsMenu.prepareVisibility = onCalendarsMenuPrepareVisibility;

   return menus;
}

function onMenuSharing(event) {
  if ($(this).hasClassName("disabled"))
    return;

  var folders = $("calendarList");
  var selected = folders.getSelectedNodes()[0];
  /* FIXME: activation of the context menu should preferably select the entry
	       above which the event has occured */
  if (selected) {
     var folderID = selected.getAttribute("id");
     var urlstr = URLForFolderID(folderID) + "/acls";

     openAclWindow(urlstr);
  }
}

function configureDragHandles() {
  var handle = $("verticalDragHandle");
  if (handle) {
    handle.addInterface(SOGoDragHandlesInterface);
    handle.leftBlock=$("leftPanel");
    handle.rightBlock=$("rightPanel");
  }

  handle = $("rightDragHandle");
  if (handle) {
    handle.addInterface(SOGoDragHandlesInterface);
    handle.upperBlock=$("eventsListView");
    handle.lowerBlock=$("calendarView");
  }
}

function initCalendarSelector() {
  var selector = $("calendarSelector");
  updateCalendarStatus();
  selector.changeNotification = updateCalendarsList;

  var list = $("calendarList");
  list.multiselect = true;
  var items = list.childNodesWithTag("li");
  for (var i = 0; i < items.length; i++) {
    var input = items[i].childNodesWithTag("input")[0];
    Event.observe(input, "click", updateCalendarStatus.bindAsEventListener(input));
    Event.observe(items[i], "mousedown", listRowMouseDownHandler);
    Event.observe(items[i], "selectstart", listRowMouseDownHandler);
    Event.observe(items[i], "click", onRowClick);
  }

  var links = $("calendarSelectorButtons").childNodesWithTag("a");
  Event.observe(links[0], "click",  onCalendarNew);
  Event.observe(links[1], "click",  onCalendarAdd);
  Event.observe(links[2], "click",  onCalendarRemove);
}

function onMenuModify(event) {
  var folders = $("calendarList");
  var selected = folders.getSelectedNodes()[0];

  if (UserLogin == selected.getAttribute("owner")) {
    var node = selected.childNodes[selected.childNodes.length - 1];
    var currentName = node.nodeValue.trim();
    var newName = window.prompt(labels["Name of the Calendar"],
				currentName);
    if (newName && newName.length > 0
	&& newName != currentName) {
      var url = (URLForFolderID(selected.getAttribute("id"))
		 + "/renameFolder?name=" + escape(newName.utf8encode()));
      triggerAjaxRequest(url, folderRenameCallback,
			 {node: node, name: " " + newName});
    }
  } else
    window.alert(clabels["Unable to rename that folder!"]);
}

function folderRenameCallback(http) {
  if (http.readyState == 4) {
    if (isHttpStatus204(http.status)) {
      var dict = http.callbackData;
      dict["node"].nodeValue = dict["name"];
    }
  }
}

function onCalendarNew(event) {
  createFolder(window.prompt(labels["Name of the Calendar"]),
	       appendCalendar);
  preventDefault(event);
}

function onCalendarAdd(event) {
  openUserFolderSelector(onFolderSubscribeCB, "calendar");
  preventDefault(event);
}

function appendCalendar(folderName, folderPath) {
  var owner;

  if (folderPath) {
    owner = getSubscribedFolderOwner(folderPath);
    folderPath = accessToSubscribedFolder(folderPath);
  }
  else
    folderPath = "/" + folderName;

  if (!owner)
    owner = UserLogin;

  //log ("append name: " + folderName + "; path: " + folderPath + "; owner: " + owner);

  if ($(folderPath))
    window.alert(clabels["You have already subscribed to that folder!"]);
  else {
    var calendarList = $("calendarList");
    var items = calendarList.childNodesWithTag("li");
    var li = document.createElement("li");
    
    // Add the calendar to the proper place
    var i = getListIndexForFolder(items, owner, folderName);
    if (i != items.length) // User is subscribed to other calendars of the same owner
      calendarList.insertBefore(li, items[i]);
    else 
      calendarList.appendChild(li);
    
    li.setAttribute("id", folderPath);
    li.setAttribute("owner", owner);

    // Generate new color
    if (calendarColorIndex == null)
      calendarColorIndex = items.length;
    calendarColorIndex++;
    var colorTable = [1, 1, 1];
    var color;
    var currentValue = calendarColorIndex;
    var index = 0;
    while (currentValue) {
      if (currentValue & 1)
	colorTable[index]++;
      if (index == 3)
	index = 0;
      currentValue >>= 1;
      index++;
    }
    colorTable[0] = parseInt(255 / colorTable[0]) - 1;
    colorTable[1] = parseInt(255 / colorTable[1]) - 1;
    colorTable[2] = parseInt(255 / colorTable[2]) - 1;

    color = "#"
      + colorTable[2].toString(16)
      + colorTable[1].toString(16)
      + colorTable[0].toString(16);
    //log ("color = " + color);
    
    var checkBox = document.createElement("input");
    checkBox.setAttribute("type", "checkbox");
    li.appendChild(checkBox);
    li.appendChild(document.createTextNode(" "));
    $(checkBox).addClassName("checkBox");
    if (owner == UserLogin)
      checkBox.checked = 1;

    var colorBox = document.createElement("div");
    li.appendChild(colorBox);
    li.appendChild(document.createTextNode(folderName));
    colorBox.appendChild(document.createTextNode("OO"));

    $(colorBox).addClassName("colorBox");
    $(colorBox).addClassName('calendarFolder' + folderPath.substr(1));

    // Register events (doesn't work with Safari)
    Event.observe(li, "mousedown",  listRowMouseDownHandler);
    Event.observe(li, "selectstart", listRowMouseDownHandler);
    Event.observe(li, "click",  onRowClick);
    Event.observe(checkBox, "click",
		  updateCalendarStatus.bindAsEventListener(checkBox));

    var url = URLForFolderID(folderPath) + "/canAccessContent";
    triggerAjaxRequest(url, calendarEntryCallback, folderPath);
    
    // Update CSS for events color
    if (!document.styleSheets) return;
    
    var styleElement = document.createElement("style");
    styleElement.type = "text/css";
    var selectors = [
		     '.calendarFolder' + folderPath.substr(1),
		     'div.colorBox.calendarFolder' + folderPath.substr(1)
		     ];
    var rules = [
		 ' { background-color: ' + color + ' !important; }',
		 ' { color: ' + color + ' !important; }'
		 ];
    for (var i = 0; i < rules.length; i++)
      if (styleElement.styleSheet && styleElement.styleSheet.addRule)
	styleElement.styleSheet.addRule(selectors[i], rules[i]); // IE
      else
	styleElement.appendChild(document.createTextNode(selectors[i] + rules[i])); // Mozilla _+ Safari
    document.getElementsByTagName("head")[0].appendChild(styleElement);
  }
}

function onFolderSubscribeCB(folderData) {
  var folder = $(folderData["folder"]);
   if (!folder)
     appendCalendar(folderData["folderName"], folderData["folder"]);
}

function onFolderUnsubscribeCB(folderId) {
  var node = $(folderId);
  node.parentNode.removeChild(node);
  if (removeFolderRequestCount == 0) {
    refreshEvents();
    refreshTasks();
    changeCalendarDisplay();
  }
}

function onCalendarRemove(event) {
  if (removeFolderRequestCount == 0) {
    var nodes = $("calendarList").getSelectedNodes();
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].deselect();
      var folderId = nodes[i].getAttribute("id");
      var folderIdElements = folderId.split("_");
      if (folderIdElements.length > 1) {
	unsubscribeFromFolder(folderId, onFolderUnsubscribeCB, folderId);
      }
      else
	deletePersonalCalendar(folderIdElements[0]);
    }
  }
  
  preventDefault(event);
}

function deletePersonalCalendar(folderElement) {
  var folderId = folderElement.substr(1);
  var label
    = labels["Are you sure you want to delete the calendar \"%{0}\"?"].formatted($(folderElement).lastChild.nodeValue.strip());
  if (window.confirm(label)) {
    removeFolderRequestCount++;
    var url = ApplicationBaseURL + "/" + folderId + "/deleteFolder";
    triggerAjaxRequest(url, deletePersonalCalendarCallback, folderId);
  }
}

function deletePersonalCalendarCallback(http) {
  if (http.readyState == 4) {
    if (isHttpStatus204(http.status)) {
      var ul = $("calendarList");
      var children = ul.childNodesWithTag("li");
      var i = 0;
      var done = false;
      while (!done && i < children.length) {
	var currentFolderId = children[i].getAttribute("id").substr(1);
	if (currentFolderId == http.callbackData) {
	  ul.removeChild(children[i]);
	  done = true;
	}
	else
	  i++;
      }
      removeFolderRequestCount--;
      if (removeFolderRequestCount == 0) {
	refreshEvents();
	refreshTasks();
	changeCalendarDisplay();
      }
    }
  }
  else
    log ("ajax problem 5: " + http.status);
}

function configureLists() {
   var list = $("tasksList");
   list.multiselect = true;
   Event.observe(list, "mousedown",
		 onTasksSelectionChange.bindAsEventListener(list));

   var input = $("showHideCompletedTasks");
   Event.observe(input, "click",
		 onShowCompletedTasks.bindAsEventListener(input));

   list = $("eventsList");
   list.multiselect = true;
   configureSortableTableHeaders(list);
   TableKit.Resizable.init(list, {'trueResize' : true, 'keepWidth' : true});
   Event.observe(list, "mousedown",
		 onEventsSelectionChange.bindAsEventListener(list));
}

function initDateSelectorEvents() {
   var arrow = $("rightArrow");
   Event.observe(arrow, "click",
		 onDateSelectorGotoMonth.bindAsEventListener(arrow));
   arrow = $("leftArrow");
   Event.observe(arrow, "click",
		 onDateSelectorGotoMonth.bindAsEventListener(arrow));
   
   var menuButton = $("monthLabel");
   Event.observe(menuButton, "click",
		 popupMonthMenu.bindAsEventListener(menuButton));
   menuButton = $("yearLabel");
   Event.observe(menuButton, "click",
		 popupMonthMenu.bindAsEventListener(menuButton));
}

function initCalendars() {
   sorting["attribute"] = "start";
   sorting["ascending"] = true;
  
   if (!document.body.hasClassName("popup")) {
      initDateSelectorEvents();
      initCalendarSelector();
      configureSearchField();
      configureLists();
      var selector = $("calendarSelector");
      if (selector)
	 selector.attachMenu("calendarsMenu");
   }
}

FastInit.addOnLoad(initCalendars);
