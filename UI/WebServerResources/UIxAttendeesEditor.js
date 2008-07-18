var resultsDiv;
var address;
var awaitingFreeBusyRequests = new Array();
var additionalDays = 2;

var attendeesEditor = {
 delay: 500,
 delayedSearch: false,
 currentField: null,
 selectedIndex: -1,
 names: null,
 UIDs: null,
 emails: null,
 states: null
};

/* address completion */

function onContactKeydown(event) {
  if (event.ctrlKey || event.metaKey) {
    this.focussed = true;
    return;
  }
  if (event.keyCode == 9) { // Tab
    preventDefault(event);
    if (this.confirmedValue)
      this.value = this.confirmedValue;
    this.hasfreebusy = false;
    var row = $(this).up("tr").next();
    this.blur(); // triggers checkAttendee function call
    var input = row.down("input");
    if (input.readOnly)
      newAttendee(null);
    else {
      input.focussed = true;
      input.activate();
    }
  }
  else if (event.keyCode == 0
	|| event.keyCode == 8 // Backspace
        || event.keyCode == 32  // Space
        || event.keyCode > 47) {
      this.setAttribute("modified", "1");
      this.confirmedValue = null;
      this.uid = null;
      this.hasfreebusy = false;
      attendeesEditor.currentField = this;
      if (this.value.length > 0 && !attendeesEditor.delayedSearch) {
	attendeesEditor.delayedSearch = true;
	setTimeout("performSearch()", attendeesEditor.delay);
      }
      else if (this.value.length == 0) {
	if (document.currentPopupMenu)
	  hideMenu(document.currentPopupMenu);
      }
  }
  else if (event.keyCode == 13) {
    preventDefault(event);
    if (this.confirmedValue)
      this.value = this.confirmedValue;
    if (this.uid)
      this.blur(); // triggers checkAttendee function call
    $(this).selectText(0, this.value.length);
    if (document.currentPopupMenu)
      hideMenu(document.currentPopupMenu);
    attendeesEditor.selectedIndex = -1;
  }
  else if ($('attendeesMenu').getStyle('visibility') == 'visible') {
    attendeesEditor.currentField = this;
    if (event.keyCode == 38) { // Up arrow
      if (attendeesEditor.selectedIndex > 0) {
	var attendees = $('attendeesMenu').select("li");
	attendees[attendeesEditor.selectedIndex--].removeClassName("selected");
	attendees[attendeesEditor.selectedIndex].addClassName("selected");
	this.value = this.confirmedValue = attendees[attendeesEditor.selectedIndex].firstChild.nodeValue.trim();
	this.uid = attendees[attendeesEditor.selectedIndex].uid;
      }
    }
    else if (event.keyCode == 40) { // Down arrow
      var attendees = $('attendeesMenu').select("li");
      if (attendees.size() - 1 > attendeesEditor.selectedIndex) {
	if (attendeesEditor.selectedIndex >= 0)
	  attendees[attendeesEditor.selectedIndex].removeClassName("selected");
	attendeesEditor.selectedIndex++;
	attendees[attendeesEditor.selectedIndex].addClassName("selected");
	this.value = this.confirmedValue = attendees[attendeesEditor.selectedIndex].firstChild.nodeValue.trim();
	this.uid = attendees[attendeesEditor.selectedIndex].uid;
      }
    }
  }
}

function performSearch() {
  // Perform address completion
  if (attendeesEditor.currentField) {
    if (document.contactLookupAjaxRequest) {
      // Abort any pending request
      document.contactLookupAjaxRequest.aborted = true;
      document.contactLookupAjaxRequest.abort();
    }
    if (attendeesEditor.currentField.value.trim().length > 0) {
      var urlstr = ( UserFolderURL + "Contacts/contactSearch?search="
		     + escape(attendeesEditor.currentField.value) );
      document.contactLookupAjaxRequest =
	triggerAjaxRequest(urlstr, performSearchCallback, attendeesEditor.currentField);
    }
  }
  attendeesEditor.delayedSearch = false;
}

