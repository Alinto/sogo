/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

String.prototype.trim = function() {
    return this.replace(/(^\s+|\s+$)/g, '');
};

String.prototype.formatted = function() {
    var newString = this;

    for (var i = 0; i < arguments.length; i++) {
        newString = newString.replace("%{" + i + "}", arguments[i], "g");
    }

    return newString;
};

String.prototype.repeat = function(count) {
    var newString = "";
    for (var i = 0; i < count; i++) {
        newString += this;
    }

    return newString;
};

String.prototype.capitalize = function() {
    return this.replace(/\w+/g,
                        function(a) {
                            return ( a.charAt(0).toUpperCase()
                                     + a.substr(1).toLowerCase() );
                        });
};

String.prototype.cssIdToHungarianId = function() {
    var parts = this.split("-");
    var newId = parts[0];
    for (var i = 1; i < parts.length; i++) {
        newId += parts[i].capitalize();
    }

    return newId;
}

String.prototype.decodeEntities = function() {
    return this.replace(/&#(\d+);/g,
                        function(wholematch, parenmatch1) {
                            return String.fromCharCode(+parenmatch1);
                        });
};

String.prototype.asDate = function () {
    var newDate;
    var date = this.split("/");
    if (date.length == 3)
        newDate = new Date(date[2], date[1] - 1, date[0]);
    else {
        date = this.split("-");
        if (date.length == 3)
            newDate = new Date(date[0], date[1] - 1, date[2]);
        else {
            if (this.length == 8) {
                newDate = new Date(this.substring(0, 4),
                                   this.substring(4, 6) - 1,
                                   this.substring(6, 8));
            }
        }
    }

    return newDate;  
};

String.prototype.asCSSIdentifier = function() {
    var characters = [ '_'  , '\\.', '#'  , '@'  , '\\*', ':'  , ','   , ' '
                       , "'", '&', '\\+' ];
    var escapeds =   [ '_U_', '_D_', '_H_', '_A_', '_S_', '_C_', '_CO_',
                       '_SP_', '_SQ_', '_AM_', '_P_' ];

    var newString = this;
    for (var i = 0; i < characters.length; i++) {
        var re = new RegExp(characters[i], 'g');
        newString = newString.replace(re, escapeds[i]);
    }

    return newString;
};

Date.prototype.clone = function() {
    var newDate = new Date();

    newDate.setTime(this.getTime());

    return newDate;
}

Date.prototype.sogoDayName = function() {
    var dayName = "";

    var day = this.getDay();
    if (day == 0) {
        dayName = labels['a2_Sunday'];
    } else if (day == 1) {
        dayName = labels['a2_Monday'];
    } else if (day == 2) {
        dayName = labels['a2_Tuesday'];
    } else if (day == 3) {
        dayName = labels['a2_Wednesday'];
    } else if (day == 4) {
        dayName = labels['a2_Thursday'];
    } else if (day == 5) {
        dayName = labels['a2_Friday'];
    } else if (day == 6) {
        dayName = labels['a2_Saturday'];
    }

    return dayName;
};

Date.prototype.deltaDays = function(otherDate) {
    var day1 = this.getTime();
    var day2 = otherDate.getTime();
    if (day1 > day2) {
        var tmp = day2;
        day2 = day1;
        day1 = tmp;
    }

    return Math.floor((day2 - day1) / 86400000);
}

Date.prototype.daysUpTo = function(otherDate) {
    var days = new Array();

    var day1 = this.getTime();
    var day2 = otherDate.getTime();
    if (day1 > day2) {
        var tmp = day1;
        day1 = day2;
        day2 = tmp;
    }
    //   var day1Date = new Date();
    //   day1Date.setTime(this.getTime());
    //   day1Date.setHours(0, 0, 0, 0);
    //   var day2Date = new Date();
    //   day2Date.setTime(otherDate.getTime());
    //   day2Date.setHours(23, 59, 59, 999);
    //   var day1 = day1Date.getTime();
    //   var day2 = day2Date.getTime();

    var nbrDays = Math.floor((day2 - day1) / 86400000) + 1;
    for (var i = 0; i < nbrDays; i++) {
        var newDate = new Date();
        newDate.setTime(day1 + (i * 86400000));
        days.push(newDate);
    }

    return days;
};

Date.prototype.getDayString = function() {
    var newString = this.getYear();
    if (newString < 1000) newString += 1900;
    var month = '' + (this.getMonth() + 1);
    if (month.length == 1)
        month = '0' + month;
    newString += month;
    var day = '' + this.getDate();
    if (day.length == 1)
        day = '0' + day;
    newString += day;

    return newString;
};

Date.prototype.getHourString = function() {
    var newString = this.getHours() + '00';
    if (newString.length == 3)
        newString = '0' + newString;

    return newString;
};

Date.prototype.getDisplayHoursString = function() {
    var hoursString = "" + this.getHours();
    if (hoursString.length == 1)
        hoursString = '0' + hoursString;

    var minutesString = "" + this.getMinutes();
    if (minutesString.length == 1)
        minutesString = '0' + minutesString;

    return hoursString + ":" + minutesString;
};

Date.prototype.stringWithSeparator = function(separator) {
    var month = '' + (this.getMonth() + 1);
    var day = '' + this.getDate();
    var year = this.getYear();
    if (year < 1000)
        year = '' + (year + 1900);
    if (month.length == 1)
        month = '0' + month;
    if (day.length == 1)
        day = '0' + day;

    if (separator == '-')
        str = year + '-' + month + '-' + day;
    else
        str = day + '/' + month + '/' + year;

    return str;
};

Date.prototype.sogoFreeBusyStringWithSeparator = function(separator) {
    return this.sogoDayName() + ", " + this.stringWithSeparator(separator);
};

