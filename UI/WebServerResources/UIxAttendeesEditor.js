var resultsDiv;
var searchField;
var running = false;
var address;
var delay = 500;
var requestField;
var awaitingFreeBusyRequests = new Array();
var additionalDays = 2;

var dayStartHour = 8;
var dayEndHour = 18;

var attendeesNames;
var attendeesEmails;

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
      requestField.setAttribute("modified", "1");
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
  var table = $("freeBusy");
  var row = table.tHead.rows[2];
  for (var i = 1; i < row.cells.length; i++) {
    var nodes = row.cells[i].childNodesWithTag("span");
    for (var j = 0; j < nodes.length; j++)
      nodes[j].removeClassName("busy");
  }
}

function redisplayFreeBusyZone()
{
  var table = $("freeBusy");
  var row = table.tHead.rows[2];
  var stDay = $("startTime_date").valueAsDate();
  var etDay = $("endTime_date").valueAsDate();

  var days = stDay.daysUpTo(etDay);
  var addDays = days.length - 1;
  var stHour = parseInt($("startTime_time_hour").value);
  var stMinute = parseInt($("startTime_time_minute").value) / 15;
  var etHour = parseInt($("endTime_time_hour").value);
  var etMinute = parseInt($("endTime_time_minute").value) / 15;
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
  var table = $("freeBusy");
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
    var sd = $('startTime_date').valueAsShortDateString();
    var ed = $('endTime_date').valueAsShortDateString();
    var urlstr = ( UserFolderURL + "../" + node.uid + "/freebusy.ifb/ajaxRead?"
                   + "sday=" + sd + "&eday=" + ed + "&additional=" + additionalDays );
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
  var table = $("freeBusy");
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
  inputs[inputs.length - 2].setAttribute("autocomplete", "off");
  inputs[inputs.length - 2].addEventListener("click", newAttendee, false);
}

