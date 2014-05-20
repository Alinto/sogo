/* -*- Mode: js2-mode; tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*
 Copyright (C) 2006-2014 Inverse
 
 This file is part of SOGo
 
 SOGo is free software; you can redistribute it and/or modify it under
 the terms of the GNU Lesser General Public License as published by the
 Free Software Foundation; either version 2, or (at your option) any
 later version.
 
 SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 License for more details.
 
 You should have received a copy of the GNU Lesser General Public
 License along with SOGo; see the file COPYING.  If not, write to the
 Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA.
 */

/******************************** Global variables *******************************************/
var firstDayOfWeek = window.opener.firstDayOfWeek;
var printCompletedTasks=1;
var printNoDueDateTasks=1;
var eventsBlocks;
var currentView;
var currentDay = window.parentvar("currentDay");
var sd, ed;

/****************************************** Ajax Requests, callbacks & events/tasks drawings ***************************************************/

function refreshContent() {
  refreshEvents(); // Get the eventBlocks and draw them
  refreshTasks();  // Get the taskLists and draw them
}

function updateDisplayView(data, newView) {
  newView = ((newView) ? newView : currentView);
  var url = ApplicationBaseURL + "/" + newView;
  var day = null;
  
  if (data) {
    day = data['day'];
  }
  if (!day)
    day = currentDay;
  
  if (day) {
    if (data) {
      var dayDiv = $("day"+day);
      if (dayDiv) {
        // Don't reload the view if the event is present in current view
        
        // Deselect day in date selector
        if (document.selectedDate)
          document.selectedDate.deselect();
        
        // Select day in date selector
        var selectedLink = $$('table#dateSelectorTable span[day='+day+']');
        if (selectedLink.length > 0) {
          selectedCell = selectedLink[0].getParentWithTagName("td");
          $(selectedCell).selectElement();
          document.selectedDate = selectedCell;
        } else
          document.selectedDate = null;
        
        setSelectedDayDate(day);
        
        return false;
      }
      else if (day.length == 6) {
        day += "01";
      }
    }
    url += "?day=" + day;
  }
  
  selectedCalendarCell = null;
  
  if (document.dayDisplayAjaxRequest) {
    document.dayDisplayAjaxRequest.aborted = true;
    document.dayDisplayAjaxRequest.abort();
  }
  document.dayDisplayAjaxRequest
  = triggerAjaxRequest(url, previewDisplayCallback,
                       { "view": newView,
                       "day": day});
}

function previewDisplayCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
    $("rightFrameEvents").innerHTML = http.responseText;
    $("currentViewMenu").remove();
    $("listCollapse").remove();
    
    // TODO : Month
    _drawAllDayEvents(eventsBlocks[1], eventsBlocks[0]);
    _drawEvents(eventsBlocks[2], eventsBlocks[0]);
  }
  else
    log ("calendarDisplayCallback Ajax error ("+ http.readyState + "/" + http.status + ")");
  
  return false;
}

function refreshEvents() {
  var todayDate = new Date();
  
  if (!currentDay)
    currentDay = todayDate.getDayString();
  
  if (currentView == "dayview") {
    sd = currentDay;
    ed = sd;
  }
  else if (currentView == "weekview") {
    var startDate;
    startDate = currentDay.asDate();
    startDate = startDate.beginOfWeek();
    sd = startDate.getDayString();
    var endDate = new Date();
    endDate.setTime(startDate.getTime());
    endDate.addDays(6);
    ed = endDate.getDayString();
  }
  else {
    var monthDate;
    monthDate = currentDay.asDate();
    monthDate.setDate(1);
    sd = monthDate.beginOfWeek().getDayString();
    
    var lastMonthDate = new Date();
    lastMonthDate.setTime(monthDate.getTime());
    lastMonthDate.setMonth(monthDate.getMonth() + 1);
    lastMonthDate.addDays(-1);
    ed = lastMonthDate.endOfWeek().getDayString();
  }
  if (document.refreshEventsAjaxRequest) {
    document.refreshEventsAjaxRequest.aborted = true;
    document.refreshEventsAjaxRequest.abort();
  }
  var url = (ApplicationBaseURL + "/eventsblocks?sd=" + sd + "&ed=" + ed
             + "&view=" + currentView);
  
  document.refreshEventsAjaxRequest
  = triggerAjaxRequest(url, refreshEventsCallback,
                       {"startDate": sd, "endDate": ed});
}

