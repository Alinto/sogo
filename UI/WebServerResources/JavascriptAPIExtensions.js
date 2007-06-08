String.prototype.trim = function() {
  return this.replace(/(^\s+|\s+$)/g, '');
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
    newDate = new Date(date[0], date[1] - 1, date[2]);
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
   var newString = this.getYear() + 1900;
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

Date.prototype.stringWithSeparator = function(separator) {
  var month = '' + (this.getMonth() + 1);
  var day = '' + this.getDate();
  if (month.length == 1)
    month = '0' + month;
  if (day.length == 1)
    day = '0' + day;

  if (separator == '-')
    str = (this.getYear() + 1900) + '-' + month + '-' + day;
  else
    str = day + '/' + month + '/' + (this.getYear() + 1900);

  return str;
}

Date.prototype.sogoFreeBusyStringWithSeparator = function(separator) {
  return this.sogoDayName() + ", " + this.stringWithSeparator(separator);
}
