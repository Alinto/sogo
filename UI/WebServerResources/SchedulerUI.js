/* JavaScript for SOGoCalendar */

var listFilter = 'view_today';

var listOfSelection = null;
var selectedCalendarCell;

var showCompletedTasks = 0;

var currentDay = '';
var currentView = "weekview";

var cachedDateSelectors = [];

var contactSelectorAction = 'calendars-contacts';

var eventsToDelete = [];
var calendarsOfEventsToDelete = [];

var usersRightsWindowHeight = 250;
var usersRightsWindowWidth = 502;

var eventsBlocks;
var calendarEvents = null;

var userStates = [ "needs-action", "accepted", "declined", "tentative" ];

function newEvent(sender, type) {
  var day = $(sender).readAttribute("day");
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
  var params = [];
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

function _editEventId(id, calendar, recurrence) {
  var targetname = "SOGo_edit_" + id;
  var urlstr = ApplicationBaseURL + calendar + "/" + id;
  if (recurrence) {
    urlstr += "/" + recurrence;
    targetname += recurrence;
  }
  urlstr += "/edit";
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
  var urlstr = (ApplicationBaseURL + calendar
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

      if (nodes.length == 1
	  && nodes[0].recurrenceTime) {
	_editRecurrenceDialog(nodes[0], "confirmDeletion");
      }
      else {
	if (confirm(label)) {
	  if (document.deleteEventAjaxRequest) {
          document.deleteEventAjaxRequest.aborted = true;
          document.deleteEventAjaxRequest.abort();
	  }
	  var sortedNodes = [];
	  var calendars = [];
	  
	  for (var i = 0; i < nodes.length; i++) {
	    var calendar = nodes[i].calendar;
	    if (!sortedNodes[calendar]) {
	      sortedNodes[calendar] = [];
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
      }
    } else {
      window.alert(labels["Please select an event or a task."]);
    }
  }
  else if (selectedCalendarCell) {
    if (selectedCalendarCell[0].recurrenceTime) {
      _editRecurrenceDialog(selectedCalendarCell[0], "confirmDeletion");
    }
    else {
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
      }
      if (isTask)
	deleteTasksFromViews(nodes);
      else
	deleteEventsFromViews(nodes)
    }
    else
      log ("deleteEventCallback Ajax error");
  }
}

function deleteTasksFromViews(tasks) {
}

function deleteEventsFromViews(events) {
  if (calendarEvents) {
    for (var i = 0; i < events.length; i++) {
      var cname = events[i];
      var event = calendarEvents[cname];
      if (event) {
	if (event.siblings) {
	  for (var j = 0; j < event.siblings.length; j++) {
	    var eventDiv = event.siblings[j];
	    eventDiv.parentNode.removeChild(eventDiv);
	  }
	}
	delete calendarEvents[cname]
      }
      var row = $(cname);
      if (row)
	row.parentNode.removeChild(row);
    }
  }
}

function _editRecurrenceDialog(eventDiv, method) {
  var targetname = "SOGo_edit_" + eventDiv.cname + eventDiv.recurrenceTime;
  var urlstr = (ApplicationBaseURL + eventDiv.calendar + "/" + eventDiv.cname
		+ "/occurence" + eventDiv.recurrenceTime + "/" + method);
  var win = window.open(urlstr, "_blank",
                        "width=490,height=70,resizable=0");
  if (win)
    win.focus();
}

function editDoubleClickedEvent(event) {
  if (this.recurrenceTime)
    _editRecurrenceDialog(this, "confirmEditing");
  else
    _editEventId(this.cname, this.calendar);

  preventDefault(event);
  event.cancelBubble = true;
}

function performEventEdition(folder, event, recurrence) {
  _editEventId(event, folder, recurrence);
}

function performEventDeletion(folder, event, recurrence) {
  if (calendarEvents) {
    var eventEntry = calendarEvents[event];
    if (eventEntry) {
      var urlstr = ApplicationBaseURL + folder + "/" + event;
      var nodes;
      if (recurrence) {
	urlstr += "/" + recurrence;
	var occurenceTime = recurrence.substring(9);
	nodes = [];
	for (var i = 0; i < eventEntry.siblings.length; i++) {
	  if (eventEntry.siblings[i].recurrenceTime
	      && eventEntry.siblings[i].recurrenceTime == occurenceTime)
	    nodes.push(eventEntry.siblings[i]);
	}
      }
      else
	nodes = eventEntry.siblings;
      urlstr += "/delete";
      document.deleteEventAjaxRequest = triggerAjaxRequest(urlstr,
							   performDeleteEventCallback,
							   { nodes: nodes,
							     recurrence: recurrence });
    }
  }
}

function performDeleteEventCallback(http) {
  if (http.readyState == 4) {
    if (isHttpStatus204(http.status)) {
      var nodes = http.callbackData.nodes;
      var recurrenceTime = 0;
      if (http.callbackData.recurrence)
	recurrenceTime = http.callbackData.recurrence.substring(9);
      var cName = nodes[0].cname;
      var eventEntry = calendarEvents[cName];
      var node = nodes.pop();
      while (node) {
	node.parentNode.removeChild(node);
	node = nodes.pop();
      }
      if (recurrenceTime) {
	var row = $(cName + "-" + recurrenceTime);
	if (row)
	  row.parentNode.removeChild(row);
      }
      else {
	delete calendarEvents[cName];
	var tables = [ "eventsList", "tasksList" ];
	for (var i = 0; i < 2; i++) {
	  var table = $(tables[i]);
	  if (table.tBodies)
	    rows = table.tBodies[0].rows;
	  else
	    rows = $(table).childNodesWithTag("li");
	  for (var j = rows.length; j > 0; j--) {
	    var row = $(rows[j - 1]);
	    var id = row.getAttribute("id");
	    if (id.indexOf(cName) == 0)
	      row.parentNode.removeChild(row);
	  }
	}
      }
    }
  }
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

  td.selectElement();
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
	var rTime = data[i][13];
	var id = escape(data[i][0]);
	if (rTime)
	  id += "-" + escape(rTime);
	row.setAttribute("id", id);
	row.cname = escape(data[i][0]);
	row.calendar = data[i][1];
	if (rTime)
	  row.recurrenceTime = escape(rTime);
	var startDate = new Date();
	startDate.setTime(data[i][4] * 1000);
	row.day = startDate.getDayString();
	row.hour = startDate.getHourString();
	row.observe("mousedown", onRowClick);
	row.observe("selectstart", listRowMouseDownHandler);
	row.observe("dblclick", editDoubleClickedEvent);
	row.observe("contextmenu", onEventContextMenu);
      
	var td = $(document.createElement("td"));
	row.appendChild(td);
	td.observe("mousedown", listRowMouseDownHandler, true);
	td.appendChild(document.createTextNode(data[i][3]));

	td = $(document.createElement("td"));
	row.appendChild(td);
	td.observe("mousedown", listRowMouseDownHandler, true);
	td.appendChild(document.createTextNode(data[i][14]));

	td = $(document.createElement("td"));
	row.appendChild(td);
	td.observe("mousedown", listRowMouseDownHandler, true);
	td.appendChild(document.createTextNode(data[i][15]));
      
	td = $(document.createElement("td"));
	row.appendChild(td);
	td.observe("mousedown", listRowMouseDownHandler, true);
	td.appendChild(document.createTextNode(data[i][6]));
      }

      if (sorting["attribute"] && sorting["attribute"].length > 0) {
	var sortHeader = $(sorting["attribute"] + "Header");
      
	if (sortHeader) {
	  var sortImages = $(table.tHead).select(".sortImage");
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
	var listItem = $(document.createElement("li"));
	list.appendChild(listItem);
	listItem.observe("mousedown", listRowMouseDownHandler);
	listItem.observe("click", onRowClick);
	listItem.observe("dblclick", editDoubleClickedEvent);
	listItem.setAttribute("id", data[i][0]);
	listItem.addClassName(data[i][5]);
	listItem.addClassName(data[i][6]);
	listItem.calendar = data[i][1];
	listItem.addClassName("calendarFolder" + data[i][1]);
	listItem.cname = escape(data[i][0]);
	var input = $(document.createElement("input"));
	input.setAttribute("type", "checkbox");
	listItem.appendChild(input);
	input.observe("click", updateTaskStatus, true);
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
	  $(selectedNodesId[i]).selectElement();
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
	$(td).selectElement();
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
  newView = ((newView) ? newView : currentView);
  var url = ApplicationBaseURL + newView;
  var day = null;
  var scrollEvent = null;

  if (data) {
    day = data['day'];
    scrollEvent = data['scrollEvent'];
  }

  if (!day)
    day = currentDay;

  if (day) {
    if (data && newView != "monthview") {
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
	  selectedCell.selectElement();
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
  if (scrollEvent)
    selectCalendarEvent(scrollEvent);
  
  // Don't scroll if in month view
  if (currentView == "monthview")
    return;

  var offset = 0;
  var daysView = $("daysView");
  var hours = $(daysView.childNodesWithTag("div")[0])
    .childNodesWithTag("div");

  // Scroll to 8 AM by default
  offset = hours[8].offsetTop;

  if (scrollEvent && calendarEvents) {
    var event = calendarEvents[scrollEvent];
    if (event) {
      var classes = $w(event.siblings[0].className);
      for (var i = 0; i < classes.length; i++)
	if (classes[i].startsWith("starts")) {
	  var starts = Math.floor(parseInt(classes[i].substr(6)) / 4);
	  offset = hours[starts].offsetTop;
	}
    }
  }

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
  var url = (ApplicationBaseURL + "eventsblocks?sd=" + sd + "&ed=" + ed
	     + "&view=" + currentView);
  document.refreshCalendarEventsAjaxRequest
    = triggerAjaxRequest(url, refreshCalendarEventsCallback,
			 {"startDate": sd, "endDate": ed,
			  "scrollEvent": scrollEvent});
}

function refreshCalendarEventsCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
    if (http.responseText.length > 0) {
      var eventsBlocks = http.responseText.evalJSON(true);
      calendarEvents = _prepareCalendarEventsCache(eventsBlocks[0]);
      if (currentView == "monthview")
	_drawMonthCalendarEvents(eventsBlocks[2]);
      else {
	_drawCalendarAllDaysEvents(eventsBlocks[1]);
	_drawCalendarEvents(eventsBlocks[2]);
      }
    }
    scrollDayView(http.callbackData["scrollEvent"]);
  }
  else
    log("AJAX error when refreshing calendar events");
}

function _prepareCalendarEventsCache(events) {
  var cache = {};

  for (var i = 0; i < events.length; i++) {
    cache[events[i][0]] = events[i];
  }

  return cache;
}

function _drawCalendarAllDaysEvents(events) {
  var daysView = $("calendarHeader");
  var subdivs = daysView.childNodesWithTag("div");
  var days = subdivs[1].childNodesWithTag("div");
  for (var i = 0; i < events.length; i++) {
    var parentDiv = days[i];
    for (var j = 0; j < events[i].length; j++) {
      var eventRep = events[i][j];
      var eventDiv = newAllDayEventDIV(eventRep);
      parentDiv.appendChild(eventDiv);
    }
  }
}

function newBaseEventDIV(eventRep, event, eventText) {
// cname, calendar, starts, lasts,
// 		     startHour, endHour, title) {
  var eventDiv = $(document.createElement("div"));
  if (!event.siblings)
    event.siblings = [];
  eventDiv.event = event;
  eventDiv.cname = event[0];
  eventDiv.calendar = event[1];
  if (eventRep.recurrenceTime)
    eventDiv.recurrenceTime = eventRep.recurrenceTime;

  eventDiv.addClassName("event");
  if (eventRep.userState && userStates[eventRep.userState])
    eventDiv.addClassName(userStates[eventRep.userState]);

  for (var i = 1; i < 5; i++) {
    var shadowDiv = $(document.createElement("div"));
    eventDiv.appendChild(shadowDiv);
    shadowDiv.addClassName("shadow");
    shadowDiv.addClassName("shadow" + i);
  }
  var innerDiv = $(document.createElement("div"));
  eventDiv.appendChild(innerDiv);
  innerDiv.addClassName("eventInside");
  innerDiv.addClassName("calendarFolder" + event[1]);

  var gradientDiv = $(document.createElement("div"));
  innerDiv.appendChild(gradientDiv);
  gradientDiv.addClassName("gradient");
  var gradientImg = $(document.createElement("img"));
  gradientDiv.appendChild(gradientImg);
  gradientImg.src = ResourcesURL + "/event-gradient.png";

  var textDiv = $(document.createElement("div"));
  innerDiv.appendChild(textDiv);
  textDiv.addClassName("text");
  textDiv.appendChild(document.createTextNode(eventText));

  eventDiv.observe("mousedown", listRowMouseDownHandler);
  eventDiv.observe("click", onCalendarSelectEvent);
  eventDiv.observe("dblclick", editDoubleClickedEvent);

  event.siblings.push(eventDiv);

  return eventDiv;
}

function newAllDayEventDIV(eventRep) {
// cname, calendar, starts, lasts,
// 		     startHour, endHour, title) {
  var event = calendarEvents[eventRep.cname];
  var eventDiv = newBaseEventDIV(eventRep, event, event[3]);

  return eventDiv;
}
			     
function _drawCalendarEvents(events) {
  var daysView = $("daysView");
  var subdivs = daysView.childNodesWithTag("div");
  var days = subdivs[1].childNodesWithTag("div");
  for (var i = 0; i < events.length; i++) {
    var parentDiv = days[i].childNodesWithTag("div")[0];
    for (var j = 0; j < events[i].length; j++) {
      var eventRep = events[i][j];
      var eventDiv = newEventDIV(eventRep);
      parentDiv.appendChild(eventDiv);
    }
  }
}

function newEventDIV(eventRep) {
  var event = calendarEvents[eventRep.cname];
  var eventDiv = newBaseEventDIV(eventRep, event, event[3]);

  var pc = 100 / eventRep.siblings;
  eventDiv.style.width = pc + "%";
  var left = eventRep.position * pc;
  eventDiv.style.left = left + "%";
  eventDiv.addClassName("starts" + eventRep.start);
  eventDiv.addClassName("lasts" + eventRep.length);

  return eventDiv;
}

function _drawMonthCalendarEvents(events) {
  var daysView = $("monthDaysView");
  var days = daysView.childNodesWithTag("div");
  for (var i = 0; i < days.length; i++) {
    var parentDiv = days[i];
    for (var j = 0; j < events[i].length; j++) {
      var eventRep = events[i][j];
      var eventDiv = newMonthEventDIV(eventRep);
      parentDiv.appendChild(eventDiv);
    }
  }
}

function newMonthEventDIV(eventRep) {
  var event = calendarEvents[eventRep.cname];
  var eventText;
  if (event[7])
    eventText = event[3];
  else
    eventText = eventRep.starthour + " - " + event[3];

  var eventDiv = newBaseEventDIV(eventRep, event, eventText);

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
        days[i].observe("click", onCalendarSelectDay);
        days[i].observe("dblclick", onClickableCellsDblClick);
      }
    else {
      var headerDivs = $("calendarHeader").childNodesWithTag("div"); 
      var headerDaysLabels
	= document.getElementsByClassName("day", headerDivs[0]);
      var headerDays = document.getElementsByClassName("day", headerDivs[1]);
      for (var i = 0; i < days.length; i++) {
	headerDays[i].hour = "allday";
	headerDaysLabels[i].observe("mousedown", listRowMouseDownHandler);
	headerDays[i].observe("click", onCalendarSelectDay);
	headerDays[i].observe("dblclick", onClickableCellsDblClick);
	days[i].observe("click", onCalendarSelectDay);
	var clickableCells
	  = document.getElementsByClassName("clickableHourCell", days[i]);
	for (var j = 0; j < clickableCells.length; j++)
	  clickableCells[j].observe("dblclick", onClickableCellsDblClick);
      }
    }
  }
  else
    log ("calendarDisplayCallback Ajax error ("
	 + http.readyState + "/" + http.status + ")");
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

  menu.observe("hideMenu", onEventContextMenuHide);
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

function selectCalendarEvent(cname) {
  // Select event in calendar view
  if (selectedCalendarCell)
    for (var i = 0; i < selectedCalendarCell.length; i++)
      selectedCalendarCell[i].deselect();

  if (calendarEvents) {
    var event = calendarEvents[cname];
//     if (event) {
//       if (event[12])
// 	log("recurrence; date=" + event[4]);
//     }
    if (event && event.siblings) {
      for (var i = 0; i < event.siblings.length; i++)
	event.siblings[i].selectElement();
      selectedCalendarCell = event.siblings;
    }
  }
}

function onCalendarSelectEvent() {
  var list = $("eventsList");

  selectCalendarEvent(this.cname);

  // Select event in events list
  $(list.tBodies[0]).deselectAll();
  var row = $(this.cname);
  if (row) {
    var div = row.parentNode.parentNode.parentNode;
    div.scrollTop = row.offsetTop - (div.offsetHeight / 2);
    row.selectElement();
  }
}

function onCalendarSelectDay(event) {
  var day = this.getAttribute("day");
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
  var daysView = $("daysView");
  var daysDiv = daysView.childNodesWithTag("div");
  var days = daysDiv[1].childNodesWithTag("div");
  var headerDiv = $($("calendarHeader").childNodesWithTag("div")[1]);
  var headerDays = headerDiv.childNodesWithTag("div");

  for (var i = 0; i < days.length; i++) {
    if (days[i] == node
	|| headerDays[i] == node) {
      headerDays[i].addClassName("selectedDay");
      days[i].addClassName("selectedDay");
    }
    else {
      headerDays[i].removeClassName("selectedDay");
      days[i].removeClassName("selectedDay");
    }
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
    http.setRequestHeader("Content-Length", 0);
    if (isHttpStatus204(http.status))
      refreshTasks();
  } else
    log ("no http client?");

  return false;
}

function updateCalendarStatus(event) {
  var list = [];
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

  var dateMenu = [];
  for (var i = 0; i < 12; i++)
    dateMenu.push(onMonthMenuItemClick);
  menus["monthListMenu"] = dateMenu;

  dateMenu = [];
  for (var i = 0; i < 11; i++)
    dateMenu.push(onYearMenuItemClick);
  menus["yearListMenu"] = dateMenu;

  menus["eventsListMenu"] = new Array(onMenuNewEventClick, "-",
				      onMenuNewTaskClick,
				      editEvent, deleteEvent, "-",
				      onSelectAll, "-",
				      null, null);
  menus["calendarsMenu"] = new Array(onCalendarModify,
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
    $(input).observe("click", updateCalendarStatus);
    items[i].observe("mousedown", listRowMouseDownHandler);
    items[i].observe("selectstart", listRowMouseDownHandler);
    items[i].observe("click", onRowClick);
    items[i].observe("dblclick", onCalendarModify);
  }

  var links = $("calendarSelectorButtons").childNodesWithTag("a");
  links[0].observe("click", onCalendarNew);
  links[1].observe("click", onCalendarAdd);
  links[2].observe("click", onCalendarRemove);
}

function onCalendarModify(event) {
  var folders = $("calendarList");
  var selected = folders.getSelectedNodes()[0];
  var calendarID = selected.getAttribute("id");
  var url = ApplicationBaseURL + calendarID + "/properties";
  var windowID = (calendarID + "properties").replace("/", "_", "g");
  var properties = window.open(url, windowID,
			       "width=300,height=100,resizable=0");
  properties.focus();
}

function updateCalendarProperties(calendarID, calendarName, calendarColor) {
  var idParts = calendarID.split(":");
  var folderName = idParts[1].split("/")[1];
  var nodeID;
  if (idParts[0] != UserLogin)
    nodeID = "/" + idParts[0] + "_" + folderName;
  else
    nodeID = "/" + folderName;
//   log("nodeID: " + nodeID);
  var calendarNode = $(nodeID);
  var childNodes = calendarNode.childNodes;
  childNodes[childNodes.length-1].nodeValue = calendarName;

  appendStyleElement(nodeID, calendarColor);
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

function setEventsOnCalendar(checkBox, li) {
  li.observe("mousedown", listRowMouseDownHandler);
  li.observe("selectstart", listRowMouseDownHandler);
  li.observe("click", onRowClick);
  li.observe("dblclick", onCalendarModify);
  checkBox.observe("click", updateCalendarStatus);
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

    var checkBox = createElement("input", null, "checkBox", { checked: 1 },
				 { type: "checkbox" }, li);
    li.appendChild(document.createTextNode(" "));

    var colorBox = document.createElement("div");
    li.appendChild(colorBox);
    li.appendChild(document.createTextNode(folderName
					   .replace("&lt;", "<", "g")
					   .replace("&gt;", ">", "g")));
    colorBox.appendChild(document.createTextNode("OO"));

    $(colorBox).addClassName("colorBox");
    $(colorBox).addClassName('calendarFolder' + folderPath.substr(1));

    // Register events (doesn't work with Safari)
    setEventsOnCalendar(checkBox, li);

    var url = URLForFolderID(folderPath) + "/canAccessContent";
    triggerAjaxRequest(url, calendarEntryCallback, folderPath);
    
    // Update CSS for events color
    appendStyleElement(folderPath, "#AAAAAA");
  }
}

function appendStyleElement(folderPath, color) {
  if (document.styleSheets) {
    var fgColor = getContrastingTextColor(color);
    var styleElement = document.createElement("style");
    styleElement.type = "text/css";
    var selectors = [
		     '.calendarFolder' + folderPath.substr(1),
		     'div.colorBox.calendarFolder' + folderPath.substr(1)
		     ];
    var rules = [
		 ' { background-color: ' + color + ' !important;'
		 + ' color: ' + fgColor + ' !important; }',
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
      var owner = nodes[i].getAttribute("owner");
      var folderId = nodes[i].getAttribute("id");
      if (owner == UserLogin) {
        var folderIdElements = folderId.split(":");
	deletePersonalCalendar(folderIdElements[0]);
      }
      else
	unsubscribeFromFolder(folderId, owner,
			      onFolderUnsubscribeCB, folderId);
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
  list.observe("mousedown", onTasksSelectionChange);
  list.observe("selectstart", listRowMouseDownHandler);

  var input = $("showHideCompletedTasks");
  input.observe("click", onShowCompletedTasks);

  list = $("eventsList");
  list.multiselect = true;
  configureSortableTableHeaders(list);
  TableKit.Resizable.init(list, {'trueResize' : true, 'keepWidth' : true});
  list.observe("mousedown", onEventsSelectionChange);
}

function initDateSelectorEvents() {
  var arrow = $("rightArrow");
  arrow.observe("click", onDateSelectorGotoMonth);
  arrow = $("leftArrow");
  arrow.observe("click", onDateSelectorGotoMonth);

  var menuButton = $("monthLabel");
  menuButton.observe("click", popupMonthMenu);
  menuButton = $("yearLabel");
  menuButton.observe("click", popupMonthMenu);
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