function refreshTasks(){
  if (document.tasksListAjaxRequest) {
    document.tasksListAjaxRequest.aborted = true;
    document.tasksListAjaxRequest.abort();
  }
  
  url = window.parentvar("ApplicationBaseURL") + "/" + "taskslist?show-completed=" + printCompletedTasks
  + "&asc=" + sorting["task-ascending"]
  + "&sort=" + sorting["task-attribute"];
  var tasksList = window.parent$("tasksList");
  var selectedIds;
  if (tasksList)
    selectedIds = tasksList.getSelectedNodesId();
  else
    selectedIds = null;
  
  document.tasksListAjaxRequest = triggerAjaxRequest(url, refreshTasksListCallback, selectedIds);
}

function refreshEventsCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
    if (http.responseText.length > 0) {
      eventsBlocks = http.responseText.evalJSON(true);
      $("rightFrameEvents").innerHTML = "";
      if ($("printLayoutList").value == "0")
        _drawEventsCells(eventsBlocks);
      else {
        updateDisplayView(null, currentView);
      }
    }
  }
  else
    log("AJAX error when refreshing calendar events");
}

function refreshTasksListCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
    if (http.responseText.length > 0) {
      var tasksBlocks = http.responseText.evalJSON(true);
      $("rightFrameTasks").innerHTML = "";
      var layout = $("printLayoutList").value;
      _drawTasksCells(tasksBlocks);
    }
  }
  else
    log("AJAX error when refreshing calendar events");
}

function _drawEventsCells(eventsBlocks) {
  var events = _("Events");
  $("rightFrameEvents").insert("<h3>"+events+"</h3>");
  for(var i=0; i < eventsBlocks[0].length; i++)
  {
    var event = _parseEvent(eventsBlocks[0][i]);
    $("rightFrameEvents").insert(event);
  }
}

function _drawTasksCells(tasksBlocks) {
  var task = _("Tasks");
  $("rightFrameTasks").insert("<h3>"+task+"</h3>");
  for(var i=0; i < tasksBlocks.length; i++)
  {
    if (!(printNoDueDateTasks == 0 && tasksBlocks[i][5] == null)) {
      var task = _parseTask(tasksBlocks[i]);
      $("rightFrameTasks").insert(task);
    }
  }
}

// TODO : Maybe use the drawfunction from the schedulerUI.js

function _drawEvents(events, eventsData) {
  var daysView = $("daysView");
  var subdivs = daysView.childNodesWithTag("div");
  for (var i = 0; i < subdivs.length; i++) {
    var subdiv = subdivs[i];
    if (subdiv.hasClassName("days")) {
      var days = subdiv.childNodesWithTag("div");
      for (var j = 0; j < days.length; j++) {
        var parentDiv = days[j].childNodesWithTag("div")[0];
        for (var k = 0; k < events[j].length; k++) {
          var eventRep = events[j][k];
          var nbr = eventRep.nbr;
          var eventCell = newEventDIV(eventRep, eventsData[nbr]);
          parentDiv.appendChild(eventCell);
        }
      }
    }
  }
}

function _drawAllDayEvents(events, eventsData) {
  var headerView = $("calendarHeader");
  var subdivs = headerView.childNodesWithTag("div");
  var days = subdivs[1].childNodesWithTag("div");
  for (var i = 0; i < days.length; i++) {
    var parentDiv = days[i];
    for (var j = 0; j < events[i].length; j++) {
      var eventRep = events[i][j];
      var nbr = eventRep.nbr;
      var eventCell = newAllDayEventDIV(eventRep, eventsData[nbr]);
      parentDiv.appendChild(eventCell);
    }
  }
}

// todo : month

function newEventDIV(eventRep, event) {
  var eventCell = newBaseEventDIV(eventRep, event, event[4]);
  
  var pc = 100 / eventRep.siblings;
  var left = Math.floor(eventRep.position * pc);
  eventCell.style.left = left + "%";
  var right = Math.floor(100 - (eventRep.position + 1) * pc);
  eventCell.style.right = right + "%";
  eventCell.addClassName("starts" + eventRep.start);
  eventCell.addClassName("lasts" + eventRep.length);
  
  if (event[7]) {
    var inside = eventCell.childNodesWithTag("div")[0];
    var textDiv = inside.childNodesWithTag("div")[1];
    textDiv.appendChild(createElement("br"));
    var span = createElement("span", null, "location");
    var text = _("Location:") + " " + event[7];
    span.update(text);
    textDiv.appendChild(span);
  }
  
  return eventCell;
}

