/* bind method: attachToEventCells(cells), attachToDayNode(dayNode)
 * callback method: updateDropCallback(this, eventCells, delta),
                    createDropCallback(this, dayDate, currentCoordinates);
 */


var SOGoEventDragDayLength = 24 * 4; /* quarters */
var SOGoEventDragHandleSize = 8; /* handles for dragging mode */
var SOGoEventDragHorizontalOffset = 3;
var SOGoEventDragVerticalOffset = 3;
var calendarID = [], activeCalendars = [];

/* singleton */
var _sogoEventDragUtilities = null;
function SOGoEventDragUtilities() {
    if (!_sogoEventDragUtilities)
        _sogoEventDragUtilities = new _SOGoEventDragUtilities();

    return _sogoEventDragUtilities;
}

function _SOGoEventDragUtilities() {
}

_SOGoEventDragUtilities.prototype = {
    eventType: null,
    eventContainerNodes: null,
    _prepareEventContainerNodes: null,
    quarterHeight: -1,
    dayWidth: -1,
    dayHeight: -1,
    daysOffset: -1,
    eventsViewNode: null,
    eventsViewNodeCumulativeCoordinates: null,

    reset: function() {
        this.eventContainerNodes = null;
        this._prepareEventContainerNodes = null;
        this.quarterHeight = -1;
        this.dayWidth = -1;
        this.dayHeight = -1;
        this.daysOffset = -1;
        this.eventsViewNode = null;
        this.eventsViewNodeCumulativeCoordinates = null;
    },

    setEventType: function(eventType) {
        var prepareMethods
            = { "multiday": this._prepareEventMultiDayContainerNodes,
                "multiday-allday": this._prepareEventMultiDayAllDayContainerNodes,
                "monthly": this._prepareEventMonthlyContainerNodes,
                "unknown": null };
        this._prepareEventContainerNodes = prepareMethods[eventType];
        this.eventType = eventType;
    },
    getEventType: function(eventType) {
        return this.eventType;
    },

    getEventContainerNodes: function() {
        if (!this.eventContainerNodes) {
            this._prepareEventContainerNodes();
        }

        return this.eventContainerNodes;
    },
    _prepareEventMultiDayContainerNodes: function() {
        this.eventContainerNodes = [];
        var daysView = $("daysView");
        var daysViewSubnodes = daysView.childNodesWithTag("div");
        for (var i = 0; i < daysViewSubnodes.length; i++) {
            var daysViewSubnode = daysViewSubnodes[i];
            if (daysViewSubnode.hasClassName("days")) {
                this.daysOffset = daysViewSubnode.offsetLeft + 2;
                var daysSubnodes = daysViewSubnode.childNodesWithTag("div");
                for (var j = 0; j < daysSubnodes.length; j++) {
                    var daysSubnode = daysSubnodes[j];
                    if (daysSubnode.hasClassName("day")) {
                        this._appendDayEventsNode(daysSubnode);
                    }
                }
            }
        }
    },
    _prepareEventMultiDayAllDayContainerNodes: function() {
        this.eventContainerNodes = [];
        var headerNode = $("calendarHeader");
        var headerSubnodes = headerNode.childNodesWithTag("div");
        for (var i = 0; i < headerSubnodes.length; i++) {
            var headerSubnode = headerSubnodes[i];
            if (headerSubnode.hasClassName("days")) {
                this.daysOffset = headerSubnode.offsetLeft + 2;
                var daysSubnodes = headerSubnode.childNodesWithTag("div");
                for (var j = 0; j < daysSubnodes.length; j++) {
                    var daysSubnode = daysSubnodes[j];
                    if (daysSubnode.hasClassName("day"))
                        this.eventContainerNodes.push(daysSubnode);
                }
            }
        }
    },
    _prepareEventMonthlyContainerNodes: function() {
        var monthView = $("monthDaysView");
        this.eventContainerNodes = monthView.childNodesWithTag("div");
        this.daysOffset = this.eventContainerNodes[0].offsetLeft + 2;
    },

    _appendDayEventsNode: function(dayNode) {
        var daySubnodes = dayNode.childNodesWithTag("div");
        for (var i = 0; i < daySubnodes.length; i++) {
            var daySubnode = daySubnodes[i];
            if (daySubnode.hasClassName("events")) {
                this.eventContainerNodes.push(daySubnode);
            }
        }
    },

    getQuarterHeight: function() {
        if (this.quarterHeight == -1) {
            var hour0 = $("hour0");
            var hour23 = $("hour23");
            this.quarterHeight = ((hour23.offsetTop - hour0.offsetTop)
                                  / (23 * 4));
        }

        return this.quarterHeight;
    },

    getDaysOffset: function() {
        if (this.daysOffset == -1)
            this._prepareEventContainerNodes();

        return this.daysOffset;
    },

    getDayWidth: function() {
        if (this.dayWidth == -1) {
            var nodes = this.getEventContainerNodes();
            if (nodes.length > 1) {
                if (this.eventType == "monthly") {
                    var total = (nodes[6].cumulativeOffset()[0]
                                 - nodes[0].cumulativeOffset()[0]);
                    this.dayWidth = total / 6;
                } else {
                    var total = (nodes[nodes.length-1].cumulativeOffset()[0]
                                 - nodes[0].cumulativeOffset()[0]);
                    this.dayWidth = total / (nodes.length - 1);
                }
            }
            else
                this.dayWidth = nodes[0].offsetWidth;
        }

        return this.dayWidth;
    },

    getDayHeight: function() {
        /* currently only used for monthly view */
        if (this.dayHeight == -1) {
            var nodes = this.getEventContainerNodes();
            if (nodes.length > 1) {
                var total = (nodes[3*7].cumulativeOffset()[1]
                             - nodes[0].cumulativeOffset()[1]);
                this.dayHeight = total / 3;
            }
        }

        return this.dayHeight;
    },

    getEventsViewNode: function() {
        if (!this.eventsViewNode) {
            if (this.eventType.startsWith("multiday"))
                this.eventsViewNode = $("daysView");
            else if (this.eventType.startsWith("multiday-allday")) {
                this.eventsViewNode = $("calendarHeader");
            }
            else
                this.eventsViewNode = $("monthDaysView");
        }
        return this.eventsViewNode;
    },

    getEventsViewNodeCumulativeCoordinates: function() {
        if (!this.eventsViewNodeCumulativeCoordinates) {
            this.eventsViewNodeCumulativeCoordinates = new SOGoCoordinates();
            var node = this.getEventsViewNode();
            var cumulativeOffset = node.cumulativeOffset();
            this.eventsViewNodeCumulativeCoordinates.x = cumulativeOffset[0];
            this.eventsViewNodeCumulativeCoordinates.y = cumulativeOffset[1];
        }

        return this.eventsViewNodeCumulativeCoordinates;
    }
};

