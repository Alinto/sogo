var resultsDiv;
var searchField;
var running = false;
var address;
var delay = 500;
var requestField;
var awaitingFreeBusyRequests = new Array();
var freeBusySelectorId;

function onContactKeydown(event) {
  if (event.keyCode == 9) {
    event.preventDefault();
    if (this.confirmedValue)
      this.value = this.confirmedValue;
    var row = this.parentNode.parentNode.nextSibling;
    while (!(row instanceof HTMLTableRowElement))
      row = row.nextSibling;
    this.blur();
    var input = row.cells[0].childNodesWithTag("input")[0];
    if (input.readOnly)
      newAttendee(null);
    else {
      input.focus();
      input.select();
      input.focussed = true;
    }
  }
  else if (!running) {
    if (event.keyCode == 8
        || event.keyCode == 32
        || event.keyCode > 47) {
      running = true;
      requestField = this;
      setTimeout("triggerRequest()", delay);
    }
    else if (this.confirmedValue) {
      if (event.keyCode == 13) {
        this.setSelectionRange(this.value.length, this.value.length);
      }
    }
  }
}

function triggerRequest() {
  if (document.contactLookupAjaxRequest) {
    document.contactLookupAjaxRequest.aborted = yes;
    document.contactLookupAjaxRequest.abort();
  }
  var urlstr = ( UserFolderURL + "Contacts/contactSearch?search="
                 + requestField.value );
  document.contactLookupAjaxRequest = triggerAjaxRequest(urlstr,
                                                         updateResults,
                                                         requestField);
}

function updateResults(http) {
  if (http.readyState == 4) {
    if (http.status == 200) {
      var searchField = http.callbackData;
      var start = searchField.value.length;
      var text = http.responseText.split(":");
      if (text[0].length > 0)
        searchField.uid = text[0];
      else
        searchField.uid = null;
      searchField.hasfreebusy = false;
      if (text[1].substring(0, searchField.value.length).toUpperCase()
          == searchField.value.toUpperCase())
        searchField.value = text[1];
      else {
        searchField.value += ' >> ' + text[1];
      }
      searchField.confirmedValue = text[1];
      if (searchField.focussed) {
        var end = searchField.value.length;
        searchField.setSelectionRange(start, end);
      }
      else
        searchField.value = text[1];
    }
    running = false;
    document.contactLookupAjaxRequest = null;
  }
}

function resetFreeBusyZone()
{
  var table = $("attendeesView").childNodesWithTag("div")[0].childNodesWithTag("table")[0];
  var row = table.tHead.rows[2];
  for (var i = 1; i < row.cells.length; i++) {
    var nodes = row.cells[i].childNodesWithTag("span");
    for (var j = 0; j < nodes.length; j++)
      nodes[j].removeClassName("busy");
  }
}

function redisplayFreeBusyZone()
{
  var table = $("attendeesView").childNodesWithTag("div")[0].childNodesWithTag("table")[0];
  var row = table.tHead.rows[2];
  var stDay = this.timeWidgets['start']['date'].valueAsDate();
  var etDay = this.timeWidgets['end']['date'].valueAsDate();
  var days = stDay.daysUpTo(etDay);
  var addDays = days.length - 1;
  var stHour = parseInt(this.timeWidgets['start']['hour'].value);
  var stMinute = parseInt(this.timeWidgets['start']['minute'].value) / 15;
  var etHour = parseInt(this.timeWidgets['end']['hour'].value);
  var etMinute = parseInt(this.timeWidgets['end']['minute'].value) / 15;
  if (stHour < 8) {
    stHour = 8;
    stMinute = 0;
  }
  if (stHour > 19) {
    stHour = 19
    stMinute = 0;
  }
  if (etHour < 8) {
    etHour = 8;
    etMinute = 0;
  }
  if (etHour > 19) {
    etHour = 19;
    etMinute = 0;
  }
  if (stHour > etHour) {
    var swap = etHour;
    etHour = stHour;
    stHour = swap;
    swap = etMinute;
    etMinute = stMinute;
    stMinute = etMinute;
  } else {
    if (stMinute > etMinute) {
      var swap = etMinute;
      etMinute = stMinute;
      stMinute = swap;
    }
  }

  var deltaCells = (etHour - stHour) + (11 * addDays);
  var deltaSpans = (deltaCells * 4 ) + (etMinute - stMinute);
  var currentCellNbr = stHour - 7;
  var currentCell = row.cells[currentCellNbr];
  var currentSpanNbr = stMinute;
  var spans = currentCell.childNodesWithTag("span");
  resetFreeBusyZone();
  while (deltaSpans > 0) {
    var currentSpan = spans[currentSpanNbr];
    currentSpan.addClassName("busy");
    currentSpanNbr++;
    if (currentSpanNbr > 3) {
      currentSpanNbr = 0;
      currentCellNbr++;
      currentCell = row.cells[currentCellNbr];
      spans = currentCell.childNodesWithTag("span");
    }
    deltaSpans--;
  }
}

