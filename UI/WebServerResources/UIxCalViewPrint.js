/* -*- Mode: js2-mode; tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*
	Copyright (C) 2005 SKYRIX Software AG
	Copyright (C) 2006-2011 Inverse

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

/******************************** Global variables *******************************************/
var firstDayOfWeek = window.opener.firstDayOfWeek;
var displayTime=true;
var printCompletedTasks=1;
var printNoDueDateTasks=1;
var eventsBlocks;
var currentView;
var sd, ed;

/******************************************* Ajust Window position from his size ***********************************************************/

function ajustWindow(width, height) {
  var left = (screen.width/2)-(width/2);
  var top = (screen.height/2)-(height/2);
  window.moveTo(left, top);
}

/****************************************** Ajax Requests, callbacks & events/tasks drawings ***************************************************/

function refreshCalendarDisplay() {
    refreshCalendarEvents();
    refreshCalendarTasks();
}

function updatePreviewDisplay() {
  var url = ApplicationBaseURL + "/" + currentView;

  if (document.dayDisplayAjaxRequest) {
    document.dayDisplayAjaxRequest.aborted = true;
    document.dayDisplayAjaxRequest.abort();
  }
  document.dayDisplayAjaxRequest
  = triggerAjaxRequest(url, previewDisplayCallback,
                       {"startDate": sd, "endDate": ed });
  
  return false;
}

function previewDisplayCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
    document.dayDisplayAjaxRequest = null;
    $("rightFrameEvents").update(http.responseText);

    if ($("printLayoutList").value == "3")
      _drawMonthEvents(eventsBlocks[2], eventsBlocks[0]);
    else
      _drawCalendarEvents(eventsBlocks[2], eventsBlocks[0]);
  }
  else
    log ("calendarDisplayCallback Ajax error ("+ http.readyState + "/" + http.status + ")");
}

function refreshCalendarEvents() {
  var todayDate = new Date();
  var currentDay = window.parentvar("currentDay");
  
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
  if (document.refreshCalendarEventsAjaxRequest) {
    document.refreshCalendarEventsAjaxRequest.aborted = true;
    document.refreshCalendarEventsAjaxRequest.abort();
  }
  var url = (ApplicationBaseURL + "/eventsblocks?sd=" + sd + "&ed=" + ed
             + "&view=" + currentView);
  
  document.refreshCalendarEventsAjaxRequest
  = triggerAjaxRequest(url, refreshCalendarEventsCallback,
                       {"startDate": sd, "endDate": ed});
}

function refreshCalendarTasks(){
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
  
  document.tasksListAjaxRequest = triggerAjaxRequest(url, refreshCalendarTasksListCallback, selectedIds);
}

function refreshCalendarEventsCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
    if (http.responseText.length > 0) {
      eventsBlocks = http.responseText.evalJSON(true);
      $("rightFrameEvents").innerHTML = "";
      if ($("printLayoutList").value == "0")
        _drawEventsCells();
      else {
        updatePreviewDisplay();
      }
    }
  }
  else
    log("AJAX error when refreshing calendar events");
}

function refreshCalendarTasksListCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
    if (http.responseText.length > 0) {
      var tasksBlocks = http.responseText.evalJSON(true);
      $("rightFrameTasks").innerHTML = "";
      var layout = $("printLayoutList").value;
      if (layout == 0)
        _drawTasksCells(tasksBlocks);
      else
        _drawTasksList(tasksBlocks);
    }
  }
  else
    log("AJAX error when refreshing calendar events");
}

function _drawEventsCells() {
  for(var i=0; i < eventsBlocks[0].length; i++)
  {
    var event = _parseEvent(eventsBlocks[0][i]);
    $("rightFrameEvents").innerHTML += event;
  }
}

function _drawTasksCells(tasksBlocks) {
  for(var i=0; i < tasksBlocks.length; i++)
  {
    if (!(printNoDueDateTasks == 0 && tasksBlocks[i][5] == null)) {
      var task = _parseTask(tasksBlocks[i]);
      $("rightFrameTasks").innerHTML += task;
    }
  }
}

function _drawTasksList(tasksBlocks) {
  var tasksList;
  tasksList = "<div><ul>";
  for(var i=0; i < tasksBlocks.length; i++)
  {
    if (!(printNoDueDateTasks == 0 && tasksBlocks[i][5] == null)) {
      tasksList += "<li>" + tasksBlocks[i][4] + "</li>";
    }
  }
  tasksList += "</ul></div>";
  $("rightFrameTasks").innerHTML = tasksList;
}