function SOGoEventDragEventCoordinates() {
}

SOGoEventDragEventCoordinates.prototype = {
    dayNumber: -1,
    start: -1,
    duration: -1,

    eventType: null,

    setEventType: function(eventType) {
        this.eventType = eventType;
        this._prepareEventType();
    },
    _prepareEventType: function() {
        var methods
            = { "multiday": this.initFromEventCellMultiDay,
                "multiday-allday": this.initFromEventCellMultiDayAllDay,
                "monthly": this.initFromEventCellMonthly,
                "unknown": null };
        this.initFromEventCell = methods[this.eventType];
    },

    initFromEventCellMultiDay: function(eventCell) {
        var classNames = eventCell.className.split(" ");
        for (var i = 0; (this.start == -1 || this.duration == -1) && i < classNames.length; i++) {
            var className = classNames[i];
            if (className.startsWith("starts")) {
                this.start = parseInt(className.substr(6));
            }
            else if (className.startsWith("lasts")) {
                this.duration = parseInt(className.substr(5));
            }
        }
        var dayNumber = -1;
        
        var dayNode = eventCell.parentNode.parentNode;
        if (currentView == "multicolumndayview") {
            calendarID[0] = dayNode.getAttribute("calendar");
            var dayNumber = this._updateMulticolumnViewDayNumber(calendarID);
        }
        else {
            var classNames = dayNode.className.split(" ");
            for (var i = 0; dayNumber == -1 && i < classNames.length; i++) {
                var className = classNames[i];
                if (className.startsWith("day") && className.length > 3) {
                    dayNumber = parseInt(className.substr(3));
                }
            }
        }
        this.dayNumber = dayNumber;
    },
    initFromEventCellMultiDayAllDay: function(eventCell) {
        this.start = 0;
        this.duration = SOGoEventDragDayLength;
        
        var dayNode = eventCell.parentNode;
        if (currentView == "multicolumndayview") {
            calendarID[0] = dayNode.getAttribute("calendar");
            var dayNumber = this._updateMulticolumnViewDayNumber(calendarID);
        }
        else {
            var classNames = dayNode.className.split(" ");
            var dayNumber = -1;
            for (var i = 0; dayNumber == -1 && i < classNames.length; i++) {
                var className = classNames[i];
                if (className.startsWith("day") && className.length > 3) {
                    dayNumber = parseInt(className.substr(3));
                }
            }
        }
        this.dayNumber = dayNumber;
    },
    initFromEventCellMonthly: function(eventCell) {
        this.start = 0;
        this.duration = SOGoEventDragDayLength;

        var dayNumber = -1;

        var week = -1;
        var day = -1;

        var dayNode = eventCell.parentNode;
        var classNames = dayNode.className.split(" ");
        for (var i = 0;
             (day == -1 || week == -1)
                 && i < classNames.length;
             i++) {
            var className = classNames[i];
            if (className.startsWith("day") && className.length > 3) {
                day = parseInt(className.substr(3));
            } else if (className.startsWith("week")
                       && !className.startsWith("weekOf")
                       && className != "weekEndDay") {
                var ofIndex = className.indexOf("of");
                if (ofIndex > -1) {
                    var len = ofIndex - 4;
                    week = parseInt(className.substr(4, len));
                }
            }
        }
        this.dayNumber = week * 7 + day;
    },

    initFromEventCells: function(eventCells) {
        this.duration = 0;
        for (var i = 0; i < eventCells.length; i++) {
            var current = new SOGoEventDragEventCoordinates();
            current.setEventType(this.eventType);
            current.initFromEventCell(eventCells[i]);
            if (this.dayNumber == -1 || current.dayNumber < this.dayNumber) {
              this.dayNumber = current.dayNumber;
              this.start = current.start;
            }
            this.duration += current.duration;
        }
    },

    getDelta: function(otherCoordinates) {
        var delta = new SOGoEventDragEventCoordinates();
        delta.dayNumber = (this.dayNumber - otherCoordinates.dayNumber);
        delta.start = (this.start - otherCoordinates.start);
        delta.duration = (this.duration - otherCoordinates.duration);

        return delta;
    },

    _quartersToHM: function(quarters) {
        var minutes = quarters * 15;
        var hours = Math.floor(minutes / 60);
        if (hours < 10)
            hours = "0" + hours;
        var mins = minutes % 60;
        if (mins < 10)
            mins = "0" + mins;

        return "" + hours + ":" + mins;
    },
  
    _updateMulticolumnViewDayNumber: function(calendarID) {
        var calendarList = $("calendarList").getElementsByTagName("li");
        for (var j = 0; j < calendarList.length ; j++) {
            if ($("calendarList").getElementsByTagName("li")[j].down().checked)
                activeCalendars.push($("calendarList").getElementsByTagName("li")[j].getAttribute("id").substr(1));
        }
        for (var k = 0; k < activeCalendars.length; k++) {
            if (activeCalendars[k] == calendarID[0]) {
                return k;
            }
        }
    },

    getStartTime: function() {
        return this._quartersToHM(this.start);
    },

    getEndTime: function() {
        var end = (this.start + this.duration) % SOGoEventDragDayLength;
        return this._quartersToHM(end);
    },

    clone: function() {
        var coordinates = new SOGoEventDragEventCoordinates();
        coordinates.dayNumber = this.dayNumber;
        coordinates.start = this.start;
        coordinates.duration = this.duration;

        return coordinates;
    }
};

