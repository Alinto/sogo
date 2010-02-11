/* -*- Mode: java; tab-width: 2; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

var SOGoEventDragDayLength = 24 * 4; /* quarters */
var SOGoEventDragHandleSize = 8; /* handles for dragging mode */
var SOGoEventDragHorizontalOffset = 3;
var SOGoEventDragVerticalOffset = 3;

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
    dayEventNodes: null,
    quarterHeight: -1,
    dayWidth: -1,
    daysOffset: -1,
    eventsViewNode: null,
    eventsViewNodeCumulativeCoordinates: null,

    reset: function() {
        this.dayEventNodes = null;
        this.quarterHeight = -1;
        this.dayWidth = -1;
        this.daysOffset = -1;
        this.eventsViewNode = null;
        this.eventsViewNodeCumulativeCoordinates = null;
    },

    getDayEventNodes: function() {
        if (!this.dayEventNodes)
            this._initDayEventNodes();

        return this.dayEventNodes;
    },
    _initDayEventNodes: function() {
        this.dayEventNodes = [];

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
    _appendDayEventsNode: function(dayNode) {
        var daySubnodes = dayNode.childNodesWithTag("div");
        for (var i = 0; i < daySubnodes.length; i++) {
            var daySubnode = daySubnodes[i];
            if (daySubnode.hasClassName("events")) {
                this.dayEventNodes.push(daySubnode);
            }
        }
    },

    getQuarterHeight: function() {
        if (this.quarterHeight == -1) {
            var hourLine0 = $("hourLine0");
            var hourLine23 = $("hourLine23");
            this.quarterHeight = ((hourLine23.offsetTop - hourLine0.offsetTop)
                             / (23 * 4));
        }

        return this.quarterHeight;
    },

    getDaysOffset: function() {
        if (this.daysOffset == -1)
            this._initDayEventNodes();

        return this.daysOffset;
    },

    getDayWidth: function() {
        if (this.dayWidth == -1) {
            var nodes = this.getDayEventNodes();
            if (nodes.length > 1) {
                var total = (nodes[nodes.length-1].cumulativeOffset()[0]
                             - nodes[0].cumulativeOffset()[0]);
                this.dayWidth = total / (nodes.length - 1);
            }
            else
                this.dayWidth = nodes[0].offsetWidth;
        }

        return this.dayWidth;
    },

    getEventsViewNode: function() {
        if (!this.eventsViewNode)
            this.eventsViewNode = $("daysView");
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

    initFromEventCell: function(eventCell) {
        var classNames = eventCell.className.split(" ");
        for (var i = 0;
             (this.start == -1 || this.duration == -1)
                 && i < classNames.length;
             i++) {
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
        var classNames = dayNode.className.split(" ");
        for (var i = 0; dayNumber == -1 && i < classNames.length; i++) {
            var className = classNames[i];
            if (className.startsWith("day") && className.length > 3) {
                dayNumber = parseInt(className.substr(3));
            }
        }
        this.dayNumber = dayNumber;
    },

    initFromEventCells: function(eventCells) {
        this.duration = 0;
        for (var i = 0; i < eventCells.length; i++) {
            var current = new SOGoEventDragEventCoordinates();
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

    currentStart: -1,
    currentDuration: -1,
    isStartGhost: false,
    isEndGhost: false,

    show: function SDGI_show() {
        if (!this.visible) {
            this.removeClassName("hidden");
            this.visible = true;
        }
    },
    hide: function SDGI_hide() {
        if (this.visible) {
            this.addClassName("hidden");
            this.visible = false;
        }
    },

    setTitle: function SDGI_setTitle(title) {
        if (this.title != title) {
            while (this.childNodes.length) {
                this.removeChild(this.firstChild);
            }
            if (title) {
                this.appendChild(document.createTextNode(title));
            }
            this.title = title;
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
            this.removeClassName("starts" + this.currentStart);
            this.currentStart = start;
            this.addClassName("starts" + this.currentStart);
        }
    },
    setDuration: function SDGI_setDuration(duration) {
        if (this.currentDuration != duration) {
            this.removeClassName("lasts" + this.currentDuration);
            this.currentDuration = duration;
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
            || newCoordinates.x != this.currentPointerCoordinates.x
            || newCoordinates.y != this.currentPointerCoordinates.y) {
            this.currentPointerCoordinates = newCoordinates;
            if (this.originalPointerCoordinates) {
                this._updateCoordinates();
                if (this.ghosts) {
                    this._updateGhosts();
                    this._updateGhostsParas();
                }
            }
        }
    },

    _updateCoordinates: function SEDGC__updateCoordinates() {
        var delta = this.currentPointerCoordinates
                        .getDelta(this.originalPointerCoordinates);
        var deltaQuarters = delta.x * SOGoEventDragDayLength + delta.y;
        this.currentCoordinates.dayNumber = this.originalCoordinates.dayNumber;

        if (this.dragMode == "move-event") {
            this.currentCoordinates.start
                = this.originalCoordinates.start + deltaQuarters;
            this.currentCoordinates.duration
                = this.originalCoordinates.duration;
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
            this.currentCoordinates.dayNumber += deltaDays;
        }
    },

    showGhosts: function SEDGC_showGhosts() {
        if (!this.ghosts) {
            this.ghosts = [];
            var utilities = SOGoEventDragUtilities();
            var nodes = utilities.getDayEventNodes();
            for (var i = 0; i < nodes.length; i++) {
                var newGhost = $(document.createElement("div"));
                Object.extend(newGhost, SOGoDragGhostInterface);
                newGhost.className = "event eventDragGhost";
                newGhost.hide();
                nodes[i].appendChild(newGhost);
                this.ghosts.push(newGhost);
            }
            var ghostHourPara = $(document.createElement("div"));
            ghostHourPara.setAttribute("id", "ghostStartHour");
            this.startHourPara = ghostHourPara;
            ghostHourPara = $(document.createElement("div"));
            ghostHourPara.setAttribute("id", "ghostEndHour");
            this.endHourPara = ghostHourPara;
            this._updateGhosts();
            this._updateGhostsParas();
        }
    },
    hideGhosts: function SEDGC_hideGhosts() {
        if (this.ghosts) {
            if (this.startHourPara.parentNode)
                this.startHourPara.parentNode.removeChild(this.startHourPara);
            this.startHourPara = null;
            if (this.endHourPara.parentNode)
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
        // logOnly("update");
        if (this.currentCoordinates.dayNumber < maxGhosts) {
            var currentDay = this.currentCoordinates.dayNumber;
            var durationLeft = this.currentCoordinates.duration;
            var start = this.currentCoordinates.start;
            var maxDuration = SOGoEventDragDayLength - start;
            var duration = durationLeft;
            if (duration > maxDuration)
                duration = maxDuration;

            var ghost;
            if (currentDay > -1) {
                ghost = this.ghosts[currentDay];
                ghost.setStartGhost();
                ghost.unsetEndGhost();
                ghost.setTitle(this.eventTitle);
                ghost.setFolderClass(this.folderClass);
                ghost.setStart(this.currentCoordinates.start);
                ghost.setDuration(duration);
                ghost.show();

                if (this.startHourPara.parentNode != ghost) {
                    if (this.startHourPara.parentNode)
                        this.startHourPara.parentNode
                            .removeChild(this.startHourPara);
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
            if (!durationLeft)
                ghost.setEndGhost();
            if (this.endHourPara.parentNode != ghost) {
                if (this.endHourPara.parentNode)
                    this.endHourPara.parentNode
                        .removeChild(this.endHourPara);
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
        while (para.childNodes.length) {
            para.removeChild(para.childNodes[0]);
        }
        var time = this.currentCoordinates.getStartTime();
        para.appendChild(document.createTextNode(time));

        para = this.endHourPara;
        while (para.childNodes.length) {
            para.removeChild(para.childNodes[0]);
        }
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

    initFromEvent: function SEDPH_initFromEvent(event) {
        this.currentCoordinates = new SOGoCoordinates();
        this.updateFromEvent(event);
        this.originalCoordinates = this.currentCoordinates.clone();

        var utilities = SOGoEventDragUtilities();
        this.containerCoordinates = utilities.getEventsViewNodeCumulativeCoordinates();
    },

    updateFromEvent: function SEDPH_updateFromEvent(event) {
        this.currentCoordinates.x = Event.pointerX(event);
        this.currentCoordinates.y = Event.pointerY(event);
    },

    getContainerBasedCoordinates: function SEDPH_getCBC() {
        return this.currentCoordinates.getDelta(this.containerCoordinates);
    },

    /* return the day and quarter coordinates of the pointer cursor within the
       day view */
    getEventViewCoordinates: function SEDPH_getEventViewCoordinates() {
        /* x = day; y = quarter */
        var coordinates = new SOGoCoordinates();

        var utilities = SOGoEventDragUtilities();
        var pxCoordinates = this.getContainerBasedCoordinates();

        var dayWidth = utilities.getDayWidth();
        var daysOffset = utilities.getDaysOffset();

        coordinates.x = Math.floor((pxCoordinates.x - daysOffset) / dayWidth);
        var maxX = utilities.getDayEventNodes().length - 1;
        if (coordinates.x < 0)
            coordinates.x = 0;
        else if (coordinates.x > maxX)
            coordinates.x = maxX;

        var quarterHeight = utilities.getQuarterHeight();
        var container = utilities.getEventsViewNode();
        pxCoordinates.y += container.scrollTop;
        coordinates.y = Math.floor((pxCoordinates.y
                                    - SOGoEventDragHorizontalOffset)
                                   / quarterHeight);
        var maxY = SOGoEventDragDayLength - 1;
        if (coordinates.y < 0)
            coordinates.y = 0;
        else if (coordinates.y > maxY)
            coordinates.y = maxY;

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
        this.scrollStep = 2 * utilities.getQuarterHeight();
    },

    setPointerHandler: function SSC_setPointerHandler(pointerHandler) {
        this.pointerHandler = pointerHandler;
    },

    updateFromPointerHandler: function SSC_updateFromPointerHandler() {
        var pointerCoordinates
            = this.pointerHandler.getContainerBasedCoordinates();
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
};

function SOGoEventDragController() {
}

SOGoEventDragController.prototype = {
    eventCells: null,

    title: null,
    folderClass: null,

    draggingModeAreas: null,

    ghostController: null,

    hasSelected: false,
    dragHasStarted: false,
    dragMode: null,
    originalDayNumber: -1,

    pointerHandler: null,

    dropCallback: null,

    stopEventDraggingBound: null,
    moveBound: null,

    attachToEventCells: function SEDC_attachToEventCells(eventCells) {
        this.eventCells = eventCells;

        this.ghostController = new SOGoEventDragGhostController();
        this._determineTitleAndFolderClass();
        this.ghostController.setTitle(this.title);
        this.ghostController.setFolderClass(this.folderClass);

        var startEventDraggingBound = this.startEventDragging.bindAsEventListener(this);
        for (var i = 0; i < eventCells.length; i++) {
            eventCells[i].observe("mousedown", startEventDraggingBound,
                                  false);
        }
    },

    attachToDayNode: function SEDC_attachToDayNode(dayNode) {
        this.ghostController = new SOGoEventDragGhostController();
        this.ghostController.setTitle(getLabel("New Event"));

        var startEventDraggingBound
            = this.startEventDragging.bindAsEventListener(this);
        dayNode.observe("mousedown", startEventDraggingBound, false);
    },

    startEventDragging: function SEDC_startEventDragging(event) {
        var target = getTarget(event);
        if (target.nodeType == 1) {
            if ((!this.eventCells && target.hasClassName("clickableHourCell"))
                || (this.eventCells && this.eventCells[0].editable)) {
                var utilities = SOGoEventDragUtilities();
                utilities.reset();

                this.pointerHandler = new SOGoEventDragPointerHandler();
                this.pointerHandler.initFromEvent(event);

                var coordinates = new SOGoEventDragEventCoordinates();
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
                    var folder = getSelectedFolder();
                    var folderID = folder.readAttribute("id").substr(1);
                    this.ghostController.setFolderClass("calendarFolder" + folderID);
                }
                this.ghostController.setDragMode(this._determineDragMode());
                this.ghostController.setPointerHandler(this.pointerHandler);

                this.scrollController = new SOGoScrollController();
                this.scrollController.setPointerHandler(this.pointerHandler);

                // if (!this.eventCell)
                //     this.originalStart = Math.floor(this.origY / this.quarterHeight);
                
                this.stopEventDraggingBound
                    = this.stopEventDragging.bindAsEventListener(this);
                if (Prototype.Browser.IE)
                    Event.observe(document.body,
                                  "mouseup", this.stopEventDraggingBound);
                else
                    Event.observe(window, "mouseup", this.stopEventDraggingBound);
                this.moveBound = this.move.bindAsEventListener(this);
                Event.observe(document.body, "mousemove", this.moveBound);
            }
            Event.stop(event);
        }

        return false;
    },
    _determineDragMode: function SEDC__determineDragMode() {
        var dragMode;

        if (this.eventCells) {
            var coordinates = this.pointerHandler.currentCoordinates.clone();
            var utilities = SOGoEventDragUtilities();
            var scrollView = utilities.getEventsViewNode();
            coordinates.y += scrollView.scrollTop;
            coordinates.y -= SOGoEventDragVerticalOffset;

            var firstCell = this.eventCells[0];
            var handleCoords = firstCell.cumulativeOffset();

            var dragMode = "move-event";
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

    _determineTitleAndFolderClass: function SEDC__dTAFC() {
        var title = "";
        var folderClass = "";
        if (this.eventCells) {
            var firstCell = this.eventCells[0];
            var divs = firstCell.childNodesWithTag("div");
            for (var i = 0; i < divs.length; i++) {
                var div = divs[i];
                if (div.hasClassName("eventInside")) {
                    title = this._determineTitleFromDIV(div);
                    folderClass = this._determineFolderClassFromDIV(div);
                }
            }
        }
        this.title = title;
        this.folderClass = folderClass;
    },
    _determineTitleFromDIV: function SEDC__determineTitleFromDIV(div) {
        var title = "";
        var insideDivs = div.childNodesWithTag("div");
        for (var i = 0; i < insideDivs.length; i++) {
            var insideDiv = insideDivs[i];
            if (insideDiv.hasClassName("text")) {
                var currentNode = insideDiv.firstChild;
                while (currentNode) {
                    title += currentNode.nodeValue;
                    currentNode = currentNode.nextSibling;
                }
                title = title.trim();
            }
        }

        return title;
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

    stopEventDragging: function SEDC_stopEventDragging(event) {
        if (Prototype.Browser.IE)
            Event.stopObserving(document.body, "mouseup", this.stopEventDraggingBound);
        else
            Event.stopObserving(window, "mouseup", this.stopEventDraggingBound);
        Event.stopObserving(document.body, "mousemove", this.moveBound);
        this.stopEventDraggingBound = null;
        this.moveBound = null;

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
                this.updateDropCallback(this, this.eventCells, delta);
            } else {
                var utilities = SOGoEventDragUtilities();
                var dayEventNodes = utilities.getDayEventNodes();
                var dayNode = dayEventNodes[this.ghostController
                                                .currentCoordinates
                                                .dayNumber]
                              .parentNode;
                this.createDropCallback(this,
                                        dayNode.readAttribute("day"),
                                        this.ghostController.currentCoordinates);
            }
        }

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

    move: function SEDC_move(event) {
        this.pointerHandler.updateFromEvent(event);
        this.scrollController.updateFromPointerHandler();

        if (this.dragHasStarted) {
            this.ghostController.updateFromPointerHandler();
        } else {
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
