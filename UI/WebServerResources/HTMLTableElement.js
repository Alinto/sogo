HTMLTableElement.prototype.getSelectedRows = function() {
  var tbody = (this.getElementsByTagName('tbody'))[0];

  return tbody.getSelectedNodes();
}

HTMLTableElement.prototype.getSelectedRowsId = function() {
  var tbody = (this.getElementsByTagName('tbody'))[0];

  return tbody.getSelectedNodesId();
}

HTMLTableElement.prototype.selectRowsMatchingClass = function(className) {
  var tbody = (this.getElementsByTagName('tbody'))[0];
  var nodes = tbody.childNodes;
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes.item(i);
    if (node instanceof HTMLElement) {
      var classStr = '' + node.getAttribute("class");
      if (classStr.indexOf(className, 0) >= 0)
        selectNode(node);
    }
  }
}

HTMLTableElement.prototype.deselectAll = function() {
  var nodes = this.getSelectedRows();
  for (var i = 0; i < nodes.length; i++)
    deselectNode(nodes[i]);
}

/* "draggesture" seems inhibited on Mozilla so we create a work-around */
HTMLTableElement.prototype.workAroundDragGesture = function() {
  this._dragGestureStartPoint = null;
  this.addEventListener("mousedown", this._dragGestureMouseDownHandler, false);
}

HTMLTableElement.prototype._dragGestureMouseDownHandler = function(event) {
  this.addEventListener("mousemove", this._dragGestureMouseMoveHandler, false);
  this.addEventListener("mouseup", this._dragGestureMouseUpHandler, false);
  this._dragGestureStartPoint = new Array(event.clientX, event.clientY);
  this._dragGestureTarget = event.target;
}

HTMLTableElement.prototype._dragGestureMouseUpHandler = function(event) {
  this.removeEventListener("mousemove", this._dragGestureMouseMoveHandler, false);
  this.removeEventListener("mouseup", this._dragGestureMouseUpHandler, false);
  this._dragGestureStartPoint = null;
}

HTMLTableElement.prototype._dragGestureMouseMoveHandler = function(event) {
  var deltaX = event.clientX - this._dragGestureStartPoint[0];
  var deltaY = event.clientX - this._dragGestureStartPoint[0];
  if (Math.sqrt((deltaX * deltaX) + (deltaY * deltaY)) > 10) {
    this.removeEventListener("mousemove", this._dragGestureMouseMoveHandler, false);
    this.removeEventListener("mousedown", this._dragGestureMouseUpHandler, false);
    this._dragGestureStartPoint = null;
    var dragStart = document.createEvent("MouseEvents");
    dragStart.initMouseEvent("draggesture-hack", true, true, window,
                             event.detail, event.screenX, event.screenY,
                             event.clientX, event.clientY, event.ctrlKey,
                             event.altKey, event.shiftKey, event.metaKey,
                             event.button, null);
    this.dispatchEvent(dragStart);
    window.addEventListener("mouseup", document.DNDManager.destinationDrop, false);
    window.addEventListener("mouseover", document.DNDManager.destinationEnter, false);
    window.addEventListener("mousemove", document.DNDManager.destinationOver, false);
    window.addEventListener("mouseout", document.DNDManager.destinationExit, false);
    event.returnValue = false;
  }
}
