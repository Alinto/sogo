function onPrintCurrentMessage(event) {
  window.print();

  preventDefault(event);
}

function initMailerPopup(event) {
  var headerTable = document.getElementsByClassName('mailer_fieldtable')[0];
  var contentDiv = document.getElementsByClassName('mailer_mailcontent')[0];

  contentDiv.setStyle({ 'top': (Element.getHeight(headerTable) + headerTable.offsetTop) + 'px' });
}

addEvent(window, 'load', initMailerPopup);
