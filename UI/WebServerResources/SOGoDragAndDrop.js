/* drag and drop */

/* HTMLElement interface */
var SOGODragAndDropSourceInterface = {
  _removeGestureHandlers: function () {
    window.removeEventListener("mousemove", this.dragGestureMouseMoveHandler, false);
    window.removeEventListener("mouseup", this.dragGestureMouseUpHandler, false);
    document._dragGestureStartPoint = null;
    document._currentMouseGestureObject = null;
  },
  bind: function() {
    this.addEventListener("mousedown", this.dragGestureMouseDownHandler, false);
  },
  dragGestureMouseDownHandler: function (event) {
    if (event.button == 0) {
      document._dragGestureStartPoint = new Array(event.clientX,
                                                  event.clientY);
      document._currentMouseGestureObject = this;
      window.addEventListener("mousemove", this.dragGestureMouseMoveHandler,
                              false);
      window.addEventListener("mouseup", this.dragGestureMouseUpHandler,
                              false);
    }
  },
  dragGestureMouseUpHandler: function (event) {
    document._currentMouseGestureObject._removeGestureHandlers();
  },
  dragGestureMouseMoveHandler: function (event) {
    var deltaX = event.clientX - document._dragGestureStartPoint[0];
    var deltaY = event.clientY - document._dragGestureStartPoint[1];
    if (Math.sqrt((deltaX * deltaX) + (deltaY * deltaY)) > 10) {
      event.returnValue = true;
      event.cancelBubble = true;
      var object = document._currentMouseGestureObject;
      var point = document._dragGestureStartPoint;
      document.DNDManager.startDragging(object, point);
      document._currentMouseGestureObject._removeGestureHandlers();
    }
  }
}

/* DNDManager */
document.DNDManager = {
  lastSource: 0,
  lastDestination: 0,
  sources: new Array(),
  destinations: new Array(),
  registerSource: function (source) {
    var id = source.getAttribute("id");
    if (!id) {
      id = "_dndSource" + (this.lastSource + 1);
      source.setAttribute("id", id);
    }
    this.sources[id] = source;
    this.lastSource++;
    source.addInterface(SOGODragAndDropSourceInterface);
  },
  registerDestination: function (destination) {
    var id = destination.getAttribute("id");
    if (!id) {
      id = "_dndDestination" + (this.lastDestination + 1);
      destination.setAttribute("id", id);
    }
    this.destinations[id] = destination;
    this.lastDestination++;
  },
  _lookupSource: function (target) {
    var source = null;
    var id = target.getAttribute("id");
    if (id)
      source = document.DNDManager.sources[id];
    return source;
  },
  _lookupDestination: function (target) {
    var destination = null;
    var id = target.getAttribute("id");
    if (id)
      destination = document.DNDManager.destinations[id];
    return destination;
  },
  startDragging: function (object, point) {
    var source = document.DNDManager._lookupSource (object);
    if (source) {
      document.DNDManager.currentDndOperation = new document.DNDOperation(source, point);
      window.addEventListener("mouseup",
                              document.DNDManager.destinationDrop, false);
      window.addEventListener("mouseover",
                              document.DNDManager.destinationEnter, false);
      window.addEventListener("mousemove",
                              document.DNDManager.destinationOver, false);
      window.addEventListener("mouseout",
                              document.DNDManager.destinationExit, false);
    }
  },
  destinationEnter: function (event) {
    var operation = document.DNDManager.currentDndOperation;
    var destination = document.DNDManager._lookupDestination (event.target);
    if (operation && destination && destination.dndAcceptType) {
      operation.type = null;
      var i = 0;
      while (operation.type == null
             && i < operation.types.length) {
        if (destination.dndAcceptType(operation.types[i])) {
          operation.type = operation.types[i];
          operation.setDestination(destination);
          if (destination.dndEnter)
            destination.dndEnter(event, operation.source, operation.type);
        }
        else
          i++;
      }
    }
  },
  destinationExit: function (event) {
    var operation = document.DNDManager.currentDndOperation;
    if (operation
        && operation.destination == event.target) {
      if (operation.destination.dndExit)
        event.target.dndExit();
      operation.setDestination(null);
    }
  },
  destinationOver: function (event) {
  },
  destinationDrop: function (event) {
    var operation = document.DNDManager.currentDndOperation;
    if (operation) {
      window.removeEventListener("mouseup",
                                 document.DNDManager.destinationDrop, false);
      window.removeEventListener("mouseover",
                                 document.DNDManager.destinationEnter, false);
      window.removeEventListener("mousemove",
                                 document.DNDManager.destinationOver, false);
      window.removeEventListener("mouseout",
                                 document.DNDManager.destinationExit, false);
      if (operation.destination == event.target) {
        if (operation.destination.dndExit) {
          operation.destination.dndExit();
        }
        if (operation.destination.dndDrop) {
          var data = null;
          if (operation.source.dndDataForType)
            data = operation.source.dndDataForType(operation.type);
          var result = operation.destination.dndDrop(data);
          if (operation.ghost) {
            if (result)
              operation.bustGhost();
            else
              operation.chaseGhost();
          }
        }
        else
          if (operation.ghost)
            operation.chaseGhost();
      } else {
        if (operation.ghost)
          operation.chaseGhost();
      }
      document.DNDManager.currentDndOperation = null;
    }
  },
  currentDndOperation: null
}