var SOGoDragGhostInterface = {
    visible: true,

    title: null,
    folderClass: null,
    inside: null,

    currentStart: -1,
    currentDuration: -1,
    isStartGhost: false,
    isEndGhost: false,

    show: function SDGI_show() {
        if (!this.visible) {
            this.removeClassName("hidden");
            if (this.inside)
                this.inside.removeClassName("hidden");
            this.visible = true;
        }
    },
    hide: function SDGI_hide() {
        if (this.visible) {
            this.addClassName("hidden");
            if (this.inside)
                this.inside.addClassName("hidden");
            this.visible = false;
        }
    },

    setTitle: function SDGI_setTitle(title) {
        if (this.title != title) {
            while (this.inside.childNodes.length) {
                this.inside.removeChild(this.inside.firstChild);
            }
            if (title) {
                this.inside.appendChild(document.createTextNode(title));
            }
            this.title = title;
        }
    },
    setLocation: function SDGI_setLocation(location) {
        if (this.location != location) {
            var spans = this.inside.select("SPAN.location");
            if (spans && spans.length > 0) {
                this.inside.removeChild(spans[0]);
            }
            if (location) {
                this.inside.appendChild(createElement("br"));
                var span = createElement("span", null, "location");
                span.appendChild(document.createTextNode(location));
                this.inside.appendChild(span);
            }
            this.location = location;
        }
    },

    setFolderClass: function SDGI_setFolderClass(folderClass) {
        if (this.folderClass != folderClass) {
            this.removeClassName(this.folderClass);
            this.folderClass = folderClass;
            this.addClassName(this.folderClass);
        }
    },

    setStart: function SDGI_setStart(start) {
        if (this.currentStart != start) {
            if (this.cssHandlesPosition)
                this.removeClassName("starts" + this.currentStart);
            this.currentStart = start;
            if (this.cssHandlesPosition)
                this.addClassName("starts" + this.currentStart);
        }
    },
    setDuration: function SDGI_setDuration(duration) {
        if (this.currentDuration != duration) {
            if (this.cssHandlesPosition)
                this.removeClassName("lasts" + this.currentDuration);
            this.currentDuration = duration;
            if (this.cssHandlesPosition)
                this.addClassName("lasts" + this.currentDuration);
        }
    },

    setStartGhost: function SDGI_setStartGhost() {
        if (!this.isStartGhost) {
            this.addClassName("startGhost");
            this.isStartGhost = true;
        }
    },
    unsetStartGhost: function SDGI_unsetStartGhost() {
        if (this.isStartGhost) {
            this.removeClassName("startGhost");
            this.isStartGhost = false;
        }
    },
    setEndGhost: function SDGI_setEndGhost() {
        if (!this.isEndGhost) {
            this.addClassName("endGhost");
            this.isEndGhost = true;
        }
    },
    unsetEndGhost: function SDGI_unsetEndGhost() {
        if (this.isEndGhost) {
            this.removeClassName("endGhost");
            this.isEndGhost = false;
        }
    }
};

function SOGoEventDragGhostController() {
}

