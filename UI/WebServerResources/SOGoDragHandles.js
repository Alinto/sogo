/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*
 * Drag handle widget interface to be added to a DIV (the drag handle)
 *
 * Available events:
 *   handle:dragged -- fired once the handle has been dropped
 *
 */
var SOGoDragHandlesInterface = {
    leftMargin: 180,
    topMargin: 180,
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
    rightSafetyBlock: null,
    startHandleDraggingBound: null,
    stopHandleDraggingBound: null,
    moveBound: null,
    delayedSave: null,
    bind: function () {
        this.startHandleDraggingBound = this.startHandleDragging.bindAsEventListener(this);
        this.observe("mousedown", this.startHandleDraggingBound, false);
    },
    enableRightSafety: function () {
        this.rightSafetyBlock = new Element('div', {'class': 'safetyBlock'});
        this.rightSafetyBlock.hide();
        document.body.appendChild(this.rightSafetyBlock);
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
            var windowHeight = window.height();
            this.dhLimit = windowHeight - 20 - this.upperBlock.cumulativeOffset().top + this.upperBlock.offsetTop;
            if (parseInt(this.getStyle("top")) > this.dhLimit &&
                windowHeight > this.topMargin) {
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
                if (this.rightSafetyBlock) {
                    this.rightSafetyBlock.setStyle({
                                top: this.rightBlock.getStyle('top'),
                                left: this.rightBlock.getStyle('left') });
                    this.rightSafetyBlock.show();
                }
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
            if (this.rightSafetyBlock)
                this.rightSafetyBlock.hide();
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
        this.fire("handle:dragged");

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
            log ("Drag handle state saved");
        }
        else if (http.readyState == 4) {
            log ("Can't save handle state");
        }
    }
};