/* DNDOperation */
document.DNDOperation = function (source, point) {
  this.startPoint = point;
  this.source = source;
  if (source.dndTypes) {
    this.types = source.dndTypes();
  }
  this.type = null;
  this.destination = null;
  if (source.dndGhost) {
    var ghost = source.dndGhost();
    ghost.style.position = "absolute;";
    ghost.style.zIndex = 10000;
    ghost.style.MozOpacity = 0.8;
    document.body.appendChild(ghost);
    this.ghost = ghost;

    document.addEventListener("mousemove", this.moveGhost, false);
  }

  return this;
};

document.DNDOperation.prototype.setDestination = function(destination) {
  this.destination = destination;
}

document.DNDOperation.prototype.moveGhost = function(event) {
  var offsetX = event.clientX;
  var offsetY = event.clientY;
  if (document.DNDManager.currentDndOperation.ghost.ghostOffsetX)
    offsetX += document.DNDManager.currentDndOperation.ghost.ghostOffsetX;
  if (document.DNDManager.currentDndOperation.ghost.ghostOffsetY)
    offsetY += document.DNDManager.currentDndOperation.ghost.ghostOffsetY;

  document.DNDManager.currentDndOperation.ghost.style.left = offsetX + "px;";
  document.DNDManager.currentDndOperation.ghost.style.top = offsetY + "px;";
}

document.DNDOperation.prototype.bustGhost = function() {
  document._dyingOperation = this;
  document.removeEventListener("mousemove", this.moveGhost, false);
  this.ghost.bustStep = 10;
  setTimeout("document._dyingOperation._fadeGhost();", 50);
}

document.DNDOperation.prototype.chaseGhost = function() {
  document._dyingOperation = this;
  document.removeEventListener("mousemove", this.moveGhost, false);
  this.ghost.bustStep = 25;
  this.ghost.chaseStep = 25;
  this.ghost.style.overflow = "hidden;"
  this.ghost.style.whiteSpace = "nowrap;";
  this.ghost.chaseDeltaX = ((this.ghost.cascadeLeftOffset() - this.startPoint[0])
                           / this.ghost.chaseStep);
  this.ghost.chaseDeltaY = ((this.ghost.cascadeTopOffset() - this.startPoint[1])
                           / this.ghost.chaseStep);
  setTimeout("document._dyingOperation._chaseGhost();", 20);
}

document.DNDOperation.prototype._chaseGhost = function() {
  if (this.ghost.chaseStep) {
    var newLeft = this.ghost.cascadeLeftOffset() - this.ghost.chaseDeltaX; 
    var newTop = this.ghost.cascadeTopOffset() - this.ghost.chaseDeltaY;
    this.ghost.style.MozOpacity = (0.04 * this.ghost.chaseStep);
    this.ghost.style.left = newLeft + "px;";
    this.ghost.style.top = newTop + "px;";
    this.ghost.chaseStep--;
    setTimeout("document._dyingOperation._chaseGhost();", 20);
  }
  else {
    document.body.removeChild(this.ghost);
    this.ghost = null;
  }
}

document.DNDOperation.prototype._fadeGhost = function() {
  if (this.ghost.bustStep) {
    this.ghost.style.MozOpacity = (0.1 * this.ghost.bustStep);
    this.ghost.style.width = (this.ghost.offsetWidth * .7) + "px;";
    this.ghost.style.height = (this.ghost.offsetHeight * .7) + "px;";
    this.ghost.bustStep--;
    setTimeout("document._dyingOperation._fadeGhost();", 50);
  }
  else {
    document.body.removeChild(this.ghost);
    this.ghost = null;
  }
}
