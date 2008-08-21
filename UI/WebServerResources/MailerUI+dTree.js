var MailerUIdTreeExtension = {
   elementCounter: 1,
   folderIcons: { account: "tbtv_account_17x17.png",
		  inbox: "tbtv_inbox_17x17.png",
		  sent: "tbtv_sent_17x17.png",
		  draft: "tbtv_drafts_17x17.png",
		  trash: "tbtv_trash_17x17.png" },
   folderNames: { inbox: labels["InboxFolderName"],
		  sent: labels["SentFolderName"],
		  draft: labels["DraftsFolderName"],
		  trash: labels["TrashFolderName"] },
   _addFolderNode: function (parent, name, fullName, type) {
      var icon = this.folderIcons[type];
      if (icon)
        icon = ResourcesURL + "/"  + icon;
      else
        icon = "";
      var displayName = this.folderNames[type];
      if (!displayName)
        displayName = name;
      this.add(this.elementCounter, parent, displayName, 1, '#', fullName,
	       type, '', '', icon, icon);
      this.elementCounter++;
   },
   _addFolder: function (parent, folder) {
      var thisCounter = this.elementCounter;
      this._addFolderNode(parent, folder.name, folder.fullName(), folder.type);
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
    return expandedFolders.toJSON();
  },
  autoSync: function() {
    this.config.useCookies = true;
  }
};

Object.extend(dTree.prototype, MailerUIdTreeExtension);
