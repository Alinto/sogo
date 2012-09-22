/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/* TODO:
   - set work days from preferences */

var OwnerLogin = "";

var resultsDiv;
var address;

var availability;

var isAllDay = parent$("isAllDay").checked + 0;
var displayStartHour = 0;
var displayEndHour = 23;

var attendeesEditor = {
    delay: 500,
    selectedIndex: -1
};

function handleAllDay() {
    window.timeWidgets['start']['time'].value = dayStartHour + ":00";
    window.timeWidgets['end']['time'].value = dayEndHour + ":00";

    $("startTime_time").disabled = true;
    $("endTime_time").disabled = true;

    $("freeBusyTimeRange").addClassName("hidden");
}

/* address completion */

function resolveListAttendees(input, append) {
    var urlstr = (UserFolderURL
                  + "Contacts/"
                  + escape(input.container) + "/"
                  + escape(input.cname) + "/properties");
    triggerAjaxRequest(urlstr, resolveListAttendeesCallback,
                       { "input": input, "append": append });
}

function resolveListAttendeesCallback(http) {
    var input = http.callbackData["input"];
    if (http.readyState == 4 && http.status == 200) {
        var append = http.callbackData["append"];
        var contacts = http.responseText.evalJSON(true);
        for (var i = 0; i < contacts.length; i++) {
            var contact = contacts[i];
            var fullName = contact[1];
            if (fullName && fullName.length > 0) {
                fullName += " <" + contact[2] + ">";
            }
            else {
                fullName = contact[2];
            }
            input.uid = null;
            input.cname = null;
            input.container = null;
            input.isList = false;
            input.value = contact[2];
            input.confirmedValue = null;
            input.hasfreebusy = false;
            input.modified = true;
            input.checkAfterLookup = true;
            performSearch(input);
            if (i < (contacts.length - 1)) {
                var nextRow = newAttendee(input.parentNode.parentNode);
                input = nextRow.down("input");
            } else if (append) {
                var row = input.parentNode.parentNode;
                var tBody = row.parentNode;
                if (row.rowIndex == (tBody.rows.length - 3)) {
                    //input.setCaretTo(0);
                    newAttendee();
                } else {
                    var nextRow = tBody.rows[row.rowIndex + 1];
                    input = nextRow.down("input");
                    //input.selectText(0, input.value.length);
                    //input.focussed = true;
                }
            } else {
                //input.setCaretTo(0);
                //input.blur();
            }
        }
    }
    else {
        // List not found (probably an LDAP group)
        performSearch(input);
    }
}

function onContactKeydown(event) {
    if (event.ctrlKey || event.metaKey) {
        this.focussed = true;
        return;
    }
    if (event.keyCode == Event.KEY_TAB || event.keyCode == Event.KEY_RETURN) {
        preventDefault(event);
        this.scrollLeft = 0;
        $(this).up('DIV').scrollLeft = 0;
        attendeesEditor.selectedIndex = -1;
        if (this.confirmedValue)
            this.value = this.confirmedValue;
        this.hasfreebusy = false;
        if (this.isList) {
            resolveListAttendees(this, true);
            event.stop();
        } else {
            this.focussed = false;
            var row = $(this).up("tr").next();
            var input = row.down("input");
            if (input) {
                input.focussed = true;
                input.activate();
            }
            else if (!this.value.blank())
                newAttendee();
        }
    }
    else if (event.keyCode == 0
             || event.keyCode == Event.KEY_BACKSPACE
             || event.keyCode == 32  // Space
             || event.keyCode > 47) {
        this.modified = true;
        this.confirmedValue = null;
        this.cname = null;
        this.uid = null;
        this.container = null;
        this.hasfreebusy = false;
        if (this.searchTimeout) {
            window.clearTimeout(this.searchTimeout);
        }
        if (this.value.length > 0) {
            var thisInput = this;
            this.searchTimeout = setTimeout(function()
                                            {performSearch(thisInput);
                                             thisInput = null;},
                                            attendeesEditor.delay);
        }
        else if (this.value.length == 0) {
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
        }
    }
    else if ($('attendeesMenu').getStyle('visibility') == 'visible') {
        if (event.keyCode == Event.KEY_UP) { // Up arrow
            if (attendeesEditor.selectedIndex > 0) {
                var attendees = $('attendeesMenu').select("li");
                attendees[attendeesEditor.selectedIndex--].removeClassName("selected");
                var attendee = attendees[attendeesEditor.selectedIndex];
                attendee.addClassName("selected");
                this.value = this.confirmedValue = attendee.address;
                this.uid = attendee.uid;
                this.isList = attendee.isList;
                this.cname = attendee.cname;
                this.container = attendee.container;
            }
        }
        else if (event.keyCode == Event.KEY_DOWN) { // Down arrow
            var attendees = $('attendeesMenu').select("li");
            if (attendees.size() - 1 > attendeesEditor.selectedIndex) {
                if (attendeesEditor.selectedIndex >= 0)
                    attendees[attendeesEditor.selectedIndex].removeClassName("selected");
                attendeesEditor.selectedIndex++;
                var attendee = attendees[attendeesEditor.selectedIndex];
                attendee.addClassName("selected");
                this.value = this.confirmedValue = attendee.address;
                this.isList = attendee.isList;
                this.uid = attendee.uid;
                this.cname = attendee.cname;
                this.container = attendee.container;
            }
        }
    }
}

function performSearch(input) {
    // Perform address completion
    if (input.value.trim().length > minimumSearchLength) {
        var urlstr = (UserFolderURL
                      + "Contacts/allContactSearch?excludeGroups=1&search="
                      + encodeURIComponent(input.value));
        triggerAjaxRequest(urlstr, performSearchCallback, input);
    }
    input.searchTimeout = null;
}

