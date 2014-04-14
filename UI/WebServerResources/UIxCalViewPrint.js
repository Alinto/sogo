/* -*- Mode: js2-mode; tab-width: 4; c-label-minimum-indentation: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

/*
	Copyright (C) 2005 SKYRIX Software AG
	Copyright (C) 2006-2011 Inverse

	This file is part of OpenGroupware.org.

	OGo is free software; you can redistribute it and/or modify it under
	the terms of the GNU Lesser General Public License as published by the
	Free Software Foundation; either version 2, or (at your option) any
	later version.

	OGo is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or
	FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
	License for more details.

	You should have received a copy of the GNU Lesser General Public
	License along with OGo; see the file COPYING.  If not, write to the
	Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
	02111-1307, USA.
*/


this.onAdjustTime = function(event) {
	onAdjustDueTime(event);
};

this.onAdjustDueTime = function(event) {
  /*var dateDelta = (window.getStartDate().valueOf() - window.getShadowStartDate().valueOf());
  var newDueDate = new Date(window.getDueDate().valueOf() + dateDelta);
  window.setDueDate(newDueDate);*/

	window.timeWidgets['start']['date'].updateShadowValue();
};

this.initTimeWidgets = function (widgets) {
	this.timeWidgets = widgets;
  
  jQuery(widgets['start']['date']).closest('.date').datepicker({autoclose: true, weekStart: 0, position: "bellow"});
  jQuery(widgets['end']['date']).closest('.date').datepicker({autoclose: true, weekStart: 0, position: "bellow"});
  
  //jQuery(widgets['start']['date']).change(onAdjustTime);
  
  /*jQuery(widgets['startingDate']['date']).closest('.date').datepicker({autoclose: true,
                                                                   weekStart: 0,
                                                                     endDate: lastDay,
                                                                   startDate: firstDay,
                                                                setStartDate: lastDay,
                                                                   startView: 2,
                                                                    position: "below-shifted-left"});*/
};




function onPrintCancelClick(event) {
  this.blur();
  onCloseButtonClick(event);
}

function onPrintClick(event) {
  this.blur();
  window.print();
}



function init() {
  
  $("cancelButton").observe("click", onPrintCancelClick);
  $("printButton").observe("click", onPrintClick);
  
  var widgets = {'start': {'date': $("startingDate")},
                 'end':   {'date': $("endingDate")}};
  initTimeWidgets(widgets);

}

document.observe("dom:loaded", init);