SOGoEventDragGhostController.prototype = {
    originalCoordinates: null,
    currentCoordinates: null,

    originalPointerCoordinates: null,
    currentPointerCoordinates: null,

    dragMode: null,

    startHourPara: null,
    endHourPara: null,
    ghosts: null,

    initWithCoordinates: function SEDGC_initWithCoordinates(coordinates) {
        this.originalCoordinates = coordinates;
        this.currentCoordinates = coordinates.clone();
    },

    setTitle: function SEDGC_setTitle(title) {
        this.eventTitle = title;
    },

    setLocation: function SEDGC_setLocation(location) {
        this.eventLocation = location;
    },

    setFolderClass: function SEDGC_setFolderClass(folderClass) {
        this.folderClass = folderClass;
    },

    setDragMode: function SEDGC_setDragMode(dragMode) {
        this.dragMode = dragMode;
    },

    setPointerHandler: function SEDGC_setPointerHandler(pointerHandler) {
        this.pointerHandler = pointerHandler;
        this.originalPointerCoordinates = null;
        this.currentPointerCoordinates = null;
        this.updateFromPointerHandler();
        this.originalPointerCoordinates = this.currentPointerCoordinates.clone();
    },

    updateFromPointerHandler: function SEDGC_updateFromPointerHandler() {
        var newCoordinates = this.pointerHandler.getEventViewCoordinates();
        if (!this.currentPointerCoordinates
            || !newCoordinates
            || newCoordinates.x != this.currentPointerCoordinates.x
            || newCoordinates.y != this.currentPointerCoordinates.y) {
            this.currentPointerCoordinates = newCoordinates;
            if (this.originalPointerCoordinates) {
                if (!newCoordinates)
                    this.currentPointerCoordinates = this.originalPointerCoordinates.clone();
                this._updateCoordinates();
                if (this.ghosts) {
                    this._updateGhosts();
                    if (this.startHourPara)
                        this._updateGhostsParas();
                }
            }
        }
    },
  
    _updateMulticolumnViewDayNumber_SEDGC: function() {
        var calendarID_SEDGC = this.folderClass.substr(14);
        var calendarList = $("calendarList").getElementsByTagName("li");
        activeCalendars = [];
        for (var j = 0; j < calendarList.length ; j++) {
            if ($("calendarList").getElementsByTagName("li")[j].down().checked)
                activeCalendars.push($("calendarList").getElementsByTagName("li")[j].getAttribute("id").substr(1));
        }
        for (var k = 0; k < activeCalendars.length; k++) {
            if (activeCalendars[k] == calendarID_SEDGC) {
                this.currentCoordinates.dayNumber = k;
                break;
            }
        }
    },
  
    _updateCoordinates: function SEDGC__updateCoordinates() {
        var delta = this.currentPointerCoordinates
                        .getDelta(this.originalPointerCoordinates);
        var deltaQuarters = delta.x * SOGoEventDragDayLength + delta.y;
        if (currentView == "multicolumndayview")
          this._updateMulticolumnViewDayNumber_SEDGC();
        else
          this.currentCoordinates.dayNumber = this.originalCoordinates.dayNumber;

        // log("dragMode: " + this.dragMode);
        if (this.dragMode == "move-event") {
            this.currentCoordinates.start
                = this.originalCoordinates.start + deltaQuarters;
            this.currentCoordinates.duration
                = this.originalCoordinates.duration;
            // log("start: " + this.currentCoordinates.start);
            // log("   duration: " + this.currentCoordinates.duration);
        } else {
            if (this.dragMode == "change-start") {
                var newDuration = this.originalCoordinates.duration - deltaQuarters;
                if (newDuration > 0) {
                    this.currentCoordinates.start
                        = this.originalCoordinates.start + deltaQuarters;
                    this.currentCoordinates.duration = newDuration;
                } else if (newDuration < 0) {
                    this.currentCoordinates.start
                        = (this.originalCoordinates.start
                           + this.originalCoordinates.duration);
                    this.currentCoordinates.duration = -newDuration;
                }
            } else if (this.dragMode == "change-end") {
                var newDuration = this.originalCoordinates.duration + deltaQuarters;
                if (newDuration > 0) {
                    this.currentCoordinates.start = this.originalCoordinates.start;
                    this.currentCoordinates.duration = newDuration;
                } else if (newDuration < 0) {
                    this.currentCoordinates.start
                        = this.originalCoordinates.start + newDuration;
                    this.currentCoordinates.duration = -newDuration;
                }
            }
        }

        if (this.currentCoordinates.start < 0) {
            var deltaDays = Math.ceil(-this.currentCoordinates.start
                                      / SOGoEventDragDayLength);
            this.currentCoordinates.start += deltaDays * SOGoEventDragDayLength;
            this.currentCoordinates.dayNumber -= deltaDays;
        } else if (this.currentCoordinates.start >= SOGoEventDragDayLength) {
            var deltaDays = Math.floor(this.currentCoordinates.start
                                       / SOGoEventDragDayLength);
            this.currentCoordinates.start -= deltaDays * SOGoEventDragDayLength;
          
            // This dayNumber needs to be updated with the calendar number.
            if (currentView == "multicolumndayview")
              this._updateMulticolumnViewDayNumber_SEDGC();
            this.currentCoordinates.dayNumber += deltaDays;
        }
    },

    showGhosts: function SEDGC_showGhosts() {
        if (!this.ghosts) {
            this.ghosts = [];
            var utilities = SOGoEventDragUtilities();
            var nodes = utilities.getEventContainerNodes();
            var isMultiday = (utilities.getEventType() == "multiday");
            for (var i = 0; i < nodes.length; i++) {
                var newGhost = $(document.createElement("div"));
                Object.extend(newGhost, SOGoDragGhostInterface);
                newGhost.className = "event eventDragGhost";
                newGhost.cssHandlesPosition = isMultiday;
                newGhost.hide();

                var ghostInside = $(document.createElement("div"));
                ghostInside.className = "eventInside";
                newGhost.inside = ghostInside;
                newGhost.appendChild(ghostInside);

                nodes[i].appendChild(newGhost);
                this.ghosts.push(newGhost);
            }
            if (isMultiday) {
                var ghostHourPara = $(document.createElement("div"));
                ghostHourPara.setAttribute("id", "ghostStartHour");
                this.startHourPara = ghostHourPara;
                ghostHourPara = $(document.createElement("div"));
                ghostHourPara.setAttribute("id", "ghostEndHour");
                this.endHourPara = ghostHourPara;
            }
            this._updateGhosts();
            if (this.startHourPara)
                this._updateGhostsParas();
        }
    },
    hideGhosts: function SEDGC_hideGhosts() {
        if (this.ghosts) {
            if (this.startHourPara && this.startHourPara.parentNode)
                this.startHourPara.parentNode.removeChild(this.startHourPara);
            this.startHourPara = null;
            if (this.endHourPara && this.endHourPara.parentNode)
                this.endHourPara.parentNode.removeChild(this.endHourPara);
            this.endHourPara = null;
            for (var i = 0; i < this.ghosts.length; i++) {
                var ghost = this.ghosts[i];
                ghost.parentNode.removeChild(ghost);
            }
            this.ghosts = null;
        }
    },

    _updateGhosts: function SEDGC__updateGhosts() {
        var maxGhosts = this.ghosts.length;
        var max = this.currentCoordinates.dayNumber;
        if (max > maxGhosts)
            max = maxGhosts;
        for (var i = 0; i < max; i++) {
            var ghost = this.ghosts[i];
            ghost.hide();
            ghost.unsetStartGhost();
            ghost.unsetEndGhost();
        }
        if (this.currentCoordinates.dayNumber < maxGhosts) {
            var currentDay = this.currentCoordinates.dayNumber;
            var durationLeft = this.currentCoordinates.duration;
            var start = this.currentCoordinates.start;
            var maxDuration = SOGoEventDragDayLength - start;
            var duration = durationLeft;
            if (duration > maxDuration)
                duration = maxDuration;

            var ghost = null;
            if (currentDay > -1) {
                ghost = this.ghosts[currentDay];
                ghost.setStartGhost();
                ghost.unsetEndGhost();
                ghost.setTitle(this.eventTitle);
                ghost.setLocation(this.eventLocation);
                ghost.setFolderClass(this.folderClass);
                ghost.setStart(this.currentCoordinates.start);
                ghost.setDuration(duration);
                ghost.show();

                if (this.startHourPara) {
                    var parentNode = this.startHourPara.parentNode;
                    if (parentNode && parentNode != ghost)
                        parentNode.removeChild(this.startHourPara);
                    ghost.appendChild(this.startHourPara);
                }
            }
            durationLeft -= duration;
            currentDay++;
            while (durationLeft && currentDay < maxGhosts) {
                duration = durationLeft;
                if (duration > SOGoEventDragDayLength)
                    duration = SOGoEventDragDayLength;
                if (currentDay > -1) {
                    ghost = this.ghosts[currentDay];
                    ghost.unsetStartGhost();
                    ghost.unsetEndGhost();
                    ghost.setTitle();
                    ghost.setFolderClass(this.folderClass);
                    ghost.setStart(0);
                    ghost.setDuration(duration);
                    ghost.show();
                }
                durationLeft -= duration;
                currentDay++;
            }
            if (!durationLeft) {
                ghost.setEndGhost();
            }

            if (this.endHourPara) {
                var parentNode = this.endHourPara.parentNode;
                if (parentNode && parentNode != ghost)
                    parentNode.removeChild(this.endHourPara);
                ghost.appendChild(this.endHourPara);
            }

            while (currentDay < maxGhosts) {
                var ghost = this.ghosts[currentDay];
                ghost.hide();
                ghost.unsetStartGhost();
                ghost.unsetEndGhost();
                currentDay++;
            }
        }
    },

    _updateGhostsParas: function SEDGC__updateGhostsParas() {
        var para = this.startHourPara;
        while (para.childNodes.length)
            para.removeChild(para.childNodes[0]);
        var time = this.currentCoordinates.getStartTime();
        para.appendChild(document.createTextNode(time));

        para = this.endHourPara;
        while (para.childNodes.length)
            para.removeChild(para.childNodes[0]);
        time = this.currentCoordinates.getEndTime();
        para.appendChild(document.createTextNode(time));
    }
};

