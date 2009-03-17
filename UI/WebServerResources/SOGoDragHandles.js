/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

var SOGoDragHandlesInterface = {
 leftMargin: 180,
 topMargin: 140,
 dhType: null,
 dhLimit: -1,
 origX: -1,
 origLeft: -1,
 origRight: -1,
 origY: -1, 
 origUpper: -1,
 origLower: -1,
 delta: -1,
 btn: null,
 leftBlock: null,
 rightBlock: null,
 upperBlock: null,
 lowerBlock: null,
 startHandleDraggingBound: null,
 stopHandleDraggingBound: null,
 moveBound: null,
 delayedSave: null,
 bind: function () {
    this.startHandleDraggingBound = this.startHandleDragging.bindAsEventListener(this);
    this.observe("mousedown", this.startHandleDraggingBound, false);
  },
 adjust: function () {
    if (!this.dhType)
      this._determineType();
		if (this.dhType == 'horizontal') {
			this.dhLimit = window.width() - 20;
			if (parseInt(this.getStyle("left")) > this.dhLimit) {
				this.setStyle({ left: this.dhLimit + "px" });
				this.rightBlock.setStyle({ left: (this.dhLimit) + 'px' });
				this.leftBlock.setStyle({ width: (this.dhLimit) + 'px' });
				if (this.delayedSave) window.clearTimeout(this.delayedSave);
				this.delayedSave = this.saveDragHandleState.delay(3, this.dhType, this.dhLimit, this.saveDragHandleStateCallback);
			}
		}
		else if (this.dhType == 'vertical') {
			this.dhLimit = window.height() - 20 - this.upperBlock.cumulativeOffset()[1] + this.upperBlock.offsetTop;
			if (parseInt(this.getStyle("top")) > this.dhLimit) {
				this.setStyle({ top: this.dhLimit + 'px' });
				this.lowerBlock.setStyle({ top: this.dhLimit + 'px' });
				this.upperBlock.setStyle({ height: (this.dhLimit - this.upperBlock.offsetTop) + 'px' });
				if (this.delayedSave) window.clearTimeout(this.delayedSave);
				this.delayedSave = this.saveDragHandleState.delay(3, this.dhType, this.dhLimit, this.saveDragHandleStateCallback);
			}
		}
	},
 _determineType: function () {
    if (this.leftBlock && this.rightBlock)
      this.dhType = 'horizontal';
    else if (this.upperBlock && this.lowerBlock)
      this.dhType = 'vertical';
  },
 startHandleDragging: function (event) {
		this.btn = event.button;
    if (!this.dhType)
      this._determineType();
    var targ = getTarget(event);
    if (targ.nodeType == 1) {
      if (this.dhType == 'horizontal') {
				this.dhLimit = window.width() - 20;
        this.origX = this.offsetLeft;
        this.origLeft = this.leftBlock.offsetWidth;
				this.delta = 0;
        this.origRight = this.rightBlock.offsetLeft - 5;
        document.body.setStyle({ cursor: "e-resize" });
      } else if (this.dhType == 'vertical') {
				this.dhLimit = window.height() - 20;
        this.origY = this.offsetTop;
        this.origUpper = this.upperBlock.offsetHeight;
				var pointY = Event.pointerY(event);
				this.delta = pointY - this.offsetTop - 5;
        this.origLower = this.lowerBlock.offsetTop - 5;
				document.body.setStyle({ cursor: "n-resize" });
      }
      this.stopHandleDraggingBound = this.stopHandleDragging.bindAsEventListener(this);
			if (Prototype.Browser.IE)
				Event.observe(document.body, "mouseup", this.stopHandleDraggingBound);
			else
				Event.observe(window, "mouseup", this.stopHandleDraggingBound);
			this.moveBound = this.move.bindAsEventListener(this);
      Event.observe(document.body, "mousemove", this.moveBound);
      this.move(event);
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
			else if (pointerX >= this.dhLimit) {
				this.rightBlock.setStyle({ left: (this.dhLimit) + 'px' });
				this.leftBlock.setStyle({ width: (this.dhLimit) + 'px' });
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
			var deltaY;
			if (pointerY <= this.topMargin)
				deltaY = Math.floor(this.topMargin - this.origY - (this.offsetHeight / 2));
			else if (pointerY >= this.dhLimit)
				deltaY = Math.floor(this.dhLimit - this.origY - (this.offsetHeight / 2));
			else
				deltaY = Math.floor(pointerY - this.origY - (this.offsetHeight / 2));
			this.lowerBlock.setStyle({ top: (this.origLower + deltaY - this.delta) + 'px' });
			this.upperBlock.setStyle({ height: (this.origUpper + deltaY - this.delta) + 'px' });
			
			this.saveDragHandleState(this.dhType, parseInt(this.lowerBlock.getStyle("top")));
    }
		if (Prototype.Browser.IE)		
			Event.stopObserving(document.body, "mouseup", this.stopHandleDraggingBound);
    else
			Event.stopObserving(window, "mouseup", this.stopHandleDraggingBound);
		Event.stopObserving(document.body, "mousemove", this.moveBound);
    
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
			else if (hX > this.dhLimit)
				hX = this.dhLimit + Math.floor(width / 2);
			var newLeft = Math.floor(hX - (width / 2));
      this.setStyle({ left: newLeft + 'px' });
    } else if (this.dhType == 'vertical') {
      var hY = Event.pointerY(event);
      var height = this.offsetHeight;
      if (hY < this.topMargin)
				hY = this.topMargin;
			else if (hY > this.dhLimit)
				hY = this.dhLimit;

      var newTop = Math.floor(hY - (height / 2)) - this.delta;
      this.setStyle({ top: newTop + 'px' });
    }
    Event.stop(event);
		if (Prototype.Browser.IE && event.button != this.btn)
			this.stopHandleDragging(event);
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
 saveDragHandleState: function (type, position, fcn) {
		if (!$(document.body).hasClassName("popup")) {
			var urlstr =  ApplicationBaseURL + "saveDragHandleState"
			+ "?" + type + "=" + position;
			var callbackFunction = fcn || this.saveDragHandleStateCallback;
			triggerAjaxRequest(urlstr, callbackFunction);
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
