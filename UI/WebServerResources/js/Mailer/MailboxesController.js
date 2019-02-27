/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 2; -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxesController.$inject = ['$scope', '$state', '$transitions', '$timeout', '$window', '$mdUtil', '$mdMedia', '$mdSidenav', '$mdDialog', '$mdToast', 'sgConstant', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'sgHotkeys', 'Account', 'Mailbox', 'VirtualMailbox', 'User', 'Preferences', 'stateAccounts'];
  function MailboxesController($scope, $state, $transitions, $timeout, $window, $mdUtil, $mdMedia, $mdSidenav, $mdDialog, $mdToast, sgConstant, focus, encodeUriFilter, Dialog, Settings, sgHotkeys, Account, Mailbox, VirtualMailbox, User, Preferences, stateAccounts) {
    var vm = this,
        account,
        mailbox,
        hotkeys = [];

    this.$onInit = function () {
      this.service = Mailbox;
      this.accounts = stateAccounts;

      // Advanced search options
      this.currentSearchParam = '';
      this.search = {
        options: {'': '',  // no placeholder when no criteria is active
                  subject: l('Enter Subject'),
                  from:    l('Enter From'),
                  to:      l('Enter To'),
                  cc:      l('Enter Cc'),
                  body:    l('Enter Body')
                 },
        subfolders: 1,
        match: 'AND',
        params: []
      };

      this.showSubscribedOnly = Preferences.defaults.SOGoMailShowSubscribedFoldersOnly;

      this.refreshUnseenCount();

      _registerHotkeys(hotkeys);

      $scope.$on('$destroy', function() {
        // Deregister hotkeys
        _.forEach(hotkeys, function(key) {
          sgHotkeys.deregisterHotkey(key);
        });
      });
    };


    function _registerHotkeys(keys) {
      _.forEach(['backspace', 'delete'], function(hotkey) {
        keys.push(sgHotkeys.createHotkey({
          key: hotkey,
          description: l('Delete selected message or folder'),
          callback: function() {
            if (Mailbox.selectedFolderController && Mailbox.selectedFolder && Mailbox.selectedFolder.$isEditable && !Mailbox.selectedFolder.hasSelectedMessage())
              Mailbox.selectedFolderController.confirmDelete(Mailbox.selectedFolder);
          }
        }));
      });

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    this.hideAdvancedSearch = function() {
      vm.service.$virtualPath = false;
      vm.service.$virtualMode = false;

      account = vm.accounts[0];
      mailbox = vm.searchPreviousMailbox;
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(mailbox.path) });
    };

    this.toggleAdvancedSearch = function() {
      if (Mailbox.selectedFolder.$isLoading) {
        // Stop search
        vm.virtualMailbox.stopSearch();
      }
      else {
        // Start search
        var root, mailboxes = [],
            _visit = function(folders) {
              _.forEach(folders, function(o) {
                if (!o.isNoSelect())
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

        if (Mailbox.$virtualPath.length) {
          root = vm.accounts[0].$getMailboxByPath(Mailbox.$virtualPath);
          mailboxes.push(root);
          if (vm.search.subfolders && root.children.length)
            _visit(root.children);
        }
        else {
          mailboxes = _.filter(vm.accounts[0].$flattenMailboxes({ all: true }), function(mailbox) {
            return !mailbox.isNoSelect();
          });
        }

        vm.virtualMailbox.setMailboxes(mailboxes);
        vm.virtualMailbox.startSearch(vm.search.match, vm.search.params);
        if ($state.$current.name != 'mail.account.virtualMailbox')
          $state.go('mail.account.virtualMailbox', { accountId: vm.accounts[0].id });
      }
    };

    this.addSearchParam = function(v) {
      this.currentSearchParam = v;
      focus('advancedSearch');
      return false;
    };

    this.newSearchParam = function(pattern) {
      if (pattern.length && this.currentSearchParam.length) {
        var n = 0, searchParam = this.currentSearchParam;
        if (pattern.startsWith("!")) {
          n = 1;
          pattern = pattern.substring(1).trim();
        }
        this.currentSearchParam = '';
        return { searchBy: searchParam, searchInput: pattern, negative: n };
      }
    };

    this.toggleAccountState = function (account) {
      account.$expanded = !account.$expanded;
      if (!this.debounceSaveState) {
        this.debounceSaveState = $mdUtil.debounce(function () {
          account.$flattenMailboxes({ reload: true, saveState: true });
        }, 1000);
      }
      this.debounceSaveState();
    };

    this.subscribe = function(account) {
      $mdDialog.show({
        templateUrl: account.id + '/subscribe',
        controller: SubscriptionsDialogController,
        controllerAs: 'subscriptions',
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          srcAccount: account
        }
      }).finally(function() {
          account.$getMailboxes({reload: true});
      });

      /**
       * @ngInject
       */
      SubscriptionsDialogController.$inject = ['$scope', '$mdDialog', 'srcAccount'];
      function SubscriptionsDialogController($scope, $mdDialog, srcAccount) {
        var vm = this;

        vm.loading = true;
        vm.filter = { name: '' };
        vm.account = new Account({
          id: srcAccount.id,
          name: srcAccount.name
        });
        vm.close = close;

        vm.account.$getMailboxes({ reload: true, all: true }).then(function() {
          vm.loading = false;
        });

        function close() {
          $mdDialog.hide();
        }
      }
    };

    this.showAdvancedSearch = function() {
      Mailbox.$virtualPath = '';
      // Close sidenav on small devices
      if (!$mdMedia(sgConstant['gt-md']))
        $mdSidenav('left').close();
    };

    this.newFolder = function(parentFolder) {
      Dialog.prompt(l('New Folder...'),
                    l('Enter the new name of your folder'))
        .then(function(name) {
          parentFolder.$newMailbox(parentFolder.id, name)
            .then(function() {
              // success
            }, function(data, status) {
              Dialog.alert(l('An error occured while creating the mailbox "%{0}".', name),
                           l(data.error));
            });
        });
    };

    this.delegate = function(account) {
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
            Dialog.alert(l('Warning'), l('An error occured, please try again.'));
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
    }; // delegate

    this.refreshUnseenCount = function() {
      var unseenCountFolders = $window.unseenCountFolders, refreshViewCheck;

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

      refreshViewCheck = Preferences.defaults.SOGoRefreshViewCheck;
      if (refreshViewCheck && refreshViewCheck != 'manually')
        $timeout(vm.refreshUnseenCount, refreshViewCheck.timeInterval()*1000);
    };

    this.isDroppableFolder = function(srcFolder, dstFolder) {
      return (dstFolder.id != srcFolder.id) && !dstFolder.isNoSelect();
    };

    this.dragSelectedMessages = function(srcFolder, dstFolder, mode) {
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
    };

  }

  angular
    .module('SOGo.MailerUI')
    .controller('MailboxesController', MailboxesController);
})();

