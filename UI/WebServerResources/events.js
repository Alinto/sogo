// written by Dean Edwards, 2005
// with input from Tino Zijdel, Matthias Miller, Diego Perini
// http://dean.edwards.name/weblog/2005/10/add-event/
function addEvent(element, type, handler) {
	// Modification by Tanny O'Haley, http://tanny.ica.com to add the
	// DOMContentLoaded for all browsers.
	if (type == "DOMContentLoaded" || type == "domload") {
		addDOMLoadEvent(handler);
		return;
	}
	
	if (element.addEventListener) {
		element.addEventListener(type, handler, false);
	} else {
		// assign each event handler a unique ID
		if (!handler.$$guid) handler.$$guid = addEvent.guid++;
		// create a hash table of event types for the element
		if (!element.events) element.events = {};
		// create a hash table of event handlers for each element/event pair
		var handlers = element.events[type];
		if (!handlers) {
			handlers = element.events[type] = {};
			// store the existing event handler (if there is one)
			if (element["on" + type]) {
				handlers[0] = element["on" + type];
			}
		}
		// store the event handler in the hash table
		handlers[handler.$$guid] = handler;
		// assign a global event handler to do all the work
		element["on" + type] = handleEvent;
	}
};
// a counter used to create unique IDs
addEvent.guid = 1;

function removeEvent(element, type, handler) {
	if (element.removeEventListener) {
		element.removeEventListener(type, handler, false);
	} else {
		// delete the event handler from the hash table
		if (element.events && element.events[type]) {
			delete element.events[type][handler.$$guid];
		}
	}
};

function handleEvent(event) {
	var returnValue = true;
	// grab the event object (IE uses a global event object)
	event = event || fixEvent(((this.ownerDocument || this.document || this).parentWindow || window).event);
	// get a reference to the hash table of event handlers
	var handlers = this.events[event.type];
	// execute each event handler
	for (var i in handlers) {
		this.$$handleEvent = handlers[i];
		if (this.$$handleEvent(event) === false) {
			returnValue = false;
		}
	}
	return returnValue;
};

function fixEvent(event) {
	// add W3C standard event methods
	event.preventDefault = fixEvent.preventDefault;
	event.stopPropagation = fixEvent.stopPropagation;
	return event;
};
fixEvent.preventDefault = function() {
	this.returnValue = false;
};
fixEvent.stopPropagation = function() {
	this.cancelBubble = true;
};

// End Dean Edwards addEvent.

// Tino Zijdel - crisp@xs4all.nl This little snippet fixes the problem that the onload attribute on 
// the body-element will overwrite previous attached events on the window object for the onload event.
if (!window.addEventListener) {
	document.onreadystatechange = function(){
		if (window.onload && window.onload != handleEvent) {
			addEvent(window, 'load', window.onload);
			window.onload = handleEvent;
		}
	}
}

// Here are my functions for adding the DOMContentLoaded event to browsers other
// than Mozilla.

// Array of DOMContentLoaded event handlers.
window.onDOMLoadEvents = new Array();
window.DOMContentLoadedInitDone = false;

// Function that adds DOMContentLoaded listeners to the array.
function addDOMLoadEvent(listener) {
	window.onDOMLoadEvents[window.onDOMLoadEvents.length]=listener;
}

// Function to process the DOMContentLoaded events array.
function DOMContentLoadedInit() {
	// quit if this function has already been called
	if (window.DOMContentLoadedInitDone) return;

	// flag this function so we don't do the same thing twice
	window.DOMContentLoadedInitDone = true;

	// iterates through array of registered functions 
	for (var i=0; i<window.onDOMLoadEvents.length; i++) {
		var func = window.onDOMLoadEvents[i];
		func();
	}
}

function DOMContentLoadedScheduler() {
	// quit if the init function has already been called
	if (window.DOMContentLoadedInitDone) return true;
	
	// First, check for Safari or KHTML.
	// Second, check for IE.
	//if DOM methods are supported, and the body element exists
	//(using a double-check including document.body, for the benefit of older moz builds [eg ns7.1] 
	//in which getElementsByTagName('body')[0] is undefined, unless this script is in the body section)
	if(/KHTML|WebKit/i.test(navigator.userAgent)) {
		if(/loaded|complete/.test(document.readyState)) {
			DOMContentLoadedInit();
		} else {
			// Not ready yet, wait a little more.
			setTimeout("DOMContentLoadedScheduler()", 250);
		}
	} else if(document.getElementById("__ie_onload")) {
		return true;
	} else if(typeof document.getElementsByTagName != 'undefined' && (document.getElementsByTagName('body')[0] != null || document.body != null)) {
		DOMContentLoadedInit();
	} else {
		// Not ready yet, wait a little more.
		setTimeout("DOMContentLoadedScheduler()", 250);
	}
	
	return true;
}

// Schedule to run the init function.
setTimeout("DOMContentLoadedScheduler()", 250);

// Just in case window.onload happens first, add it there too.
addEvent(window, "load", DOMContentLoadedInit);

// If addEventListener supports the DOMContentLoaded event.
if(document.addEventListener)
	document.addEventListener("DOMContentLoaded", DOMContentLoadedInit, false);

/* for Internet Explorer */
/*@cc_on @*/
/*@if (@_win32)
	document.write("<script id=__ie_onload defer src=\"//:\"><\/script>");
	var script = document.getElementById("__ie_onload");
	script.onreadystatechange = function() {
		if (this.readyState == "complete") {
			DOMContentLoadedInit(); // call the onload handler
		}
	};
/*@end @*/
