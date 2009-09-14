/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

function onPrintCurrentMessage(event) {
    window.print();

    preventDefault(event);
}

function initPopupMailer(event) {
    configureLinksInMessage();
    resizeMailContent();

    configureLoadImagesButton();
    configureSignatureFlagImage();
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
        var url = ApplicationBaseURL + encodeURI(mailboxName) + "/deleteMessages";
        var path = mailboxName + "/" + messageName;
        
        window.opener.deleteMessageWithDelay(url, messageName, mailboxName, path);
    }
  
    window.close();
    return false;
}

document.observe("dom:loaded", initPopupMailer);
