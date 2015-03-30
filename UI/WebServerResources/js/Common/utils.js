String.prototype.endsWith = function(suffix) {
  return this.indexOf(suffix, this.length - suffix.length) !== -1;
};

String.prototype.startsWith = function(pattern, position) {
  position = angular.isNumber(position) ? position : 0;
  return this.lastIndexOf(pattern, position) === position;
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

String.prototype.asDate = function () {
    var newDate;
    var date = this.split("/");
    if (date.length == 3)
        newDate = new Date(date[2], date[1] - 1, date[0]); // dd/mm/yyyy
    else {
        date = this.split("-");
        if (date.length == 3)
            newDate = new Date(date[0], date[1] - 1, date[2]); // yyyy-mm-dd
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

  if (/^\d+/.test(newString)) {
    newString = '_' + newString;
  }

  return newString;
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

Date.prototype.addDays = function(nbrDays) {
    var milliSeconds = this.getTime();
    milliSeconds += 86400000 * nbrDays;
    this.setTime(milliSeconds);
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

// YYYYMMDD
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

// MMHH
Date.prototype.getHourString = function() {
    var newString = this.getHours() + '00';
    if (newString.length == 3)
        newString = '0' + newString;

    return newString;
};

function l() {
  var key = arguments[0];
  var value = key;
  if (labels[key]) {
    value = labels[key];
  }
  else if (clabels[key]) {
    value = clabels[key];
  }
  for (var i = 1, j = 0; i < arguments.length; i++, j++) {
    value = value.replace('%{' + j + '}', arguments[i]);
  }

  return value;
}
