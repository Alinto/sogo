function onPrintCurrentMessage(event) {
  window.print();

  preventDefault(event);
}

function initPopupMailer(event) {
  configureLinksInMessage();
  resizeMailContent();
}

addEvent(window, 'load', initPopupMailer);
