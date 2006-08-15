// Title: Tigra Calendar
// Description: See the demo at url
// URL: http://www.softcomplex.com/products/tigra_calendar/
// Version: 3.1 (European date format)
// Date: 08-08-2002 (mm-dd-yyyy)
// Feedback: feedback@softcomplex.com (specify product title in the subject)
// Note: Permission given to use this script in ANY kind of applications if
//    header lines are left unchanged.
// Note: Script consists of two files: calendar?.js and calendar.html
// About us: Our company provides offshore IT consulting services.
//    Contact us at sales@softcomplex.com if you have any programming task you
//    want to be handled by professionals. Our typical hourly rate is $20.

// modified by Martin Hoerning, mh@skyrix.com, 2002-12-05
// 2003-01-23 added date format support (Martin Hoerning)

// if two digit year input dates after this year considered 20 century.
var NUM_CENTYEAR = 30;
// are year scrolling buttons required by default
var BUL_YEARSCROLL = true;
var DEF_CALPAGE = 'skycalendar.html';

var calendars = [];
var RE_NUM = /^\-?\d+$/;
var dateFormat = "yyyy-mm-dd";

function skycalendar(obj_target) {
  // assing methods
  this.gen_date = cal_gen_date1;
  this.gen_tsmp = cal_gen_tsmp1;
  this.prs_date = cal_prs_date1;
  this.prs_tsmp = cal_prs_tsmp1;
  this.popup    = cal_popup1;
  this.setCalendarPage = cal_setcalpage1;
  this.setDateFormat   = cal_setdateformat1;

  // validate input parameters
  if (!obj_target)
    return cal_error("Error calling the calendar: no target control specified");
  if (obj_target.value == null)
    return cal_error("Error calling the calendar: parameter specified is not valid tardet control");
  this.target = obj_target;
  this.year_scroll = BUL_YEARSCROLL;
  this.calpage     = DEF_CALPAGE;
	
  // register in global collections
  this.id = calendars.length;
  calendars[this.id] = this;
}

function cal_setcalpage1(str_page) {
  this.calpage = str_page;
}

function cal_setdateformat1(str_dateformat) {
  this.dateFormat = str_dateformat;
}

function cal_popup1(str_datetime) {
  this.dt_current = this.prs_tsmp(str_datetime ? str_datetime : this.target.value);
  if (!this.dt_current) return;

  var obj_calwindow = window.open(
    this.calpage+'?datetime=' + this.dt_current.valueOf()+ '&id=' + this.id,
      'Calendar', 'width=200,height=190'+
      ',status=no,resizable=no,top=200,left=200,dependent=yes,alwaysRaised=yes'
    );
  obj_calwindow.opener = window;
  obj_calwindow.focus();
}

// timestamp generating function
function cal_gen_tsmp1(dt_datetime) {
  return this.gen_date(dt_datetime);
}

// date generating function
function cal_gen_date1(dt_datetime) {
  var out = this.dateFormat;
  var idx;
  if (out.indexOf("yyyy") != 1) {
    t = out.split("yyyy");
    out = t.join(dt_datetime.getFullYear());
  }
  else {
    return cal_error("Missing year-part 'yyyy' in format: '"+this.dateFormat);
  }
  if (out.indexOf("mm") != 1) {
    t = out.split("mm");
    out = t.join((dt_datetime.getMonth() < 9 ? '0' : '')+
                 (dt_datetime.getMonth()+1));
  }
  else {
    return cal_error("Missing month-part 'mm' in format: '"+this.dateFormat);
  }
  if (out.indexOf("dd") != 1) {
    t = out.split("dd");
    out = t.join((dt_datetime.getDate() < 10 ? '0' : '')+
                 dt_datetime.getDate());
  }
  else {
    return cal_error("Missing day-part 'dd' in format: '"+this.dateFormat);
  }

  return out;
}

// timestamp parsing function
function cal_prs_tsmp1(str_datetime) {
  // if no parameter specified return current timestamp
  if (!str_datetime)
    return (new Date());

  // if positive integer treat as milliseconds from epoch
  if (RE_NUM.exec(str_datetime))
    return new Date(str_datetime);
		
  return this.prs_date(str_datetime);
}

// date parsing function
function cal_prs_date1(str_date) {
  var idx;
  var year  = null;
  var month = null;
  var day   = null;

  if (str_date.length != this.dateFormat.length) {
    return cal_error ("Invalid date format: '"+str_date+
                      "'.\nFormat accepted is '"+this.dateFormat+"'.");
  }

  if ((idx = this.dateFormat.indexOf("yyyy")) != 1) {
    year = str_date.substring(idx, idx+4);
  }
  else {
    return cal_error("Missing year-part 'yyyy' in format: '"+this.dateFormat);
  }
  if ((idx = this.dateFormat.indexOf("mm")) != 1) {
    month = str_date.substring(idx, idx+2);
  }
  else {
    return cal_error("Missing month-part 'mm' in format: '"+this.dateFormat);
  }
  if ((idx = this.dateFormat.indexOf("dd")) != 1) {
    day = str_date.substring(idx, idx+2);
  }
  else {
    return cal_error("Missing day-part 'dd' in format: '"+this.dateFormat);
  }

  if (!day) return cal_error("Invalid date format: '"+str_date+
                             "'.\nNo day of month value can be found.");
  if (!RE_NUM.exec(day))
    return cal_error("Invalid day of month value: '"+day+
                     "'.\nAllowed values are unsigned integers.");

  if (!month) return cal_error("Invalid date format: '"+str_date+
                             "'.\nNo month of year value can be found.");
  if (!RE_NUM.exec(month))
    return cal_error("Invalid month of year value: '"+month+
                     "'.\nAllowed values are unsigned integers.");
  
  if (!year) return cal_error("Invalid date format: '"+str_date+
                             "'.\nNo year value can be found.");
  if (!RE_NUM.exec(year))
    return cal_error("Invalid year value: '"+year+
                     "'.\nAllowed values are unsigned integers.");

  
  var dt_date = new Date();
  dt_date.setDate(1);
  if (month < 1 || month > 12)
    return cal_error("Invalid month value: '"+month+
                     "'.\nAllowed range is 01-12.");
  dt_date.setMonth(month-1);
  if (year < 100) year = Number(year)+(year < NUM_CENTYEAR ? 2000 : 1900);
  dt_date.setFullYear(year);
  var dt_numdays = new Date(year, month, 0);
  dt_date.setDate(day);
  if (dt_date.getMonth() != (month-1))
    return cal_error("Invalid day of month value: '"+day+
                     "'.\nAllowed range is 01-"+dt_numdays.getDate()+".");
  return (dt_date);
}

function cal_error(str_message) {
  alert (str_message);
  return null;
}
