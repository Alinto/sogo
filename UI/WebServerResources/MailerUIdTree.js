var MailerUIdTreeExtension = {
    elementCounter: 1,
    folderIcons: { account: "tbtv_account_17x17.png",
                   inbox: "tbtv_inbox_17x17.png",
                   sent: "tbtv_sent_17x17.png",
                   draft: "tbtv_drafts_17x17.png",
                   trash: "tbtv_trash_17x17.png",
                   junk: "tb-mail-junk-flat-17x17.png" },
    folderNames: { inbox: _("InboxFolderName"),
                   sent: _("SentFolderName"),
                   draft: _("DraftsFolderName"),
                   trash: _("TrashFolderName"),
                   junk: _("JunkFolderName") },
    _addFolderNode: function (parent, name, fullName, type, unseen) {
        var icon = this.folderIcons[type];
        if (icon)
            icon = ResourcesURL + "/"  + icon;
        else
            icon = "";
        var displayName = this.folderNames[type];
        if (!displayName)
            displayName = name;
        displayName += "<span class=\"unseenCount hidden\"> (" + parseInt(unseen) + ")</span>";
        this.add(this.elementCounter, parent, displayName, 1, '#', fullName,
                 type, '', '', icon, icon, true);
        this.elementCounter++;
    },
    _addFolder: function (parent, folder) {
        var thisCounter = this.elementCounter;
        this._addFolderNode(parent, folder.displayName, folder.fullName(), folder.type, folder.unseen);
        for (var i = 0; i < folder.children.length; i++)
            this._addFolder(thisCounter, folder.children[i]);
    },
    addMailAccount: function (mailAccount) {
        this._addFolder(0, mailAccount);
    },
    setCookie: function(cookieName, cookieValue, expires, path, domain, secure) {

    },
    getCookie: function(cookieName) {
        return ("");
    },
    updateCookie: function () {
        if (Mailer.foldersStateTimer)
            clearTimeout(Mailer.foldersStateTimer);
        Mailer.foldersStateTimer = setTimeout('saveFoldersState()', 3000); // 3 seconds
    },
    getFoldersState: function () {
        var expandedFolders = new Array();
        for (var n = 0; n < this.aNodes.length; n++) {
            if (this.aNodes[n]._io && this.aNodes[n].pid != this.root.id) {
                expandedFolders.push(this.aNodes[n].dataname);
            }
        }
        return Object.toJSON(expandedFolders);
    },
    autoSync: function() {
        this.config.useCookies = true;
    },
    getMailboxNode: function(mailbox) {
        var childNode = null;
        for (var i = 0; (childNode == null) && (i < this.aNodes.length); i++) {
            var aNode = this.aNodes[i];
            if (aNode.dataname == mailbox) {
                childNode = $("smailboxTree" + aNode.id);
            }
        }

        return ((childNode) ? childNode.parentNode : null);
    }
};

Object.extend(dTree.prototype, MailerUIdTreeExtension);