function resetAllFreeBusys()
{
  var table = $("freeBusy");
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

function initializeWindowButtons() {
   var okButton = $("okButton");
   var cancelButton = $("cancelButton");

   okButton.addEventListener("click", onEditorOkClick, false);
   cancelButton.addEventListener("click", onEditorCancelClick, false);
}

function onEditorOkClick(event) {
   event.preventDefault();

   attendeesNames = new Array();
   attendeesEmails = new Array();

   var table = $("freeBusy");
   var inputs = table.getElementsByTagName("input");
   for (var i = 0; i < inputs.length - 2; i++) {
     var name = inputs[i].uid;
     if (!(name && name.length > 0)) {
       name = extractEmailName(inputs[i].value);
       log ("name: " + name);
     }
     var email = extractEmailAddress(inputs[i].value);
     var pos = attendeesEmails.indexOf(email);
     if (pos == -1)
       pos = attendeesEmails.length;
     attendeesNames[pos] = name;
     attendeesEmails[pos] = email;
   }

   parent$("attendeesNames").value = attendeesNames.join(",");
   parent$("attendeesEmails").value = attendeesEmails.join(",");
   window.opener.refreshAttendees();

   window.close();
}

function onEditorCancelClick(event) {
   event.preventDefault();
   window.close();
}

function synchronizeWithParent(srcWidgetName, dstWidgetName) {
   var srcDate = parent$(srcWidgetName + "_date");
   var dstDate = $(dstWidgetName + "_date");
   dstDate.value = srcDate.value;

   var srcHour = parent$(srcWidgetName + "_time_hour");
   var dstHour = $(dstWidgetName + "_time_hour");
   dstHour.value = srcHour.value;

   var srcMinute = parent$(srcWidgetName + "_time_minute");
   var dstMinute = $(dstWidgetName + "_time_minute");
   dstMinute.value = srcMinute.value;
}

function initializeTimeWidgets() {
   synchronizeWithParent("startTime", "startTime");
   synchronizeWithParent("endTime", "endTime");

   $("startTime_date").addEventListener("change", onTimeDateWidgetChange, false);
   $("startTime_time_hour").addEventListener("change", onTimeWidgetChange, false);
   $("startTime_time_minute").addEventListener("change", onTimeWidgetChange,
					       false);

   $("endTime_date").addEventListener("change", onTimeDateWidgetChange, false);
   $("endTime_time_hour").addEventListener("change", onTimeWidgetChange, false);
   $("endTime_time_minute").addEventListener("change", onTimeWidgetChange, false);
}

function onTimeWidgetChange()
{
   redisplayFreeBusyZone();
}

function onTimeDateWidgetChange(event) {
  var table = $("freeBusy");

  var rows = table.tHead.rows;
  for (var i = 0; i < rows.length; i++) {
     for (var j = rows[i].cells.length - 1; j > 0; j--) {
	rows[i].deleteCell(j);
     }
  }

  rows = table.tBodies[0].rows;
  for (var i = 0; i < rows.length; i++) {
     for (var j = rows[i].cells.length - 1; j > 0; j--) {
	rows[i].deleteCell(j);
     }
  }

  prepareTableHeaders();
  prepareTableRows();
  redisplayFreeBusyZone();
  resetAttendeesValue();
  resetAllFreeBusys();
}

function prepareTableHeaders() {
   var startTimeDate = $("startTime_date");
   var startDate = startTimeDate.valueAsDate();

   var endTimeDate = $("endTime_date");
   var endDate = endTimeDate.valueAsDate();
   endDate.setTime(endDate.getTime() + (additionalDays * 86400000));

   var rows = $("freeBusy").tHead.rows;
   var days = startDate.daysUpTo(endDate);
   for (var i = 0; i < days.length; i++) {
      var header1 = document.createElement("th");
      header1.colSpan = (dayEndHour - dayStartHour) + 1;
      header1.appendChild(document.createTextNode(days[i].toLocaleDateString()));
      rows[0].appendChild(header1);
      for (var hour = dayStartHour; hour < (dayEndHour + 1); hour++) {
	 var header2 = document.createElement("th");
	 var text = hour + ":00";
	 if (hour < 10)
	    text = "0" + text;
	 header2.appendChild(document.createTextNode(text));
	 rows[1].appendChild(header2);

	 var header3 = document.createElement("th");
	 for (var span = 0; span < 4; span++) {
	    var spanElement = document.createElement("span");
	    spanElement.addClassName("freeBusyZoneElement");
	    header3.appendChild(spanElement);
	 }
	 rows[2].appendChild(header3);
      }
   }
}

function prepareTableRows() {
   var startTimeDate = $("startTime_date");
   var startDate = startTimeDate.valueAsDate();

   var endTimeDate = $("endTime_date");
   var endDate = endTimeDate.valueAsDate();
   endDate.setTime(endDate.getTime() + (additionalDays * 86400000));

   var rows = $("freeBusy").tBodies[0].rows;
   var days = startDate.daysUpTo(endDate);
   for (var i = 0; i < days.length; i++) {
      for (var rowNbr = 0; rowNbr < rows.length; rowNbr++) {
	 for (var hour = dayStartHour; hour < (dayEndHour + 1); hour++) {
	    var cell = document.createElement("td");
	    rows[rowNbr].appendChild(cell);
	 }
      }
   }
}

function prepareAttendees() {
   var value = parent$("attendeesNames").value;
   if (value.length > 0) {
      attendeesNames = parent$("attendeesNames").value.split(",");
      attendeesEmails = parent$("attendeesEmails").value.split(",");

      var body = $("freeBusy").tBodies[0];
      for (var i = 0; i < attendeesNames.length; i++) {
	 var tr = body.insertRow(i);
	 var td = document.createElement("td");
	 td.addClassName("attendees");
	 var input = document.createElement("input");
	 var value = "";
	 if (attendeesNames[i].length > 0)
	    value += attendeesNames[i] + " ";
	 value += "<" + attendeesEmails[i] + ">";
	 input.value = value;
	 input.setAttribute("uid", attendeesNames[i]);
	 input.addClassName("textField");
	 input.setAttribute("modified", "0");
	 tr.appendChild(td)
	 td.appendChild(input)
      }
   }
   else {
      attendeesNames = new Array();
      attendeesEmails = new Array();
   }
}

function onFreeBusyLoadHandler() {
   initializeWindowButtons();
   initializeTimeWidgets();
   prepareAttendees();
   prepareTableHeaders();
   prepareTableRows();
   redisplayFreeBusyZone();
   resetAttendeesValue();
   resetAllFreeBusys();
}

window.addEventListener("load", onFreeBusyLoadHandler, false);