function newAttendee(event)
{
  var table = $("attendeesView").childNodesWithTag("div")[0].childNodesWithTag("table")[0];
  var tbody = table.tBodies[0];
  var model = tbody.rows[tbody.rows.length - 1];
  var newAttendeeRow = tbody.rows[tbody.rows.length - 2]
  var newRow = model.cloneNode(true);
  var input = newRow.cells[0].childNodesWithTag("input")[0];
  input.setAttribute("autocomplete", "off");
  newRow.setAttribute("class", "");
  tbody.insertBefore(newRow, newAttendeeRow);
  input.serial = "pouet";
  input.addEventListener("blur", checkAttendee, false);
  input.addEventListener("keydown", onContactKeydown, false);
  input.focus();
  input.focussed = true;
}

function checkAttendee()
{
  this.focussed = false;
  var th = this.parentNode.parentNode;
  var tbody = th.parentNode;
  if (this.value.trim().length == 0)
    tbody.removeChild(th);
  else if (!this.hasfreebusy) {
    if (this.confirmedValue)
      this.value = this.confirmedValue;
    displayFreeBusyForNode(this);
    this.hasfreebusy = true;
  }
  resetAttendeesValue();
}

function displayFreeBusyForNode(node)
{
  var nodes = node.parentNode.parentNode.cells;
  if (node.uid) {
    for (var i = 1; i < nodes.length; i++) {
      nodes[i].removeClassName("noFreeBusy");
      nodes[i].innerHTML = ('<span class="freeBusyZoneElement"></span>'
                            + '<span class="freeBusyZoneElement"></span>'
                            + '<span class="freeBusyZoneElement"></span>'
                            + '<span class="freeBusyZoneElement"></span>');
    }
    if (document.contactFreeBusyAjaxRequest) {
      document.contactFreeBusyAjaxRequest.aborted = true;
      document.contactFreeBusyAjaxRequest.abort();
    }
    var sd = startDayAsShortString();
    var ed = endDayAsShortString();
    var urlstr = ( UserFolderURL + "../" + node.uid + "/freebusy.ifb/ajaxRead?"
                   + "sday=" + sd + "&eday=" + ed + "&additional=2" );
    document.contactFreeBusyAjaxRequest
      = triggerAjaxRequest(urlstr,
                           updateFreeBusyData,
                           node);
  } else {
    for (var i = 1; i < nodes.length; i++) {
      nodes[i].addClassName("noFreeBusy");
      nodes[i].innerHTML = '';
    }
  }
}

function setSlot(tds, nbr, status) {
  var tdnbr = Math.floor(nbr / 4);
  var spannbr = nbr - (tdnbr * 4);
  var days = 0;
  if (tdnbr > 24) {
    days = Math.floor(tdnbr / 24);
    tdnbr -= (days * 24);
  }
  if (tdnbr > 7 && tdnbr < 19) {
    var i = (days * 11 + tdnbr - 7);
    var td = tds[i];
    var spans = td.childNodesWithTag("span");
    if (status == '2')
      spans[spannbr].addClassName("maybe-busy");
    else
      spans[spannbr].addClassName("busy");
  }
}

function updateFreeBusyData(http)
{
  if (http.readyState == 4) {
    if (http.status == 200) {
      var node = http.callbackData;
      var slots = http.responseText.split(",");
      var tds = node.parentNode.parentNode.cells;
      for (var i = 0; i < slots.length; i++) {
        if (slots[i] != '0')
          setSlot(tds, i, slots[i]);
      }
    }
    document.contactFreeBusyAjaxRequest = null;
    if (awaitingFreeBusyRequests.length > 0)
      displayFreeBusyForNode(awaitingFreeBusyRequests.shift());
  }
}