function performSearchCallback(http) {
  if (http.readyState == 4) {
    var menu = $('attendeesMenu');
    var list = menu.down("ul");
    
    var input = http.callbackData;

    if (http.status == 200) {
      var start = input.value.length;
      var data = http.responseText.evalJSON(true);

      if (data.length > 1) {
	$(list.childNodesWithTag("li")).each(function(item) {
	    item.remove();
	  });
	
	// Populate popup menu
	for (var i = 0; i < data.length; i++) {
	  var contact = data[i];
	  var completeEmail = contact["name"] + " <" + contact["email"] + ">";
	  var node = document.createElement("li");
	  list.appendChild(node);
	  node.uid = contact["uid"];
	  node.appendChild(document.createTextNode(completeEmail));
	  $(node).observe("mousedown", onAttendeeResultClick);
	}

	// Show popup menu
	var offsetScroll = Element.cumulativeScrollOffset(attendeesEditor.currentField);
	var offset = Element.cumulativeOffset(attendeesEditor.currentField);
	var top = offset[1] - offsetScroll[1] + node.offsetHeight + 3;
	var height = 'auto';
	var heightDiff = window.height() - offset[1];
	var nodeHeight = node.getHeight();

	if ((data.length * nodeHeight) > heightDiff)
	    // Limit the size of the popup to the window height, minus 12 pixels
	    height = parseInt(heightDiff/nodeHeight) * nodeHeight - 12 + 'px';

	menu.setStyle({ top: top + "px",
	      left: offset[0] + "px",
	      height: height,
	      visibility: "visible" });
	menu.scrollTop = 0;

	document.currentPopupMenu = menu;
	$(document.body).observe("click", onBodyClickMenuHandler);
      }
      else {
	if (document.currentPopupMenu)
	  hideMenu(document.currentPopupMenu);

	if (data.length == 1) {
	  // Single result
	  var contact = data[0];
	  if (contact["uid"].length > 0)
	    input.uid = contact["uid"];
	  var completeEmail = contact["name"] + " <" + contact["email"] + ">";
	  if (contact["name"].substring(0, input.value.length).toUpperCase()
	      == input.value.toUpperCase())
	    input.value = completeEmail;
	  else
	    // The result matches email address, not user name
	    input.value += ' >> ' + completeEmail;
	  input.confirmedValue = completeEmail;
	  var end = input.value.length;
	  $(input).selectText(start, end);

	  attendeesEditor.selectedIndex = -1;
	}
      }
    }
    else
      if (document.currentPopupMenu)
	hideMenu(document.currentPopupMenu);
    document.contactLookupAjaxRequest = null;
  }
}

function onAttendeeResultClick(event) {
  if (attendeesEditor.currentField) {
    attendeesEditor.currentField.uid = this.uid;
    attendeesEditor.currentField.value = this.firstChild.nodeValue.trim();
    attendeesEditor.currentField.confirmedValue = attendeesEditor.currentField.value;
    attendeesEditor.currentField.blur(); // triggers checkAttendee function call
  }
}

function resetFreeBusyZone() {
  var table = $("freeBusyHeader");
  var row = table.rows[2];
  for (var i = 0; i < row.cells.length; i++) {
    var nodes = $(row.cells[i]).childNodesWithTag("span");
    for (var j = 0; j < nodes.length; j++)
      nodes[j].removeClassName("busy");
  }
}

