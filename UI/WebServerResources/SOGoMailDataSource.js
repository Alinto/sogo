/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

SOGoMailDataSource = Class.create({
        
        initialize: function(dataTable, url) {
            // Instance variables
            this.dataTable = dataTable;
            this.url = url;
            
            this.uids = new Array();
            this.cache = new Hash();
            
            this.loaded = false;
            this.delayedGetData = false;
            this.ajaxGetData = false;

            // Constants
            this.overflow = 60;
        },
        
        destroy: function() {
            this.uids.clear();
            var keys = this.cache.keys();
            for (var i = 0; i < keys.length; i++)
                this.cache.unset(keys[i]);
        },

        invalidate: function(uid) {
            this.cache.unset(uid);
            var index = this.uids.indexOf(parseInt(uid));
            log ("MailDataSource.invalidate(" + uid + ") at index " + index);
            if (index >= 0) {
                this.uids.splice(index, 1);
            }

            return index;
        },
        
        load: function(urlParams) {
            var params;
            this.loaded = false;
            if (urlParams.keys().length > 0) {
                params = urlParams.keys().collect(function(key) { return key + "=" + urlParams.get(key); }).join("&");
            }
            else
                params = "";

//             log ("MailDataSource.load() " + params);
            triggerAjaxRequest(this.url + "/uids",
                               this._loadCallback.bind(this),
                               null,
                               params,
                               { "Content-type": "application/x-www-form-urlencoded" });
        },
    
        _loadCallback: function(http) {
            if (http.status == 200) {
                if (http.responseText.length > 0) {
                    this.uids = $A(http.responseText.evalJSON(true));
                    log ("MailDataSource._loadCallback() " + this.uids.length + " uids");
                    this.loaded = true;
                }
            }
            else {
                alert("SOGoMailDataSource._loadCallback Error " + http.status + ": " + http.responseText);
            }
        },
        
        getData: function(id, index, count, callbackFunction, delay) {
            if (this.loaded == false) {
                // UIDs are not yet loaded -- delay the call to the current function
//                 log ("MailDataSource.getData() delaying data fetching while waiting for UIDs");
                if (this.delayedGetData) window.clearTimeout(this.delayedGetData);
                this.delayedGetData = this.getData.bind(this, id, index, count, callbackFunction, delay).delay(0.3);
                return;
            }
            if (this.delayed_getData) window.clearTimeout(this.delayed_getData);
            this.delayed_getData = this._getData.bind(this,
                                                      id,
                                                      index,
                                                      count,
                                                      callbackFunction
                                                      ).delay(delay);
        },
        
        _getData: function(id, index, count, callbackFunction) {
            var start, end;
            var i, j;
            var missingUids = new Array();
            
            // Compute last index depending on number of UIDs
            start = index - (this.overflow/2);
            if (start < 0) start = 0;
            end = index + count + this.overflow - (index - start);
            if (end > this.uids.length) {
                start -= end - this.uids.length;
                end = this.uids.length;
                if (start < 0) start = 0;
            }
            log ("MailDataSource._getData() from " + index + " to " + (index + count) + " boosted from " + start + " to " + end);

            for (i = 0, j = start; j < end; j++) {
                if (!this.cache.get(this.uids[j])) {
                     missingUids[i] = this.uids[j];
                    i++;
                }
            }

            if (this.delayed_getRemoteData) window.clearTimeout(this.delayed_getRemoteData);
            if (missingUids.length > 0) {
                var params = "uids=" + missingUids.join(",");
                this.delayed_getRemoteData = this._getRemoteData.bind(this,
                                                                      { callbackFunction: callbackFunction,
                                                                        start: start, end: end,
                                                                        id: id },
                                                                      params).delay(0.5);
            }
            else
                this._returnData(callbackFunction, id, start, end);
        },
        
        _getRemoteData: function(callbackData, urlParams) {
            if (this.ajaxGetData) {
                this.ajaxGetData.aborted = true;
                this.ajaxGetData.abort();
//                 log ("MailDataSource._getData() aborted previous AJAX request");
            }
//             log ("MailDataSource._getData() fetching headers of " + urlParams);
            this.ajaxGetData = triggerAjaxRequest(this.url + "/headers",
                                                  this._getRemoteDataCallback.bind(this),
                                                  callbackData,
                                                  urlParams,
                                                  { "Content-type": "application/x-www-form-urlencoded" });
        },
    
        _getRemoteDataCallback: function(http) {
            if (http.status == 200) {
                if (http.responseText.length > 0) {
                    // We receives an array of hashes
                    var headers = $A(http.responseText.evalJSON(true));
                    var data = http.callbackData;
                    
                    for (var i = 0; i < headers.length; i++) {
                        this.cache.set(headers[i]["uid"], headers[i]);
                    }
                    
                    this._returnData(data["callbackFunction"], data["id"], data["start"], data["end"]);
                }
            }
            else {
                alert("SOGoMailDataSource._getRemoteDataCallback Error " + http.status + ": " + http.responseText);
            }
        },
        
        _returnData: function(callbackFunction, id, start, end) {
            var i, j;
            var data = new Array();
            for (i = start, j = 0; i < end; i++, j++) {
                data[j] = this.cache.get(this.uids[i]);
            }
            callbackFunction(id, start, this.uids.length, data);
        },

        indexOf: function(uid) {
            this.uids.indexOf(uid + "");
        }
});
