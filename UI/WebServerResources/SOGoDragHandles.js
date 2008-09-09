/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

var SOGoDragHandlesInterface = {
 leftMargin: 180,
 topMargin: 120,
 dhType: null,
 origX: -1,
 origLeft: -1,
 origRight: -1,
 origY: -1, 
 origUpper: -1,
 origLower: -1,
 delta: -1,
 leftBlock: null,
 rightBlock: null,
 upperBlock: null,
 lowerBlock: null,
 startHandleDraggingBound: null,
 stopHandleDraggingBound: null,
 moveBound: null,
 bind: function () {
    this.startHandleDraggingBound = this.startHandleDragging.bindAsEventListener(this);
    this.observe("mousedown", this.startHandleDraggingBound, false);
  },
 _determineType: function () {
    if (this.leftBlock && this.rightBlock)
      this.dhType = 'horizontal';
    else if (this.upperBlock && this.lowerBlock)
      this.dhType = 'vertical';
  },
 startHandleDragging: function (event) {
    if (!this.dhType)
      this._determineType();
    var targ = getTarget(event);
    if (targ.nodeType == 1) {
      if (this.dhType == 'horizontal') {
        this.origX = this.offsetLeft;
        this.origLeft = this.leftBlock.offsetWidth;
				delta = 0;
        this.origRight = this.rightBlock.offsetLeft - 5;
        document.body.setStyle({ cursor: "e-resize" });
      } else if (this.dhType == 'vertical') {
        this.origY = this.offsetTop;
        this.origUpper = this.upperBlock.offsetHeight;
				var pointY = Event.pointerY(event);
				if (pointY <= this.topMargin) delta = this.topMargin;
        else delta = pointY - this.offsetTop - 5;
        this.origLower = this.lowerBlock.offsetTop - 5;
        document.body.setStyle({ cursor: "n-resize" });
      }
      this.stopHandleDraggingBound = this.stopHandleDragging.bindAsEventListener(this);
      document.body.observe("mouseup", this.stopHandleDraggingBound, true);
      this.moveBound = this.move.bindAsEventListener(this);
      document.body.observe("mousemove", this.moveBound, true);
      this.move(event);
      event.cancelBubble = true;
    }

    return false;
  },
 stopHandleDragging: function (event) {
    if (!this.dhType)
      this._determineType();
    if (this.dhType == 'horizontal') {
      var pointerX = Event.pointerX(event);
      if (pointerX <= this.leftMargin) {
				this.rightBlock.setStyle({ left: (this.leftMargin) + 'px' });
				this.leftBlock.setStyle({ width: (this.leftMargin) + 'px' });
      }
      else {
				var deltaX = Math.floor(pointerX - this.origX - (this.offsetWidth / 2));
				this.rightBlock.setStyle({ left: (this.origRight + deltaX) + 'px' });
				this.leftBlock.setStyle({ width: (this.origLeft + deltaX) + 'px' });
      }
      this.saveDragHandleState(this.dhType, parseInt(this.leftBlock.getStyle("width")));
    }
    else if (this.dhType == 'vertical') {
			var pointerY = Event.pointerY(event);
			if (pointerY <= this.topMargin) {
				this.lowerBlock.setStyle({ top: (this.topMargin - delta) + 'px' });
				this.upperBlock.setStyle({ height: (this.topMargin - delta) + 'px' });
			}
			else {
				var deltaY = Math.floor(pointerY - this.origY - (this.offsetHeight / 2));
				this.lowerBlock.setStyle({ top: (this.origLower + deltaY - delta) + 'px' });
				this.upperBlock.setStyle({ height: (this.origUpper + deltaY - delta) + 'px' });
			}
			this.saveDragHandleState(this.dhType, parseInt(this.lowerBlock.getStyle("top")));
    }
    Event.stopObserving(document.body, "mouseup", this.stopHandleDraggingBound, true);
    Event.stopObserving(document.body, "mousemove", this.moveBound, true);
    
    document.body.setAttribute('style', '');
		document.body.setStyle({ cursor: "default" });

    Event.stop(event);
  },
 move: function (event) {
    if (!this.dhType)
      this._determineType();
    if (this.dhType == 'horizontal') {
      var hX =  Event.pointerX(event);
      var width = this.offsetWidth;
      if (hX < this.leftMargin)
				hX = this.leftMargin + Math.floor(width / 2);
      var newLeft = Math.floor(hX - (width / 2));
      this.setStyle({ left: newLeft + 'px' });
    } else if (this.dhType == 'vertical') {
      var height = this.offsetHeight;
      var hY = Event.pointerY(event);
      if (hY < this.topMargin)
				hY = this.topMargin + Math.floor(height / 2);
      var newTop = Math.floor(hY - (height / 2))  - delta;
      this.setStyle({ top: newTop + 'px' });
    }
    Event.stop(event);
  },
 doubleClick: function (event) {
    if (!this.dhType)
      this._determineType();
    if (this.dhType == 'horizontal') {
      var lLeft = this.leftBlock.offsetLeft;
    
      if (this.offsetLeft > lLeft) {
        var leftdelta = this.rightBlock.offsetLeft - this.offsetLeft;

        this.setStyle({ left: lLeft + 'px' });
        this.leftBlock.setStyle({ width: '0px' });
        this.rightBlock.setStyle({ left: (lLeft + leftdelta) + 'px' });
      }
    } else if (this.dhType == 'vertical') {
      var uTop = this.upperBlock.offsetTop;

      if (this.offsetTop > uTop) {
        var topdelta = this.lowerBlock.offsetTop - this.offsetTop;
      
        this.setStyle({ top: uTop + 'px' });
        this.upperBlock.setStyle({ width: '0px' });
        this.lowerBlock.setStyle({ top: (uTop + topdelta) + 'px' });
      }
    }
  },
 saveDragHandleState: function (type, position) {
		if (!$(document.body).hasClassName("popup")) {
			var urlstr =  ApplicationBaseURL + "saveDragHandleState"
			+ "?" + type + "=" + position;
			triggerAjaxRequest(urlstr, this.saveDragHandleStateCallback);
		}
  },
    
 saveDragHandleStateCallback: function (http) {
    if (isHttpStatus204(http.status)) {
      log ("drag handle state saved");
    }
    else if (http.readyState == 4) {
      log ("can't save handle state");
    }
  }
};