function newBaseEventDIV(eventRep, event, eventText) {
  //	log ("0 cname = " + event[0]);
  //	log ("1 calendar = " + event[1]);
  //  log ("2 calendar name = " + event[2]);
  //	log ("3 status = " + event[3]);
  //	log ("4 title = " + event[4]);
  //	log ("5 start = " + event[5]);
  //	log ("6 end = " + event[6]);
  //	log ("7 location = " + event[7]);
  //	log ("8 isallday = " + event[8]);
  //	log ("9 classification = " + event[9]); // 0 = public, 1 = private, 2 = confidential
  //	log ("10 category = " + event[10]);
  //	log ("11 participants emails = " + event[11]);
  //	log ("12 participants states = " + event[12]);
  //	log ("13 owner = " + event[13]);
  //	log ("14 iscycle = " + event[14]);
  //	log ("15 nextalarm = " + event[15]);
  //	log ("16 recurrenceid = " + event[16]);
  //	log ("17 isexception = " + event[17]);
  //  log ("18 editable = " + event[18]);
  //  log ("19 erasable = " + event[19]);
  //  log ("20 ownerisorganizer = " + event[20]);
  
  var eventCell = createElement("div");
  eventCell.cname = event[0];
  eventCell.calendar = event[1];
  var startDate = new Date(event[5]*1000);
  if (startDate) {
    eventCell.startDate = event[5];
    eventCell.writeAttribute('day', startDate.getDayString());
    eventCell.writeAttribute('hour', event[8]? 'allday' : startDate.getHourString());
  }
  //    if (event[8] == 1)
  //        eventCell.addClassName("private");
  //    else if (event[8] == 2)
  //        eventCell.addClassName("confidential");
  if (eventRep.recurrenceTime)
    eventCell.recurrenceTime = eventRep.recurrenceTime;
  //eventCell.owner = event[12];
  eventCell.isException = event[17];
  eventCell.editable = event[18];
  eventCell.erasable = event[19] || IsSuperUser;
  eventCell.ownerIsOrganizer = event[20];
  eventCell.addClassName("event");
  //    if (event[14] > 0)
  //        eventCell.addClassName("alarm");
  
  var innerDiv = createElement("div");
  eventCell.appendChild(innerDiv);
  innerDiv.addClassName("eventInside");
  innerDiv.addClassName("calendarFolder" + event[1]);
  if (eventRep.userState >= 0 && userStates[eventRep.userState])
    innerDiv.addClassName(userStates[eventRep.userState]);
  
  var gradientDiv = createElement("div");
  innerDiv.appendChild(gradientDiv);
  gradientDiv.addClassName("gradient");
  
  var gradientImg = createElement("img");
  gradientDiv.appendChild(gradientImg);
  gradientImg.src = ResourcesURL + "/event-gradient.png";
  
  var textDiv = createElement("div");
  innerDiv.appendChild(textDiv);
  textDiv.addClassName("text");
  var iconSpan = createElement("span", null, "icons");
  textDiv.update(eventText.replace(/(\\r)?\\n/g, "<BR/>"));
  textDiv.appendChild(iconSpan);
  
  // Add alarm and classification icons
  if (event[9] == 1)
    createElement("img", null, null, {src: ResourcesURL + "/private.png"}, null, iconSpan);
  else if (event[9] == 2)
    createElement("img", null, null, {src: ResourcesURL + "/confidential.png"}, null, iconSpan);
  if (event[15] > 0)
    createElement("img", null, null, {src: ResourcesURL + "/alarm.png"}, null, iconSpan);
  
  if (event[10] != null) {
    var category = event[10].decodeEntities();
    var categoryStyle = categoriesStyles.get(category);
    if (!categoryStyle) {
      categoryStyle = 'category_' + categoriesStyles.keys().length;
      categoriesStyles.set([category], categoryStyle);
    }
    innerDiv.addClassName(categoryStyle);
  }
  
  return eventCell;
}

