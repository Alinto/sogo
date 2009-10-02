/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

// The popup menu with id "contactsMenu" must exist before
// using this interface.
var SOGoAutoCompletionInterface = {
    uidField: "c_name",
    excludeGroups: false,
    animationParent: null,
    selectedIndex: -1,
    delay: 0.750,
    delayedSearch: false,
    menu: null,
    baseUrl: null,
    onListAdded: null,
    endEditable: null,

    bind: function () {
        this.menu = $('contactsMenu');
        this.writeAttribute("autocomplete", "off");
        this.observe("keydown", this.onKeydown.bindAsEventListener(this));
        this.observe("blur", this.onBlur.bindAsEventListener(this));
    },
    
    onKeydown: function (event) {
        if (event.ctrlKey || event.metaKey) {
            this.focussed = true;
            return;
        }
        if (event.keyCode == Event.KEY_TAB) {
            if (this.confirmedValue)
                this.value = this.confirmedValue;
            else
                this.uid = null;
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
            if (this.endEditable)
                this.endEditable ();
            if (this.onListAdded)
                this.onListAdded ();
        }
        else if (event.keyCode == 0
                 || event.keyCode == Event.KEY_BACKSPACE
                 || event.keyCode == 32  // Space
                 || event.keyCode > 47) {
            this.confirmedValue = null;
            this.selectedIndex = -1;
            if (this.delayedSearch)
                window.clearTimeout(this.delayedSearch);
            this.delayedSearch = this.performSearch.delay(this.delay, this);
        }
        else if (event.keyCode == Event.KEY_RETURN) {
            preventDefault(event);
            if (this.confirmedValue)
                this.value = this.confirmedValue;
            $(this).select();
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
            this.selectedIndex = -1;
            if (this.endEditable)
                this.endEditable ();
            if (this.onListAdded)
                this.onListAdded ();
        }
        else if (this.menu.getStyle('visibility') == 'visible') {
            if (event.keyCode == Event.KEY_UP) { // Up arrow
                if (this.selectedIndex > 0) {
                    var contacts = this.menu.select("li");
                    contacts[this.selectedIndex--].removeClassName("selected");
                    this.value = contacts[this.selectedIndex].readAttribute("address");
                    this.uid = contacts[this.selectedIndex].uid;
                    contacts[this.selectedIndex].addClassName("selected");
                    var e = contacts[this.selectedIndex];
                    this.writeAttribute("card", e.readAttribute("card"));
                    this.writeAttribute("mail", e.readAttribute("mail"));
                    this.writeAttribute("uname", e.readAttribute("uname"));
                    this.writeAttribute("container", e.readAttribute("container"));
                }
            }
            else if (event.keyCode == Event.KEY_DOWN) { // Down arrow
                var contacts = this.menu.select("li");
                if (contacts.size() - 1 > this.selectedIndex) {
                    if (this.selectedIndex >= 0)
                        contacts[this.selectedIndex].removeClassName("selected");
                    this.selectedIndex++;
                    this.value = contacts[this.selectedIndex].readAttribute("address");
                    this.uid = contacts[this.selectedIndex].uid;
                    contacts[this.selectedIndex].addClassName("selected");
                    var e = contacts[this.selectedIndex];
                    this.writeAttribute("card", e.readAttribute("card"));
                    this.writeAttribute("mail", e.readAttribute("mail"));
                    this.writeAttribute("uname", e.readAttribute("uname"));
                    this.writeAttribute("container", e.readAttribute("container"));
                }
            }
        }
    },

    onBlur: function (event) {
        if (this.delayedSearch)
            window.clearTimeout(this.delayedSearch);
        if (this.confirmedValue)
            this.value = this.confirmedValue;
        else
            this.uid = null;
    },

    performSearch: function (input) {
        // Perform address completion
        if (document.contactLookupAjaxRequest) {
            // Abort any pending request
            document.contactLookupAjaxRequest.aborted = true;
            document.contactLookupAjaxRequest.abort();
        }
        if (input.value.trim().length > 2) {
            var urlstr = (UserFolderURL + "Contacts/allContactSearch?search="
                          + encodeURIComponent(input.value));
            if (input.baseUrl)
                urlstr = input.baseUrl + encodeURIComponent(input.value);
            if (input.excludeGroups)
                urlstr += "&excludeGroups=1";
            if (input.excludeLists)
                urlstr += "&excludeLists=1";
            if (input.animationParent)
                startAnimation(input.animationParent);
            document.contactLookupAjaxRequest =
            triggerAjaxRequest(urlstr, input.performSearchCallback.bind(input), input);
        }
        else {
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
        }
    },

    performSearchCallback: function (http) {
        if (http.readyState == 4) {
            var list = this.menu.down("ul");

            var input = http.callbackData;

            if (http.status == 200) {
                var start = input.value.length;
                var data = http.responseText.evalJSON(true);

                if (data.contacts.length > 1) {
                    list.select("li").each(function(item) {
                            item.stopObserving("mousedown");
                            item.remove();
                        });

                    // Populate popup menu
                    for (var i = 0; i < data.contacts.length; i++) {
                        var contact = data.contacts[i];
                        var completeEmail = contact["c_cn"];
                        if (contact["c_mail"])
                            completeEmail += " <" + contact["c_mail"] + ">";
                        var node = new Element('li', { 'address': completeEmail });
                        var matchPosition = completeEmail.toLowerCase().indexOf(data.searchText.toLowerCase());
                        var matchBefore = completeEmail.substring(0, matchPosition);
                        var matchText = completeEmail.substring(matchPosition, matchPosition + data.searchText.length);
                        var matchAfter = completeEmail.substring(matchPosition + data.searchText.length);
                        list.appendChild(node);
                        node.writeAttribute ("card", contact['c_name']);
                        node.writeAttribute ("uid", contact['c_mail']);
                        if (contact['c_name'].endsWith (".vlf")) {
                            node.writeAttribute("container", contact['container']);
                        }
                        else {
                            node.writeAttribute("mail", contact['c_mail']);
                            node.writeAttribute("uname", contact['c_cn']);
                            node.writeAttribute("container", contact['container']);
                        }
                        node.appendChild(document.createTextNode(matchBefore));
                        node.appendChild(new Element('strong').update(matchText));
                        node.appendChild(document.createTextNode(matchAfter));
                        if (contact["contactInfo"])
                            node.appendChild(document.createTextNode(" (" + contact["contactInfo"] + ")"));
                        $(node).observe("mousedown", this.onAddressResultClick.bindAsEventListener(this));
                    }

                    // Show popup menu
                    var offsetScroll = Element.cumulativeScrollOffset(input);
                    var offset = Element.cumulativeOffset(input);
                    var top = offset[1] - offsetScroll[1] + node.offsetHeight + 3;
                    var height = 'auto';
                    var heightDiff = window.height() - offset[1];
                    var nodeHeight = node.getHeight();

                    if ((data.contacts.length * nodeHeight) > heightDiff)
                        // Limit the size of the popup to the window height, minus 12 pixels
                        height = parseInt(heightDiff/nodeHeight) * nodeHeight - 12 + 'px';

                    this.menu.setStyle({ top: top + "px",
                                left: offset[0] + "px",
                                height: height,
                                visibility: "visible" });
                    this.menu.scrollTop = 0;

                    document.currentPopupMenu = this.menu;
                    $(document.body).stopObserving("click");
                    $(document.body).observe("click", onBodyClickMenuHandler);
                }
                else { // Only one result
                    if (document.currentPopupMenu)
                        hideMenu(document.currentPopupMenu);

                    if (data.contacts.length == 1) {
                        // Single result
                        var contact = data.contacts[0];
                        input.uid = contact[this.uidField];
                        if (contact['c_name'].endsWith (".vlf") && this.onListAdded) {
                            this.writeAttribute("container", contact['container']);
                            this.writeAttribute("card", contact['c_name']);
                            this.onListAdded ();
                        }
                        else {
                            input.writeAttribute("card", contact['c_name']);
                            input.writeAttribute("mail", contact['c_mail']);
                            input.writeAttribute("uname", contact['c_cn']);
                            var completeEmail = contact["c_cn"] + " <" + contact["c_mail"] + ">";
                            if (contact["c_cn"].substring(0, input.value.length).toUpperCase()
                                == input.value.toUpperCase())
                                input.value = completeEmail;
                            else
                                // The result matches email address, not user name
                                input.value += ' >> ' + completeEmail;
                            input.confirmedValue = completeEmail;

                            var end = input.value.length;
                            $(input).selectText(start, end);

                            this.selectedIndex = -1;
                        }
                    }
                }
            }
            else
                if (document.currentPopupMenu)
                    hideMenu(document.currentPopupMenu);
            document.contactLookupAjaxRequest = null;
        }
    },

    onAddressResultClick: function(event) {
        var e = Event.element(event);
        if (e.tagName != 'LI')
            e = e.up('LI');
        if (e) {
            var card = e.readAttribute("card");
            this.writeAttribute("card", card);
            if (card.endsWith (".vlf") && this.onListAdded) {
                this.writeAttribute("container", e.readAttribute("container"));
                this.onListAdded ();
            }
            else {
                this.writeAttribute("mail", e.readAttribute("mail"));
                this.writeAttribute("uname", e.readAttribute("uname"));
            }
            this.writeAttribute("uid", e.readAttribute("uid"));
            this.value = e.readAttribute("address");
            this.confirmedValue = this.value;
            if (this.endEditable)
                this.endEditable ();
        }
    }
};
