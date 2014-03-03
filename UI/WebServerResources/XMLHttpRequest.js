// XMLHttpRequest.js Copyright (C) 2008 Sergey Ilinsky (http://www.ilinsky.com)
//
// This work is free software; you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation; either version 2.1 of the License, or
// (at your option) any later version.

// This work is distributed in the hope that it will be useful,
// but without any warranty; without even the implied warranty of
// merchantability or fitness for a particular purpose. See the
// GNU Lesser General Public License for more details.

// You should have received a copy of the GNU Lesser General Public License
// along with this library; if not, write to the Free Software Foundation, Inc.,
// 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

(function () {

	// Save reference to earlier defined object implementation (if any)
	var oXMLHttpRequest	= window.XMLHttpRequest;

	// Define on browser type
	var bGecko	= !!window.controllers,
		bIE		= window.document.all && !window.opera;

	// Constructor
	function cXMLHttpRequest() {
		this._object	= oXMLHttpRequest ? new oXMLHttpRequest : new window.ActiveXObject("Microsoft.XMLHTTP");
		this._listeners	= [];
	};

	// BUGFIX: Firefox with Firebug installed would break pages if not executed
	if (bGecko && oXMLHttpRequest.wrapped)
		cXMLHttpRequest.wrapped	= oXMLHttpRequest.wrapped;

	// Constants
	cXMLHttpRequest.UNSENT				= 0;
	cXMLHttpRequest.OPENED				= 1;
	cXMLHttpRequest.HEADERS_RECEIVED	= 2;
	cXMLHttpRequest.LOADING				= 3;
	cXMLHttpRequest.DONE				= 4;

	// Public Properties
	cXMLHttpRequest.prototype.readyState	= cXMLHttpRequest.UNSENT;
	cXMLHttpRequest.prototype.responseText	= '';
	cXMLHttpRequest.prototype.responseXML	= null;
	cXMLHttpRequest.prototype.status		= 0;
	cXMLHttpRequest.prototype.statusText	= '';

	// Instance-level Events Handlers
	cXMLHttpRequest.prototype.onreadystatechange	= null;

	// Class-level Events Handlers
	cXMLHttpRequest.onreadystatechange	= null;
	cXMLHttpRequest.onopen				= null;
	cXMLHttpRequest.onsend				= null;
	cXMLHttpRequest.onabort				= null;

	// Public Methods
	cXMLHttpRequest.prototype.open	= function(sMethod, sUrl, bAsync, sUser, sPassword) {

		// When bAsync parameter value is ommited, use true as default
		if (arguments.length < 3)
			bAsync	= true;

		// Save async parameter for fixing Gecko bug with missing readystatechange in synchronous requests
		this._async		= bAsync;

		// Set the onreadystatechange handler
		var oRequest	= this,
			nState		= this.readyState,
			fOnUnload;

		// BUGFIX: IE - memory leak on page unload (inter-page leak)
		if (bIE && bAsync) {
			fOnUnload = function() {
				if (oRequest._object.readyState != cXMLHttpRequest.DONE) {
					fCleanTransport(oRequest);
					// Safe to abort here since onreadystatechange handler removed
					oRequest.abort();
				}
			};
			window.attachEvent("onunload", fOnUnload);
		}

		this._object.onreadystatechange	= function() {
			if (bGecko && !bAsync)
				return;

			// Synchronize state
			oRequest.readyState		= oRequest._object.readyState;

			//
			fSynchronizeValues(oRequest);

			// BUGFIX: Firefox fires unneccesary DONE when aborting
			if (oRequest._aborted) {
				// Reset readyState to UNSENT
				oRequest.readyState	= cXMLHttpRequest.UNSENT;

				// Return now
				return;
			}

			if (oRequest.readyState == cXMLHttpRequest.DONE) {
				//
				fCleanTransport(oRequest);
// Uncomment this block if you need a fix for IE cache
/*
				// BUGFIX: IE - cache issue
				if (!oRequest._object.getResponseHeader("Date")) {
					// Save object to cache
					oRequest._cached	= oRequest._object;

					// Instantiate a new transport object
					cXMLHttpRequest.call(oRequest);

					// Re-send request
					oRequest._object.open(sMethod, sUrl, bAsync, sUser, sPassword);
					oRequest._object.setRequestHeader("If-Modified-Since", oRequest._cached.getResponseHeader("Last-Modified") || new window.Date(0));
					// Copy headers set
					if (oRequest._headers)
						for (var sHeader in oRequest._headers)
							if (typeof oRequest._headers[sHeader] == "string")	// Some frameworks prototype objects with functions
								oRequest._object.setRequestHeader(sHeader, oRequest._headers[sHeader]);

					oRequest._object.onreadystatechange	= function() {
						// Synchronize state
						oRequest.readyState		= oRequest._object.readyState;

						if (oRequest._aborted) {
							//
							oRequest.readyState	= cXMLHttpRequest.UNSENT;

							// Return
							return;
						}

						if (oRequest.readyState == cXMLHttpRequest.DONE) {
							// Clean Object
							fCleanTransport(oRequest);

							// get cached request
							if (oRequest.status == 304)
								oRequest._object	= oRequest._cached;

							//
							delete oRequest._cached;

							//
							fSynchronizeValues(oRequest);

							//
							fReadyStateChange(oRequest);

							// BUGFIX: IE - memory leak in interrupted
							if (bIE && bAsync)
								window.detachEvent("onunload", fOnUnload);
						}
					};
					oRequest._object.send(null);

					// Return now - wait untill re-sent request is finished
					return;
				};
*/
				// BUGFIX: IE - memory leak in interrupted
				if (bIE && bAsync)
					window.detachEvent("onunload", fOnUnload);
			}

			// BUGFIX: Some browsers (Internet Explorer, Gecko) fire OPEN readystate twice
			if (nState != oRequest.readyState)
				fReadyStateChange(oRequest);

			nState	= oRequest.readyState;
		};
		// Add method sniffer
		if (cXMLHttpRequest.onopen)
			cXMLHttpRequest.onopen.apply(this, arguments);

		if (arguments.length > 4)
			this._object.open(sMethod, sUrl, bAsync, sUser, sPassword);
		else
		if (arguments.length > 3)
			this._object.open(sMethod, sUrl, bAsync, sUser);
		else
			this._object.open(sMethod, sUrl, bAsync);

		// BUGFIX: Gecko - missing readystatechange calls in synchronous requests
		if (!bAsync && bGecko) {
			this.readyState	= cXMLHttpRequest.OPENED;

			fReadyStateChange(this);
		}
	};
	cXMLHttpRequest.prototype.send	= function(vData) {
		// Add method sniffer
		if (cXMLHttpRequest.onsend)
			cXMLHttpRequest.onsend.apply(this, arguments);

		// BUGFIX: Safari - fails sending documents created/modified dynamically, so an explicit serialization required
		// BUGFIX: IE - rewrites any custom mime-type to "text/xml" in case an XMLNode is sent
		// BUGFIX: Gecko - fails sending Element (this is up to the implementation either to standard)
		if (vData && vData.nodeType) {
			vData	= window.XMLSerializer ? new window.XMLSerializer().serializeToString(vData) : vData.xml;
			if (!this._headers["Content-Type"])
				this._object.setRequestHeader("Content-Type", "application/xml");
		}

		this._object.send(vData);

		// BUGFIX: Gecko - missing readystatechange calls in synchronous requests
		if (bGecko && !this._async) {
			this.readyState	= cXMLHttpRequest.OPENED;

			// Synchronize state
			fSynchronizeValues(this);

			// Simulate missing states
			while (this.readyState < cXMLHttpRequest.DONE) {
				this.readyState++;
				fReadyStateChange(this);
				// Check if we are aborted
				if (this._aborted)
					return;
			}
		}
	};
	cXMLHttpRequest.prototype.abort	= function() {
		// Add method sniffer
		if (cXMLHttpRequest.onabort)
			cXMLHttpRequest.onabort.apply(this, arguments);

		// BUGFIX: Gecko - unneccesary DONE when aborting
		if (this.readyState > cXMLHttpRequest.UNSENT)
			this._aborted	= true;

		this._object.abort();

		// BUGFIX: IE - memory leak
		fCleanTransport(this);
	};
	cXMLHttpRequest.prototype.getAllResponseHeaders	= function() {
		return this._object.getAllResponseHeaders();
	};
	cXMLHttpRequest.prototype.getResponseHeader	= function(sName) {
		return this._object.getResponseHeader(sName);
	};
	cXMLHttpRequest.prototype.setRequestHeader	= function(sName, sValue) {
		// BUGFIX: IE - cache issue
		if (!this._headers)
			this._headers	= {};
		this._headers[sName]	= sValue;

		return this._object.setRequestHeader(sName, sValue);
	};

	// EventTarget interface implementation
	cXMLHttpRequest.prototype.addEventListener	= function(sName, fHandler, bUseCapture) {
		for (var nIndex = 0, oListener; oListener = this._listeners[nIndex]; nIndex++)
			if (oListener[0] == sName && oListener[1] == fHandler && oListener[2] == bUseCapture)
				return;
		// Add listener
		this._listeners.push([sName, fHandler, bUseCapture]);
	};

	cXMLHttpRequest.prototype.removeEventListener	= function(sName, fHandler, bUseCapture) {
		for (var nIndex = 0, oListener; oListener = this._listeners[nIndex]; nIndex++)
			if (oListener[0] == sName && oListener[1] == fHandler && oListener[2] == bUseCapture)
				break;
		// Remove listener
		if (oListener)
			this._listeners.splice(nIndex, 1);
	};

	cXMLHttpRequest.prototype.dispatchEvent	= function(oEvent) {
		var oEvent	= {
			'type':			oEvent.type,
			'target':		this,
			'currentTarget':this,
			'eventPhase':	2,
			'bubbles':		oEvent.bubbles,
			'cancelable':	oEvent.cancelable,
			'timeStamp':	oEvent.timeStamp,
			'stopPropagation':	function() {},	// There is no flow
			'preventDefault':	function() {},	// There is no default action
			'initEvent':		function() {}	// Original event object should be inited
		};

		// Execute onreadystatechange
		if (oEvent.type == "readystatechange" && this.onreadystatechange)
			(this.onreadystatechange.handleEvent || this.onreadystatechange).apply(this, [oEvent]);

		// Execute listeners
		for (var nIndex = 0, oListener; oListener = this._listeners[nIndex]; nIndex++)
			if (oListener[0] == oEvent.type && !oListener[2])
				(oListener[1].handleEvent || oListener[1]).apply(this, [oEvent]);
	};

	//
	cXMLHttpRequest.prototype.toString	= function() {
		return '[' + "object" + ' ' + "XMLHttpRequest" + ']';
	};

	cXMLHttpRequest.toString	= function() {
		return '[' + "XMLHttpRequest" + ']';
	};

	// Helper function
	function fReadyStateChange(oRequest) {
		// Sniffing code
		if (cXMLHttpRequest.onreadystatechange)
			cXMLHttpRequest.onreadystatechange.apply(oRequest);

		// Fake event
		oRequest.dispatchEvent({
			'type':			"readystatechange",
			'bubbles':		false,
			'cancelable':	false,
			'timeStamp':	new Date + 0
		});
	};

	function fGetDocument(oRequest) {
		var oDocument	= oRequest.responseXML;
		// Try parsing responseText
		if (bIE && oDocument && !oDocument.documentElement && oRequest.getResponseHeader("Content-Type").match(/[^\/]+\/[^\+]+\+xml/)) {
			oDocument	= new window.ActiveXObject("Microsoft.XMLDOM");
			oDocument.loadXML(oRequest.responseText);
		}
		// Check if there is no error in document
		if (oDocument)
			if ((bIE && oDocument.parseError != 0) || !oDocument.documentElement || (oDocument.documentElement && oDocument.documentElement.tagName == "parsererror"))
				return null;
		return oDocument;
	};

	function fSynchronizeValues(oRequest) {
		try {	oRequest.responseText	= oRequest._object.responseText;	} catch (e) {}
		try {	oRequest.responseXML	= fGetDocument(oRequest._object);	} catch (e) {}
		try {	oRequest.status			= oRequest._object.status;			} catch (e) {}
		try {	oRequest.statusText		= oRequest._object.statusText;		} catch (e) {}
	};

	function fCleanTransport(oRequest) {
		// BUGFIX: IE - memory leak (on-page leak)
		oRequest._object.onreadystatechange	= new window.Function;

		// Delete private properties
		delete oRequest._headers;
	};

	// Internet Explorer 5.0 (missing apply)
	if (!window.Function.prototype.apply) {
		window.Function.prototype.apply	= function(oRequest, oArguments) {
			if (!oArguments)
				oArguments	= [];
			oRequest.__func	= this;
			oRequest.__func(oArguments[0], oArguments[1], oArguments[2], oArguments[3], oArguments[4]);
			delete oRequest.__func;
		};
	};

	// Register new object with window
	window.XMLHttpRequest	= cXMLHttpRequest;
})();