function SOGoCoordinates() {
}

SOGoCoordinates.prototype = {
    x: -1,
    y: -1,

    getDelta: function SC_getDelta(otherCoordinates) {
        var delta = new SOGoCoordinates();
        delta.x = this.x - otherCoordinates.x;
        delta.y = this.y - otherCoordinates.y;

        return delta;
    },

    getDistance: function SC_getDistance(otherCoordinates) {
        var delta = this.getDelta(otherCoordinates);

        return Math.sqrt(delta.x * delta.x + delta.y * delta.y);
    },

    clone: function SC_clone() {
        var coordinates = new SOGoCoordinates();
        coordinates.x = this.x;
        coordinates.y = this.y;

        return coordinates;
    }
};

function SOGoEventDragPointerHandler() {
}

SOGoEventDragPointerHandler.prototype = {
    originalCoordinates: null,
    currentCoordinates: null,
    containerCoordinates: null,

    /* return the day and quarter coordinates of the pointer cursor within the
       day view */
    getEventViewCoordinates: null,

    initFromEvent: function SEDPH_initFromEvent(event) {
        this.currentCoordinates = new SOGoCoordinates();
        this.updateFromEvent(event);
        this.originalCoordinates = this.currentCoordinates.clone();

        var utilities = SOGoEventDragUtilities();
        this.containerCoordinates = utilities.getEventsViewNodeCumulativeCoordinates();
        if (utilities.getEventType() == "multiday-allday") {
            /* a hack */
            this.containerCoordinates.x -= SOGoEventDragVerticalOffset;
            this.containerCoordinates.y -= 40;
        }
    },

    updateFromEvent: function SEDPH_updateFromEvent(event) {
        this.currentCoordinates.x = Event.pointerX(event);
        this.currentCoordinates.y = Event.pointerY(event);
    },

    getContainerBasedCoordinates: function SEDPH_getCBC() {
        var coordinates = this.currentCoordinates.getDelta(this.containerCoordinates);
        var container = SOGoEventDragUtilities().getEventsViewNode();

        if (container.clientWidth == 0)
            /* a hack for Safari */
            container = $(container.id);
        if (coordinates.x < 0 || coordinates.x > container.clientWidth
            || coordinates.y < 0 || coordinates.y > container.clientHeight)
            coordinates = null;

        return coordinates;
    },

    prepareWithEventType: function SEDPH_prepareWithEventType(eventType) {
        var methods = { "multiday": this.getEventMultiDayViewCoordinates,
                        "multiday-allday": this.getEventMultiDayAllDayViewCoordinates,
                        "monthly": this.getEventMonthlyViewCoordinates,
                        "unknown": null };
        var method = methods[eventType];
        this.getEventViewCoordinates = method;
    },

    getEventMultiDayViewCoordinates: function SEDPH_gEMultiDayViewC() {
        var coordinates = this.getEventMultiDayAllDayViewCoordinates();
        if (coordinates) {
            var utilities = SOGoEventDragUtilities();
            var quarterHeight = utilities.getQuarterHeight();
            var container = utilities.getEventsViewNode();
            var pxCoordinates = this.getContainerBasedCoordinates();
            pxCoordinates.y += container.scrollTop;
            coordinates.y = Math.floor((pxCoordinates.y
                                        - SOGoEventDragHorizontalOffset)
                                       / quarterHeight);
            var maxY = SOGoEventDragDayLength - 1;
            if (coordinates.y < 0)
                coordinates.y = 0;
            else if (coordinates.y > maxY)
                coordinates.y = maxY;
        }

        return coordinates;
    },
    getEventMultiDayAllDayViewCoordinates: function SEDPH_gEMultiDayADVC() {
        /* x = day; y = quarter */
        var coordinates;

        var pxCoordinates = this.getContainerBasedCoordinates();
        if (pxCoordinates) {
            coordinates = new SOGoCoordinates();

            var utilities = SOGoEventDragUtilities();
            var dayWidth = utilities.getDayWidth();
            var daysOffset = utilities.getDaysOffset();

            coordinates.x = Math.floor((pxCoordinates.x - daysOffset) / dayWidth);
            var maxX = utilities.getEventContainerNodes().length - 1;
            if (coordinates.x < 0)
                coordinates.x = 0;
            else if (coordinates.x > maxX)
                coordinates.x = maxX;
            coordinates.y = 0;
        } else {
            coordinates = null;
        }

        // logOnly("coordinates.x: " + coordinates.x);

        return coordinates;
    },
    getEventMonthlyViewCoordinates: function SEDPH_gEMonthlyViewC() {
        /* x = day; y = quarter */
        var coordinates;

        var pxCoordinates = this.getContainerBasedCoordinates();
        if (pxCoordinates) {
            coordinates = new SOGoCoordinates();
            var utilities = SOGoEventDragUtilities();
            var daysOffset = utilities.getDaysOffset();
            var daysTopOffset = daysOffset; /* change later */
            var dayHeight = utilities.getDayHeight();
            var daysY = Math.floor((pxCoordinates.y - daysTopOffset) / dayHeight);
            if (daysY < 0)
                daysY = 0;
            var dayWidth = utilities.getDayWidth();

            coordinates.x = Math.floor((pxCoordinates.x - daysOffset) / dayWidth);
            if (coordinates.x < 0)
                coordinates.x = 0;
            else if (coordinates.x > 6)
                coordinates.x = 6;
            coordinates.x += 7 * daysY;
            coordinates.y = 0;
        } else {
            coordinates = null;
        }

        return coordinates;
    },

    getDistance: function SEDPH_getDistance() {
        return this.currentCoordinates.getDistance(this.originalCoordinates);
    }
};

function SOGoScrollController() {
    this.init();
}

SOGoScrollController.prototype = {
    pointerHandler: null,

    scrollView: null,
    lastScroll: 0,
    scrollStep: 0,

    init: function SSC_init() {
        var utilities = SOGoEventDragUtilities();
        this.scrollView = utilities.getEventsViewNode();
        this.scrollStep = 6 * utilities.getQuarterHeight();
    },

    setPointerHandler: function SSC_setPointerHandler(pointerHandler) {
        this.pointerHandler = pointerHandler;
    },

    updateFromPointerHandler: function SSC_updateFromPointerHandler() {
        var pointerCoordinates
            = this.pointerHandler.getContainerBasedCoordinates();
        if (pointerCoordinates) {
            var now = new Date().getTime();
            if (!this.lastScroll || now > this.lastScroll + 100) {
                this.lastScroll = now;
                var scrollY = pointerCoordinates.y - this.scrollStep;
                if (scrollY < 0) {
                    var minY = -this.scrollView.scrollTop;
                    if (scrollY < minY)
                        scrollY = minY;
                    this.scrollView.scrollTop += scrollY;
                } else {
                    scrollY = pointerCoordinates.y + this.scrollStep;
                    var delta = scrollY - this.scrollView.clientHeight;
                    if (delta > 0) {
                        this.scrollView.scrollTop += delta;
                    }
                }
            }
        }
    }
};