function _parseEvent(event) {
  // Localized strings :
  var start = _("Start:");
  var end = _("End:");
  var Location = _("Location:");
  var Calendar = _("Calendar:");
  
  
  var parsedEvent;
  var startDate = new Date(event[5] *1000);
  var endDate = new Date(event[6] *1000);
	parsedEvent = "<div class=\"divEventsPreview\"><table>";
  parsedEvent += "<tr><th></th><th>"+ event[4] +"</th></tr>";
  parsedEvent += "<tr><td class=\"label\">" + start + "</td><td>" + startDate.toLocaleString() + "</td></tr>";
  parsedEvent += "<tr><td class=\"label\">" + end + "</td><td>" + endDate.toLocaleString() + "</td></tr>";
  if (event[7] != "")
    parsedEvent += "<tr><td class=\"label\">"+ Location +"</td><td>" + event[7] + "</td></tr>";
  parsedEvent += "<tr><td class=\"label\">"+ Calendar +"</td><td>" + event[2] + "</td></tr>";
  parsedEvent += "</table></div>";
	return parsedEvent;
}

function _parseTask(task) {
  var parsedTask;
  var end = _("Due Date:");
  var Calendar = _("Calendar:");
  var Location = _("Location:");
  
  parsedTask = "<div class=\"divTasksPreview\"><table>";
  if (task[12] == "overdue")
    parsedTask += "<tr><th></th><th class=\"overdueTasks\">"+ task[4] +"</th></tr>";
  else if (task[12] == "completed") {
    parsedTask += "<tr><th></th><th class=\"completedTasks\">"+ task[4] +"</th></tr>";
  }
  else
    parsedTask += "<tr class=\"tasksTitle\"><th></th><th>"+ task[4] +"</th></tr>";
  
  if (task[5] != null) {
    var endDate = new Date(task[5] *1000);
    parsedTask += "<tr><td class=\"label\">"+ end +"</td><td>"+ endDate.toLocaleString() + "</td></tr>";
  }
  if (task[7] != "") {
    parsedTask += "<tr><td class=\"label\">"+ Location +"</td><td>" + task[7] + "</td></tr>";
  }
  parsedTask += "<tr><td class=\"label\">" + Calendar + "</td><td>" + task[2] + "</td></tr>";
  parsedTask += "</table></div>";
  
  return parsedTask;
}

/************************************** Preview Navigation *****************************************/

function onCalendarGotoDay(node) {
  var day = node.getAttribute("date");
    
  changeDateSelectorDisplay(day);
  updateDisplayView({ "day": day });
  refreshEvents();
  
  return false;
}

function changeDateSelectorDisplay(day, keepCurrentDay) {
  var url = ApplicationBaseURL + "/dateselector";
  if (day) {
    if (day.length < 8)
      day += "01";
    url += "?day=" + day;
  }
  
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
  
  return false;
}

/*********************** Input Field, Checkboxes, Radio and listMenu *********************************/

function onInputTitleChange(event){
  var inputFieldTitle = $("inputFieldTitle").value;
  if (inputFieldTitle)
    document.getElementById("rightFrameTitle").innerHTML = inputFieldTitle + "<br />";
  else
    document.getElementById("rightFrameTitle").innerHTML = inputFieldTitle;
}

function onPrintLayoutListChange() {
  var selectedLayout = $("printLayoutList").value;
  var parentView = window.parentvar("currentView");
  switch(selectedLayout) {
    case "0": // List view
      window.resizeTo(700,500);
      currentView = parentView;
      ajustFrames();
      break;
      
    case "1": // Day view
      window.resizeTo(1010,500);
      currentView = "dayview";
      ajustFrames(currentView);
      break;
      
    case "2": // Week view
      window.resizeTo(1010,500);
      currentView = "weekview";
      ajustFrames(currentView);
      break;
      
      //todo : month
  }
  
  refreshContent();
}

function ajustFrames(view) {
  if (view == "dayview" || view == "weekview") {
    document.getElementById("rightFrameEvents").style.width = '100%';
    document.getElementById("rightFrameTasks").style.width = '100%';
    document.getElementById("rightFrameTasks").style.pageBreakBefore = 'always';
    document.getElementById("rightFrameTasks").style.pageBreakInside = 'avoid';
    
  }
  else {
    document.getElementById("rightFrameEvents").style.width = '49.5%';
    document.getElementById("rightFrameTasks").style.width = '49.5%';
    document.getElementById("rightFrameTasks").style.pageBreakBefore = 'auto';
    document.getElementById("rightFrameTasks").style.pageBreakInside = 'auto';
  }
  
}

