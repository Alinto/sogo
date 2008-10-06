/* -*- Mode: java; tab-width: 2; c-tab-always-indent: t; indent-tabs-mode: t; c-basic-offset: 2 -*- */

function onPrintCurrentMessage(event) {
  window.print();

  preventDefault(event);
}

function initPopupMailer(event) {
  configureLinksInMessage();
  resizeMailContent();

	var loadImagesButton = $("loadImagesButton");
	if (loadImagesButton)
		loadImagesButton.observe("click",
														 onMessageLoadImages.bindAsEventListener(loadImagesButton));

	configureLoadImagesButton();
}

function onMessageLoadImages(event) {
	var msguid = window.opener.Mailer.currentMessages[window.opener.Mailer.currentMailbox];
	var url = (window.opener.ApplicationBaseURL + window.opener.encodeURI(window.opener.Mailer.currentMailbox) + "/"
						 + msguid + "/view?noframe=1&unsafe=1");
	document.messageAjaxRequest
		= triggerAjaxRequest(url, messageCallback, msguid);
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
		var rowId_index = window.name.search(/[0-9]+$/);
    var rowId = window.name.substr(rowId_index);
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
