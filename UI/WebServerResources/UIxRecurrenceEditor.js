var RecurrenceEditor = {
 types: new Array("Daily", "Weekly", "Monthly", "Yearly"),
 currentRepeatType: 0
}

function onRepeatTypeChange(event) {
  setRepeatType(parseInt(this.value));
}

function setRepeatType(type) {
  var elements;

  RecurrenceEditor.currentRepeatType = type;

  for (var i = 0; i <= 3; i++) {
    elements = $$("TABLE TR.recurrence" + RecurrenceEditor.types[i]);
    if (i != type)
      elements.each(function(row) {
	  row.hide();
	});
  }
  elements = $$("TABLE TR.recurrence" + RecurrenceEditor.types[type]);
  elements.each(function(row) {
      row.show();
    });
}

function getSelectedDays(element) {
  var elementsArray = $A(element.getElementsByTagName('DIV'));
  var days = new Array();
  elementsArray.each(function(item) {
       if (isNodeSelected(item))
	days.push(item.readAttribute("name"));
    });
  return days.join(",");
}

function onDayClick(event) {
  var element = $(this);
  if (isNodeSelected(element))
    this.removeClassName("_selected");
  else
    this.addClassName("_selected");
}

function onRangeChange(event) {
  $('endDate_date').disabled = (this.value != 2);
}

function onAdjustTime(event) {
  // must be defined for date picker widget
}

function initializeSelectors() {
  $$("DIV#week SPAN.week DIV").each(function(element) {
      element.observe("click", onDayClick, false);
    });

  $$("DIV#month SPAN.week DIV").each(function(element) {
      element.observe("click", onDayClick, false);
    });
}

function initializeWindowButtons() {
   var okButton = $("okButton");
   var cancelButton = $("cancelButton");

   Event.observe(okButton, "click", onEditorOkClick, false);
   Event.observe(cancelButton, "click", onEditorCancelClick, false);

   $("repeatType").observe("change", onRepeatTypeChange, false);
}

function initializeFormValues() {
  var repeatType = parent$("repeatType").value;

  // Select repeat type
  $("repeatType").value = repeatType;

  // Default values
  $('recurrence_form').setRadioValue('dailyRadioButtonName', 0);
  $('recurrence_form').setRadioValue('monthlyRadioButtonName', 0);
  $('recurrence_form').setRadioValue('yearlyRadioButtonName', 0);
  $('endDate_date').disabled = true;
  
  if (repeatType == 0) {
    // Repeat daily
    $('recurrence_form').setRadioValue('dailyRadioButtonName', parent$("repeat1").value);
    $('dailyDaysField').value = parent$("repeat2").value;
  }
  else if (repeatType == 1) {
    // Repeat weekly
    $('weeklyWeeksField').value = parent$("repeat1").value;
    var weekDiv = $("week").firstChild;
    var daysArray = parent$("repeat2").value.split(",");
    daysArray.each(function(index) {
	$(weekDiv).down('div', index).addClassName("_selected");
      });
  }
  else if (repeatType == 2) {
    // Repeat monthly
    $('monthlyMonthsField').value = parent$("repeat1").value;
    $('recurrence_form').setRadioValue('monthlyRadioButtonName', parent$("repeat2").value);
    $('monthlyRepeat').value = parent$("repeat3").value;
    $('monthlyDay').value = parent$("repeat4").value;
    var monthDiv = $("month");
    var daysArray = parent$("repeat5").value.split(",");
    daysArray.each(function(index) {
	$(monthDiv).down('DIV[name="'+index+'"]').addClassName("_selected");
      });
  }
  else if (repeatType == 3) {
    // Repeat yearly
    $('yearlyYearsField').value = parent$("repeat1").value;
    $('recurrence_form').setRadioValue('yearlyRadioButtonName', parent$("repeat2").value);
    $('yearlyDayField').value = parent$("repeat3").value;
    $('yearlyMonth1').value = parent$("repeat4").value;
    $('yearlyRepeat').value = parent$("repeat5").value;
    $('yearlyDay').value = parent$("repeat6").value;
    $('yearlyMonth2').value = parent$("repeat7").value;
  }
  else
    repeatType = 0;
  
  setRepeatType(repeatType);

  var range = parent$("range1").value;
  $('recurrence_form').setRadioValue('rangeRadioButtonName', range);

  if (range == 1) {
    $('rangeAppointmentsField').value = parent$("range2").value;
  }
  else if (range == 2) {
    $('endDate_date').value = parent$("range2").value;
    $('endDate_date').disabled = false;
  }

  // Observe change of range radio buttons to activate the date picker when required
  Form.getInputs($('recurrence_form'), 'radio', 'rangeRadioButtonName').each(function(input) {
      input.observe("change", onRangeChange);
    });

  // Show page
  $("recurrence_pattern").show();
  $("range_of_recurrence").show();
}

