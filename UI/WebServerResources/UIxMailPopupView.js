/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function onPrintCurrentMessage(event) {
  window.print();

  preventDefault(event);
}

function initPopupMailer(event) {
  configureLinksInMessage();
  resizeMailContent();
}

function onICalendarButtonClick(event) {
  var link = $("iCalendarAttachment").value;
  if (link) {
    var urlstr = link + "/" + this.action;
    var currentMsg;
    if (window.opener && window.opener.open && !window.opener.closed && window.messageUID) {
      var c = window.opener;
      window.opener.triggerAjaxRequest(urlstr,
																			 window.opener.ICalendarButtonCallback,
																			 window.messageUID);
    }
  }  
  else
    log("no link");
}

function onMenuDeleteMessage(event) {
  if (window.opener && window.opener.open && !window.opener.closed) {
    var rowId = window.name.substr(9);
    var messageId = window.opener.Mailer.currentMailbox + "/" + rowId;
    var url = ApplicationBaseURL + messageId + "/trash";

    window.opener.deleteMessageWithDelay(url,
																				 rowId,
																				 window.opener.Mailer.currentMailbox,
																				 messageId);
  }
  
  window.close();
  return false;
}

FastInit.addOnLoad(initPopupMailer);
