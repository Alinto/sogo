function onPrintCurrentMessage(event) {
  window.print();

  preventDefault(event);
}

function initPopupMailer(event) {
  configureLinksInMessage();
  resizeMailContent();
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
