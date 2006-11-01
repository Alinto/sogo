String.prototype.trim = function() {
  return this.replace(/(^\s+|\s+$)/g, '');
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

Date.prototype.sogoFreeBusyStringWithSeparator = function(separator) {
  var str = this.sogoDayName() + ", ";
  if (separator == '-')
    str += (this.getYear() + 1900) + '-' + (this.getMonth() + 1) + '-' + this.getDate();
  else
    str += this.getDate() + '/' + (this.getMonth() + 1) + '/' + (this.getYear() + 1900);

  return str;
}
