/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

String.prototype.endsWith = function(suffix) {
  return this.indexOf(suffix, this.length - suffix.length) !== -1;
};

String.prototype.startsWith = function(pattern, position) {
  position = angular.isNumber(position) ? position : 0;
  return this.lastIndexOf(pattern, position) === position;
};

// See ngSanitize
String.prototype.encodeEntities = function () {
  // Regular Expressions for parsing tags and attributes
  var SURROGATE_PAIR_REGEXP = /[\uD800-\uDBFF][\uDC00-\uDFFF]/g,
      // Match everything outside of normal chars and " (quote character)
      NON_ALPHANUMERIC_REGEXP = /([^#-~ |!])/g;

  return this.
    replace(/&/g, '&amp;').
    replace(SURROGATE_PAIR_REGEXP, function(value) {
      var hi = value.charCodeAt(0);
      var low = value.charCodeAt(1);
      return '&#' + (((hi - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000) + ';';
    }).
    replace(NON_ALPHANUMERIC_REGEXP, function(value) {
      return '&#' + value.charCodeAt(0) + ';';
    }).
    replace(/</g, '&lt;').
    replace(/>/g, '&gt;');
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

String.prototype.md5 = function() {
  if (!this.length) { return; }
  // MD5 (Message-Digest Algorithm) by WebToolkit
  var md5 = function(s){function L(k,d){return(k<<d)|(k>>>(32-d));}function K(G,k){var I,d,F,H,x;F=(G&2147483648);H=(k&2147483648);I=(G&1073741824);d=(k&1073741824);x=(G&1073741823)+(k&1073741823);if(I&d){return(x^2147483648^F^H);}if(I|d){if(x&1073741824){return(x^3221225472^F^H);}else{return(x^1073741824^F^H);}}else{return(x^F^H);}}function r(d,F,k){return(d&F)|((~d)&k);}function q(d,F,k){return(d&k)|(F&(~k));}function p(d,F,k){return(d^F^k);}function n(d,F,k){return(F^(d|(~k)));}function u(G,F,aa,Z,k,H,I){G=K(G,K(K(r(F,aa,Z),k),I));return K(L(G,H),F);}function f(G,F,aa,Z,k,H,I){G=K(G,K(K(q(F,aa,Z),k),I));return K(L(G,H),F);}function D(G,F,aa,Z,k,H,I){G=K(G,K(K(p(F,aa,Z),k),I));return K(L(G,H),F);}function t(G,F,aa,Z,k,H,I){G=K(G,K(K(n(F,aa,Z),k),I));return K(L(G,H),F);}function e(G){var Z;var F=G.length;var x=F+8;var k=(x-(x%64))/64;var I=(k+1)*16;var aa=Array(I-1);var d=0;var H=0;while(H<F){Z=(H-(H%4))/4;d=(H%4)*8;aa[Z]=(aa[Z]|(G.charCodeAt(H)<<d));H++;}Z=(H-(H%4))/4;d=(H%4)*8;aa[Z]=aa[Z]|(128<<d);aa[I-2]=F<<3;aa[I-1]=F>>>29;return aa;}function B(x){var k="",F="",G,d;for(d=0;d<=3;d++){G=(x>>>(d*8))&255;F="0"+G.toString(16);k=k+F.substr(F.length-2,2);}return k;}function J(k){k=k.replace(/rn/g,"n");var d="";for(var F=0;F<k.length;F++){var x=k.charCodeAt(F);if(x<128){d+=String.fromCharCode(x);}else{if((x>127)&&(x<2048)){d+=String.fromCharCode((x>>6)|192);d+=String.fromCharCode((x&63)|128);}else{d+=String.fromCharCode((x>>12)|224);d+=String.fromCharCode(((x>>6)&63)|128);d+=String.fromCharCode((x&63)|128);}}}return d;}var C=Array();var P,h,E,v,g,Y,X,W,V;var S=7,Q=12,N=17,M=22;var A=5,z=9,y=14,w=20;var o=4,m=11,l=16,j=23;var U=6,T=10,R=15,O=21;s=J(s);C=e(s);Y=1732584193;X=4023233417;W=2562383102;V=271733878;for(P=0;P<C.length;P+=16){h=Y;E=X;v=W;g=V;Y=u(Y,X,W,V,C[P+0],S,3614090360);V=u(V,Y,X,W,C[P+1],Q,3905402710);W=u(W,V,Y,X,C[P+2],N,606105819);X=u(X,W,V,Y,C[P+3],M,3250441966);Y=u(Y,X,W,V,C[P+4],S,4118548399);V=u(V,Y,X,W,C[P+5],Q,1200080426);W=u(W,V,Y,X,C[P+6],N,2821735955);X=u(X,W,V,Y,C[P+7],M,4249261313);Y=u(Y,X,W,V,C[P+8],S,1770035416);V=u(V,Y,X,W,C[P+9],Q,2336552879);W=u(W,V,Y,X,C[P+10],N,4294925233);X=u(X,W,V,Y,C[P+11],M,2304563134);Y=u(Y,X,W,V,C[P+12],S,1804603682);V=u(V,Y,X,W,C[P+13],Q,4254626195);W=u(W,V,Y,X,C[P+14],N,2792965006);X=u(X,W,V,Y,C[P+15],M,1236535329);Y=f(Y,X,W,V,C[P+1],A,4129170786);V=f(V,Y,X,W,C[P+6],z,3225465664);W=f(W,V,Y,X,C[P+11],y,643717713);X=f(X,W,V,Y,C[P+0],w,3921069994);Y=f(Y,X,W,V,C[P+5],A,3593408605);V=f(V,Y,X,W,C[P+10],z,38016083);W=f(W,V,Y,X,C[P+15],y,3634488961);X=f(X,W,V,Y,C[P+4],w,3889429448);Y=f(Y,X,W,V,C[P+9],A,568446438);V=f(V,Y,X,W,C[P+14],z,3275163606);W=f(W,V,Y,X,C[P+3],y,4107603335);X=f(X,W,V,Y,C[P+8],w,1163531501);Y=f(Y,X,W,V,C[P+13],A,2850285829);V=f(V,Y,X,W,C[P+2],z,4243563512);W=f(W,V,Y,X,C[P+7],y,1735328473);X=f(X,W,V,Y,C[P+12],w,2368359562);Y=D(Y,X,W,V,C[P+5],o,4294588738);V=D(V,Y,X,W,C[P+8],m,2272392833);W=D(W,V,Y,X,C[P+11],l,1839030562);X=D(X,W,V,Y,C[P+14],j,4259657740);Y=D(Y,X,W,V,C[P+1],o,2763975236);V=D(V,Y,X,W,C[P+4],m,1272893353);W=D(W,V,Y,X,C[P+7],l,4139469664);X=D(X,W,V,Y,C[P+10],j,3200236656);Y=D(Y,X,W,V,C[P+13],o,681279174);V=D(V,Y,X,W,C[P+0],m,3936430074);W=D(W,V,Y,X,C[P+3],l,3572445317);X=D(X,W,V,Y,C[P+6],j,76029189);Y=D(Y,X,W,V,C[P+9],o,3654602809);V=D(V,Y,X,W,C[P+12],m,3873151461);W=D(W,V,Y,X,C[P+15],l,530742520);X=D(X,W,V,Y,C[P+2],j,3299628645);Y=t(Y,X,W,V,C[P+0],U,4096336452);V=t(V,Y,X,W,C[P+7],T,1126891415);W=t(W,V,Y,X,C[P+14],R,2878612391);X=t(X,W,V,Y,C[P+5],O,4237533241);Y=t(Y,X,W,V,C[P+12],U,1700485571);V=t(V,Y,X,W,C[P+3],T,2399980690);W=t(W,V,Y,X,C[P+10],R,4293915773);X=t(X,W,V,Y,C[P+1],O,2240044497);Y=t(Y,X,W,V,C[P+8],U,1873313359);V=t(V,Y,X,W,C[P+15],T,4264355552);W=t(W,V,Y,X,C[P+6],R,2734768916);X=t(X,W,V,Y,C[P+13],O,1309151649);Y=t(Y,X,W,V,C[P+4],U,4149444226);V=t(V,Y,X,W,C[P+11],T,3174756917);W=t(W,V,Y,X,C[P+2],R,718787259);X=t(X,W,V,Y,C[P+9],O,3951481745);Y=K(Y,h);X=K(X,E);W=K(W,v);V=K(V,g);}var i=B(Y)+B(X)+B(W)+B(V);return i.toLowerCase();};
  return md5(this.toLowerCase());
};

String.prototype.capitalize = function() {
  return this.charAt(0).toUpperCase() + this.slice(1);
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
                                   this.substring(6, 8)); // yyyymmdd
            }
        }
    }

    return newDate;
};

String.prototype.formatted = function() {
  var newString = this;

  for (var i = 0; i < arguments.length; i++) {
    newString = newString.replace("%{" + i + "}", arguments[i], "g");
  }

  return newString;
};

String.prototype.isValidEmail = function() {
  var emailRE = /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i;
  return emailRE.test(this);
};

String.prototype.asCSSIdentifier = function() {
  var characters = [ '_'  , '\\.', '#'  , '@'  , '\\*', ':'  , ','   , ' ',    "'",    '&',    '\\+' ];
  var escapeds =   [ '_U_', '_D_', '_H_', '_A_', '_S_', '_C_', '_CO_', '_SP_', '_SQ_', '_AM_', '_P_' ];

  var newString = this;
  for (var i = 0; i < characters.length; i++) {
    var re = new RegExp(characters[i], 'g');
    newString = newString.replace(re, escapeds[i]);
  }

  newString = newString.replace(/[^\x00-\x7F]/g, '');

  if (/^\d+/.test(newString)) {
    newString = '_' + newString;
  }

  return newString;
};

String.prototype.timeInterval = function () {
  var interval;
  if (this == "once_per_hour")
    interval = 3600;
  else if (this == "every_minute")
    interval = 60;
  else {
    interval = parseInt(this.substr(6)) * 60;
  }

  return interval;
};

String.prototype.parseDate = function(localeProvider, format) {
  var string, formattingTokens, tokens, token, now, date, regexes, i, parsedInput, matchesCount;

  string = '' + this;
  formattingTokens = /%[dembByYHIMp]/g;
  now = new Date();
  date = {
    year: now.getYear() + 1900,
    month: now.getMonth(),
    day: now.getDate(),
    hour: 0,
    minute: 0
  };
  regexes = {
    '%d': [/\d\d/, function(input) {
      date.day = parseInt(input);
      return (date.day < 32);
    }],
    '%e': [/ ?\d?\d/, function(input) {
      date.day = parseInt(input);
      return (date.day < 32);
    }],
    '%m': [/\d\d/, function(input) {
      date.month = parseInt(input) - 1;
      return (date.month < 12);
    }],
    '%b': [/[^\d\s\.\/\-]{2,}/, function(input) {
      var i = _.indexOf(_.map(localeProvider.shortMonths, _.toLower), _.toLower(input));
      if (i >= 0)
        date.month = i;
      return (i >= 0);
    }],
    '%B': [/[^\d\s\.\/\-]{2,}/, function(input) {
      var i = _.indexOf(_.map(localeProvider.months, _.toLower), _.toLower(input));
      if (i >= 0)
        date.month = i;
      return (i >= 0);
    }],
    '%y': [/\d\d/, function(input) {
      var nearFuture = parseInt(now.getFullYear().toString().substring(2)) + 5;
      date.year = parseInt(input);
      if (date.year < nearFuture) date.year += 2000;
      else date.year += 1900;
      return true;
    }],
    '%Y': [/[12]\d\d\d/, function(input) {
      date.year = parseInt(input);
      return true;
    }],
    '%H': [/\d{1,2}/, function(input) {
      date.hour = parseInt(input);
      return (date.hour < 24);
    }],
    '%I': [/\d{1,2}/, function(input) {
      date.hour = parseInt(input);
      return (date.hour <= 12);
    }],
    '%M': [/[0-5]\d/, function(input) {
      date.minute = parseInt(input);
      return (date.minute < 60 );
    }],
    '%p': [/[^\d\s\/\-]+/, function(input) {
      var linput = _.toLower(input), am = _.toLower(l('AM')), pm = _.toLower(l('PM'));
      if (linput == pm)
        date.hour += 12;
      return (linput == am || linput == pm);
    }],
  };
  tokens = format.match(formattingTokens) || [];
  matchesCount = 0;

  for (i = 0; i < tokens.length; i++) {
    token = tokens[i];
    parsedInput = (string.match(regexes[token][0]) || [])[0];
    if (parsedInput) {
      string = string.slice(string.indexOf(parsedInput) + parsedInput.length);
      if (regexes[token][1](parsedInput))
        matchesCount++;
    }
  }

  if (tokens.length === matchesCount) {
    // console.debug(this + ' + ' + format + ' = ' + JSON.stringify(date));
    return new Date(date.year, date.month, date.day, date.hour, date.minute);
  }
  else
    return new Date(NaN);
};

Date.prototype.clone = function() {
  var newDate = new Date();

  newDate.setTime(this.getTime());

  return newDate;
};

Date.prototype.daysUpTo = function(otherDate) {
    var days = [];

    var day1 = this.getTime();
    var day2 = otherDate.getTime();
    if (day1 > day2) {
        var tmp = day1;
        day1 = day2;
        day2 = tmp;
    }

    var nbrDays = Math.round((day2 - day1) / 86400000) + 1;
    for (var i = 0; i < nbrDays; i++) {
        var newDate = new Date();
        newDate.setTime(day1 + (i * 86400000));
        days.push(newDate);
    }

    return days;
};

Date.prototype.minutesTo = function(otherDate) {
  var delta, dstOffset;

  delta = Math.floor(otherDate.valueOf() - this.valueOf())/1000/60;
  dstOffset = otherDate.getTimezoneOffset() - this.getTimezoneOffset();

  return delta - dstOffset;
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
  var initialDate, milliSeconds, dstOffset;

  milliSeconds = this.getTime();
  initialDate = new Date(milliSeconds);
  milliSeconds += 86400000 * nbrDays;
  this.setTime(milliSeconds);

  dstOffset = this.getTimezoneOffset() - initialDate.getTimezoneOffset();
  if (dstOffset !== 0) {
    milliSeconds = this.getTime() + dstOffset*60*1000;
    this.setTime(milliSeconds);
  }

  return this;
};

Date.prototype.addHours = function(nbrHours) {
  var milliSeconds = this.getTime();
  milliSeconds += 3600000 * nbrHours;
  this.setTime(milliSeconds);
};

Date.prototype.addMinutes = function(nbrMinutes) {
  var milliSeconds = this.getTime();
  milliSeconds += 60000 * nbrMinutes;
  this.setTime(milliSeconds);
};

Date.prototype.beginOfDay = function() {
    var beginOfDay = new Date(this.getTime());
    beginOfDay.setHours(0);
    beginOfDay.setMinutes(0);
    beginOfDay.setSeconds(0);
    beginOfDay.setMilliseconds(0);

    return beginOfDay;
};

/**
 * See [SOGoUser dayOfWeekForDate:]
 */
Date.prototype.dayOfWeek = function(localeProvider) {
  var offset, baseDayOfWeek, dayOfWeek;

  offset = localeProvider.firstDayOfWeek;
  baseDayOfWeek = this.getDay();
  if (offset > baseDayOfWeek)
    baseDayOfWeek += 7;

  dayOfWeek = baseDayOfWeek - offset;

  return dayOfWeek;
};

/**
 * See [SOGoUser firstWeekOfYearForDate:]
 */
Date.prototype.firstWeekOfYearForDate = function(localeProvider) {
  var firstWeekRule, dayOfWeek, januaryFirst, firstWeek;

  firstWeekRule = localeProvider.firstWeekOfYear;

  januaryFirst = new Date(this.getTime());
  januaryFirst.setMonth(0);
  januaryFirst.setDate(1);
  dayOfWeek = januaryFirst.dayOfWeek(localeProvider);

  if (firstWeekRule == 'First4DayWeek') {
    if (dayOfWeek < 4)
      firstWeek = januaryFirst.beginOfWeek(localeProvider.firstDayOfWeek);
    else
      firstWeek = januaryFirst.addDays(7).beginOfWeek(localeProvider.firstDayOfWeek);
  }
  else if (firstWeekRule == 'FirstFullWeek') {
    if (dayOfWeek === 0)
      firstWeek = januaryFirst.beginOfWeek(localeProvider.firstDayOfWeek);
    else
      firstWeek = januaryFirst.addDays(7).beginOfWeek(localeProvider.firstDayOfWeek);
  }
  else {
    firstWeek = januaryFirst.beginOfWeek(localeProvider.firstDayOfWeek);
  }

  return firstWeek;
};

/**
 * See [SOGoUser weekNumberForDate:]
 */
Date.prototype.getWeek = function(localeProvider) {
  var firstWeek, previousWeek, weekNumber, clone;

  clone = new Date(this.getTime());
  clone.addDays(6);
  firstWeek = clone.firstWeekOfYearForDate(localeProvider);
  if (firstWeek.getTime() < clone.getTime()) {
    weekNumber = 1 + Math.floor((clone.getTime() - firstWeek.getTime()) / (86400000 * 7));
  }
  else
    {
      // Date is within the last week of the previous year;
      // Compute the previous week number to find the week number of the requested date.
      // The number will either be 52 or 53.
      previousWeek = new Date(clone.getTime());
      previousWeek.addDays(-7);
      firstWeek = previousWeek.firstWeekOfYearForDate(localeProvider);
      weekNumber = 2 + Math.floor((previousWeek.getTime() - firstWeek.getTime()) / (86400000 * 7));
    }

  return weekNumber;
};

Date.prototype.beginOfWeek = function(firstDayOfWeek) {
    var offset = firstDayOfWeek - this.getDay();
    if (offset > 0)
        offset -= 7;

    var beginOfWeek = this.beginOfDay();
    beginOfWeek.setHours(12);
    beginOfWeek.addDays(offset);

    return beginOfWeek;
};

Date.prototype.endOfWeek = function(firstDayOfWeek) {
    var endOfWeek = this.beginOfWeek(firstDayOfWeek);
    endOfWeek.addDays(6);

    endOfWeek.setHours(23);
    endOfWeek.setMinutes(59);
    endOfWeek.setSeconds(59);
    endOfWeek.setMilliseconds(999);

    return endOfWeek;
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

Date.prototype.format = function(localeProvider, format) {
  var separators, parts, i, max,
      date = [],
      validParts = /%[deaAmbByYUHIMp]/g,
      val = {
        '%d': this.getDate(),                                  // day of month (e.g., 01)
        '%e': this.getDate(),                                  // day of month, space padded
        '%a': localeProvider.shortDays[this.getDay()],         // locale's abbreviated weekday name (e.g., Sun)
        '%A': localeProvider.days[this.getDay()],              // locale's full weekday name (e.g., Sunday)
        '%m': this.getMonth() + 1,                             // month (01..12)
        '%b': localeProvider.shortMonths[this.getMonth()],     // locale's abbreviated month name (e.g., Jan)
        '%B': localeProvider.months[this.getMonth()],          // locale's full month name (e.g., January)
        '%y': this.getFullYear().toString().substring(2),      // last two digits of year (00..99)
        '%Y': this.getFullYear(),                              // year
        '%U': this.getWeek(localeProvider),                    // week of the year
        '%H': this.getHours(),                                 // hour (00..23)
        '%M': this.getMinutes() };                             // minute (00..59)
  val['%I'] = val['%H'] > 12 ? val['%H'] % 12 : val['%H'];     // hour (01..12)
  val['%p'] = val['%H'] < 12 ? l('AM') : l('PM');              // locale's equivalent of either AM or PM

  val['%d'] = (val['%d'] < 10 ? '0' : '') + val['%d'];
  val['%e'] = (val['%e'] < 10 ? ' ' : '') + val['%e'];
  val['%m'] = (val['%m'] < 10 ? '0' : '') + val['%m'];
  val['%H'] = (val['%H'] < 10 ? '0' : '') + val['%H'];
  val['%I'] = (val['%I'] < 10 ? '0' : '') + val['%I'];
  val['%M'] = (val['%M'] < 10 ? '0' : '') + val['%M'];

  separators = format.replace(validParts, '\0').split('\0');
  parts = format.match(validParts);
  for (i = 0, max = parts.length; i <= max; i++){
    if (separators.length)
      date.push(separators.shift());
    date.push(val[parts[i]]);
  }

  return date.join('');
};

Element.prototype.setCaretTo = function(pos) {
  if (this.setSelectionRange) {  // For Mozilla and Safari
    this.focus();
    this.setSelectionRange(pos, pos);
  }
  else if (this.createTextRange) {  // For IE
    var range = this.createTextRange();
    range.move('character', pos);
    range.select();
  }
};

Element.prototype.selectText = function(start, end) {
  if (this.setSelectionRange) {     // For Mozilla and Safari
    this.setSelectionRange(start, end);
  }
  else if (this.createTextRange) {  // For IE
    var textRange = this.createTextRange();
    textRange.moveStart('character', start);
    textRange.moveEnd('character', end-element.value.length);
    textRange.select();
  }
  else {
    this.select();
  }
};

/* Functions */

function l() {
  var key = arguments[0], value = key, args = arguments, i, j;

  // Retrieve translation
  if (labels[key]) {
    value = labels[key];
  }
  else if (clabels[key]) {
    value = clabels[key];
  }

  // Format placeholders %{0}, %{1], %{2}, ...
  for (i = 1, j = 0; i < args.length; i++, j++) {
    value = value.replace('%{' + j + '}', args[i]);
  }

  // Format placeholders %d and %s
  i = 1;
  if (args.length > 1) {
    value = value.replace(/%((%)|s|d)/g, function(m) {
      // m is the matched format, e.g. %s, %d
      var val = null;
      if (m[2]) {
        val = m[2];
      }
      else {
        val = args[i];
        // A switch statement so that the formatter can be extended. Default is %s
        switch (m) {
        case '%d':
          val = parseFloat(val);
          if (isNaN(val))
            val = 0;
          break;
        }
        i++;
      }
      return val;
    });
  }

  return value;
}

function hexToRgb(hex) {
  var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? {
    r: parseInt(result[1], 16),
    g: parseInt(result[2], 16),
    b: parseInt(result[3], 16)
  } : null;
}

// Respect contrast ratio recommendation from W3C:
// http://www.w3.org/TR/WCAG20/#contrast-ratiodef
function contrast(hex) {
  var color, c, l = 1;

  color = hexToRgb(hex);
  if (color) {
    c = [color.r / 255, color.g / 255, color.b / 255];

    for (var i = 0; i < c.length; ++i) {
      if (c[i] <= 0.03928) {
	c[i] = c[i] / 12.92;
      }
      else {
	c[i] = Math.pow((c[i] + 0.055) / 1.055, 2.4);
      }
    }

    l = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }

  if (l > 0.179) {
    return 'black';
  }
  else {
    return 'white';
  }
}

function guid() {
  function S4() {
    return (((1+Math.random())*0x10000)|0).toString(16).substring(1); 
  }
  
  return (S4() + S4() + "-" + S4() + "-4" + S4().substr(0,3) + "-" + S4() + "-" + S4() + S4() + S4()).toLowerCase();
}
