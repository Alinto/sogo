/* -*- Mode: js2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

SOGoMailDataSource = Class.create({

        initialize: function(dataTable, url) {
            // Instance variables
            this.dataTable = dataTable;
            this.id = url;
            this.url = url;

            this.uids = new Array();
            this.threaded = false;
            this.cache = new Hash();

            this.loaded = false;
            this.delayedGetData = false;
            this.ajaxGetData = false;

            // Constants
            this.overflow = 50;   // must be higher or equal to the overflow of the data table class
        },

        destroy: function() {
            this.uids.clear();
            var keys = this.cache.keys();
            for (var i = 0; i < keys.length; i++)
                this.cache.unset(keys[i]);
        },

        invalidate: function(uid) {
            this.cache.unset(uid);
            var index = this.indexOf(uid);
//            log ("MailDataSource.invalidate(" + uid + ") at index " + index);

            return index;
        },

        remove: function(uid) {
//            log ("MailDataSource.remove(" + uid + ")");
            var index = this.invalidate(uid);
            if (index >= 0) {
                this.uids.splice(index, 1);
            }

            return index;
        },

        init: function(uids, threaded, headers, quotas) {
            this.uids = uids;
            if (typeof threaded != "undefined") {
                this.threaded = threaded;
                if (threaded)
                    this.uids.shift(); // drop key fields
            }
//            log ("MailDataSource.init() " + this.uids.length + " uids loaded");

            if (quotas && Object.isFunction(updateQuotas))
                updateQuotas(quotas);

            if (headers) {
                var keys = headers[0];
                for (var i = 1; i < headers.length; i++) {
                    var header = [];
                    for (var j = 0; j < keys.length; j++)
                        header[keys[j]] = headers[i][j];
                    this.cache.set(header["uid"], header);
                }
//                log ("MailDataSource.init() " + this.cache.keys().length + " headers loaded");
            }

            this.loaded = true;
//            log ("MailDataSource.init() " + this.uids.length + " UIDs, " + this.cache.keys().length + " headers");
        },

        load: function(urlParams) {
            var params;
            this.loaded = false;
            if (urlParams.keys().length > 0) {
                params = urlParams.keys().collect(function(key) { return key + "=" + urlParams.get(key); }).join("&");
            }
            else
                params = "";
            this.id = this.url + "?" + params;

//            log ("MailDataSource.load() " + params);
            triggerAjaxRequest(this.url + "/uids",
                               this._loadCallback.bind(this),
                               null,
                               params,
                               { "Content-type": "application/x-www-form-urlencoded" });
        },

        _loadCallback: function(http) {
            if (http.status == 200) {
                if (http.responseText.length > 0) {
                    var data = http.responseText.evalJSON(true);
                    if (data.uids)
                        this.init(data.uids, data.threaded, data.headers, data.quotas);
                    else
                        this.init(data);
                    if (this.delayedGetData) {
                        this.delayedGetData();
                        this.delayedGetData = false;
                    }
                }
            }
            else {
                log("SOGoMailDataSource._loadCallback Error " + http.status + ": " + http.responseText);
            }
        },

        getData: function(id, index, count, callbackFunction, delay) {
            if (this.loaded == false) {
                // UIDs are not yet loaded -- delay the call until loading the data is completed.
//                log ("MailDataSource.getData() delaying data fetching while waiting for UIDs");
                this.delayedGetData = this.getData.bind(this, id, index, count, callbackFunction, delay);
                return;
            }

            var start, end;

            if (count > 1) {
                // Compute last index depending on number of UIDs
                start = index - (this.overflow/2);
                if (start < 0) start = 0;
                end = index + count + this.overflow - (index - start);
                if (end > this.uids.length) {
                    start -= end - this.uids.length;
                    end = this.uids.length;
                    if (start < 0) start = 0;
                }
            }
            else {
                // Count is 1; don't fetch more data since the caller is
                // SOGoDataTable.invalide() and asks for only one data row.
                start = index;
                end = index + count;
            }
//            log ("MailDataSource._getData() from " + index + " to " + (index + count) + " boosted from " + start + " to " + end);

            var missingUids = [];
            for (var j = start; j < end; j++) {
                var uid = this.threaded? this.uids[j][0] : this.uids[j];
                if (!this.cache.get(uid)) {
//                    log ("MailDataSource._getData missing headers of uid " + uid + " at index " + j + (this.threaded? " (":" (non-") + "threaded)");
                    missingUids.push(uid);
                }
            }

            if (this.delayed_getRemoteData) window.clearTimeout(this.delayed_getRemoteData);
            if (missingUids.length > 0) {
                var params = "uids=" + missingUids.join(",");
                this.delayed_getRemoteData = this._getRemoteData.bind(this,
                                                                      { callbackFunction: callbackFunction,
                                                                        start: start, end: end,
                                                                        id: id },
                                                                      params).delay(delay);
            }
            else if (callbackFunction)
                this._returnData(callbackFunction, id, start, end);
        },

        _getRemoteData: function(callbackData, urlParams) {
            if (this.ajaxGetData) {
                this.ajaxGetData.aborted = true;
                this.ajaxGetData.abort();
//                 log ("MailDataSource._getRemoteData() aborted previous AJAX request");
            }
//            log ("MailDataSource._getRemoteData() fetching headers of " + urlParams);
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
                    var keys = headers[0];
                    for (var i = 1; i < headers.length; i++) {
                        var header = [];
                        for (var j = 0; j < keys.length; j++)
                            header[keys[j]] = headers[i][j];
                        this.cache.set(header["uid"], header);
                    }

                    if (data["callbackFunction"])
                        this._returnData(data["callbackFunction"], data["id"], data["start"], data["end"]);
                }
            }
            else {
                log("SOGoMailDataSource._getRemoteDataCallback Error " + http.status + ": " + http.responseText);
            }
        },

        _returnData: function(callbackFunction, id, start, end) {
            var i, j;
            var data = new Array();
            for (i = start, j = 0; i < end; i++, j++) {
                if (this.threaded) {
                    data[j] = this.cache.get(this.uids[i][0]);

                    // Add thread-related data
                    if (parseInt(this.uids[i][2]) > 0)
                        data[j]['Thread'] = '&nbsp;'; //'<img class="messageThread" src="' + ResourcesURL + '/arrow-down.png">';
                    else if (data[j]['Thread'])
                        delete data[j]['Thread'];
                    if (parseInt(this.uids[i][1]) > -1)
                        data[j]['ThreadLevel'] = this.uids[i][1];
                    else
                        delete data[j]['ThreadLevel'];
                }
                else {
                    data[j] = this.cache.get(this.uids[i]);
                }
            }
            callbackFunction(id, start, this.uids.length, data);
        },

        indexOf: function(uid) {
            var index = -1;
            if (this.threaded) {
                for (var i = 0; i < this.uids.length; i++)
                    if (this.uids[i][0] == uid) {
                        index = i;
                        break;
                    }
            }
            else
                index = this.uids.indexOf(parseInt(uid));

            return index;
        },

        uidAtIndex: function(index) {
            if (this.threaded)
                return this.uids[index][0];
            else
                return this.uids[index];
        }
});