function onEventsCheck(checkBox) {
  if(checkBox.checked){
    document.getElementById("rightFrameEvents").style.display = 'block';
    if ($("printLayoutList").value == 0){
      document.getElementById("rightFrameTasks").style.width = '49.5%';
    }
  }
  else {
    document.getElementById("rightFrameEvents").style.display = 'none';
    if ($("printLayoutList").value == 0){
      document.getElementById("rightFrameTasks").style.width = '100%';
    }
  }
}

function onTasksCheck(checkBox) {
  var printOptions = document.getElementsByName("printOptions");
  for (var i = 0; i < printOptions.length; i++)
    printOptions[i].disabled = !checkBox.checked;
  
  if(checkBox.checked) {
    document.getElementById("rightFrameTasks").style.display = 'block';
    if ($("printLayoutList").value == 0){
      document.getElementById("rightFrameEvents").style.width = '49.5%';
    }
  }
  else {
    document.getElementById("rightFrameTasks").style.display = 'none';
    if ($("printLayoutList").value == 0){
      document.getElementById("rightFrameEvents").style.width = '100%';
    }
  }
}

/*function onPrintDateCheck() {
 var dateRange = document.getElementsByName("dateRange");
 var customDate = document.getElementById("customDate");
 for (var i = 0; i < dateRange.length; i++)
 if (dateRange[i].children[1].children[0].disabled == customDate.checked)
 dateRange[i].children[1].children[0].disabled = !customDate.checked;
 }*/

function onPrintCompletedTasksCheck(checkBox) {
  printCompletedTasks = (checkBox.checked ? 1 : 0);
  refreshTasks();
}

function onPrintNoDueDateTasksCheck(checkBox) {
  printNoDueDateTasks = (checkBox.checked ? 1 : 0);
  refreshTasks();
}

/************** Date picker functions *************
 this.initTimeWidgets = function (widgets) {
 this.timeWidgets = widgets;
 
 jQuery(widgets['start']['date']).closest('.date').datepicker({autoclose: true, weekStart: 0});
 jQuery(widgets['end']['date']).closest('.date').datepicker({autoclose: true, weekStart: 0});
 
 //jQuery(widgets['start']['date']).change(onAdjustTime);
 
 jQuery(widgets['startingDate']['date']).closest('.date').datepicker({autoclose: true,
 weekStart: 0,
 endDate: lastDay,
 startDate: firstDay,
 setStartDate: lastDay,
 startView: 2,
 position: "below-shifted-left"});
 }
 
 this.onAdjustTime = function(event) {
 onAdjustDueTime(event);
 }
 
 this.onAdjustDueTime = function(event) {
 var dateDelta = (window.getStartDate().valueOf() - window.getShadowStartDate().valueOf());
 var newDueDate = new Date(window.getDueDate().valueOf() + dateDelta);
 window.setDueDate(newDueDate);
 
 window.timeWidgets['start']['date'].updateShadowValue();
 }
 /****************************************************/

/******************************* Buttons ***********************************************/

function onPrintCancelClick(event) {
  this.blur();
  onCloseButtonClick(event);
}

function onPrintClick(event) {
  this.blur();
  window.print();
}
/**************************** Initialization *******************************************/

function init() {
  
  initializePrintSettings();
  //initializeWhatToPrint();
  //initializeOptions();
  $("cancelButton").observe("click", onPrintCancelClick);
  $("printButton").observe("click", onPrintClick);
  
  /* TODO : Selected and custom date must be implemented and finished.
   document.getElementById("eventsTasks").disabled=true;
   document.getElementById("customDate").disabled=true;*/
  
  onPrintLayoutListChange();
}

function initializePrintSettings() {
  $("inputFieldTitle").observe("change", onInputTitleChange);
  $("printLayoutList").observe("change", onPrintLayoutListChange);
}

/*function initializeWhatToPrint() {
 var widgets = {'start': {'date': $("startingDate")},
 'end':   {'date': $("endingDate")}};
 initTimeWidgets(widgets);
 onPrintDateCheck();
 
 }*/

/*function initializeOptions() {
 }*/

document.observe("dom:loaded", init);
