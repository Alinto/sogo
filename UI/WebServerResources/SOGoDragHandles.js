var SOGoDragHandlesInterface = {
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
  bind: function () {
    this.addEventListener("mousedown", this.startHandleDragging, false);
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
    if (event.button == 0) {
      if (this.dhType == 'horizontal') {
        this.origX = this.offsetLeft;
        this.origLeft = this.leftBlock.offsetWidth;
        delta = 0;
        this.origRight = this.rightBlock.offsetLeft - 5;
        document.body.style.cursor = "e-resize";
      } else if (this.dhType == 'vertical') {
        this.origY = this.offsetTop;
        this.origUpper = this.upperBlock.offsetHeight;
        delta = event.clientY - this.offsetTop - 5;
        this.origLower = this.lowerBlock.offsetTop - 5;
        document.body.style.cursor = "n-resize";
      }
      document._currentDragHandle = this;
      document.addEventListener("mouseup", this.documentStopHandleDragging, true);
      document.addEventListener("mousemove", this.documentMove, true);
      this.move(event);
      event.cancelBubble = true;
    }

    return false;
  },
  documentStopHandleDragging: function (event) {
    var handle = document._currentDragHandle;
    return handle.stopHandleDragging(event);
  },
  documentMove: function (event) {
    var handle = document._currentDragHandle;
    return handle.move(event);
  },
  stopHandleDragging: function (event) {
    if (!this.dhType)
      this._determineType();
    if (this.dhType == 'horizontal') {
      var deltaX
        = Math.floor(event.clientX - this.origX - (this.offsetWidth / 2));
      this.rightBlock.style.left = (this.origRight + deltaX) + 'px;';
      this.leftBlock.style.width = (this.origLeft + deltaX) + 'px;';
    } else if (this.dhType == 'vertical') {
      var deltaY
        = Math.floor(event.clientY - this.origY - (this.offsetHeight / 2));
      this.lowerBlock.style.top = (this.origLower + deltaY - delta) + 'px;';
      this.upperBlock.style.height = (this.origUpper + deltaY - delta) + 'px;';
    }
 
    document.removeEventListener("mouseup", this.documentStopHandleDragging, true);
    document.removeEventListener("mousemove", this.documentMove, true);
    document.body.setAttribute('style', '');

    this.move(event);
    document._currentDragHandle = null;
    event.cancelBubble = true;

    return false;
  },
  move: function (event) {
    if (!this.dhType)
      this._determineType();
    if (this.dhType == 'horizontal') {
      var width = this.offsetWidth;
      var hX = event.clientX;
      if (hX > -1) {
        var newLeft = Math.floor(hX - (width / 2));
        this.style.left = newLeft + 'px;';
        event.cancelBubble = true;
      
        return false;
      }
    } else if (this.dhType == 'vertical') {
      var height = this.offsetHeight;
      var hY = event.clientY;
      if (hY > -1) {
        var newTop = Math.floor(hY - (height / 2))  - delta;
        this.style.top = newTop + 'px;';
        event.cancelBubble = true;

        return false;
      }
    }
  },
  doubleClick: function (event) {
    if (!this.dhType)
      this._determineType();
    if (this.dhType == 'horizontal') {
      var lLeft = this.leftBlock.offsetLeft;
    
      if (this.offsetLeft > lLeft) {
        var leftdelta = this.rightBlock.offsetLeft - this.offsetLeft;

        this.style.left = lLeft + 'px;';
        this.leftBlock.style.width = '0px';
        this.rightBlock.style.left = (lLeft + leftdelta) + 'px;';
      }
    } else if (this.dhType == 'vertical') {
      var uTop = this.upperBlock.offsetTop;

      if (this.offsetTop > uTop) {
        var topdelta = this.lowerBlock.offsetTop - this.offsetTop;
      
        this.style.top = uTop + 'px;';
        this.upperBlock.style.width = '0px';
        this.lowerBlock.style.top = (uTop + topdelta) + 'px;';
      }
    }
  }

};

