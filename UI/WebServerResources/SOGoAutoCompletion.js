/* -*- Mode: java; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

//  NOTE: The popup menu with id "contactsMenu" must exist before
//  using this interface.
// 
//  This interface fires two events:
//   - autocompletion:changed : fired when a new contact is selected
//   - autocompletion:changedlist : fired when a new list is selected
//
var SOGoAutoCompletionInterface = {

    // Attributes that could be changed from the object
    // inheriting the inteface
    uidField: "c_name",
    addressBook: null,
    excludeGroups: false,
    excludeLists: false,

    // Internal attributes
    animationParent: null,
    selectedIndex: -1,
    delay: 0.750,
    delayedSearch: false,
    menu: null,

    bind: function () {
        this.menu = $('contactsMenu');
        this.writeAttribute("autocomplete", "off");
        this.writeAttribute("container", null);
        this.confirmedValue = null;
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
                this.writeAttribute("uid", null);
             if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
        }
        else if (event.keyCode == 0
                 || event.keyCode == Event.KEY_BACKSPACE
                 || event.keyCode == Event.KEY_DELETE
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
            else
                this.writeAttribute("uid", null);
            if (document.currentPopupMenu)
                hideMenu(document.currentPopupMenu);
            this.selectedIndex = -1;
            if (this.readAttribute("container")) {
                this.confirmedValue = null;
                this.fire("autocompletion:changedlist", this.readAttribute("container"));
            }
            else
                this.fire("autocompletion:changed", event.keyCode);
        }
        else if (this.menu.getStyle('visibility') == 'visible') {
            if (event.keyCode == Event.KEY_UP) { // Up arrow
                if (this.selectedIndex > 0) {
                    var contacts = this.menu.select("li");
                    contacts[this.selectedIndex--].removeClassName("selected");
                    this.value = contacts[this.selectedIndex].readAttribute("address");
                    this.confirmedValue = this.value;
                    this.writeAttribute("uid", contacts[this.selectedIndex].readAttribute("uid"));
                    contacts[this.selectedIndex].addClassName("selected");
                    var container = contacts[this.selectedIndex].readAttribute("container");
                    if (container)
                        this.writeAttribute("container", container);
                }
            }
            else if (event.keyCode == Event.KEY_DOWN) { // Down arrow
                var contacts = this.menu.select("li");
                if (contacts.size() - 1 > this.selectedIndex) {
                    if (this.selectedIndex >= 0)
                        contacts[this.selectedIndex].removeClassName("selected");
                    this.selectedIndex++;
                    this.value = contacts[this.selectedIndex].readAttribute("address");
                    this.confirmedValue = this.value;
                    this.writeAttribute("uid", contacts[this.selectedIndex].readAttribute("uid"));
                    contacts[this.selectedIndex].addClassName("selected");
                    var container = contacts[this.selectedIndex].readAttribute("container");
                    if (container)
                        this.writeAttribute("container", container);
                }
            }
        }
    },

    onBlur: function (event) {
        if (this.delayedSearch)
            window.clearTimeout(this.delayedSearch);
        if (this.confirmedValue) {
            this.value = this.confirmedValue;
            if (this.readAttribute("container"))
                this.fire("autocompletion:changedlist", this.readAttribute("container"));
            else
                this.fire("autocompletion:changed", event.keyCode);
        }
        else
            this.writeAttribute("uid", null);
    },

    performSearch: function (input) {
        // Perform address completion
        if (document.contactLookupAjaxRequest) {
            // Abort any pending request
            document.contactLookupAjaxRequest.aborted = true;
            document.contactLookupAjaxRequest.abort();
        }
        if (input.value.trim().length > minimumSearchLength) {
            var urlstr = UserFolderURL + "Contacts/";
            if (input.addressBook)
                urlstr += input.addressBook + "/contact";
            else
                urlstr += "allContact";
            urlstr += "Search?search=" + encodeURIComponent(input.value);
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
                        var node = new Element('li', { 'address': completeEmail,
                                                       'uid': contact[this.uidField] });
                        var matchPosition = completeEmail.toLowerCase().indexOf(data.searchText.toLowerCase());
                        if (matchPosition > -1) {
                            var matchBefore = completeEmail.substring(0, matchPosition);
                            var matchText = completeEmail.substring(matchPosition, matchPosition + data.searchText.length);
                            var matchAfter = completeEmail.substring(matchPosition + data.searchText.length);
                            node.appendChild(document.createTextNode(matchBefore));
                            node.appendChild(new Element('strong').update(matchText));
                            node.appendChild(document.createTextNode(matchAfter));
                        }
                        else {
                            node.appendChild(document.createTextNode(completeEmail));
                        }
                        list.appendChild(node);
                        if (contact['c_name'].endsWith (".vlf")) {
                            // Keep track of list containers
                            node.writeAttribute("container", contact['container']);
                        }
                        if (contact["contactInfo"])
                            node.appendChild(document.createTextNode(" (" + contact["contactInfo"] + ")"));
                        $(node).observe("mousedown", this.onAddressResultClick.bindAsEventListener(this));
                    }

                    // Show popup menu
                    var offsetScroll = Element.cumulativeScrollOffset(input);
                    var offset = Element.positionedOffset(input);
                    if ($(document.body).hasClassName("popup") && typeof initPopupMailer == 'undefined')
                    // Hack for some situations where the offset must be computed differently
                         offset = Element.cumulativeOffset(input);
                    var top = offset.top - offsetScroll.top + node.offsetHeight + 3;
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
                else {
                    if (document.currentPopupMenu)
                        hideMenu(document.currentPopupMenu);

                    if (data.contacts.length == 1) {
                        // Single result
                        var contact = data.contacts[0];
                        input.writeAttribute("uid", contact[this.uidField]);
                        if (contact['c_name'].endsWith(".vlf")) {
                            this.writeAttribute("container", contact['container']);
                        }
                        var completeEmail = contact["c_cn"];
                        if (contact["c_mail"])
                            completeEmail += " <" + contact["c_mail"] + ">";
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
            preventDefault(event);
            this.value = e.readAttribute("address");
            this.writeAttribute("uid", e.readAttribute("uid"));
            if (e.readAttribute("container"))
                this.fire("autocompletion:changedlist", e.readAttribute("container"));
            else {
                this.confirmedValue = this.value;
                this.fire("autocompletion:changed", Event.KEY_RETURN);
            }
        }
    }
};
