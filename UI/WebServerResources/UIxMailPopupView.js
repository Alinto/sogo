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

    if (UserDefaults["SOGoMailDisplayRemoteInlineImages"] == 'always')
        loadRemoteImages();

    window.messageUID = mailboxName + "/" + messageName;

    handleReturnReceipt();

    var td = $("subject");
    if (td)
        document.title = td.allTextContent();

    var button = $$(".tbicon_junk").first();
    button.stopObserving("click");

    if (window.mailboxType == "SOGoJunkFolder") {
        button.title = "Mark the selected messages as not junk";
        button.select('span').first().childNodes[3].nodeValue = "Not junk";
    }
    else {
        button.title = "Mark the selected messages as junk";
        button.select('span').first().childNodes[3].nodeValue = "Junk";
    }

    button.on("click", window.opener.onMarkOrUnmarkMessagesAsJunk.bind(button, (window.mailboxType == "SOGoJunkFolder")));
}

function onICalendarButtonClick(event) {
    var link = $("iCalendarAttachment").value;
    if (link) {
        var urlstr = link + "/" + this.action;
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
        var url = ApplicationBaseURL + encodeURI(mailboxName) + "/batchDelete";
        var path = mailboxName + "/" + messageName;
        
        window.opener.deleteMessageWithDelay(url, messageName, mailboxName, path);
    }
  
    window.close();
    return false;
}

document.observe("dom:loaded", initPopupMailer);