function _drawCalendarEvents(events, eventsData) {
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

function _drawMonthEvents(events, eventsData) {
  var daysView = $("monthDaysView");
  var days = daysView.childNodesWithTag("div");
  for (var i = 0; i < days.length; i++) {
    var parentDiv = days[i];
    for (var j = 0; j < events[i].length; j++) {
      var eventRep = events[i][j];
      var nbr = eventRep.nbr;
      var eventCell = newMonthEventDIV(eventRep, eventsData[nbr]);
      parentDiv.innerHTML += eventCell;
    }
  }
}

function newMonthEventDIV(eventRep, event) {
  var eventText;
  if (event[8]) // all-day event
    eventText = event[4];
  else
    eventText = "<span>" + eventRep.starthour + " - " + event[4] + "</span>";

  return eventText;
}

function _parseEvent(event) {
  var parsedEvent;
  var startDate = new Date(event[5] *1000);
  var endDate = new Date(event[6] *1000);
	parsedEvent = "<div class=divEventsPreview><table>";
  parsedEvent += "<tr><td><b>"+ event[4] +"</b></td></tr>";
  if (displayTime)
    parsedEvent += "<tr><td>"+ startDate.toLocaleString() + " - " + endDate.toLocaleString() + "</td></tr>";
  else
    parsedEvent += "<tr><td>"+ startDate.toGMTString() + "<br />" + endDate.toGMTString() + "</td></tr>";
  parsedEvent += "<tr><td><var:string label:value='Calendar: ' />" + event[2] + "</td></tr>";
  parsedEvent += "</table></div>";
	return parsedEvent;
}

function _parseTask(task) {
  var parsedTask;
  var dueDate;
  
  parsedTask = "<div class=divTasksPreview><table>";
  if (task[12] == "overdue")
    parsedTask += "<tr><td><span class=\"overdueTasks\"><b>"+ task[4] +"</b></span></td></tr>";
  else if (task[12] == "completed") {
    parsedTask += "<tr><td><b><span class=\"completedTasks\">"+ task[4] +"</b></span></td></tr>";
  }
  else
    parsedTask += "<tr><td><b>"+ task[4] +"</b></td></tr>";
  
  if (task[5] != null) {
    dueDate = new Date(task[5] *1000);
    if (displayTime)
      parsedTask += "<tr><td class=\"EventsTasksDate\">"+ dueDate.toLocaleString() + "</td></tr>";
    else
      parsedTask += "<tr><td class=\"EventsTasksDate\">"+ dueDate.toGMTString() + "</td></tr>";
  }
  parsedTask += "<tr><td><var:string label:value='Calendar: ' />" + task[2] + "</td></tr>";
  parsedTask += "</table></div>";
  
  return parsedTask;
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
      window.resizeTo(660,500);
      ajustWindow(660,500);
      $("rightSide").style.width = "390px";
      currentView = parentView;
      break;
      
    case "1": // Day view
      window.resizeTo(660,500);
      ajustWindow(660,500);
      $("rightSide").style.width = "390px";
      currentView = "dayview";
      break;
      
    case "2": // Week view
      window.resizeTo(1010,500);
      ajustWindow(1010,500);
      $("rightSide").style.width = "740px";
      currentView = "weekview";
      break;
      
    case "3": // Month view
      window.resizeTo(1010,500);
      ajustWindow(1010,500);
      $("rightSide").style.width = "740px";
      currentView = "monthview";
      break;
  }
  
  refreshCalendarDisplay();
}

function onEventsCheck(checkBox) {
  if(checkBox.checked)
    document.getElementById("rightFrameEvents").style.display = 'block';
  else
    document.getElementById("rightFrameEvents").style.display = 'none';
}

function onTasksCheck(checkBox) {
  var printOptions = document.getElementsByName("printOptions");
  for (var i = 0; i < printOptions.length; i++)
    printOptions[i].disabled = !checkBox.checked;
    
  if(checkBox.checked)
    document.getElementById("rightFrameTasks").style.display = 'block';
  else
    document.getElementById("rightFrameTasks").style.display = 'none';
}

function onPrintDateCheck() {
  var dateRange = document.getElementsByName("dateRange");
  var customDate = document.getElementById("customDate");
  for (var i = 0; i < dateRange.length; i++)
    if (dateRange[i].children[1].children[0].disabled == customDate.checked)
      dateRange[i].children[1].children[0].disabled = !customDate.checked;
}

function onDisplayTimeFormatCheck(){
  var radioTimeFormat = document.getElementsByName("printTimeFormat");
  displayTime = (radioTimeFormat[0].checked ? true : false);
  refreshCalendarDisplay();
}

function onPrintCompletedTasksCheck(checkBox) {
  printCompletedTasks = (checkBox.checked ? 1 : 0);
  refreshCalendarTasks();
}

function onPrintNoDueDateTasksCheck(checkBox) {
  printNoDueDateTasks = (checkBox.checked ? 1 : 0);
  refreshCalendarTasks();
}

/************** Date picker functions *************/
this.initTimeWidgets = function (widgets) {
	this.timeWidgets = widgets;
  
  jQuery(widgets['start']['date']).closest('.date').datepicker({autoclose: true, weekStart: 0});
  jQuery(widgets['end']['date']).closest('.date').datepicker({autoclose: true, weekStart: 0});
  
  //jQuery(widgets['start']['date']).change(onAdjustTime);
  
  /*jQuery(widgets['startingDate']['date']).closest('.date').datepicker({autoclose: true,
   weekStart: 0,
   endDate: lastDay,
   startDate: firstDay,
   setStartDate: lastDay,
   startView: 2,
   position: "below-shifted-left"});*/
}

this.onAdjustTime = function(event) {
	onAdjustDueTime(event);
}

this.onAdjustDueTime = function(event) {
  /*var dateDelta = (window.getStartDate().valueOf() - window.getShadowStartDate().valueOf());
   var newDueDate = new Date(window.getDueDate().valueOf() + dateDelta);
   window.setDueDate(newDueDate);*/
  
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
  initializeWhatToPrint();
  //initializeOptions();
  $("cancelButton").observe("click", onPrintCancelClick);
  $("printButton").observe("click", onPrintClick);
  
  onPrintLayoutListChange();
}

function initializePrintSettings() {
  $("inputFieldTitle").observe("change", onInputTitleChange);
  $("printLayoutList").observe("change", onPrintLayoutListChange);
}

function initializeWhatToPrint() {
  var widgets = {'start': {'date': $("startingDate")},
                 'end':   {'date': $("endingDate")}};
  initTimeWidgets(widgets);
  onPrintDateCheck();
}

/*function initializeOptions() {
}*/

document.observe("dom:loaded", init);