function SOGoEventDragLeftPanelController() {
}

SOGoEventDragLeftPanelController.prototype = {
    updateLeftPanelVisual : null,
    dropCalendar : null,
    DnDLeftPanelImage : $("DnDLeftPanelImage"),

    setLeftPanelVisual: function SEDLPC_setLeftPanelVisual() {
        var that = this;
        this.updateLeftPanelVisual = $("leftPanel").on("mousemove", function(e){
            that.DnDLeftPanelImage.style.left = e.pageX + 5 + "px";
            that.DnDLeftPanelImage.style.top = e.pageY + 5 + "px";
        });
    },
    
    updateFromPointerHandler: function SEDLPC_updateFromPointerHandler(event) {
        // Highlight the calendar hover
        $$('#calendarList li').each(function(e){
                                    e.removeClassName('genericHoverClass');
                                    });
        var hoverCalendar = $(event).findElement('#calendarList li');
        if (hoverCalendar) {
            hoverCalendar.addClassName('genericHoverClass');
            this.dropCalendar = hoverCalendar;
        }
        else
            this.dropCalendar = null;
    },
    
    startEvent: function SEDLPC_startEvent() {
        this.DnDLeftPanelImage.style.visibility = 'visible';
        this.updateLeftPanelVisual.start();
    },
    
    stopEvent: function SEDLPC_stopEvent() {
        this.DnDLeftPanelImage.style.visibility = 'hidden';
        this.updateLeftPanelVisual.stop();
    }
}

function SOGoEventDragController() {
}

