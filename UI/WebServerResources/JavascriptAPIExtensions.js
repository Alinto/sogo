String.prototype.trim = function() {
  return this.replace(/(^\s+|\s+$)/g, '');
}

String.prototype.formatted = function() {
  var newString = this;

  for (var i = 0; i < arguments.length; i++)
    newString = newString.replace("%{" + i + "}", arguments[i], "g");

  return newString;
}

String.prototype.repeat = function(count) {
   var newString = "";
   for (var i = 0; i < count; i++) {
      newString += this;
   }

   return newString;
}

String.prototype.capitalize = function() {
  return this.replace(/\w+/g,
                      function(a) {
                        return ( a.charAt(0).toUpperCase()
                                 + a.substr(1).toLowerCase() );
                      });
}

String.prototype.decodeEntities = function() {
  return this.replace(/&#(\d+);/g,
                      function(wholematch, parenmatch1) {
                        return String.fromCharCode(+parenmatch1);
                      });
}

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
}

Date.prototype.daysUpTo = function(otherDate) {
  var days = new Array();

  var day1 = this.getTime();
  var day2 = otherDate.getTime();

  var nbrDays = Math.floor((day2 - day1) / 86400000) + 1;
  for (var i = 0; i < nbrDays; i++) {
    var newDate = new Date();
    newDate.setTime(day1 + (i * 86400000));
    days.push(newDate);
  }

  return days;
}

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
}

Date.prototype.getHourString = function() {
   var newString = this.getHours() + '00';
   if (newString.length == 3)
     newString = '0' + newString;

   return newString;
}

Date.prototype.getDisplayHoursString = function() {
   var hoursString = "" + this.getHours();
   if (hoursString.length == 1)
     hoursString = '0' + hoursString;

   var minutesString = "" + this.getMinutes();
   if (minutesString.length == 1)
     minutesString = '0' + minutesString;

   return hoursString + ":" + minutesString;
}

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
}

Date.prototype.sogoFreeBusyStringWithSeparator = function(separator) {
  return this.sogoDayName() + ", " + this.stringWithSeparator(separator);
}

Date.prototype.addDays = function(nbrDays) {
   var milliSeconds = this.getTime();
   milliSeconds += 86400000 * nbrDays;
   this.setTime(milliSeconds);
}

Date.prototype.earlierDate = function(otherDate) {
   var workDate = new Date();
   workDate.setTime(otherDate.getTime());
   workDate.setHours(0);
   return ((this.getTime() < workDate.getTime())
	   ? this : otherDate);
}

Date.prototype.laterDate = function(otherDate) {
   var workDate = new Date();
   workDate.setTime(otherDate.getTime());
   workDate.setHours(23);
   workDate.setMinutes(59);
   workDate.setSeconds(59);
   workDate.setMilliseconds(999);
   return ((this.getTime() < workDate.getTime())
	   ? otherDate : this);
}

Date.prototype.beginOfWeek = function() {
   var beginNumber;
   var dayNumber = this.getDay();
   if (weekStartIsMonday) {
     beginNumber = 1;
     if (dayNumber == 0)
	dayNumber = 7;
   }
   else
     beginNumber = 0;

   var beginOfWeek = new Date();
   beginOfWeek.setTime(this.getTime());
   beginOfWeek.addDays(beginNumber - dayNumber);
   beginOfWeek.setHours(0);
   beginOfWeek.setMinutes(0);
   beginOfWeek.setSeconds(0);
   beginOfWeek.setMilliseconds(0);

   return beginOfWeek;
}

Date.prototype.endOfWeek = function() {
   var beginNumber;
   var dayNumber = this.getDay();
   if (weekStartIsMonday) {
      beginNumber = 1;
      if (dayNumber == 0)
	 dayNumber = 7;
   }
   else
      beginNumber = 0;

   var endOfWeek = new Date();
   endOfWeek.setTime(this.getTime());
   endOfWeek.addDays(6 + beginNumber - dayNumber);

   endOfWeek.setHours(23);
   endOfWeek.setMinutes(59);
   endOfWeek.setSeconds(59);
   endOfWeek.setMilliseconds(999);

   return endOfWeek;
}