function performSearchCallback(http) {
    if (http.readyState == 4) {
        var menu = $('attendeesMenu');
        var list = menu.down("ul");
    
        var input = http.callbackData;

        if (http.status == 200) {
            var start = input.value.length;
            var data = http.responseText.evalJSON(true);

            if (data.contacts.length > 1 && input.focussed) {
                list.input = input;
                $(list.childNodesWithTag("li")).each(function(item) {
                        item.remove();
                    });
	
                // Populate popup menu
                for (var i = 0; i < data.contacts.length; i++) {
                    var contact = data.contacts[i];
                    var isList = (contact["c_component"] &&
                                  contact["c_component"] == "vlist");
                    var completeEmail = contact["c_cn"].trim();
                    if (contact["c_mail"]) {
                        if (completeEmail)
                            completeEmail += " <" + contact["c_mail"] + ">";
                        else
                            completeEmail = contact["c_mail"];
                    }
                    var node = createElement('li');
                    list.appendChild(node);
                    node.address = completeEmail;
                    // log("node.address: " + node.address);
                    if (contact["c_uid"])
                        node.uid = (contact["isMSExchange"]? UserLogin + ":" : "") + contact["c_uid"];
                    else
                        node.uid = null;
                    node.isList = isList;
                    if (isList) {
                        node.cname = contact["c_name"];
                        node.container = contact["container"];
                    }
                    var matchPosition = completeEmail.toLowerCase().indexOf(data.searchText.toLowerCase());
                    if (matchPosition > -1) {
                        var matchBefore = completeEmail.substring(0, matchPosition);
                        var matchText = completeEmail.substring(matchPosition, matchPosition + data.searchText.length);
                        var matchAfter = completeEmail.substring(matchPosition + data.searchText.length);
                        node.appendChild(document.createTextNode(matchBefore));
                        node.appendChild(new Element('strong').update(matchText));
                        node.appendChild(document.createTextNode(matchAfter));
                    }
                    else {
                        node.appendChild(document.createTextNode(completeEmail));
                    }
                    if (contact["contactInfo"])
                        node.appendChild(document.createTextNode(" (" +
                                                                 contact["contactInfo"] + ")"));
                    node.observe("mousedown",
                                 onAttendeeResultClick.bindAsEventListener(node));
                }

                // Show popup menu
                var offsetScroll = Element.cumulativeScrollOffset(input);
                var offset = Element.cumulativeOffset(input);
                var top = offset[1] - offsetScroll[1] + node.offsetHeight + 3;
                var height = 'auto';
                var heightDiff = window.height() - offset[1];
                var nodeHeight = node.getHeight();

                if ((data.contacts.length * nodeHeight) > heightDiff)
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
                
                if (data.contacts.length == 1) {
                    // Single result
                    var contact = data.contacts[0];
                    if (contact["c_uid"])
                        input.uid = (contact["isMSExchange"]? UserLogin + ":" : "") + contact["c_uid"];
                    else
                        input.uid = null;
                    var isList = (contact["c_component"] &&
                                  contact["c_component"] == "vlist");
                    if (isList) {
                        input.cname = contact["c_name"];
                        input.container = contact["container"];
                    }
                    var completeEmail = contact["c_cn"].trim();
                    if (contact["c_mail"]) {
                        if (completeEmail)
                            completeEmail += " <" + contact["c_mail"] + ">";
                        else
                            completeEmail = contact["c_mail"];
                    }
                    if ((input.value == contact["c_mail"])
                        || (contact["c_cn"].substring(0, input.value.length).toUpperCase()
                            == input.value.toUpperCase())
                        || !input.focussed) {
                        input.value = completeEmail;
                    }
                    else
                        // The result matches email address, not user name
                        input.value += ' >> ' + completeEmail;
                    input.isList = isList;
                    input.confirmedValue = completeEmail;
                    var end = input.value.length;
                    if (input.focussed)
                        $(input).selectText(start, end);
                    else if (isList)
                        resolveListAttendees(input, true);
                    else
                        // We lost the focus -- force freebusy lookup
                        input.checkAfterLookup = true;

                    attendeesEditor.selectedIndex = -1;

                    if (input.checkAfterLookup) {
                        input.checkAfterLookup = false;
                        input.modified = true;
                        input.hasfreebusy = false;
                        checkAttendee(input);
                    }
                }
                initializeAttendeeRole(input);
            }
        }
        else
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
    }
}

function initializeAttendeeRole(input) {
    var row = $(input.parentNode.parentNode);
    if (input.uid && input.uid == OwnerLogin) {
        row.removeAttribute("role");
        row.removeClassName("attendee-row");
        row.setAttribute("partstat", "accepted");
        row.addClassName("organizer-row");
        row.isOrganizer = true;
    } else {
        row.removeAttribute("partstat");
        row.removeClassName("organizer-row");
        if (input.value.length > 0) {
            row.setAttribute("role", "req-participant");
            row.addClassName("attendee-row");
        }
        row.isOrganizer = false;
    }
}

function onAttendeeResultClick(event) {
    var input = this.parentNode.input;
    input.uid = this.uid;
    input.cname = this.cname;
    input.container = this.container;
    input.isList = this.isList;
    input.confirmedValue = input.value = this.address;
    initializeAttendeeRole(input);
    checkAttendee(input);
    this.scrollLeft = 0;
    $(this).up('DIV').scrollLeft = 0;

    this.parentNode.input = null;
}

