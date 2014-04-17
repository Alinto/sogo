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
var displayTime;
/*********************************************************************************************/

this.onAdjustTime = function(event) {
	onAdjustDueTime(event);
}

this.onAdjustDueTime = function(event) {
  /*var dateDelta = (window.getStartDate().valueOf() - window.getShadowStartDate().valueOf());
  var newDueDate = new Date(window.getDueDate().valueOf() + dateDelta);
  window.setDueDate(newDueDate);*/

	window.timeWidgets['start']['date'].updateShadowValue();
}

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
function refreshCalendarDisplay(){
    refreshCalendarEvents();
    refreshCalendarTasks();
}

function refreshCalendarTasks(){
  
}

function refreshCalendarEvents() {
  var todayDate = new Date();
  var sd;
  var ed;
  var currentDay = window.parentvar("currentDay");
  var currentView = window.parentvar("currentView");
  
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

function refreshCalendarEventsCallback(http) {
  if (http.readyState == 4
      && http.status == 200) {
    if (http.responseText.length > 0) {
      var layout = $("printLayoutList").value;
      var eventsBlocks = http.responseText.evalJSON(true);
      $("rightFrameEvents").innerHTML = "";
      // 0 == listLayout
      if (layout == "0"){
        _drawListEvents(eventsBlocks);
      }
      // 1 == weekLayout
      if (layout == "1"){
        _drawWeekEvents(eventsBlocks);
      }
      // 2 == monthLayout
      if (layout == "2"){
        _drawMonthEvents(eventsBlocks);
      }
    }
  }
  else
    log("AJAX error when refreshing calendar events");
}

function _drawListEvents(eventsBlocks) {
  for(var i=0; i<eventsBlocks[0].length; i++)
  {
    var event = _parseEvent(eventsBlocks[0][i]);
    $("rightFrameEvents").innerHTML += event;
  }
}

function _parseEvent(event)
{
  var startDate = new Date(event[5] *1000);
  var endDate = new Date(event[6] *1000);
	var parsedEvent;
	parsedEvent = "<div class=divEventsPreview><table>";
  parsedEvent += "<tr><td><b>"+ event[4] +"</b></td></tr>";
  if (displayTime)
    parsedEvent += "<tr><td>"+ startDate.toLocaleString() + " - " + endDate.toLocaleString() + "</td></tr>";
  else
    parsedEvent += "<tr><td>"+ startDate.toGMTString() + "<br />" + endDate.toGMTString() + "</td></tr>";
  parsedEvent += "<tr><td>Calendar : " + event[2] + "</td></tr>";
  parsedEvent += "</table></div>";
	return parsedEvent;
}

function _drawMonthCalendarEvents(events, eventsData) {
  var daysView = $("monthDaysView");
  var days = daysView.childNodesWithTag("div");
  for (var i = 0; i < days.length; i++) {
    var parentDiv = days[i];
    for (var j = 0; j < events[i].length; j++) {
      var eventRep = events[i][j];
      var nbr = eventRep.nbr;
      var eventCell = newMonthEventDIV(eventRep, eventsData[nbr]);
      parentDiv.appendChild(eventCell);
    }
  }
}

/*********************** Input Field, Checkboxes, Radio and listMenu *********************************/

function onInputTitle(event){
  var titleValue = $("title").value;
  if (titleValue)
    document.getElementById("rightFrameTitle").innerHTML = titleValue + "<br />";
  else
    document.getElementById("rightFrameTitle").innerHTML = titleValue;
}

function onPrintLayoutListChange(event) {
  // TODO : Common filtering; what to display on the view
  
  // legend for the events display; 0=list, 1=week, 2=month
  
  refreshCalendarDisplay();
}

function initializeLayoutList() {
  var printLayoutList = $("printLayoutList");
  var title = $("title");
  if (printLayoutList) {
    onPrintLayoutListChange();
    printLayoutList.observe("change", onPrintLayoutListChange);
    
  }
  if (title){
    title.observe("change", onInputTitle);
  }
}

function onTasksCheck(checkBox) {
  if (checkBox) {
    var printOptions = document.getElementsByName("printOptions");
    for (var i = 0; i < printOptions.length; i++)
      if (printOptions[i] != checkBox)
        printOptions[i].disabled = !checkBox.checked;
    
    if(checkBox.checked)
      document.getElementById("rightFrameTasks").style.display = 'block';
    else
      document.getElementById("rightFrameTasks").style.display = 'none';
  }
}

function onEventsCheck(checkBox) {
  if (checkBox){
    if(checkBox.checked)
      document.getElementById("rightFrameEvents").style.display = 'block';
    else
      document.getElementById("rightFrameEvents").style.display = 'none';
  }
    
}

function printDateCheck() {
  var dateRange = document.getElementsByName("dateRange");
  var customDate = document.getElementById("customDate");
  for (var i = 0; i < dateRange.length; i++)
    if (dateRange[i].children[1].children[0].disabled == customDate.checked)
      dateRange[i].children[1].children[0].disabled = !customDate.checked;
}

function displayTimeCheck(){
  var radioButtons = document.getElementsByName("printTime");
  if (radioButtons[0].checked)
    displayTime = true;
  else
    displayTime = false;

  refreshCalendarDisplay();
}

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
  
  $("cancelButton").observe("click", onPrintCancelClick);
  $("printButton").observe("click", onPrintClick);
  
  var widgets = {'start': {'date': $("startingDate")},
                 'end':   {'date': $("endingDate")}};
  initTimeWidgets(widgets);
  printDateCheck();
  displayTimeCheck();
  initializeLayoutList();
  refreshCalendarDisplay();
}

document.observe("dom:loaded", init);
