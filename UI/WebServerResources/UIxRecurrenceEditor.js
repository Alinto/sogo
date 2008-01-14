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

  for (var i = 0; i <=3; i++) {
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

function onDayClick(event) {
  var element = $(this);
  if (element.hasClassName("selected"))
    this.removeClassName("selected");
  else
    this.addClassName("selected");
}

function initializeSelectors() {
  $$("DIV#week DIV.week DIV").each(function(element) {
      element.observe("click", onDayClick, false);
    });

  $$("DIV#month DIV.week DIV").each(function(element) {
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

  if (repeatType === 0) {
    $('recurrence_form').setRadioValue('dailyRadioButtonName', parent$("repeat1").value);
    $('dailyDaysField').value = parent$("repeat2").value;
  }
  else if ($("repeatType").value == 1) {
    $('weeklyWeeksField').value = parent$("repeat1").value;
    $('recurrence_form').setCheckBoxListValues('weeklyCheckBoxName', parent$("repeat2").value);
  }
  else if ($("repeatType").value == 2) {
    $('monthlyMonthsField').value = parent$("repeat1").value;
    $('recurrence_form').setRadioValue('monthlyRadioButtonName', parent$("repeat2").value);
    $('monthlyRepeat').value = parent$("repeat3").value;
    $('monthlyDay').value = parent$("repeat4").value;
    $('recurrence_form').setCheckBoxListValues('monthlyCheckBoxName', parent$("repeat5").value);
  }
  else if (repeatType == 3) {
    $('yearlyYearsField').value = parent$("repeat1").value;
    $('recurrence_form').setRadioValue('yearlyRadioButtonName', parent$("repeat2").value);
    $('yearlyDayField').value = parent$("repeat3").value;
    $('yearlyMonth1').value = parent$("repeat4").value;
    $('yearlyRepeat').value = parent$("repeat5").value;
    $('yearlyDay').value = parent$("repeat6").value;
    $('yearlyMonth2').value = parent$("repeat7").value;
  }
  else {
    // Default values
    setRepeatType(0);
    $('recurrence_form').setRadioValue('dailyRadioButtonName', 0);
    $('dailyDaysField').value = 1;

    $('weeklyWeeksField').value = 1;

    $('monthlyMonthsField').value = 1;
    $('recurrence_form').setRadioValue('monthlyRadioButtonName', 0);

    $('yearlyYearsField').value = 1;
    $('recurrence_form').setRadioValue('yearlyRadioButtonName', 0);
    $('yearlyDayField').value = 1;
    
  }

  $('recurrence_form').setRadioValue('rangeRadioButtonName', parent$("range1").value);

  if (parent$("range1").value == 1) {
    $('rangeAppointmentsField').value = parent$("range2").value;
  }
  else if (parent$("range1").value == 2) {
    $('endDate').value = parent$("range2").value;
  }
}

function onEditorOkClick(event) {
   preventDefault(event);
   var v;

   parent$("repeatType").value = $("repeatType").value;

   if ($("repeatType").value == 0) {
     parent$("repeat1").value = $('recurrence_form').getRadioValue('dailyRadioButtonName');
     parent$("repeat2").value = $('dailyDaysField').value;

     // We check if the dailyDaysField really contains an integer
     v = parseInt(parent$("repeat2").value);
     if (parent$("repeat1").value == 0 && (isNaN(v) || v <= 0)) {
       window.alert("Please specify a numerical value in the Days field greater or equal to 1.");
       return false;
     }
   } 
   else if ($("repeatType").value == 1) {
     parent$("repeat1").value = $('weeklyWeeksField').value;
     parent$("repeat2").value = $('recurrence_form').getCheckBoxListValues('weeklyCheckBoxName');

     // We check if the weeklyWeeksField really contains an integer
     v = parseInt(parent$("repeat1").value);
     if (isNaN(v) || v <= 0) {
       window.alert("Please specify a numerical value in the Week(s) field greater or equal to 1.");
       return false;
     }
   }
   else if ($("repeatType").value == 2) {
     parent$("repeat1").value = $('monthlyMonthsField').value;
     parent$("repeat2").value = $('recurrence_form').getRadioValue('monthlyRadioButtonName');
     parent$("repeat3").value = $('monthlyRepeat').value;
     parent$("repeat4").value = $('monthlyDay').value;
     parent$("repeat5").value = $('recurrence_form').getCheckBoxListValues('monthlyCheckBoxName');
     
     // We check if the monthlyMonthsField really contains an integer
     v = parseInt(parent$("repeat1").value);
     if (isNaN(v) || v <= 0) {
       window.alert("Please specify a numerical value in the Month(s) field greater or equal to 1.");
       return false;
     }
   }
   else {
     parent$("repeat1").value = $('yearlyYearsField').value;
     parent$("repeat2").value = $('recurrence_form').getRadioValue('yearlyRadioButtonName');
     parent$("repeat3").value = $('yearlyDayField').value;
     parent$("repeat4").value = $('yearlyMonth1').value;
     parent$("repeat5").value = $('yearlyRepeat').value;
     parent$("repeat6").value = $('yearlyDay').value;
     parent$("repeat7").value = $('yearlyMonth2').value;

     // We check if the yearlyYearsField really contains an integer
     v = parseInt(parent$("repeat1").value);
     if (isNaN(v) || v <= 0) {
       window.alert("Please specify a numerical value in the Year(s) field greater or equal to 1.");
       return false;
     }
   }

   parent$("range1").value = $('recurrence_form').getRadioValue('rangeRadioButtonName');

   if (parent$("range1").value == 1) {
     parent$("range2").value = $('rangeAppointmentsField').value;

     // We check if the rangeAppointmentsField really contains an integer
     v = parseInt(parent$("range2").value);
     if (isNaN(v) || v <= 0) {
       window.alert("Please specify a numerical value in the Appointment(s) field  greater or equal to 1.");
       return false;
     }
   }
   else if (parent$("range1").value == 2) {
     parent$("range2").value = $('endDate').value;
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
}

FastInit.addOnLoad(onRecurrenceLoadHandler);