function redisplayFreeBusyZone() {
  var table = $("freeBusyHeader");
  var row = table.rows[2];
  var stDay = $("startTime_date").valueAsDate();
  var etDay = $("endTime_date").valueAsDate();

  var days = stDay.daysUpTo(etDay);
  var addDays = days.length - 1;
  var stHour = parseInt($("startTime_time_hour").value);
  var stMinute = parseInt($("startTime_time_minute").value) / 15;
  var etHour = parseInt($("endTime_time_hour").value);
  var etMinute = parseInt($("endTime_time_minute").value) / 15;
  if (stHour < dayStartHour) {
    stHour = dayStartHour;
    stMinute = 0;
  }
  if (stHour > dayEndHour + 1) {
    stHour = dayEndHour + 1;
    stMinute = 0;
  }
  if (etHour < dayStartHour) {
    etHour = dayStartHour;
    etMinute = 0;
  }
  if (etHour > dayEndHour + 1) {
    etHour = dayEndHour;
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

  var deltaCells = (etHour - stHour) + ((dayEndHour - dayStartHour + 1) * addDays);
  var deltaSpans = (deltaCells * 4 ) + (etMinute - stMinute);
  var currentCellNbr = stHour - dayStartHour;
  var currentCell = row.cells[currentCellNbr];
  var currentSpanNbr = stMinute;
  var spans = $(currentCell).childNodesWithTag("span");
  resetFreeBusyZone();
  while (deltaSpans > 0) {
    var currentSpan = spans[currentSpanNbr];
    currentSpan.addClassName("busy");
    currentSpanNbr++;
    if (currentSpanNbr > 3) {
      currentSpanNbr = 0;
      currentCellNbr++;
      currentCell = row.cells[currentCellNbr];
      spans = $(currentCell).childNodesWithTag("span");
    }
    deltaSpans--;
  }
}

function newAttendee(event) {
   var table = $("freeBusyAttendees");
   var tbody = table.tBodies[0];
   var model = tbody.rows[tbody.rows.length - 1];
   var futureRow = tbody.rows[tbody.rows.length - 2];
   var newRow = model.cloneNode(true);
   tbody.insertBefore(newRow, futureRow);
  
   $(newRow).removeClassName("attendeeModel");
 
   var input = $(newRow).down("input");
   input.observe("keydown", onContactKeydown);
   input.observe("blur", checkAttendee);

   input.focussed = true;
   input.activate();

   table = $("freeBusyData");
   tbody = table.tBodies[0];
   model = tbody.rows[tbody.rows.length - 1];
   futureRow = tbody.rows[tbody.rows.length - 2];
   newRow = model.cloneNode(true);
   tbody.insertBefore(newRow, futureRow);
   $(newRow).removeClassName("dataModel");

   var attendeesDiv = $$('TABLE#freeBusy TD.freeBusyAttendees DIV').first();
   var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();
   
   dataDiv.scrollTop = attendeesDiv.scrollTop;
}

function checkAttendee() {
  if (document.currentPopupMenu)
    hideMenu(document.currentPopupMenu);

  if (document.currentPopupMenu && !this.confirmedValue) {
    // Hack for IE7; blur event is triggered on input field when
    // selecting a menu item
    var visible = $(document.currentPopupMenu).getStyle('visibility') != 'hidden';
    if (visible)
      return;
  }
  
  this.focussed = false;
  var row = this.parentNode.parentNode;
  var tbody = row.parentNode;
  if (tbody && this.value.trim().length == 0) {
    var dataTable = $("freeBusyData").tBodies[0];
    var dataRow = dataTable.rows[row.sectionRowIndex];
    tbody.removeChild(row);
    dataTable.removeChild(dataRow);
  }
  else if (this.readAttribute("modified") == "1") {
    if (!$(row).hasClassName("needs-action")) {
      $(row).addClassName("needs-action");
      $(row).removeClassName("declined");
      $(row).removeClassName("accepted");    
    }
    if (!this.hasfreebusy) {
      if (this.uid && this.confirmedValue)
	this.value = this.confirmedValue;
      displayFreeBusyForNode(this);
      this.hasfreebusy = true;
    }
    this.setAttribute("modified", "0");
  }
  
  attendeesEditor.currentField = null;
}

function displayFreeBusyForNode(input) {
  var rowIndex = input.parentNode.parentNode.sectionRowIndex;
  var nodes = $("freeBusyData").tBodies[0].rows[rowIndex].cells;
  if (input.uid) {
    if (document.contactFreeBusyAjaxRequest)
      awaitingFreeBusyRequests.push(input);
    else {
      for (var i = 0; i < nodes.length; i++) {
	$(nodes[i]).removeClassName("noFreeBusy");
	$(nodes[i]).innerHTML = ('<span class="freeBusyZoneElement"></span>'
				 + '<span class="freeBusyZoneElement"></span>'
				 + '<span class="freeBusyZoneElement"></span>'
				 + '<span class="freeBusyZoneElement"></span>');
      }
      if (document.contactFreeBusyAjaxRequest) {
	// Abort any pending request
	document.contactFreeBusyAjaxRequest.aborted = true;
	document.contactFreeBusyAjaxRequest.abort();
      }
      var sd = $('startTime_date').valueAsShortDateString();
      var ed = $('endTime_date').valueAsShortDateString();
      var urlstr = ( UserFolderURL + "../" + input.uid
		     + "/freebusy.ifb/ajaxRead?"
		     + "sday=" + sd + "&eday=" + ed + "&additional=" +
		     additionalDays );
      document.contactFreeBusyAjaxRequest
	= triggerAjaxRequest(urlstr,
			     updateFreeBusyDataCallback,
			     input);
    }
  } else {
    for (var i = 0; i < nodes.length; i++) {
      $(nodes[i]).addClassName("noFreeBusy");
      $(nodes[i]).update();
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
  if (tdnbr > (dayStartHour - 1) && tdnbr < (dayEndHour + 1)) {
    var i = (days * (dayEndHour - dayStartHour + 1) + tdnbr - (dayStartHour - 1));
    var td = tds[i - 1];
    var spans = $(td).childNodesWithTag("span");
    if (status == '2')
      $(spans[spannbr]).addClassName("maybe-busy");
    else
      $(spans[spannbr]).addClassName("busy");
  }
}

function updateFreeBusyDataCallback(http) {
  if (http.readyState == 4) {
    if (http.status == 200) {
      var input = http.callbackData;
      var slots = http.responseText.split(",");
      var rowIndex = input.parentNode.parentNode.sectionRowIndex;
      var nodes = $("freeBusyData").tBodies[0].rows[rowIndex].cells;
      for (var i = 0; i < slots.length; i++) {
        if (slots[i] != '0')
	  setSlot(nodes, i, slots[i]);
      }
    }
    document.contactFreeBusyAjaxRequest = null;
    if (awaitingFreeBusyRequests.length > 0)
      displayFreeBusyForNode(awaitingFreeBusyRequests.shift());
  }
}

function resetAllFreeBusys() {
  var table = $("freeBusy");
  var inputs = table.getElementsByTagName("input");

  for (var i = 0; i < inputs.length - 2; i++) {
    var currentInput = inputs[i];
    currentInput.hasfreebusy = false;
    displayFreeBusyForNode(inputs[i]);
  }
}

function initializeWindowButtons() {
   var okButton = $("okButton");
   var cancelButton = $("cancelButton");

   okButton.observe("click", onEditorOkClick, false);
   cancelButton.observe("click", onEditorCancelClick, false);

   var buttons = $("freeBusyViewButtons").childNodesWithTag("a");
   for (var i = 0; i < buttons.length; i++)
     buttons[i].observe("click", listRowMouseDownHandler, false);
   buttons = $("freeBusyZoomButtons").childNodesWithTag("a");
   for (var i = 0; i < buttons.length; i++)
     buttons[i].observe("click", listRowMouseDownHandler, false);
   buttons = $("freeBusyButtons").childNodesWithTag("a");
   for (var i = 0; i < buttons.length; i++)
     buttons[i].observe("click", listRowMouseDownHandler, false);
}

function onEditorOkClick(event) {
   preventDefault(event);
   
   attendeesEditor.names = new Array();
   attendeesEditor.UIDs = new Array();
   attendeesEditor.emails = new Array();
   attendeesEditor.states = new Array();

   var table = $("freeBusy");
   var inputs = table.getElementsByTagName("input");
   for (var i = 0; i < inputs.length - 2; i++) {
     var row = $(inputs[i]).up("tr");
     var name = extractEmailName(inputs[i].value);
     var email = extractEmailAddress(inputs[i].value);
     var uid = "";
     if (inputs[i].uid)
       uid = inputs[i].uid;
     if (!(name && name.length > 0))
       if (inputs[i].uid)
	 name = inputs[i].uid;
       else
	 name = email;
     var state = "needs-action";
     if (row.hasClassName("accepted"))
       state = "accepted";
     else if (row.hasClassName("declined"))
       state = "declined";
     var pos = attendeesEditor.emails.indexOf(email);
     if (pos == -1)
       pos = attendeesEditor.emails.length;
     attendeesEditor.names[pos] = name;
     attendeesEditor.UIDs[pos] = uid;
     attendeesEditor.emails[pos] = email;
     attendeesEditor.states[pos] = state;
   }
   parent$("attendeesNames").value = attendeesEditor.names.join(",");
   parent$("attendeesUIDs").value = attendeesEditor.UIDs.join(",");
   parent$("attendeesEmails").value = attendeesEditor.emails.join(",");
   parent$("attendeesStates").value = attendeesEditor.states.join(",");
   window.opener.refreshAttendees();

   updateParentDateFields("startTime", "startTime");
   updateParentDateFields("endTime", "endTime");

   window.close();
}

function onEditorCancelClick(event) {
   preventDefault(event);
   window.close();
}

function synchronizeWithParent(srcWidgetName, dstWidgetName) {
   var srcDate = parent$(srcWidgetName + "_date");
   var dstDate = $(dstWidgetName + "_date");
   dstDate.value = srcDate.value;
   dstDate.updateShadowValue(srcDate);

   var srcHour = parent$(srcWidgetName + "_time_hour");
   var dstHour = $(dstWidgetName + "_time_hour");
   dstHour.value = srcHour.value;
   dstHour.updateShadowValue(srcHour);

   var srcMinute = parent$(srcWidgetName + "_time_minute");
   var dstMinute = $(dstWidgetName + "_time_minute");
   dstMinute.value = srcMinute.value;
   dstMinute.updateShadowValue(dstMinute);
}

function updateParentDateFields(srcWidgetName, dstWidgetName) {
   var srcDate = $(srcWidgetName + "_date");
   var dstDate = parent$(dstWidgetName + "_date");
   dstDate.value = srcDate.value;

   var srcHour = $(srcWidgetName + "_time_hour");
   var dstHour = parent$(dstWidgetName + "_time_hour");
   dstHour.value = srcHour.value;

   var srcMinute = $(srcWidgetName + "_time_minute");
   var dstMinute = parent$(dstWidgetName + "_time_minute");
   dstMinute.value = srcMinute.value;
}

function onTimeWidgetChange() {
   redisplayFreeBusyZone();
}

function onTimeDateWidgetChange() {
   var table = $("freeBusyHeader");
   var rows = table.select("tr");
   for (var i = 0; i < rows.length; i++) {
      for (var j = rows[i].cells.length - 1; j > -1; j--) {
         rows[i].deleteCell(j);
      }
   }
  
   table = $("freeBusyData");
   rows = table.select("tr");
   for (var i = 0; i < rows.length; i++) {
      for (var j = rows[i].cells.length - 1; j > -1; j--) {
         rows[i].deleteCell(j);
      }
   }

   prepareTableHeaders();
   prepareTableRows();
   redisplayFreeBusyZone();
   resetAllFreeBusys();
}

function prepareTableHeaders() {
   var startTimeDate = $("startTime_date");
   var startDate = startTimeDate.valueAsDate();

   var endTimeDate = $("endTime_date");
   var endDate = endTimeDate.valueAsDate();
   endDate.setTime(endDate.getTime() + (additionalDays * 86400000));

   var rows = $("freeBusyHeader").rows;
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
            $(spanElement).addClassName("freeBusyZoneElement");
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

   var rows = $("freeBusyData").tBodies[0].rows;
   var days = startDate.daysUpTo(endDate);
   var width = $('freeBusyHeader').getWidth();
   $("freeBusyData").setStyle({ width: width + 'px' });
   for (var i = 0; i < days.length; i++)
      for (var rowNbr = 0; rowNbr < rows.length; rowNbr++)
	for (var hour = dayStartHour; hour < (dayEndHour + 1); hour++)
	  rows[rowNbr].appendChild(document.createElement("td"));
}

function prepareAttendees() {
   var value = parent$("attendeesNames").value;
   var tableAttendees = $("freeBusyAttendees");
   var tableData = $("freeBusyData");
   if (value.length > 0) {
      attendeesEditor.names = parent$("attendeesNames").value.split(",");
      attendeesEditor.UIDs = parent$("attendeesUIDs").value.split(",");
      attendeesEditor.emails = parent$("attendeesEmails").value.split(",");
      attendeesEditor.states = parent$("attendeesStates").value.split(",");

      var tbodyAttendees = tableAttendees.tBodies[0];
      var modelAttendee = tbodyAttendees.rows[tbodyAttendees.rows.length - 1];
      var newAttendeeRow = tbodyAttendees.rows[tbodyAttendees.rows.length - 2];

      var tbodyData = tableData.tBodies[0];
      var modelData = tbodyData.rows[tbodyData.rows.length - 1];
      var newDataRow = tbodyData.rows[tbodyData.rows.length - 2];

      for (var i = 0; i < attendeesEditor.names.length; i++) {
         var row = modelAttendee.cloneNode(true);
         tbodyAttendees.insertBefore(row, newAttendeeRow);
         $(row).removeClassName("attendeeModel");
         $(row).addClassName(attendeesEditor.states[i]);
         var input = $(row).down("input");
         var value = "";
         if (attendeesEditor.names[i].length > 0
             && attendeesEditor.names[i] != attendeesEditor.emails[i])
            value += attendeesEditor.names[i] + " ";
         value += "<" + attendeesEditor.emails[i] + ">";
         input.value = value;
         if (attendeesEditor.UIDs[i].length > 0)
            input.uid = attendeesEditor.UIDs[i];
         input.setAttribute("name", "");
         input.setAttribute("modified", "0");
         input.observe("blur", checkAttendee);
         input.observe("keydown", onContactKeydown);
	 
         row = modelData.cloneNode(true);
         tbodyData.insertBefore(row, newDataRow);
         $(row).removeClassName("dataModel");
	 
         displayFreeBusyForNode(input);
      }
   }
   else {
      attendeesEditor.names = new Array();
      attendeesEditor.UIDs = new Array();
      attendeesEditor.emails = new Array();
      //newAttendee(null);
   }

   var inputs = tableAttendees.select("input");
   inputs[inputs.length - 2].setAttribute("autocomplete", "off");
   inputs[inputs.length - 2].observe("click", newAttendee);
}

function onWindowResize(event) {
   var view = $('freeBusyView');
   var attendeesCell = $$('TABLE#freeBusy TD.freeBusyAttendees').first();
   var headerDiv = $$('TABLE#freeBusy TD.freeBusyHeader DIV').first();
   var attendeesDiv = $$('TABLE#freeBusy TD.freeBusyAttendees DIV').first();
   var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();
   var width = view.getWidth() - attendeesCell.getWidth();
   var height = view.getHeight() - headerDiv.getHeight();

   attendeesDiv.setStyle({ height: (height - 20) + 'px' });
   headerDiv.setStyle({ width: (width - 20) + 'px' });
   dataDiv.setStyle({ width: (width - 4) + 'px',
            height: (height - 2) + 'px' });
}

function onScroll(event) {
  var headerDiv = $$('TABLE#freeBusy TD.freeBusyHeader DIV').first();
  var attendeesDiv = $$('TABLE#freeBusy TD.freeBusyAttendees DIV').first();
  var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();

  headerDiv.scrollLeft = dataDiv.scrollLeft;
  attendeesDiv.scrollTop = dataDiv.scrollTop;
}

function onFreeBusyLoadHandler() {
   var widgets = {'start': {'date': $("startTime_date"),
                            'hour': $("startTime_time_hour"),
                            'minute': $("startTime_time_minute")},
                  'end': {'date': $("endTime_date"),
                          'hour': $("endTime_time_hour"),
                          'minute': $("endTime_time_minute")}};

   synchronizeWithParent("startTime", "startTime");
   synchronizeWithParent("endTime", "endTime");

   initTimeWidgets(widgets);
   initializeWindowButtons();
   prepareTableHeaders();
   prepareTableRows();
   redisplayFreeBusyZone();
   prepareAttendees();
   onWindowResize(null);
   Event.observe(window, "resize", onWindowResize);
   $$('TABLE#freeBusy TD.freeBusyData DIV').first().observe("scroll", onScroll);
}

FastInit.addOnLoad(onFreeBusyLoadHandler);

/* Functions related to UIxTimeDateControl widget */

function initTimeWidgets(widgets) {
   this.timeWidgets = widgets;

   assignCalendar('startTime_date');
   assignCalendar('endTime_date');

   widgets['start']['date'].observe("change",
                 this.onAdjustTime, false);
   widgets['start']['hour'].observe("change",
                 this.onAdjustTime, false);
   widgets['start']['minute'].observe("change",
                 this.onAdjustTime, false);

   widgets['end']['date'].observe("change",
                 this.onAdjustTime, false);
   widgets['end']['hour'].observe("change",
                 this.onAdjustTime, false);
   widgets['end']['minute'].observe("change",
                 this.onAdjustTime, false);

   var allDayLabel = $("allDay");
   if (allDayLabel) {
      var input = $(allDayLabel).childNodesWithTag("input")[0];
      input.observe("change", onAllDayChanged.bindAsEventListener(input));
      if (input.checked) {
         for (var type in widgets) {
            widgets[type]['hour'].disabled = true;
            widgets[type]['minute'].disabled = true;
         }
      }
   }
}

function onAdjustTime(event) {
   var endDate = window.getEndDate();
   var startDate = window.getStartDate();
   if ($(this).readAttribute("id").startsWith("start")) {
      // Start date was changed
      var delta = window.getShadowStartDate().valueOf() -
         startDate.valueOf();
      var newEndDate = new Date(endDate.valueOf() - delta);
      window.setEndDate(newEndDate);
      window.timeWidgets['end']['date'].updateShadowValue();
      window.timeWidgets['end']['hour'].updateShadowValue();
      window.timeWidgets['end']['minute'].updateShadowValue();
      window.timeWidgets['start']['date'].updateShadowValue();
      window.timeWidgets['start']['hour'].updateShadowValue();
      window.timeWidgets['start']['minute'].updateShadowValue();
   }
   else {
      // End date was changed
      var delta = endDate.valueOf() - startDate.valueOf();  
      if (delta < 0) {
         alert(labels.validate_endbeforestart);
         var oldEndDate = window.getShadowEndDate();
         window.setEndDate(oldEndDate);

         window.timeWidgets['end']['date'].updateShadowValue();
         window.timeWidgets['end']['hour'].updateShadowValue();
         window.timeWidgets['end']['minute'].updateShadowValue();
      }
   }

   // Specific function for the attendees editor
   onTimeDateWidgetChange();
}

function _getDate(which) {
  var date = window.timeWidgets[which]['date'].valueAsDate();
  date.setHours( window.timeWidgets[which]['hour'].value );
  date.setMinutes( window.timeWidgets[which]['minute'].value );

  return date;
}

function getStartDate() {
  return this._getDate('start');
}

function getEndDate() {
  return this._getDate('end');
}

function _getShadowDate(which) {
  var date = window.timeWidgets[which]['date'].getAttribute("shadow-value").asDate();
  var intValue = parseInt(window.timeWidgets[which]['hour'].getAttribute("shadow-value"));
  date.setHours(intValue);
  intValue = parseInt(window.timeWidgets[which]['minute'].getAttribute("shadow-value"));
  date.setMinutes(intValue);

  return date;
}

function getShadowStartDate() {
  return this._getShadowDate('start');
}

function getShadowEndDate() {
  return this._getShadowDate('end');
}

function _setDate(which, newDate) {
   window.timeWidgets[which]['date'].setValueAsDate(newDate);
   window.timeWidgets[which]['hour'].value = newDate.getHours();
   var minutes = newDate.getMinutes();
   if (minutes % 15)
      minutes += (15 - minutes % 15);
   window.timeWidgets[which]['minute'].value = minutes;
}

function setStartDate(newStartDate) {
   this._setDate('start', newStartDate);
}

function setEndDate(newEndDate) {
   this._setDate('end', newEndDate);
}