function resetAttendeesValue()
{
  var table = $("attendeesView").childNodesWithTag("div")[0].childNodesWithTag("table")[0];
  var inputs = table.getElementsByTagName("input");
  var uids = new Array();
  for (var i = 0; i < inputs.length - 2; i++) {
    var currentInput = inputs[i];
    var uid = currentInput.getAttribute("uid");
    if (uid) {
      currentInput.uid = uid;
      currentInput.setAttribute("uid", null);
    }
    uids.push(currentInput.uid);
    currentInput.setAttribute("autocomplete", "off");
    currentInput.addEventListener("keydown", onContactKeydown, false);
    currentInput.addEventListener("blur", checkAttendee, false);
  }
  var input = $(freeBusySelectorId);
  input.value = uids.join(",");
  inputs[inputs.length - 2].setAttribute("autocomplete", "off");
  inputs[inputs.length - 2].addEventListener("click", newAttendee, false);
}

function initializeFreeBusyUserSelector()
{
  resetAttendeesValue();
  resetAllFreeBusys();
  disableAnchor($('FBStartTimeReplica_date').parentNode.childNodesWithTag('a')[0]);
  disableAnchor($('FBEndTimeReplica_date').parentNode.childNodesWithTag('a')[0]);
}

function resetAllFreeBusys()
{
  var table = $("attendeesView").childNodesWithTag("div")[0].childNodesWithTag("table")[0];
  var inputs = table.getElementsByTagName("input");

  for (var i = 0; i < inputs.length - 2; i++) {
    var currentInput = inputs[i];
    currentInput.hasfreebusy = false;
//     log ("input: " + currentInput.uid);
    awaitingFreeBusyRequests.push(currentInput);
  }
  if (awaitingFreeBusyRequests.length > 0)
    displayFreeBusyForNode(awaitingFreeBusyRequests.shift());
}

if (this.initTimeWidgets)
  this.oldInitTimeWidgets = this.initTimeWidgets;

this.initTimeWidgets = function(widgets) {
  if (this.oldInitTimeWidgets)
    this.oldInitTimeWidgets(widgets);

  this.timeWidgets = widgets;

  widgets['start']['hour'].addEventListener("change", onTimeWidgetChange, false);
  widgets['start']['minute'].addEventListener("change", onTimeWidgetChange, false);
  widgets['end']['hour'].addEventListener("change", onTimeWidgetChange, false);
  widgets['end']['minute'].addEventListener("change", onTimeWidgetChange, false);
  widgets['start']['date'].addEventListener("change", onTimeDateWidgetChange, false);
  widgets['end']['date'].addEventListener("change", onTimeDateWidgetChange, false);

  widgets['start']['date'].assignReplica($("FBStartTimeReplica_date"));
  widgets['end']['date'].assignReplica($("FBEndTimeReplica_date"));

  var form = $("FBStartTimeReplica_date").form;
  widgets['end']['hour'].assignReplica(form["FBEndTimeReplica_time_hour"]);
  widgets['end']['minute'].assignReplica(form["FBEndTimeReplica_time_minute"]);
  widgets['start']['hour'].assignReplica(form["FBStartTimeReplica_time_hour"]);
  widgets['start']['minute'].assignReplica(form["FBStartTimeReplica_time_minute"]);
}

function onTimeDateWidgetChange(event) {
  if (document.timeWidgetsFreeBusyAjaxRequest) {
    document.timeWidgetsFreeBusyAjaxRequest.aborted = true;
    document.timeWidgetsFreeBusyAjaxRequest.abort();
  }

  var date1 = window.timeWidgets['start']['date'].valueAsShortDateString();
  var date2 = window.timeWidgets['end']['date'].valueAsShortDateString();
  var attendees = $(freeBusySelectorId).value;
  var urlstr = ( "../freeBusyTable?sday=" + date1 + "&eday=" + date2
                 + "&attendees=" + attendees );
  document.timeWidgetsFreeBusyAjaxRequest
    = triggerAjaxRequest(urlstr, timeWidgetsFreeBusyCallback);
}

function timeWidgetsFreeBusyCallback(http)
{
  if (http.readyState == 4) {
    if (http.status == 200) {
      var div = $("parentOf" + freeBusySelectorId.capitalize());
      div.innerHTML = http.responseText;
      resetAttendeesValue();
      resetAllFreeBusys();
      redisplayFreeBusyZone();
    }
    document.timeWidgetsFreeBusyAjaxRequest = null;
  }
}

function onTimeWidgetChange()
{
  setTimeout("redisplayFreeBusyZone();", 1000);
}

function onFreeBusyLoadHandler() {
  initializeFreeBusyUserSelector();
}

window.addEventListener("load", onFreeBusyLoadHandler, false);