SOGoEventDragController.prototype = {
    eventCells: null,

    eventType: null,
    eventIsInvitation: false,
    title: null,
    folderClass: null,

    draggingModeAreas: null,

    ghostController: null,
    leftPanelController: null,

    hasSelected: false,
    dragHasStarted: false,
    dragMode: null,
    originalDayNumber: -1,

    pointerHandler: null,

    dropCallback: null,

    onDragStartBound: null,
    onDragStopBound: null,
    onDragModeBound: null,

    _determineDragMode: null,

    attachToEventCells: function SEDC_attachToEventCells(eventCells) {
        this.eventCells = eventCells;

        this.ghostController = new SOGoEventDragGhostController();
        this.leftPanelController = new SOGoEventDragLeftPanelController();
        this._determineEventInvitation(eventCells[0]);
        this._determineEventType(eventCells[0]);
        this._prepareEventType();
        this._determineTitleAndFolderClass();
        this.ghostController.setTitle(this.title);
        this.ghostController.setLocation(this.location);
        this.ghostController.setFolderClass(this.folderClass);
        this.leftPanelController.setLeftPanelVisual();

        this.onDragStartBound = this.onDragStart.bindAsEventListener(this);
        for (var i = 0; i < eventCells.length; i++) {
            eventCells[i].observe("mousedown", this.onDragStartBound, false);
            if (eventCells[i].editable && !this.eventIsInvitation) {
                eventCells[i].addClassName("draggable");
            }
        }

        if (this.eventType == "multiday") {
            var topDragGrip = $(document.createElement("div"));
            topDragGrip.addClassName("topDragGrip");
            eventCells[0].appendChild(topDragGrip);

            var bottomDragGrip = $(document.createElement("div"));
            bottomDragGrip.addClassName("bottomDragGrip");
            eventCells[eventCells.length-1].appendChild(bottomDragGrip);
        } else {
            var leftDragGrip = $(document.createElement("div"));
            leftDragGrip.addClassName("leftDragGrip");
            eventCells[0].appendChild(leftDragGrip);

            var rightDragGrip = $(document.createElement("div"));
            rightDragGrip.addClassName("rightDragGrip");
            eventCells[eventCells.length-1].appendChild(rightDragGrip);
        }
    },

    attachToDayNode: function SEDC_attachToDayNode(dayNode) {
        this._determineEventType(dayNode);
        this._prepareEventType();
        this.ghostController = new SOGoEventDragGhostController();
        this.ghostController.setTitle(_("New Event"));

        this.onDragStartBound = this.onDragStart.bindAsEventListener(this);
        dayNode.observe("mousedown", this.onDragStartBound, false);
    },

    onDragStart: function SEDC_onDragStart(event) {
        var target = getTarget(event);
        if (eventIsLeftClick(event) && (target.nodeType == 1)) {
            if (/minutes\d{2}/.test(target.className))
                target = target.parentNode;
            if ((!this.eventCells
                 && (target.hasClassName("clickableHourCell")
                     || target.hasClassName("day"))
                 && (target.scrollHeight - target.clientHeight <= 1))
                || (this.eventCells && this.eventCells[0].editable
                    && !this.eventIsInvitation)) {
                var utilities = SOGoEventDragUtilities();
                utilities.setEventType(this.eventType);

                this.pointerHandler = new SOGoEventDragPointerHandler();
                this.pointerHandler.prepareWithEventType(this.eventType);
                this.pointerHandler.initFromEvent(event);

                var coordinates = new SOGoEventDragEventCoordinates();
                coordinates.setEventType(this.eventType);
                if (this.eventCells) {
                    coordinates.initFromEventCells(this.eventCells);
                } else {
                    var eventViewCoordinates
                        = this.pointerHandler.getEventViewCoordinates();
                    coordinates.dayNumber = eventViewCoordinates.x;
                    coordinates.start = eventViewCoordinates.y;
                    coordinates.duration = 1;
                }
                this.ghostController.initWithCoordinates(coordinates);

                if (!this.eventCells) {
                    if (currentView == "multicolumndayview") {
                        if (target.getAttribute("calendar"))
                            var folderID = target.getAttribute("calendar");
                        else
                            var folderID = target.up("[calendar]").getAttribute("calendar");
                    }
                    else {
                        var folder = getSelectedFolder();
                        var folderID = folder.readAttribute("id").substr(1);
                    }
                    this.ghostController.setFolderClass("calendarFolder" + folderID);
                }
                this.ghostController.setDragMode(this._determineDragMode());
                this.ghostController.setPointerHandler(this.pointerHandler);

                if (this.eventType == "multiday") {
                    this.scrollController = new SOGoScrollController();
                    this.scrollController.setPointerHandler(this.pointerHandler);
                }

                this.onDragStopBound
                    = this.onDragStop.bindAsEventListener(this);
                if (Prototype.Browser.IE)
                    Event.observe(document.body,
                                  "mouseup", this.onDragStopBound);
                else
                    Event.observe(window, "mouseup", this.onDragStopBound);
                this.onDragModeBound = this.onDragMode.bindAsEventListener(this);
                Event.observe(document.body, "mousemove", this.onDragModeBound);
            }
        }
    },

    _determineEventInvitation: function SEDC__determineEventType(node) {
        var isInvitation = false;
        for (var i = 0; !isInvitation && i < userStates.length; i++) {
            var inside = node.select("DIV.eventInside")[0];
            if (inside.hasClassName(userStates[i]))
                isInvitation = true;
        }

        this.eventIsInvitation = isInvitation;
    },

    _determineEventType: function SEDC__determineEventType(node) {
        var type = "unknown";

        var dayNode;
        var currentNode = node;
        while (!currentNode.hasClassName("day"))
            currentNode = currentNode.parentNode;
        dayNode = currentNode;

        // log("dayNode: " + dayNode.className);
        var secondParent = dayNode.parentNode;
        // log("secondParent: " + secondParent.className);
        if (secondParent.id == "monthDaysView") {
            type = "monthly";
        } else {
            var thirdParent = secondParent.parentNode;
            // log("thirdParent: " + thirdParent.id);
            if (thirdParent.id == "calendarHeader")
                type = "multiday-allday";
            else if (thirdParent.id == "daysView")
                type = "multiday";
        }

        // log("type: " + type);

        this.eventType = type;
    },
    _prepareEventType: function SEDC__prepareEventType() {
        var methods
            = { "multiday": this._determineDragModeMultiDay,
                "multiday-allday": this._determineDragModeMultiDayAllDay,
                "monthly": this._determineDragModeMonthly,
                "unknown": null };
        this._determineDragMode = methods[this.eventType];
    },

    _determineDragModeMultiDay: function SEDC__determineDragModeMultiDay() {
        var dragMode;

        if (this.eventCells) {
            var coordinates = this.pointerHandler.currentCoordinates.clone();
            var utilities = SOGoEventDragUtilities();
            var scrollView = utilities.getEventsViewNode();
            coordinates.y += scrollView.scrollTop;
            coordinates.y -= SOGoEventDragVerticalOffset;

            var firstCell = this.eventCells[0];
            var handleCoords = firstCell.cumulativeOffset();

            dragMode = "move-event";
            if ((handleCoords[0] <= coordinates.x
                 && coordinates.x <= handleCoords[0] + firstCell.clientWidth)
                && (handleCoords[1] <= coordinates.y
                    && coordinates.y <= handleCoords[1] + SOGoEventDragHandleSize))
                dragMode = "change-start";
            else {
                var lastCell = this.eventCells[this.eventCells.length-1];
                handleCoords = lastCell.cumulativeOffset();
                handleCoords[1] += (lastCell.clientHeight
                                    - SOGoEventDragHandleSize - 1);
                if ((handleCoords[0] <= coordinates.x
                     && coordinates.x <= handleCoords[0] + lastCell.clientWidth)
                    && (handleCoords[1] <= coordinates.y
                        && coordinates.y <= handleCoords[1] + SOGoEventDragHandleSize))
                    dragMode = "change-end";
            }
        } else {
            dragMode = "change-end";
        }

        return dragMode;
    },
    _determineDragModeMultiDayAllDay: function SEDC__detDMMultiDayAllDay() {
        var dragMode;

        if (this.eventCells) {
            var coordinates = this.pointerHandler.currentCoordinates.clone();
            coordinates.x -= SOGoEventDragHorizontalOffset;
            coordinates.y -= SOGoEventDragVerticalOffset;

            var firstCell = this.eventCells[0];
            var handleCoords = firstCell.cumulativeOffset();

            dragMode = "move-event";
            if (handleCoords[0] <= coordinates.x
                && coordinates.x <= handleCoords[0] + SOGoEventDragHandleSize)
                dragMode = "change-start";
            else {
                var lastCell = this.eventCells[this.eventCells.length-1];
                handleCoords = lastCell.cumulativeOffset();
                handleCoords[0] += lastCell.clientWidth;
                if (handleCoords[0] - SOGoEventDragHandleSize <= coordinates.x
                    && coordinates.x <= handleCoords[0])
                    dragMode = "change-end";
            }
        } else {
            dragMode = "change-end";
        }

        return dragMode;
    },
    _determineDragModeMonthly: function SEDC__determineDragModeMultiDay() {
        var dragMode;

        if (this.eventCells) {
            var coordinates = this.pointerHandler.currentCoordinates.clone();
            coordinates.x -= SOGoEventDragHorizontalOffset;
            coordinates.y -= SOGoEventDragVerticalOffset;

            var firstCell = this.eventCells[0];
            var handleCoords = firstCell.cumulativeOffset();

            dragMode = "move-event";
            var eventHeight = 16; /* arbitrary value */

            if (handleCoords[1] <= coordinates.y
                && coordinates.y <= handleCoords[1] + eventHeight
                && handleCoords[0] <= coordinates.x
                && coordinates.x <= handleCoords[0] + SOGoEventDragHandleSize)
                dragMode = "change-start";
            else {
                var lastCell = this.eventCells[this.eventCells.length-1];
                handleCoords = lastCell.cumulativeOffset();
                handleCoords[0] += lastCell.clientWidth;
                if (handleCoords[1] <= coordinates.y
                    && coordinates.y <= handleCoords[1] + eventHeight
                    && handleCoords[0] - SOGoEventDragHandleSize <= coordinates.x
                    && coordinates.x <= handleCoords[0])
                    dragMode = "change-end";
            }
        } else {
            dragMode = "change-end";
        }

        return dragMode;
    },

    _determineTitleAndFolderClass: function SEDC__dTAFC() {
        var title = "";
        var folderClass = "";
        var location = null;
        if (this.eventCells) {
            var firstCell = this.eventCells[0];
            var divs = firstCell.childNodesWithTag("div");
            for (var i = 0; i < divs.length; i++) {
                var div = divs[i];
                if (div.hasClassName("eventInside")) {
                    var titleDIV = this._determineTitleDIV(div);
                    if (titleDIV) {
                        title = this._determineTitleFromDIV(titleDIV);
                        location = this._determineLocationFromDIV(titleDIV);
                    }
                    folderClass = this._determineFolderClassFromDIV(div);
                }
            }
        }
        this.title = title;
        this.location = location;
        this.folderClass = folderClass;
    },
    _determineTitleDIV: function SEDC__determineTitleDIV(div) {
        var titleDIV = null;
        var insideDivs = div.childNodesWithTag("div");
        for (var i = 0; titleDIV == null && i < insideDivs.length; i++) {
            var insideDiv = insideDivs[i];
            if (insideDiv.hasClassName("text")) {
                titleDIV = insideDiv;
            }
        }

        return titleDIV;
    },
    _determineTitleFromDIV: function SEDC__determineTitleFromDIV(titleDIV) {
        var title = "";

        var currentNode = titleDIV.firstChild;
        while (currentNode) {
            if (currentNode.nodeType == Node.TEXT_NODE) {
                title += currentNode.nodeValue;
            }
            currentNode = currentNode.nextSibling;
        }

        return title.trim();
    },
    _determineLocationFromDIV: function SEDC__determineLocationFromDIV(titleDIV) {
        var location = "";

        var spans = titleDIV.select("span.location");
        if (spans && spans.length > 0) {
            var locationSPAN = spans[0];
            var currentNode = locationSPAN.firstChild;
            while (currentNode) {
                if (currentNode.nodeType == Node.TEXT_NODE) {
                    location += currentNode.nodeValue;
                }
                currentNode = currentNode.nextSibling;
            }
        }

        return location.trim();
    },
    _determineFolderClassFromDIV: function SEDC__detFolderClassFromDIV(div) {
        var folderClass = null;

        var classes = div.className.split(" ");
        for (var i = 0; folderClass == null && i < classes.length; i++) {
            var currentClass = classes[i];
            if (currentClass.startsWith("calendarFolder")) {
                folderClass = currentClass;
            }
        }

        return folderClass;
    },

    onDragStop: function SEDC_onDragStop(event) {
        if (Prototype.Browser.IE)
            Event.stopObserving(document.body, "mouseup", this.onDragStopBound);
        else
            Event.stopObserving(window, "mouseup", this.onDragStopBound);
        Event.stopObserving(document.body, "mousemove", this.onDragModeBound);
        this.onDragStopBound = null;
        this.onDragModeBound = null;
        if (this.leftPanelController)
            this.leftPanelController.stopEvent();

        var utilities = SOGoEventDragUtilities();
        if (this.dragHasStarted) {
            this.ghostController.hideGhosts();
            this.dragHasStarted = false;

            if (this.eventCells) {
                for (var i = 0; i < this.eventCells.length; i++) {
                    var currentCell = this.eventCells[i];
                    currentCell.removeClassName("dragging");
                }
                var delta = this.ghostController
                                .currentCoordinates
                                .getDelta(this.ghostController
                                              .originalCoordinates);
              
                if (this.leftPanelController.dropCalendar != null) {
                    $$('#calendarList li').each(function(e) {
                                        e.removeClassName('genericHoverClass');
                                        });
                    calendarID[0] = this.folderClass.substr(14);
                    calendarID[1] = this.leftPanelController.dropCalendar.getAttribute("id").substr(1);
                    delta.start = 0;
                    if (calendarID[0] != calendarID[1])
                        this.updateDropCallback(this, this.eventCells, delta, calendarID);
                }
                else if (currentView == "multicolumndayview" && delta.dayNumber != 0) {
                    var position = activeCalendars.indexOf(calendarID[0]);
                    position += delta.dayNumber;
                    calendarID[1] = activeCalendars[position];
                    this.updateDropCallback(this, this.eventCells, delta, calendarID);
                }
                else
                    this.updateDropCallback(this, this.eventCells, delta, 0);
            } else {
                var eventContainerNodes = utilities.getEventContainerNodes();
                var dayNode = eventContainerNodes[this.ghostController
                                                      .currentCoordinates
                                                      .dayNumber];
                if (dayNode.hasClassName("events"))
                    dayNode = dayNode.parentNode;
                this.createDropCallback(this,
                                        dayNode.readAttribute("day"),
                                        this.ghostController.currentCoordinates);
            }
        }
        utilities.reset();

        Event.stop(event);
    },

    _coordinateToTime: function SEDC_coordinateToTime(coordinate) {
        var hours = Math.floor(coordinate / 4);
        var minutes = (coordinate % 4) * 15;
        if (minutes < 10)
            minutes = "0" + minutes;
        var time = hours + ":" + minutes;

        return time;
    },

    onDragMode: function SEDC_onDragMode(event) {
        this.pointerHandler.updateFromEvent(event);
        if (this.scrollController)
            this.scrollController.updateFromPointerHandler();
        
        if (this.dragHasStarted) {
            var newCoordinates = this.ghostController.pointerHandler.getEventViewCoordinates();
            if (newCoordinates == null && this.leftPanelController != null) {
                if (this.ghostController.ghosts) {
                    this.ghostController.hideGhosts();
                    this.leftPanelController.startEvent();
                }
                this.leftPanelController.updateFromPointerHandler(event);
            }
            else {
                if (this.ghostController.ghosts == null) {
                    this.ghostController.showGhosts();
                    this.leftPanelController.dropCalendar = null;
                    $$('#calendarList li').each(function(e){ e.removeClassName('genericHoverClass'); });
                    this.leftPanelController.stopEvent();
                }
                this.ghostController.updateFromPointerHandler();
            }
        }
        else {
            var distance = this.pointerHandler.getDistance();
            if (distance > 3) {
                $("eventDialog").hide();
                this.dragHasStarted = true;
                if (this.eventCells) {
                    for (var i = 0; i < this.eventCells.length; i++) {
                        var currentCell = this.eventCells[i];
                        currentCell.addClassName("dragging");
                    }
                }
                this.ghostController.showGhosts();
                this.ghostController.updateFromPointerHandler();
            }
        }
        Event.stop(event);
    }
};