Date.prototype.addDays = function(nbrDays) {
    var milliSeconds = this.getTime();
    milliSeconds += 86400000 * nbrDays;
    this.setTime(milliSeconds);
};

Date.prototype.earlierDate = function(otherDate) {
    var workDate = new Date();
    workDate.setTime(otherDate.getTime());
    workDate.setHours(0);
    return ((this.getTime() < workDate.getTime())
            ? this : otherDate);
};

Date.prototype.laterDate = function(otherDate) {
    var workDate = new Date();
    workDate.setTime(otherDate.getTime());
    workDate.setHours(23);
    workDate.setMinutes(59);
    workDate.setSeconds(59);
    workDate.setMilliseconds(999);
    return ((this.getTime() < workDate.getTime())
            ? otherDate : this);
};

Date.prototype.beginOfDay = function() {
    var beginOfDay = new Date(this.getTime());
    beginOfDay.setHours(0);
    beginOfDay.setMinutes(0);
    beginOfDay.setSeconds(0);
    beginOfDay.setMilliseconds(0);

    return beginOfDay;
}
  
Date.prototype.beginOfWeek = function() {
    var offset = firstDayOfWeek - this.getDay();
    if (offset > 0)
        offset -= 7;

    var beginOfWeek = this.beginOfDay();
    beginOfWeek.setHours(12);
    beginOfWeek.addDays(offset);
  
    return beginOfWeek;
};

Date.prototype.endOfWeek = function() {
    var endOfWeek = this.beginOfWeek();
    endOfWeek.addDays(6);

    endOfWeek.setHours(23);
    endOfWeek.setMinutes(59);
    endOfWeek.setSeconds(59);
    endOfWeek.setMilliseconds(999);
  
    return endOfWeek;
};

String.prototype._base64_keyStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
String.prototype.base64encode = function () {
    var output = "";
    var chr1, chr2, chr3, enc1, enc2, enc3, enc4;
    var i = 0;
 
    var input = this.utf8encode();

    while (i < input.length) {
        chr1 = input.charCodeAt(i++);
        chr2 = input.charCodeAt(i++);
        chr3 = input.charCodeAt(i++);
 
        enc1 = chr1 >> 2;
        enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
        enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
        enc4 = chr3 & 63;
 
        if (isNaN(chr2)) {
            enc3 = enc4 = 64;
        } else if (isNaN(chr3)) {
            enc4 = 64;
        }
 
        output = output +
            this._base64_keyStr.charAt(enc1) + this._base64_keyStr.charAt(enc2) +
            this._base64_keyStr.charAt(enc3) + this._base64_keyStr.charAt(enc4);
    }
 
    return output;
};

String.prototype.base64decode = function() { 
    var output = "";
    var chr1, chr2, chr3;
    var enc1, enc2, enc3, enc4;
    var i = 0;
 
    var input = "" + this; // .replace(/[^A-Za-z0-9\+\/\=]/g, "")
    while (i < input.length) {
        enc1 = this._base64_keyStr.indexOf(input.charAt(i++));
        enc2 = this._base64_keyStr.indexOf(input.charAt(i++));
        enc3 = this._base64_keyStr.indexOf(input.charAt(i++));
        enc4 = this._base64_keyStr.indexOf(input.charAt(i++));

        chr1 = (enc1 << 2) | (enc2 >> 4);
        chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
        chr3 = ((enc3 & 3) << 6) | enc4;
 
        output = output + String.fromCharCode(chr1);
 
        if (enc3 != 64) {
            output = output + String.fromCharCode(chr2);
        }
        if (enc4 != 64) {
            output = output + String.fromCharCode(chr3);
        }
    }

    return output;
};

String.prototype.utf8encode = function() {
    var string = this.replace(/\r\n/g,"\n");
    var utftext = "";
 
    for (var n = 0; n < this.length; n++) {
        var c = this.charCodeAt(n);

        if (c < 128) {
            utftext += String.fromCharCode(c);
        }
        else if((c > 127) && (c < 2048)) {
            utftext += String.fromCharCode((c >> 6) | 192);
            utftext += String.fromCharCode((c & 63) | 128);
        }
        else {
            utftext += String.fromCharCode((c >> 12) | 224);
            utftext += String.fromCharCode(((c >> 6) & 63) | 128);
            utftext += String.fromCharCode((c & 63) | 128);
        }
    }
 
    return utftext;
};

String.prototype.utf8decode = function() {
    var string = "";
    var i = 0;
    var c = c1 = c2 = 0;

    while (i < string.length) {
        c = utftext.charCodeAt(i);
 
        if (c < 128) {
            string += String.fromCharCode(c);
            i++;
        }
        else if((c > 191) && (c < 224)) {
            c2 = this.charCodeAt(i+1);
            string += String.fromCharCode(((c & 31) << 6) | (c2 & 63));
            i += 2;
        }
        else {
            c2 = this.charCodeAt(i+1);
            c3 = this.charCodeAt(i+2);
            string += String.fromCharCode(((c & 15) << 12) | ((c2 & 63) << 6) | (c3 & 63));
            i += 3;
        }
    }
 
    return string;
};

String.prototype.cssSafeString = function() {
    var newString = this.replace("#", "_", "g");
    newString = newString.replace(".", "_", "g");
    newString = newString.replace("@", "_", "g");

    return newString;
};

window.width = function() {
    if (window.innerWidth)
        return window.innerWidth;
    else if (document.body && document.body.offsetWidth)
        return document.body.offsetWidth;
    else
        return 0;
};

window.height = function() {
    if (window.innerHeight)
        return window.innerHeight;
    else if (document.body && document.body.offsetHeight)
        return document.body.offsetHeight;
    else
        return 0;
};