function onEditorOkClick(event) {
   preventDefault(event);
   var repeatType = $("repeatType").value;
   var v;

   parent$("repeatType").value = repeatType;

   if (repeatType == 0) {
     // Repeat daily
     v = $('recurrence_form').getRadioValue('dailyRadioButtonName')
     parent$("repeat1").value = v;

     // We check if the dailyDaysField really contains an integer
     if (v == 0) {
       parent$("repeat2").value = $('dailyDaysField').value;
       v = parseInt(parent$("repeat2").value);
       if (isNaN(v) || v <= 0) {
	 window.alert("Please specify a numerical value in the Days field greater or equal to 1.");
	 return false;
       }
     }
   } 
   else if (repeatType == 1) {
     // Repeat weekly
     v = $('weeklyWeeksField').value;
     parent$("repeat1").value = v;
     parent$("repeat2").value = getSelectedDays($('week'));

     // We check if the weeklyWeeksField really contains an integer
     v = parseInt(v);
     if (isNaN(v) || v <= 0) {
       window.alert("Please specify a numerical value in the Week(s) field greater or equal to 1.");
       return false;
     }
   }
   else if (repeatType == 2) {
     // Repeat monthly
     v = $('monthlyMonthsField').value;
     parent$("repeat1").value = v;
     parent$("repeat2").value = $('recurrence_form').getRadioValue('monthlyRadioButtonName');
     parent$("repeat3").value = $('monthlyRepeat').value;
     parent$("repeat4").value = $('monthlyDay').value;
     parent$("repeat5").value = getSelectedDays($('month'));

     // FIXME - right now we do not support rules
     //         such as The Second Tuesday...
     if (parent$("repeat2").value == 0) {
       window.alert("This type of recurrence is currently unsupported.");
       return false;
     }

     // We check if the monthlyMonthsField really contains an integer
     v = parseInt(v);
     if (isNaN(v) || v <= 0) {
       window.alert("Please specify a numerical value in the Month(s) field greater or equal to 1.");
       return false;
     }
   }
   else {
     // Repeat yearly 
     parent$("repeat1").value = $('yearlyYearsField').value;
     parent$("repeat2").value = $('recurrence_form').getRadioValue('yearlyRadioButtonName');
     parent$("repeat3").value = $('yearlyDayField').value;
     parent$("repeat4").value = $('yearlyMonth1').value;
     parent$("repeat5").value = $('yearlyRepeat').value;
     parent$("repeat6").value = $('yearlyDay').value;
     parent$("repeat7").value = $('yearlyMonth2').value;

     // FIXME - right now we do not support rules
     //         such as Every Second Tuesday of February
     if (parent$("repeat2").value == 1) {
       window.alert("This type of recurrence is currently unsupported.");
       return false;
     }

     // We check if the yearlyYearsField really contains an integer
     v = parseInt(parent$("repeat1").value);
     if (isNaN(v) || v <= 0) {
       window.alert("Please specify a numerical value in the Year(s) field greater or equal to 1.");
       return false;
     }
   }

   var range = $('recurrence_form').getRadioValue('rangeRadioButtonName');
   parent$("range1").value = range;

   if (range == 1) {
     parent$("range2").value = $('rangeAppointmentsField').value;

     // We check if the rangeAppointmentsField really contains an integer
     v = parseInt(parent$("range2").value);
     if (isNaN(v) || v <= 0) {
       window.alert("Please specify a numerical value in the Appointment(s) field  greater or equal to 1.");
       return false;
     }
   }
   else if (range == 2) {
     parent$("range2").value = $('endDate_date').value;
   }

   window.close();
}

function onEditorCancelClick(event) {
   preventDefault(event);
   window.close();
}

function onRecurrenceLoadHandler() {
  initializeFormValues();
  initializeSelectors();
  initializeWindowButtons();
  assignCalendar('endDate_date');
}

FastInit.addOnLoad(onRecurrenceLoadHandler);
