/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 2; -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxesController.$inject = ['$scope', '$state', '$timeout', '$window', '$mdDialog', '$mdToast', '$mdMedia', '$mdSidenav', 'sgConstant', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'sgHotkeys', 'Account', 'Mailbox', 'VirtualMailbox', 'User', 'Preferences', 'stateAccounts'];
  function MailboxesController($scope, $state, $timeout, $window, $mdDialog, $mdToast, $mdMedia, $mdSidenav, sgConstant, focus, encodeUriFilter, Dialog, Settings, sgHotkeys, Account, Mailbox, VirtualMailbox, User, Preferences, stateAccounts) {
    var vm = this,
        account,
        mailbox,
        hotkeys = [];

    vm.service = Mailbox;
    vm.accounts = stateAccounts;
    vm.toggleAccountState = toggleAccountState;
    vm.subscribe = subscribe;
    vm.newFolder = newFolder;
    vm.delegate = delegate;
    vm.editFolder = editFolder;
    vm.revertEditing = revertEditing;
    vm.selectFolder = selectFolder;
    vm.saveFolder = saveFolder;
    vm.compactFolder = compactFolder;
    vm.emptyTrashFolder = emptyTrashFolder;
    vm.confirmDelete = confirmDelete;
    vm.markFolderRead = markFolderRead;
    vm.share = share;
    vm.metadataForFolder = metadataForFolder;
    vm.setFolderAs = setFolderAs;
    vm.refreshUnseenCount = refreshUnseenCount;
    vm.isDroppableFolder = isDroppableFolder;
    vm.dragSelectedMessages = dragSelectedMessages;

    // Advanced search options
    vm.showingAdvancedSearch = false;
    vm.currentSearchParam = '';
    vm.addSearchParam = addSearchParam;
    vm.newSearchParam = newSearchParam;
    vm.showAdvancedSearch = showAdvancedSearch;
    vm.hideAdvancedSearch = hideAdvancedSearch;
    vm.toggleAdvancedSearch = toggleAdvancedSearch;
    vm.search = {
      options: {'': l('Select a criteria'),
                subject: l('Enter Subject'),
                from: l('Enter From'),
                to: l('Enter To'),
                cc: l('Enter Cc'),
                body: l('Enter Body')
               },
      mailbox: 'INBOX',
      subfolders: 1,
      match: 'AND',
      params: []
    };


    Preferences.ready().then(function() {
      vm.showSubscribedOnly = Preferences.defaults.SOGoMailShowSubscribedFoldersOnly;
    });

    vm.refreshUnseenCount();

    _registerHotkeys(hotkeys);

    $scope.$on('$destroy', function() {
      // Deregister hotkeys
      _.forEach(hotkeys, function(key) {
        sgHotkeys.deregisterHotkey(key);
      });
    });


    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: 'backspace',
        description: l('Delete selected message or folder'),
        callback: function() {
          if (Mailbox.selectedFolder && !Mailbox.selectedFolder.hasSelectedMessage())
            confirmDelete(Mailbox.selectedFolder);
        }
      }));

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    function showAdvancedSearch(path) {
      vm.showingAdvancedSearch = true;
      vm.search.mailbox = path;
      // Close sidenav on small devices
      if (!$mdMedia(sgConstant['gt-md']))
        $mdSidenav('left').close();
    }

    function hideAdvancedSearch() {
      vm.showingAdvancedSearch = false;
      vm.service.$virtualMode = false;

      account = vm.accounts[0];
      mailbox = vm.searchPreviousMailbox;
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(mailbox.path) });
    }

    function toggleAdvancedSearch() {
      if (Mailbox.selectedFolder.$isLoading) {
        // Stop search
        vm.virtualMailbox.stopSearch();
      }
      else {
        // Start search
        var root, mailboxes = [],
            _visit = function(folders) {
              _.forEach(folders, function(o) {
                mailboxes.push(o);
                if (o.children && o.children.length > 0) {
                  _visit(o.children);
                }
              });
            };

        vm.virtualMailbox = new VirtualMailbox(vm.accounts[0]);

        // Don't set the previous selected mailbox if we're in virtual mode
        // That allows users to do multiple advanced search but return
        // correctly to the previously selected mailbox once done.
        if (!Mailbox.$virtualMode)
          vm.searchPreviousMailbox = Mailbox.selectedFolder;

        Mailbox.selectedFolder = vm.virtualMailbox;
        Mailbox.$virtualMode = true;

        if (angular.isDefined(vm.search.mailbox)) {
          root = vm.accounts[0].$getMailboxByPath(vm.search.mailbox);
          mailboxes.push(root);
          if (vm.search.subfolders && root.children.length)
            _visit(root.children);
        }
        else {
          mailboxes = vm.accounts[0].$flattenMailboxes();
        }

        vm.virtualMailbox.setMailboxes(mailboxes);
        vm.virtualMailbox.startSearch(vm.search.match, vm.search.params);
        $state.go('mail.account.virtualMailbox', { accountId: vm.accounts[0].id });
      }
    }

    function addSearchParam(v) {
      vm.currentSearchParam = v;
      focus('advancedSearch');
      return false;
    }

    function newSearchParam(pattern) {
      if (pattern.length && vm.currentSearchParam.length) {
        var n = 0, searchParam = vm.currentSearchParam;
        if (pattern.startsWith("!")) {
          n = 1;
          pattern = pattern.substring(1).trim();
        }
        vm.currentSearchParam = '';
        return { searchBy: searchParam, searchInput: pattern, negative: n };
      }
    }

    function toggleAccountState(account) {
      account.$expanded = !account.$expanded;
      account.$flattenMailboxes({ reload: true, saveState: true });
      // Fire a window resize to recompute the virtual-repeater.
      // This is a fix until the following issue is officially resolved:
      // https://github.com/angular/material/issues/7309
      $timeout(function() {
        angular.element($window).triggerHandler('resize');
      }, 150);
    }

    function subscribe(account) {
      $mdDialog.show({
        templateUrl: account.id + '/subscribe',
        controller: SubscriptionsDialogController,
        controllerAs: 'subscriptions',
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          metadataForFolder: metadataForFolder,
          srcAccount: account
        }
      }).finally(function() {
          account.$getMailboxes({reload: true});
      });

      /**
       * @ngInject
       */
      SubscriptionsDialogController.$inject = ['$scope', '$mdDialog', 'metadataForFolder', 'srcAccount'];
      function SubscriptionsDialogController($scope, $mdDialog, metadataForFolder, srcAccount) {
        var vm = this;

        vm.loading = true;
        vm.filter = { name: '' };
        vm.metadataForFolder = metadataForFolder;
        vm.account = new Account({
          id: srcAccount.id,
          name: srcAccount.name
        });
        vm.close = close;


        vm.account.$getMailboxes().then(function() {
          vm.loading = false;
        });


        function close() {
          $mdDialog.cancel();
        }
      }
    }

    function newFolder(parentFolder) {
      Dialog.prompt(l('New folder'),
                    l('Enter the new name of your folder :'))
        .then(function(name) {
          parentFolder.$newMailbox(parentFolder.id, name)
            .then(function() {
              // success
            }, function(data, status) {
              Dialog.alert(l('An error occured while creating the mailbox "%{0}".', name),
                           l(data.error));
            });
        });
    }

    function delegate(account) {
      $mdDialog.show({
        templateUrl: account.id + '/delegation', // UI/Templates/MailerUI/UIxMailUserDelegation.wox
        controller: MailboxDelegationController,
        controllerAs: 'delegate',
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          User: User,
          account: account
        }
      });

      /**
       * @ngInject
       */
      MailboxDelegationController.$inject = ['$scope', '$mdDialog', 'User', 'account'];
      function MailboxDelegationController($scope, $mdDialog, User, account) {
        var vm = this;

        vm.users = account.delegates;
        vm.account = account;
        vm.userToAdd = '';
        vm.searchText = '';
        vm.userFilter = userFilter;
        vm.closeModal = closeModal;
        vm.removeUser = removeUser;
        vm.addUser = addUser;

        function userFilter($query) {
          return User.$filter($query, account.delegates);
        }

        function closeModal() {
          $mdDialog.hide();
        }

        function removeUser(user) {
          account.$removeDelegate(user.uid).catch(function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'));
          });
        }

        function addUser(data) {
          if (data) {
            account.$addDelegate(data).then(function() {
              vm.userToAdd = '';
              vm.searchText = '';
            }, function(error) {
              Dialog.alert(l('Warning'), error);
            });
          }
        }
      }
    } // delegate

    function editFolder(folder) {
      vm.editMode = folder.path;
      focus('mailboxName_' + folder.path);
    }

    function revertEditing(folder) {
      folder.$reset();
      vm.editMode = false;
    }

    function selectFolder($event, account, folder) {
      if (vm.editMode == folder.path)
        return;
      vm.editMode = false;
      vm.showingAdvancedSearch = false;
      vm.service.$virtualMode = false;
      // Close sidenav on small devices
      if (!$mdMedia(sgConstant['gt-md']))
        $mdSidenav('left').close();
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(folder.path) });
      $event.stopPropagation();
      $event.preventDefault();
    }

    function saveFolder(folder) {
      folder.$rename()
        .then(function(data) {
          vm.editMode = false;
        });
    }

    function compactFolder(folder) {
      folder.$compact().then(function() {
        $mdToast.show(
          $mdToast.simple()
            .content(l('Folder compacted'))
            .position('top right')
            .hideDelay(3000));
      });
    }

    function emptyTrashFolder(folder) {
      folder.$emptyTrash().then(function() {
        $mdToast.show(
          $mdToast.simple()
            .content(l('Trash emptied'))
            .position('top right')
            .hideDelay(3000));
      });
    }

    function confirmDelete(folder) {
      Dialog.confirm(l('Confirmation'), l('Do you really want to move this folder into the trash ?'))
        .then(function() {
          folder.$delete()
            .then(function() {
              $state.go('mail.account.inbox');
            }, function(data, status) {
              Dialog.alert(l('An error occured while deleting the mailbox "%{0}".', folder.name),
                           l(data.error));
            });
        });
    }

    function markFolderRead(folder) {
      folder.$markAsRead();
    }

    function share(folder) {
      // Fetch list of ACL users
      folder.$acl.$users().then(function() {
        // Show ACL editor
        $mdDialog.show({
          templateUrl: folder.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: 'AclController', // from the ng module SOGo.Common
          controllerAs: 'acl',
          clickOutsideToClose: true,
          escapeToClose: true,
          locals: {
            usersWithACL: folder.$acl.users,
            User: User,
            folder: folder
          }
        });
      });
    } // share

    function metadataForFolder(folder) {
      if (folder.type == 'inbox')
        return {name: folder.name, icon:'inbox', special: true};
      else if (folder.type == 'draft')
        return {name: l('DraftsFolderName'), icon: 'drafts', special: true};
      else if (folder.type == 'sent')
        return {name: l('SentFolderName'), icon: 'send', special: true};
      else if (folder.type == 'trash')
        return {name: l('TrashFolderName'), icon: 'delete', special: true};
      else if (folder.type == 'junk')
        return {name: l('JunkFolderName'), icon: 'thumb_down', special: true};
      else if (folder.type == 'additional')
        return {name: folder.name, icon: 'folder_shared', special: true};

      return {name: folder.name, icon: 'folder_open', special: false};
    }

    function setFolderAs(folder, type) {
      folder.$setFolderAs(type).then(function() {
        folder.$account.$getMailboxes({reload: true});
      });
    }

    function refreshUnseenCount() {
      var unseenCountFolders = $window.unseenCountFolders;

      _.forEach(vm.accounts, function(account) {

        // Always include the INBOX
        if (!_.includes(unseenCountFolders, account.id + '/folderINBOX'))
          unseenCountFolders.push(account.id + '/folderINBOX');

        _.forEach(account.$$flattenMailboxes, function(mailbox) {
          if (angular.isDefined(mailbox.unseenCount) &&
              !_.includes(unseenCountFolders, mailbox.id))
            unseenCountFolders.push(mailbox.id);
        });
      });

      Account.$$resource.post('', 'unseenCount', {mailboxes: unseenCountFolders}).then(function(data) {
        _.forEach(vm.accounts, function(account) {
          _.forEach(account.$$flattenMailboxes, function(mailbox) {
            if (data[mailbox.id])
              mailbox.unseenCount = data[mailbox.id];
          });
        });
      });

      Preferences.ready().then(function() {
        var refreshViewCheck = Preferences.defaults.SOGoRefreshViewCheck;
        if (refreshViewCheck && refreshViewCheck != 'manually')
          $timeout(vm.refreshUnseenCount, refreshViewCheck.timeInterval()*1000);
      });
    }

    function isDroppableFolder(srcFolder, dstFolder) {
      return (dstFolder.id != srcFolder.id) && !dstFolder.isNoSelect();
    }

    function dragSelectedMessages(srcFolder, dstFolder, mode) {
      var dstId, messages, uids, clearMessageView, promise, success;

      dstId = '/' + dstFolder.id;
      messages = srcFolder.$selectedMessages();
      if (messages.length === 0)
        messages = [srcFolder.$selectedMessage()];
      uids = _.map(messages, 'uid');
      clearMessageView = (srcFolder.selectedMessage && uids.indexOf(srcFolder.selectedMessage) >= 0);

      if (mode == 'copy') {
        promise = srcFolder.$copyMessages(messages, dstId);
        success = l('%{0} message(s) copied', messages.length);
      }
      else {
        promise = srcFolder.$moveMessages(messages, dstId);
        success = l('%{0} message(s) moved', messages.length);
      }

      promise.then(function() {
        if (clearMessageView)
          $state.go('mail.account.mailbox');
        $mdToast.show(
          $mdToast.simple()
            .content(success)
            .position('top right')
            .hideDelay(2000));
      });
    }

  }

  angular
    .module('SOGo.MailerUI')
    .controller('MailboxesController', MailboxesController);
})();

