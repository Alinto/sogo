var MailerUIdTreeExtension = {
   elementCounter: 1,
   folderIcons: { account: "tbtv_account_17x17.gif",
		  inbox: "tbtv_inbox_17x17.gif",
		  sent: "tbtv_sent_17x17.gif",
		  draft: "tbtv_drafts_17x17.gif",
		  trash: "tbtv_trash_17x17.gif" },
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
      var fullName = "";
      var currentFolder = folder;
      while (currentFolder) {
	 fullName = "/" + currentFolder.name + fullName;
	 currentFolder = currentFolder.parentFolder;
      }
      this._addFolderNode(parent, folder.name, fullName, folder.type);
      for (var i = 0; i < folder.children.length; i++)
      this._addFolder(thisCounter, folder.children[i]);
   },
   addMailAccount: function (mailAccount) {
      this._addFolder(0, mailAccount);
   }
};

Object.extend(dTree.prototype, MailerUIdTreeExtension);
