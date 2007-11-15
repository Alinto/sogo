function onPrintCurrentMessage(event) {
  window.print();

  preventDefault(event);
}

function initPopupMailer(event) {
  configureLinksInMessage();
  resizeMailContent();
}

FastInit.addOnLoad(initPopupMailer);
