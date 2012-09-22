/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*
 * Time picker widget interface to be added to an INPUT (this!)
 *
 * Available events:
 *   time:change -- fired once the value of the input has changed
 *
 */
var SOGoTimePickerInterface = {

    div: null,
    extendedButton: null,

    pos: 'bellow',
    
    minutes: '00',
    hours: '00',
    extended: false,

    mouseInside: false,
    disposeHandler: null,

    bind: function () {
        // Build widget
        this.div = new Element("div", {'class': 'SOGoTimePickerMenu ' + this.pos});
        this.div.hide();
        document.body.appendChild(this.div);
        var inner = new Element("div");
        this.div.appendChild(inner);

        var hours = new Element("div", {'class': 'hours'});
        inner.appendChild(hours);
        for (var i = 0; i < 24; i++) {
            var v = (i < 10)? '0' + i : i;
            var content = new Element("div", {'class': 'SOGoTimePickerHour_'+v}).update(v);
            content.on("click", this.onHourClick.bindAsEventListener(this));
            var span = new Element("span", {'class': 'cell'});
            span.appendChild(content);
            hours.appendChild(span);
            if (i == 11) {
                hours = new Element("div", {'class': 'hours'});
                inner.appendChild(hours);
            }
        }
        
        var minutes = new Element("div", {'class': 'minutes min5'});
        inner.appendChild(minutes);
        for (var i = 0; i < 60; i += 5) {
            var v = (i < 10)? '0' + i : i;
            var content = new Element("div", {'class': 'SOGoTimePickerMinute_'+v}).update(":"+v);
            content.on("click", this.onMinuteClick.bindAsEventListener(this));
            var span = new Element("span", {'class': 'cell'});
            span.appendChild(content);
            minutes.appendChild(span);
            if (i == 25) {
                minutes = new Element("div", {'class': 'minutes min5'});
                inner.appendChild(minutes);
            }
        }

        var minutes = new Element("div", {'class': 'minutes min1'});
        minutes.hide();
        inner.appendChild(minutes);
        for (var i = 0; i < 60;) {
            var v = (i < 10)? '0' + i : i;
            var content = new Element("div", {'class': 'SOGoTimePickerMinute_'+v}).update(":"+v);
            content.on("click", this.onMinuteClick.bindAsEventListener(this));
            var span = new Element("span", {'class': 'cell'});
            span.appendChild(content);
            minutes.appendChild(span);
            i++;
            if (i % 5 == 0) {
                minutes = new Element("div", {'class': 'minutes min1'});
                minutes.hide();
                inner.appendChild(minutes);
            }
        }

        var a = new Element("a", {'class': 'button'});
        a.on("click", this.toggleExtendedView.bindAsEventListener(this));
        this.extendedButton = new Element("span").update('&gt;&gt;');
        a.appendChild(this.extendedButton);
        inner.appendChild(a);

        inner.appendChild(new Element("hr"));
       
        // Compute position
        this.position();

        // Register observers
        this.on("click", this.toggleVisibility.bindAsEventListener(this));
        this.on("change", this.onChange.bindAsEventListener(this));
        this.on("keydown", this.onKeydown.bindAsEventListener(this));
        this.div.on("mouseenter", this.onEnter.bindAsEventListener(this));
        this.div.on("mouseleave",  this.onLeave.bindAsEventListener(this));
        this.disposeHandler = $(document.body).on("click", this.onDispose.bindAsEventListener(this));
        this.disposeHandler.stop();

        // Apply current input value if defined
        this.onChange();
    },

    setPosition: function (newPos) {
        if (newPos == 'bellow' || newPos == 'above') {
            this.div.removeClassName(this.pos);
            this.div.addClassName(newPos);
            this.pos = newPos;
            this.position();
        }
    },

    position: function () {
        var inputPosition = this.cumulativeOffset();
        var inputDimensions = this.getDimensions();
        var divWidth = this.div.getWidth();
        var windowWidth = window.width();
        var left = inputPosition[0];
        var arrow = -1000 + inputDimensions['width'] - 10;
        if (left + divWidth > windowWidth) {
            left = windowWidth - divWidth - 4;
            arrow += (inputPosition[0] - left);
        }
        var top = inputPosition[1];
        if (this.pos == 'bellow')
            top += 22;
        else
            top -= this.div.getHeight();
        this.div.setStyle({ top: top+"px",
                            left: left+"px",
                            backgroundPosition: arrow+'px top'});
    },

    onHourClick: function (event) {
        this.div.down('.SOGoTimePickerHour_' + this.hours).removeClassName("selected");
        this.hours = Event.findElement(event).className.substring(19);
        this.div.down('.SOGoTimePickerHour_' + this.hours).addClassName("selected");
        this._updateValue();
    },

    onMinuteClick: function (event) {
        this.div.select('.SOGoTimePickerMinute_' + this.minutes).each(function(e) { e.removeClassName("selected") });
        this.minutes = Event.findElement(event).className.substring(21);
        this.div.select('.SOGoTimePickerMinute_' + this.minutes).each(function(e) { e.addClassName("selected") });
        this._updateValue();
        this.div.hide();
    },

    toggleExtendedView: function (event) {
        this.extended = !this.extended;
        if (this.extended) {
            this.extendedButton.update('&lt;&lt;');
            this.div.select("DIV.min5").invoke('hide');
            this.div.select("DIV.min1").invoke('show');
        }
        else {
           this.extendedButton.update('&gt;&gt;');
            this.div.select("DIV.min1").invoke('hide');
            this.div.select("DIV.min5").invoke('show');
        }
        if (this.pos == 'above')
            this.position();
    },

    toggleVisibility: function (event) {
        if (this.div.visible())
            this.div.hide();
        else {
            $$('DIV.SOGoTimePickerMenu').invoke('hide');
            this.div.show();
            this.disposeHandler.start();
        }
        Event.stop(event);
    },

    onChange: function (event) {
        this.div.down('.SOGoTimePickerHour_' + this.hours).removeClassName("selected");
        this.div.select('.SOGoTimePickerMinute_' + this.minutes).each(function(e) { e.removeClassName("selected") });

        var matches = this.value.match(/([0-9]{1,2}):?([0-9]{2})/);
        if (matches) {
            this.hours = matches[1];
            this.minutes = matches[2] || '0';
            if (parseInt(this.hours, 10) > 23) this.hours = 23;
            if (parseInt(this.minutes, 10) > 59) this.minutes = 59;
            if (this.minutes % 5 == 0) {
                if (this.extended)
                    this.toggleExtendedView();
            }
            else if (!this.extended)
                this.toggleExtendedView();

            if (this.hours.length < 2) this.hours = '0' + this.hours;
            if (this.minutes.length < 2) this.minutes = '0' + this.minutes;
            this.div.down('.SOGoTimePickerHour_' + this.hours).addClassName("selected");
            this.div.select('.SOGoTimePickerMinute_' + this.minutes).each(function(e) { e.addClassName("selected") });
        }
         
        this._updateValue(true);
    },

    onKeydown: function (event) {
        this.div.hide();
        this.disposeHandler.stop();
        if (event.metaKey == 1 || event.ctrlKey == 1 ||
            event.keyCode == Event.KEY_TAB ||
            event.keyCode == Event.KEY_BACKSPACE)
            return true;
        if (event.keyCode > 57 && event.keyCode != 186 && event.keyCode != 59 ||
            (event.keyCode == 186 || event.keyCode == 59) && this.value.indexOf(":") >= 0)
            Event.stop(event);
    },

    onEnter: function (event) {
        this.mouseInside = true;
        this.disposeHandler.stop();
    },

    onLeave: function (event) {
        this.mouseInside = false;
        this.disposeHandler.start();
    },

    onDispose: function (event) {
        if (!this.mouseInside) {
            this.div.hide();
            this.disposeHandler.stop();
            Event.stop(event);
        }
    },

    _updateValue: function (force) {
        var value = this.hours + ':' + this.minutes;
        if (force || value != this.value) {
            this.value = value;
            this.fire("time:change");
        }
    }
};