function redisplayEventSpans() {
    // log("redisplayEventSpans");

    var table = $("freeBusyHeader");
    var row = table.rows[2];
    var stDay = window.getStartDate();
    var etDay = window.getEndDate();

    var days = stDay.daysUpTo(etDay);
    var addDays = days.length - 1;
    var stHour = stDay.getHours();
    var stMinute = Math.round(stDay.getMinutes() / 15);
    if (stMinute == 4) {
        stMinute = 0;        
        stHour++;
    }
    var etHour = etDay.getHours();
    var etMinute = Math.round(etDay.getMinutes() / 15);
    if (etMinute == 4) {
        etMinute = 0;
        etHour++;
    }

    if (stHour < displayStartHour) {
        stHour = displayStartHour;
        stMinute = 0;
    }
    if (stHour > displayEndHour + 1) {
        stHour = displayEndHour + 1;
        stMinute = 0;
    }
    if (etHour < displayStartHour) {
        etHour = displayStartHour;
        etMinute = 0;
    }
    if (etHour > displayEndHour + 1) {
        etHour = displayEndHour;
        etMinute = 0;
    }

    var deltaCells = (etHour - stHour) + ((displayEndHour - displayStartHour + 1) * addDays);
    var deltaSpans = (deltaCells * 4 ) + (etMinute - stMinute);
    var currentCellNbr = stHour - displayStartHour;
    var currentCell = row.cells[currentCellNbr];
    var currentSpanNbr = stMinute;
    var spans = $(currentCell).childNodesWithTag("span");

    /* we first reset the cache of busy spans */
    if (row.busySpans) {
        for (var i = 0; i < row.busySpans.length; i++) {
            row.busySpans[i].removeClassName("busy");
        }
    }
    row.busySpans = [];

    /* now we mark the spans corresponding to our event */
    while (deltaSpans > 0) {
        var currentSpan = spans[currentSpanNbr];
        row.busySpans.push(currentSpan);
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
    scrollToEvent();
}

function onAttendeeStatusClick(event) {
    rotateAttendeeStatus(this);
}

function rotateAttendeeStatus(row) {
    var values;
    var attributeName;
    if (row.isOrganizer) {
        values = [ "accepted", "declined", "tentative", "needs-action" ];
        attributeName = "partstat";
    } else {
        values = [ "req-participant", "opt-participant",
                   "chair", "non-participant" ];
        attributeName = "role";
    }
    var value = row.getAttribute(attributeName);
    var idx = (value ? values.indexOf(value) : -1);
    if (idx == -1 || idx > (values.length - 2)) {
        idx = 0;
    } else {
        idx++;
    }
    row.setAttribute(attributeName, values[idx]);
    if (!Prototype.Browser.Gecko) {
        /* This hack enables a refresh of the row element right after the
           click. Otherwise, this occurs only when leaving the element with
           them mouse cursor. */
        row.className = row.className;
    }
}

function onNewAttendeeClick(event) {
    newAttendee();
    event.stop();
}

function newAttendee(previousAttendee) {
    var table = $("freeBusyAttendees");
    var tbody = table.tBodies[0];
    var model = tbody.rows[tbody.rows.length - 1];
    var nextRowIndex = tbody.rows.length - 2;
    if (previousAttendee) {
        nextRowIndex = previousAttendee.rowIndex + 1;
    }
    var nextRow = tbody.rows[nextRowIndex];
    var newRow = $(model.cloneNode(true));
    tbody.insertBefore(newRow, nextRow);
    var result = newRow;

    var statusTD = newRow.down(".attendeeStatus");
    if (statusTD) {
        var boundOnStatusClick = onAttendeeStatusClick.bindAsEventListener(newRow);
        statusTD.observe("click", boundOnStatusClick, false);
    }

    $(newRow).removeClassName("attendeeModel");
 
    var input = newRow.down("input");
    input.observe("keydown", onContactKeydown.bindAsEventListener(input));
    input.observe("blur", onInputBlur);

    input.focussed = true;
    input.activate();

    table = $("freeBusyData");
    tbody = table.tBodies[0];
    model = tbody.rows[tbody.rows.length - 1];
    nextRow = tbody.rows[nextRowIndex];
    newRow = $(model.cloneNode(true));
    tbody.insertBefore(newRow, nextRow);
    newRow.removeClassName("dataModel");

    var attendeesDiv = $$('TABLE#freeBusy TD.freeBusyAttendees DIV').first();
    var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();
   
    dataDiv.scrollTop = attendeesDiv.scrollTop = table.clientHeight;

    return result;
}

function checkAttendee(input) {
    var row = $(input.parentNode.parentNode);
    var tbody = row.parentNode;
    if (tbody && input.value.blank()) {
        var dataTable = $("freeBusyData").tBodies[0];
        var dataRow = dataTable.rows[row.sectionRowIndex];
        input.stopObserving();
        tbody.removeChild(row);
        dataTable.removeChild(dataRow);
    }
    else if (input.modified) {
        if (!row.hasClassName("needs-action")) {
            row.addClassName("needs-action");
            row.removeClassName("declined");
            row.removeClassName("accepted");
        }
        if (!input.hasfreebusy) {
            if (input.uid && input.confirmedValue) {
                input.value = input.confirmedValue;
            }
            displayFreeBusyForNode(input);
            input.hasfreebusy = true;
        }
        input.modified = false;
    }
}

function onInputBlur(event) {
    if (document.currentPopupMenu && !this.confirmedValue) {
        // Hack for IE7; blur event is triggered on input field when
        // selecting a menu item
        var visible = $(document.currentPopupMenu).getStyle('visibility') != 'hidden';
        if (visible) {
            // log("XXX we return");
            return;
        }
    }

    if (document.currentPopupMenu)
        hideMenu(document.currentPopupMenu);

    if (this.isList) {
        resolveListAttendees(this, false);
    } else {
        initializeAttendeeRole(this);
        checkAttendee(this);
    }
}

/* FIXME: any other way to repeat an object? */
var _fullFreeDay = [];
for (var i = 0; i < 96; i++) {
    _fullFreeDay.push('0');
}

function availabilitySession(uids, direction, start, end, listener) {
    this.mDirection = direction;
    if (direction > 0) {
        this._findDate = this._forwardFindDate;
        this._adjustCurrentStart = this._forwardAdjustCurrentStart;
    }
    else {
        this._findDate = this._backwardFindDate;
        this._adjustCurrentStart = this._backwardAdjustCurrentStart;
    }

    this.mStart = start;

    this.mStartLimit = 0;
    this.mEndLimit = 24 * 4;
    this.mWorkDaysOnly = false;

    /* The duration of the range covering the start and end of the event, in
       quarters.

       15 minutes * 60 secs * 1000 ms = 900000 ms */
    this.mDuration = Math.ceil((end.getTime() - start.getTime()) / 900000);
    this.mUids = uids;
    this.mListener = listener;
}

availabilitySession.prototype = {
  mStart: null,
  mDirection: null,
  mStartLimit: 0,
  mEndLimit: 0,
  mWorkDaysOnly: 0,

  mListener: null,
  mUids: null,

  mCurrentStart: null,
  mFirstStep: false,

  mCurrentEntries: null,
  mActiveRequests: 0,

  setLimits: function aS_setLimits(start, end) {
      this.mStartLimit = start;
      this.mEndLimit = end;
  },

  setWorkDaysOnly: function aS_setWorkDaysOnly(workDaysOnly) {
      this.mWorkDaysOnly = workDaysOnly;
  },

  _step: function aS__step() {
      this.mCurrentEntries = null;
      var max = this.mUids.length;
      if (max > 0) {
          this.mActiveRequests = max;
          for (var i = 0; i < max; i++) {
              // log("request start");
              var fbRequest = new freeBusyRequest(this.mCurrentStart,
                                                  this.mCurrentStart,
                                                  this.mUids[i],
                                                  this);
              fbRequest.start();
          }
      }
      else {
          this.mActiveRequests = 1;
          this.onRequestComplete(null, true, _fullFreeDay);
      }
  },

  start: function aS_start() {
      this.mCurrentStart = this.mStart.clone();
      this.mCurrentStart.setHours(0);
      this.mCurrentStart.setMinutes(0);
      if (this.mWorkDaysOnly) {
          this._adjustCurrentStart();
      }
      this.mFirstStep = true;
      this._step();
  },

  onRequestComplete: function aS_onRequestComplete(request, success, entries) {
      this.mActiveRequests--;
      this._mergeEntries(entries);
      if (this.mActiveRequests == 0) {
          var foundDate = this._findDate();
          if (foundDate) {
              var foundEndDate = foundDate.clone();
              foundEndDate.setTime(foundDate.getTime()
                                   + this.mDuration * 900000);
              this.mListener.onRequestComplete(this, foundDate, foundEndDate);
          }
          else {
              if (this.mDirection > 0) {
                  this.mCurrentStart.addDays(1);
              }
              else {
                  this.mCurrentStart.addDays(-1);
              }
              if (this.mWorkDaysOnly) {
                  this._adjustCurrentStart();
              }
              this._step();
          }
      }
  },

  _forwardAdjustCurrentStart: function aS__forwardAdjustCurrentStart() {
      var day = this.mCurrentStart.getDay();
      if (day == 0) {
          this.mCurrentStart.addDays(1);
      }
      else if (day == 6) {
          this.mCurrentStart.addDays(2);
      }
  },
  _backwardAdjustCurrentStart: function aS__backwardAdjustCurrentStart() {
      var day = this.mCurrentStart.getDay();
      if (day == 0) {
          this.mCurrentStart.addDays(-2);
      }
      else if (day == 6) {
          this.mCurrentStart.addDays(-1);
      }
  },

  _mergeEntries: function aS__mergeEntries(entries) {
      if (this.mCurrentEntries) {
          var currentIndex = 0;
          while (currentIndex > -1) {
              this.mCurrentEntries[currentIndex] = entries[currentIndex];
              currentIndex = entries.indexOf('1', currentIndex  + 1);
          }
      }
      else {
          this.mCurrentEntries = entries;
      }
  },

  _forwardFindDate: function aS__forwardFindDate() {
      var foundDate = null;

      var maxOffset = this.mEndLimit - this.mDuration;
      var offset = 0;
      if (this.mFirstStep) {
          offset = Math.floor(this.mStart.getHours() * 4
                              + this.mStart.getMinutes() / 15) + 1;
          this.mFirstStep = false;
      }
      else {
          offset = this.mCurrentEntries.indexOf('0');
      }
      if (offset > -1 && offset < this.mStartLimit) {
          offset = this.mStartLimit;
      }
      while (!foundDate && offset > -1 && offset <= maxOffset) {
          var testDuration = 0;
          while (this.mCurrentEntries[offset] == '0'
                 && testDuration < this.mDuration) {
              testDuration++;
              offset++;
          }
          if (testDuration == this.mDuration) {
              foundDate = new Date();
              var foundTime = (this.mCurrentStart.getTime()
                               + (offset - testDuration) * 900000);
              foundDate.setTime(foundTime);
          }
          else {
              offset = this.mCurrentEntries.indexOf('0', offset + 1);
          }
      }

      return foundDate;
  },
  _backwardFindDate: function aS__backwardFindDate() {
      var foundDate = null;

      var maxOffset = this.mEndLimit - this.mDuration;
      var offset;
      if (this.mFirstStep) {
          offset = Math.floor(this.mStart.getHours() * 4
                              + this.mStart.getMinutes() / 15) - 1;
          this.mFirstStep = false;
      }
      else {
          offset = this.mCurrentEntries.lastIndexOf('0');
      }
      if (offset > maxOffset) {
          offset = maxOffset;
      }
      while (!foundDate
             && offset >= this.mStartLimit) {
          var testDuration = 0;
          var testOffset = offset;
          while (this.mCurrentEntries[testOffset] == '0'
                 && testDuration < this.mDuration) {
              testDuration++;
              testOffset++;
          }
          if (testDuration == this.mDuration) {
              foundDate = new Date();
              var foundTime = (this.mCurrentStart.getTime()
                               + offset * 900000);
              foundDate.setTime(foundTime);
          }
          else {
              offset = this.mCurrentEntries.lastIndexOf('0', offset - 1);
          }
      }

      return foundDate;
  }
};

function availabilityController(previousSlotButton, nextSlotButton) {
    this.mActive = false;
    this.previousSlotButton = previousSlotButton;
    this.nextSlotButton = nextSlotButton;

    var boundCallback = this.onPreviousSlotClick.bindAsEventListener(this);
    previousSlotButton.observe("click", boundCallback, false);
    boundCallback = this.onNextSlotClick.bindAsEventListener(this);
    $("nextSlot").observe("click", boundCallback, false);
}

availabilityController.prototype = {
  mActive: false,
  previousSlotButton: null,
  nextSlotButton: null,

  onPreviousSlotClick: function ac_onPreviousSlotClick(event) {
      if (!this.mActive) {
          this.mActive = true;
          this._findSlot(-1);
      }
      this.previousSlotButton.blur();
  },
  onNextSlotClick: function aC_onNextSlotClick(event) {
      if (!this.mActive) {
          this.mActive = true;
          this._findSlot(1);
      }
      this.nextSlotButton.blur();
  },
  _findSlot: function aC__findSlot(direction) {
      var uids = [];

      var inputs = $("freeBusy").getElementsByTagName("input");
      for (var i = 0; i < inputs.length - 1; i++) {
          if (inputs[i].uid) {
              uids.push(inputs[i].uid);
          }
      }

      var start;
      var end;
      if (isAllDay) {
          start = window.timeWidgets['start']['date'].inputAsDate();
          end = window.timeWidgets['end']['date'].inputAsDate();
          start.setHours(dayStartHour);
          start.setMinutes(0);
          start.setSeconds(0);
          end.setHours(dayEndHour);
          end.setMinutes(0);
          end.setSeconds(0);
      }
      else {
          start = window.getStartDate();
          end = window.getEndDate();
      }
      var session = new availabilitySession(uids, direction,
                                            start, end,
                                            this);
      if (isAllDay) {
          session.setLimits(dayStartHour * 4, dayEndHour * 4);
      } else {
          var start = (parseInt($("timeSlotStartLimitHour").value)
                       + parseInt($("timeSlotStartLimitMinute").value));
          var end = (parseInt($("timeSlotEndLimitHour").value)
                     + parseInt($("timeSlotEndLimitMinute").value));
          session.setLimits(start, end);
      }
      session.setWorkDaysOnly($("workDaysOnly").checked);
      session.start();
  },
  onRequestComplete: function aC_onRequestComplete(session, start, end) {
      window.setStartDate(start);
      window.setEndDate(end);

      if (start.getDay() != session.mStart.getDay()) {
          onTimeDateWidgetChange();
      }
      else {
          redisplayEventSpans();
      }
      this.mActive = false;
  }
};

/* freebusy cache, used internally by freeBusyRequest below */
var _fbCache = {};

function _freeBusyCacheEntry() {
}

_freeBusyCacheEntry.prototype = {
  startDate: null,
  entries: null,

  getEntries: function fBCE_getEntries(sd, ed) {
      var entries = null;

      var adjustedSd = sd.beginOfDay();

      if (this.startDate && this.startDate.getTime() <= adjustedSd.getTime()) {
          var offset = this.startDate.deltaDays(adjustedSd) * 96;
          if (this.entries.length > offset) {
              var adjustedEd = ed.beginOfDay();
              var nbrDays = adjustedSd.deltaDays(adjustedEd) + 1;
              var nbrQu = nbrDays * 96;
              var offsetEnd = offset + nbrQu;
              if (this.entries.length >= offsetEnd) {
                  entries = this.entries.slice(offset, offsetEnd);
              }
          }
      }

      return entries;
  },

  getFetchRanges: function fBCE_getFetchRanges(sd, ed) {
      var fetchDates;

      var adjustedSd = sd.beginOfDay();
      var adjustedEd = ed.beginOfDay();
      var nbrDays = adjustedSd.deltaDays(adjustedEd) + 1;
      if (this.startDate) {
          fetchDates = [];

          if (adjustedSd.getTime() < this.startDate.getTime()) {
              var start = adjustedSd.clone();
              start.addDays(-7);
              var end = this.startDate.beginOfDay();
              end.addDays(-1);
              fetchDates.push({ start: start, end: end });
          }

          var currentNbrDays = this.entries.length / 96;
          var nextDate = this.startDate.clone();
          nextDate.addDays(currentNbrDays);
          if (adjustedEd.getTime() >= nextDate.getTime()) {
              var end = nextDate.clone();
              end.addDays(7);
              fetchDates.push({ start: nextDate, end: end });
          }
      }
      else {
          var start = adjustedSd.clone();
          start.addDays(-7);
          var end = adjustedEd.clone();
          end.addDays(7);
          fetchDates = [ { start: start, end: end } ];
      }

      return fetchDates;
  },

  integrateEntries: function fBCE_integrateEntries(entries, start, end) {
      if (this.startDate) {
          if (start.getTime() < this.startDate) {
              var days = start.deltaDays(this.startDate);
              if (entries.length == (days * 96)) {
                  this.startDate = start;
                  this.entries = entries.concat(this.entries);
              }
          }
          else {
              this.entries = this.entries.concat(entries);
          }
      } else {
          this.startDate = start;
          this.entries = entries;
      }
  }
};

function freeBusyRequest(start, end, uid, listener) {
    this.mStart = start.beginOfDay();
    this.mEnd = end.beginOfDay();
    this.mUid = uid;
    this.mListener = listener;
    this.mPendingRequests = 0;
}

freeBusyRequest.prototype = {
  mStart: null,
  mEnd: null,
  mUid: null,
  mListener: null,

  mCacheEntry: null,

  mPendingRequests: 0,

  start: function fBR_start() {
      this.mCacheEntry = _fbCache[this.mUid];
      if (!this.mCacheEntry) {
          this.mCacheEntry = new _freeBusyCacheEntry();
          _fbCache[this.mUid] = this.mCacheEntry;
      }
      var entries = this.mCacheEntry.getEntries(this.mStart, this.mEnd);
      if (entries) {
          this.mListener.onRequestComplete(this, true, entries);
      }
      else {
          if (this.mPendingRequests == 0) {
              var fetchRanges = this.mCacheEntry.getFetchRanges(this.mStart, this.mEnd);
              this.mPendingRequests = fetchRanges.length;
              for (var i = 0; i < fetchRanges.length; i++) {
                  var fetchRange = fetchRanges[i];
                  this._performAjaxRequest(fetchRange.start, fetchRange.end);
              }
          }
          else {
              /* a nearly impossible condition that we want to handle */
              log("freebusy request is already active");
          }
      }
  },

  _performAjaxRequest: function fBR__performAjaxRequest(rqStart, rqEnd) {
      var urlstr = UserFolderURL + "../";
      var uids = this.mUid.split(":");
      if (uids.length > 1)
          urlstr += (uids[0]
                     + "/freebusy.ifb/ajaxRead?"
                     + "uid=" + uids[1]
                     + "&");
      else
          urlstr += (this.mUid
                     + "/freebusy.ifb/ajaxRead?");
      urlstr += ("sday=" + rqStart.getDayString()
                 + "&eday=" + rqEnd.getDayString());
      
      var thisRequest = this;
      var callback = function fBR__performAjaxRequest_cb(http) {
          if (http.readyState == 4) {
              thisRequest.onRequestComplete(http, rqStart, rqEnd);
              thisRequest = null;
          }
      };

      triggerAjaxRequest(urlstr, callback);
  },

  onRequestComplete: function fBR_onRequestComplete(http, rqStart, rqEnd) {
      this.mPendingRequests--;
      if (http.status == 200 && http.responseText) {
          var newEntries = http.responseText.split(",");
          var cacheEntry = this.mCacheEntry;
          cacheEntry.integrateEntries(newEntries, rqStart, rqEnd);
          if (this.mPendingRequests == 0) {
              var entries = this.mCacheEntry.getEntries(this.mStart,
                                                        this.mEnd);
              this.mListener.onRequestComplete(this, true, entries);
          }
      }
  }
};

function editorConflictHandler(uids, startDate, endDate, listener) {
    this.mUids = uids;
    this.mRemaining = uids.length;
    this.mCurrentUid = 0;

    this.mStartDate = startDate;
    this.mEndDate = endDate;

    this.mListener = listener;
}

editorConflictHandler.prototype = {
  mUids: null,
  mCurrentUid: 0,

  mStartDate: null,
  mEndDate: null,

  mQuOffset: 0,
  mQuOffsetMax: 0,

  mCurrentEntries: null,

  mListener: null,

  start: function eCH_start() {
      this.mQuOffset = (this.mStartDate.getHours() * 4
                        + Math.floor(this.mStartDate.getMinutes() / 15));
      this.mQuOffsetMax = (this.mEndDate.deltaDays(this.mStartDate) * 96
                           + this.mEndDate.getHours() * 4
                           + Math.ceil(this.mEndDate.getMinutes() / 15));
      this._step();
  },

  _step: function eCH__step() {
      if (this.mCurrentUid < this.mUids.length) {
          var fbRequest = new freeBusyRequest(this.mStartDate,
                                              this.mEndDate,
                                              this.mUids[this.mCurrentUid],
                                              this);
          fbRequest.start();
      }
      else {
          this.mListener.onRequestComplete(this, true);
      }
  },

  onRequestComplete: function eCH_onRequestComplete(fbRequest, success,
                                                    entries) {
      var periodEntries = entries.slice(this.mQuOffset, this.mQuOffsetMax);
      if (periodEntries.indexOf("1") > -1) {
          this.mListener.onRequestComplete(this, false);
      }
      else {
          this.mCurrentUid++;
          this._step();
      }
  }
};

function displayFreeBusyForNode(input) {
    var rowIndex = input.parentNode.parentNode.sectionRowIndex;
    var row = $("freeBusyData").tBodies[0].rows[rowIndex];
    var nodes = row.cells;
    //log ("displayFreeBusyForNode index " + rowIndex + " (" + nodes.length + " cells)");
    if (input.uid) {
        if (!input.hasfreebusy) {
            // log("forcing draw of nodes");
            for (var i = 0; i < nodes.length; i++) {
                var node = $(nodes[i]);
                node.removeClassName("noFreeBusy");
                while (node.firstChild) {
                    node.removeChild(node.firstChild);
                }
                for (var j = 0; j < 4; j++) {
                    createElement("span", null, "freeBusyZoneElement",
                                  null, null, node);
                }
            }
        }

        var sd = $('startTime_date').inputAsDate();
        var ed = $('endTime_date').inputAsDate();
        var listener = {
          onRequestComplete: function(request, success, entries) {
              if (success) {
                  drawFbData(input, entries);
              }
          }
        };

        var rq = new freeBusyRequest(sd, ed, input.uid, listener);
        rq.start();
    } else {
        for (var i = 0; i < nodes.length; i++) {
            var node = $(nodes[i]);
            node.addClassName("noFreeBusy");
            while (node.firstChild) {
                node.removeChild(node.firstChild);
            }
        }
    }
}

function setSpanStatus(span, status) {
    var currentClass = span.freeBusyClass;
    if (!currentClass)
        currentClass = "";
    var newClass;
    if (status == '1') {
        newClass = "busy";
    }
    else if (status == '2') {
        newClass = "maybe-busy";
    }
    else {
        newClass = "";
    }
    if (newClass != currentClass) {
        if (currentClass.length > 0) {
            span.removeClassName(currentClass);
        }
        if (newClass.length > 0) {
            span.addClassName(newClass);
        }
        span.freeBusyClass = newClass;
    }
}

function drawFbData(input, slots) {
    var rowIndex = input.parentNode.parentNode.sectionRowIndex;

    var slotNbr = 0;
    var tds = $("freeBusyData").tBodies[0].rows[rowIndex].cells;
    if (tds.length * 4 == slots.length) {
        for (var i = 0; i < tds.length; i++) {
            var spans = tds[i].childNodesWithTag("span");
            for (var j = 0; j < spans.length; j++) {
                setSpanStatus(spans[j], slots[slotNbr]);
                slotNbr++;
            }
        }
    }
    else {
        log("inconsistency between freebusy results and"
            + " the number of cells");
        log("  expecting: " + tds.length + " received: " + slots.length);
    }
}

function resetAllFreeBusys() {
    var inputs = $("freeBusy").getElementsByTagName("input");
    for (var i = 0; i < inputs.length - 1; i++) {
        var currentInput = inputs[i];
        currentInput.hasfreebusy = false;
        displayFreeBusyForNode(currentInput);
    }
}

function initializeTimeSlotWidgets() {
    availability = new availabilityController($("previousSlot"),
                                              $("nextSlot"));

    var hourWidgets = [ "timeSlotStartLimitHour",
                        "timeSlotEndLimitHour" ];
    for (var i = 0; i < hourWidgets.length; i++) {
        var hourWidget = $(hourWidgets[i]);
        for (var h = 0; h < 24; h++) {
            var option = createElement("option", null, null,
                                       { value: h * 4 });
            var text = (h < 10) ? ("0" + h) : ("" + h);
            option.appendChild(document.createTextNode(text));
            hourWidget.appendChild(option);
        }
    }
    var limitWidget = $("timeSlotStartLimitHour");
    limitWidget.value = dayStartHour * 4;
    limitWidget = $("timeSlotEndLimitHour");
    limitWidget.value = dayEndHour * 4;

    var minuteWidgets = [ "timeSlotStartLimitMinute",
                          "timeSlotEndLimitMinute" ];
    for (var i = 0; i < minuteWidgets.length; i++) {
        var minuteWidget = $(minuteWidgets[i]);
        for (var h = 0; h < 4; h++) {
            var option = createElement("option", null, null,
                                       { value: h });
            var quValue = h * 15;
            var text = (h == 0) ? "00" : ("" + quValue);
            option.appendChild(document.createTextNode(text));
            minuteWidget.appendChild(option);
        }
    }
//    var limitWidget = $("timeSlotStartLimitMinute");
//    limitWidget.value = Math.floor(parseInt($("startTime_time_minute").value)
//                                   / 15);
//    limitWidget = $("timeSlotEndLimitMinute");
//    limitWidget.value = Math.floor(parseInt($("endTime_time_minute").value)
//                                   / 15);
}

function initializeWindowButtons() {
    var okButton = $("okButton");
    var cancelButton = $("cancelButton");
    
    okButton.observe("click", onEditorOkClick, false);
    cancelButton.observe("click", onEditorCancelClick, false);
}

function cleanInt(data) {
    var rc = data;
    if (rc.substr (0, 1) == "0")
        rc = rc.substr (1, rc.length - 1);
    return parseInt (rc);
}

function scrollToEvent () {
    var headerDiv = $$('TABLE#freeBusy TD.freeBusyHeader DIV').first();
    var dataDiv = $$('TABLE#freeBusy TD.freeBusyData DIV').first();
  
    var scroll = 0;
    var spans = $$('TR#currentEventPosition TH SPAN');
    for (var i = 0; i < spans.length; i++) {
        scroll += spans[i].getWidth (spans[i]);
        if (spans[i].hasClassName("busy")) {
            scroll -= 20 * spans[i].getWidth (spans[i]);
            break;
        }
    }

    headerDiv.scrollLeft = scroll;
    dataDiv.scrollLeft = headerDiv.scrollLeft;
}

//function updateSlotDisplayCallback(http) {
//    var data = http.responseText.evalJSON(true);
//    var start = new Date();
//    var end = new Date();
//    var cb = redisplayEventSpans;
//
//    start.setFullYear(parseInt (data[0]['startDate'].substr(0, 4)),
//                      parseInt (data[0]['startDate'].substr(4, 2)) - 1,
//                      parseInt (data[0]['startDate'].substr(6, 2)));
//    end.setFullYear(parseInt (data[0]['endDate'].substr(0, 4)),
//                    parseInt (data[0]['endDate'].substr(4, 2)) - 1,
//                    parseInt (data[0]['endDate'].substr(6, 2)));
//    
//    window.timeWidgets['end']['date'].setInputAsDate(end);
//    window.timeWidgets['end']['hour'].value = cleanInt(data[0]['endHour']);
//    window.timeWidgets['end']['minute'].value = cleanInt(data[0]['endMinute']);
//
//    if (window.timeWidgets['start']['date'].valueAsShortDateString() !=
//        data[0]['startDate']) {
//        cb = onTimeDateWidgetChange;
//    }
//
//    window.timeWidgets['start']['date'].setInputAsDate(start);
//    window.timeWidgets['start']['hour'].value = cleanInt(data[0]['startHour']);
//    window.timeWidgets['start']['minute'].value = cleanInt(data[0]['startMinute']);
//
//    cb();
//}

function onEditorOkClick(event) {
    preventDefault(event);

    var uids = [];
    var inputs = $("freeBusy").getElementsByTagName("input");
    for (var i = 0; i < inputs.length - 1; i++) {
        var input = inputs[i];
        if (!input.disabled && input.uid) {
            uids.push(input.uid);
        }
    }

    var startDate = getStartDate();
    var endDate = getEndDate();

    var listener = {
      onRequestComplete: function eCH_l_onRequestComplete(handlers, code) {
          var label = ("A time conflict exists with one or more attendees.\n"
                       + "Would you like to keep the current settings anyway?");
          if (code || window.confirm(_(label))) {
              _confirmEditorOkClick();
          }
      }
    };
    
    var conflictHandler = new editorConflictHandler(uids, startDate,
                                                    endDate, listener);
    conflictHandler.start();
}

function _confirmEditorOkClick() {
    var attendees = window.opener.attendees;
    var newAttendees = new Hash();
    var inputs = $("freeBusy").getElementsByTagName("input");
    for (var i = 0; i < inputs.length - 1; i++) {
        if (inputs[i].disabled)
            continue;
        var row = $(inputs[i]).up("tr");
        var name = extractEmailName(inputs[i].value);
        var email = extractEmailAddress(inputs[i].value);
        var uid = "";
        if (inputs[i].uid)
            uid = inputs[i].uid;
        if (!(name && name.length > 0))
            if (uid.length > 0)
                name = uid;
            else
                name = email;
        var attendee = attendees["email"];
        if (!attendee) {
            attendee = {"email": email,
                        "name": name,
                        "role": "req-participant",
                        "partstat": "needs-action",
                        "uid": uid};
        }
        var partstat = row.getAttribute("partstat");
        if (partstat)
            attendee["partstat"] = partstat;
        var role = row.getAttribute("role");
        if (role)
            attendee["role"] = role;
        newAttendees.set(email, attendee);
    }
    window.opener.refreshAttendees(Object.toJSON(newAttendees));

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

    var srcTime = parent$(srcWidgetName + "_time");
    var dstTime = $(dstWidgetName + "_time");
    dstTime.value = srcTime.value;
    dstTime.updateShadowValue(srcTime);
}

function updateParentDateFields(srcWidgetName, dstWidgetName) {
    var srcDate = $(srcWidgetName + "_date");
    var dstDate = parent$(dstWidgetName + "_date");
    dstDate.value = srcDate.value;

    var srcTime = $(srcWidgetName + "_time");
    var dstTime = parent$(dstWidgetName + "_time");
    dstTime.value = srcTime.value;
}

function onTimeWidgetChange() {
    redisplayEventSpans();
}

function onTimeDateWidgetChange() {
    var rows = $("freeBusyHeader").select("tr");
    for (var i = 0; i < rows.length; i++) {
        for (var j = rows[i].cells.length - 1; j > -1; j--) {
            rows[i].deleteCell(j);
        }
    }
  
    rows = $("freeBusyData").select("tr");
    for (var i = 0; i < rows.length; i++) {
        for (var j = rows[i].cells.length - 1; j > -1; j--) {
            rows[i].deleteCell(j);
        }
    }

    prepareTableHeaders();
    prepareTableRows();
    redisplayEventSpans();
    resetAllFreeBusys();
}

function prepareTableHeaders() {
    var startTimeDate = $("startTime_date");
    var startDate = startTimeDate.inputAsDate();

    var endTimeDate = $("endTime_date");
    var endDate = endTimeDate.inputAsDate();
    endDate.setTime(endDate.getTime());

    var rows = $("freeBusyHeader").rows;
    var days = startDate.daysUpTo(endDate);

    for (var i = 0; i < days.length; i++) {
        var header1 = document.createElement("th");
        header1.colSpan = ((displayEndHour - displayStartHour) + 1)/2;
        header1.appendChild(document.createTextNode(days[i].toLocaleDateString()));
        rows[0].appendChild(header1);
        var header1b = document.createElement("th");
        header1b.colSpan = ((displayEndHour - displayStartHour) + 1)/2;
        header1b.appendChild(document.createTextNode(days[i].toLocaleDateString()));
        rows[0].appendChild(header1b);
        for (var hour = displayStartHour; hour < (displayEndHour + 1); hour++) {
            var header2 = document.createElement("th");
            var text = hour + ":00";
            if (hour < 10)
                text = "0" + text;
            if (hour >= dayStartHour && hour < dayEndHour)
                $(header2).addClassName ("officeHour");
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
    var startDate = startTimeDate.inputAsDate();

    var endTimeDate = $("endTime_date");
    var endDate = endTimeDate.inputAsDate();
    endDate.setTime(endDate.getTime());

    var rows = $("freeBusyData").tBodies[0].rows;
    var days = startDate.daysUpTo(endDate);
    var width = $('freeBusyHeader').getWidth();
    $("freeBusyData").setStyle({ width: width + 'px' });

    for (var i = 0; i < days.length; i++)
        for (var rowNbr = 0; rowNbr < rows.length; rowNbr++)
            for (var hour = displayStartHour; hour < (displayEndHour + 1); hour++)
                rows[rowNbr].appendChild(createElement("td"));
}

function prepareAttendees() {
    var tableAttendees = $("freeBusyAttendees");
    var tableData = $("freeBusyData");
    var organizer = window.opener.getCalendarOwner();
    var attendees = window.opener.attendees;
    var attendeesKeys = (attendees ? attendees.keys() : null);

    var tbodyAttendees = tableAttendees.tBodies[0];
    var modelAttendee = tbodyAttendees.rows[tbodyAttendees.rows.length - 1];
    var newAttendeeRow = tbodyAttendees.rows[tbodyAttendees.rows.length - 2];
    
    var tbodyData = tableData.tBodies[0];
    var modelData = tbodyData.rows[tbodyData.rows.length - 1];
    var newDataRow = tbodyData.rows[tbodyData.rows.length - 2];
    
    // Unconditionaly add the organizer
    var row = $(modelAttendee.cloneNode(true));
    tbodyAttendees.insertBefore(row, newAttendeeRow);
    row.removeClassName("attendeeModel");
    row.setAttribute("partstat", organizer["partstat"]);
    row.setAttribute("role", organizer["role"]);
    var uid = organizer["uid"];
    row.addClassName("organizer-row");
    row.removeClassName("attendee-row");
    row.isOrganizer = true;
    var input = row.down("input");
    var value = organizer["name"];
    if (value)
        value += " ";
    else
        value = "";
    value += "<" + organizer["email"] + ">";
    input.value = value;
    input.uid = uid;
    //input.cname = organizer["cname"];
    input.setAttribute("name", "");
    input.modified = false;
    input.disable();
    
    row = $(modelData.cloneNode(true));
    tbodyData.insertBefore(row, newDataRow);
    row.removeClassName("dataModel");
    displayFreeBusyForNode(input);

    if (attendeesKeys && attendeesKeys.length > 0) {

        attendeesKeys.each(function(atKey) {
            var attendee = attendees.get(atKey);
            var row = $(modelAttendee.cloneNode(true));
            tbodyAttendees.insertBefore(row, newAttendeeRow);
            row.removeClassName("attendeeModel");
            row.setAttribute("partstat", attendee["partstat"]);
            row.setAttribute("role", attendee["role"]);
            var uid = attendee["uid"];
            if (uid && uid == OwnerLogin) {
                row.addClassName("organizer-row");
                row.removeClassName("attendee-row");
                row.isOrganizer = true;
            } else {
                row.addClassName("attendee-row");
                row.removeClassName("organizer-row");
                row.isOrganizer = false;
            }
            var statusTD = row.down(".attendeeStatus");
            if (statusTD) {
                var boundOnStatusClick
                    = onAttendeeStatusClick.bindAsEventListener(row);
                statusTD.observe("click", boundOnStatusClick, false);
            }
                
            var input = row.down("input");
            var value = attendee["name"];
            if (value)
                value += " ";
            else
                value = "";
            value += "<" + attendee["email"] + ">";
            input.value = value;
            input.uid = uid;
            input.cname = attendee["cname"];
            input.setAttribute("name", "");
            input.modified = false;
            input.observe("blur", onInputBlur);
            input.observe("keydown",
                          onContactKeydown.bindAsEventListener(input));

            row = $(modelData.cloneNode(true));
            tbodyData.insertBefore(row, newDataRow);
            row.removeClassName("dataModel");
            displayFreeBusyForNode(input);
        });
    }
    else {
        newAttendee();
    }

    // Activate "Add attendee" button
    var links = tableAttendees.select("TR.futureAttendee TD A");
    links.first().observe("click", onNewAttendeeClick);
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
    OwnerLogin = window.opener.getOwnerLogin();

    var widgets = {'start': {'date': $("startTime_date"),
                             'time': $("startTime_time")},
                   'end': {'date': $("endTime_date"),
                           'time': $("endTime_time")}};
    synchronizeWithParent("startTime", "startTime");
    synchronizeWithParent("endTime", "endTime");

    initTimeWidgets(widgets);
    initializeTimeSlotWidgets();

    initializeWindowButtons();
    prepareAttendees();
    onWindowResize(null);
    Event.observe(window, "resize", onWindowResize);
    $$('TABLE#freeBusy TD.freeBusyData DIV').first().observe("scroll", onScroll);
    scrollToEvent();
}

document.observe("dom:loaded", onFreeBusyLoadHandler);

/* Functions related to UIxTimeDateControl widget */

function initTimeWidgets(widgets) {
    this.timeWidgets = widgets;

    jQuery(widgets['start']['date']).closest('.date').datepicker({autoclose: true, position: 'above'});
    jQuery(widgets['start']['date']).change(onAdjustTime);
    widgets['start']['time'].on("time:change", onAdjustTime);
    widgets['start']['time'].addInterface(SOGoTimePickerInterface);
    widgets['start']['time'].setPosition('above');

    jQuery(widgets['end']['date']).closest('.date').datepicker({autoclose: true, position: 'above'});
    jQuery(widgets['end']['date']).change(onAdjustTime);
    widgets['end']['time'].on("time:change", onAdjustTime);
    widgets['end']['time'].addInterface(SOGoTimePickerInterface);
    widgets['end']['time'].setPosition('above');

    var allDayLabel = $("allDay");
    if (allDayLabel) {
        var input = $(allDayLabel).childNodesWithTag("input")[0];
        input.observe("change", onAllDayChanged.bindAsEventListener(input));
        if (input.checked) {
            for (var type in widgets)
                widgets[type]['time'].disabled = true;
        }
    }

    if (isAllDay)
        handleAllDay();
}

function onAdjustTime(event) {
    var endDate = window.getEndDate();
    var startDate = window.getStartDate();
    if (this.id.startsWith("start")) {
        // Start date was changed
        var delta = window.getShadowStartDate().valueOf() -
            startDate.valueOf();
        var newEndDate = new Date(endDate.valueOf() - delta);
        window.setEndDate(newEndDate);
        window.timeWidgets['end']['date'].updateShadowValue();
        window.timeWidgets['end']['time'].updateShadowValue();
        window.timeWidgets['start']['date'].updateShadowValue();
        window.timeWidgets['start']['time'].updateShadowValue();
    }
    else {
        // End date was changed
        var delta = endDate.valueOf() - startDate.valueOf();  
        if (delta < 0) {
            alert(labels.validate_endbeforestart);
            var oldEndDate = window.getShadowEndDate();
            window.setEndDate(oldEndDate);

            window.timeWidgets['end']['date'].updateShadowValue();
            window.timeWidgets['end']['time'].updateShadowValue();
            window.timeWidgets['end']['time'].onChange(); // method from SOGoTimePicker
        }
    }

    // Specific function for the attendees editor
    onTimeDateWidgetChange();
}

function _getDate(which) {
    var date = window.timeWidgets[which]['date'].inputAsDate();
    var time = window.timeWidgets[which]['time'].value.split(":");
    date.setHours(time[0]);
    date.setMinutes(time[1]);

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
    var time = window.timeWidgets[which]['time'].getAttribute("shadow-value").split(":");
    date.setHours(time[0]);
    date.setMinutes(time[1]);

    return date;
}

function getShadowStartDate() {
    return this._getShadowDate('start');
}

function getShadowEndDate() {
    return this._getShadowDate('end');
}

function _setDate(which, newDate) {
    window.timeWidgets[which]['date'].setInputAsDate(newDate);
    if (!isAllDay) {
        window.timeWidgets[which]['time'].value = newDate.getDisplayHoursString();
        if (window.timeWidgets[which]['time'].onChange) window.timeWidgets[which]['time'].onChange(); // method from SOGoTimePicker
    }
}

function setStartDate(newStartDate) {
    this._setDate('start', newStartDate);
}

function setEndDate(newEndDate) {
    this._setDate('end', newEndDate);
}
