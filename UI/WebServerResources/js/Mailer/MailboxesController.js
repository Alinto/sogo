/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 2; -*- */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  MailboxesController.$inject = ['$scope', '$rootScope', '$state', '$transitions', '$timeout', '$window', '$mdUtil', '$mdMedia', '$mdSidenav', '$mdDialog', '$mdToast', 'sgConstant', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'sgHotkeys', 'Account', 'Mailbox', 'VirtualMailbox', 'User', 'Preferences', 'stateAccounts', 'Message'];
  function MailboxesController($scope, $rootScope, $state, $transitions, $timeout, $window, $mdUtil, $mdMedia, $mdSidenav, $mdDialog, $mdToast, sgConstant, focus, encodeUriFilter, Dialog, Settings, sgHotkeys, Account, Mailbox, VirtualMailbox, User, Preferences, stateAccounts, Message) {
    var vm = this,
        account,
        mailbox,
        hotkeys = [];

    $scope.closeDialog = function () {
      $mdDialog.hide();
    };

    this.$onInit = function () {
      this.service = Mailbox;
      this.accounts = stateAccounts;
      this.message = Message;
      this.advancedSearchPanelVisible = false;

      // Advanced search options
      this.reset();

      this.search = {
        subfolders: 1,
        match: 'AND',
        params: []
      };
      this.highlightWords = [];

      this.showSubscribedOnly = Preferences.defaults.SOGoMailShowSubscribedFoldersOnly;

      Account.refreshUnseenCount($window.unseenCountFolders);

      _registerHotkeys(hotkeys);

      $scope.$on('$destroy', function() {
        // Deregister hotkeys
        _.forEach(hotkeys, function(key) {
          sgHotkeys.deregisterHotkey(key);
        });
      });

      $rootScope.$on('showMailAdvancedSearchPanel', function () {
        vm.showAdvancedSearch();
      });

      $rootScope.$on('resetMailAdvancedSearchPanel', function () {
        vm.reset();
      });

      $rootScope.$on('showRemoveOldEmailsPanel', function (e, d) {
        vm.showRemoveOldEmailsPanel(d.folder);
      });
    };


    function _registerHotkeys(keys) {
      _.forEach(['backspace', 'delete'], function(hotkey) {
        keys.push(sgHotkeys.createHotkey({
          key: hotkey,
          description: l('Delete selected message or folder'),
          callback: function() {
            if (Mailbox.selectedFolderController &&
                Mailbox.selectedFolder &&
                Mailbox.selectedFolder.$isEditable &&
                !Mailbox.selectedFolder.hasSelectedMessage() &&
                Mailbox.selectedFolder.$selectedCount() === 0)
              Mailbox.selectedFolderController.confirmDelete(Mailbox.selectedFolder);
          }
        }));
        keys.push(sgHotkeys.createHotkey({
          key: 'shift+s',
          description: l('Advanced search'),
          callback: function () {
           vm.showAdvancedSearch();
          }
        }));
      });

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }
    this.hideAdvancedSearch = function(e) {
      vm.service.$virtualPath = false;
      vm.service.$virtualMode = false;

      account = vm.accounts[0];
      mailbox = vm.searchPreviousMailbox;
      vm.search.params = [];
      vm.highlightWords = [];
      if (mailbox && mailbox.path) {
        // Reset
        mailbox.setHighlightWords([]);
        mailbox.$filter({
          "sort": "date",
          "asc": false,
          "match": "OR"
        }).then(function () {
          $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(mailbox.path) });
          vm.$onInit(); // Reinit search fields
        });
      }
      e.stopPropagation();
    };

    this.addHighlightWords = function(sentence) {
      var words = sentence.split(" ");

      words.forEach(word => {
        var cleanedWord = word.trim().toLowerCase();
        if (!this.highlightWords.includes(cleanedWord)) {
          this.highlightWords.push(cleanedWord);
        }
      });
    };

    this.reset = function() {
      this.highlightWords = [];
      this.searchForm = {
        from: '',
        to: '',
        contains: '',
        notContains: '',
        subject: '',
        body: '',
        date: 'anytime',
        dateStart: new Date(),
        dateEnd: new Date(),
        bcc: '',
        size: '',
        sizeOperator: '>',
        sizeUnit: 'mb',
        attachements: 0,
        favorite: 0,
        unseen: 0,
        tags: { searchText: '', selected: '' },
        flags: [],
      };
    }

    this.addSearchParameters = function() {
      this.search.params = [];
      this.highlightWords = [];
      // From
      if (this.searchForm.from && this.searchForm.from.length > 0) {
        this.search.params.push(this.newSearchParam('from', this.searchForm.from));
        this.addHighlightWords(this.searchForm.from);
      }
      // To
      if (this.searchForm.to && this.searchForm.to.length > 0) {
        this.search.params.push(this.newSearchParam('to', this.searchForm.to));
      }
      // Bcc
      if (this.searchForm.bcc && this.searchForm.bcc.length > 0) {
        this.search.params.push(this.newSearchParam('bcc', this.searchForm.bcc));
      }
      // Contains
      if (this.searchForm.contains && this.searchForm.contains.length > 0) {
        this.search.params.push(this.newSearchParam('contains', this.searchForm.contains));
        this.addHighlightWords(this.searchForm.contains);
      }
      // Does not contains
      if (this.searchForm.doesnotcontains && this.searchForm.doesnotcontains.length > 0) {
        this.search.params.push(this.newSearchParam('not_contains', this.searchForm.doesnotcontains));
      }
      // Subject
      if (this.searchForm.subject && this.searchForm.subject.length > 0) {
        this.search.params.push(this.newSearchParam('subject', this.searchForm.subject));
        this.addHighlightWords(this.searchForm.subject);
      }
      // Body
      if (this.searchForm.body && this.searchForm.body.length > 0) {
        this.search.params.push(this.newSearchParam('body', this.searchForm.body));
        this.addHighlightWords(this.searchForm.body);
      }
      // Date
      if (this.searchForm.date && this.searchForm.date.length > 0) {
        var date = null;
        var dateTo = null;
        var today = new Date();
        var tmp = new Date(today);
        switch (this.searchForm.date) {
          case 'anytime':
            break;
          case 'last7days':
            tmp.setDate(tmp.getDate() - 7);
            date = this.formatDate(tmp);
            this.search.params.push(this.newSearchParam('date', date, '>='));
            break;
          case 'last30days':
            tmp.setDate(tmp.getDate() - 30);
            date = this.formatDate(tmp);
            this.search.params.push(this.newSearchParam('date', date, '>='));
            break;
          case 'last6month':
            tmp.setMonth(tmp.getMonth() - 6);
            date = this.formatDate(tmp);
            this.search.params.push(this.newSearchParam('date', date, '>='));
            break;
          case 'before':
            date = this.formatDate(this.searchForm.dateStart);
            this.search.params.push(this.newSearchParam('date', date, '<'));
            break;
          case 'after':
            date = this.formatDate(this.searchForm.dateStart);
            this.search.params.push(this.newSearchParam('date', date, '>='));
            break;
          case 'between':
            date = this.formatDate(this.searchForm.dateStart);
            dateTo = this.formatDate(this.searchForm.dateEnd);
            this.search.params.push(this.newSearchDateBetweenParam(date, dateTo));
            break;
        }
      }
      // Size
      if (this.searchForm.size && this.searchForm.size > 0) {
        this.search.params.push(this.newSearchParam('size', this.searchForm.size.toString(), this.searchForm.sizeOperator));
      }
      // Attachment
      if (this.searchForm.attachements) {
        this.search.params.push(this.newSearchParam('attachment', '1', '='));
      }
      // Favorite
      if (this.searchForm.favorite) {
        this.search.params.push(this.newSearchParam('favorite', '1', '='));
      }
      // Unseen
      if (this.searchForm.unseen) {
        this.search.params.push(this.newSearchParam('unseen', '1', '='));
      }
      // Flags
      if (this.searchForm.flags && this.searchForm.flags.length > 0) {
        this.search.params.push(this.newSearchFlagsParam());
      }

      this.toggleAdvancedSearch();
    }

    this.searchFieldChange = function (event) {
      if (13 == event.keyCode) {
        this.addSearchParameters();
        $mdDialog.hide();
        vm.advancedSearchPanelVisible = false;
      } 
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
          root.setHighlightWords(vm.highlightWords);
          mailboxes.push(root);
          if (vm.search.subfolders && root.children.length)
            _visit(root.children);
        }
        else {
          mailboxes = _.filter(vm.accounts[0].$flattenMailboxes({ all: true }), function(mailbox) {
            return !mailbox.isNoSelect();
          });
        }

        mailboxes.forEach((mailbox) => {
          mailbox
        });
        vm.virtualMailbox.setMailboxes(mailboxes);
        vm.virtualMailbox.startSearch(vm.search.match, vm.search.params);
        if ($state.$current.name != 'mail.account.virtualMailbox')
          $state.go('mail.account.virtualMailbox', { accountId: vm.accounts[0].id });
      }
    };

  
    this.formatDate = function(date) {
      var year = date.getFullYear();
      var month = (date.getMonth() + 1).toString().padStart(2, '0');
      var day = date.getDate().toString().padStart(2, '0');
      return year + '-' + month + '-' + day;
    };

    this.changeDate = function() {
      if ('between' == this.searchForm.date) {
        if (this.searchForm.dateStart > this.searchForm.dateEnd) {
          this.searchForm.dateEnd = this.searchForm.dateStart;
        }
      }
    };

    this.newSearchParam = function (searchParam, pattern, operator = '>') {
      if (pattern.length && searchParam.length) {
        var n = 0;
        if (pattern.startsWith("!")) {
          n = 1;
          pattern = pattern.substring(1).trim();
        }

        switch (searchParam) {
          case 'size':
            return { searchBy: searchParam, searchInput: pattern, negative: n, operator: operator, sizeUnit: this.searchForm.sizeUnit };
          case 'date':
            return { searchBy: searchParam, searchInput: pattern, negative: n, operator: operator };
          default:
            return { searchBy: searchParam, searchInput: pattern, negative: n };
        }
      }
    };

    this.newSearchDateBetweenParam = function (dateFrom, dateTo) {
      return { searchBy: 'date_between', searchInput: "*", dateFrom: dateFrom, dateTo: dateTo, negative: 0 };
    };

    this.newSearchFlagsParam = function () {
      return { searchBy: 'flags', searchInput: "*", flags: vm.searchForm.flags, negative: 0 };
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
      if (!vm.advancedSearchPanelVisible) {
        vm.advancedSearchPanelVisible = true;
        if (Mailbox.selectedFolder.path)
          Mailbox.$virtualPath = Mailbox.selectedFolder.path;

        // Close sidenav on small devices
        if (!$mdMedia(sgConstant['gt-md']))
          $mdSidenav('left').close();

        $mdDialog.show({
          template: document.getElementById('advancedSearch').innerHTML,
          parent: angular.element(document.body),
          controller: function () {
            var dialogCtrl = this;

            this.$onInit = function () {
              // Pass main controller
              this.mainController = vm;
              this.mailbox = Mailbox;
              this.message = Message;
            };

            dialogCtrl.closeDialog = function () {
              $mdDialog.hide();
              vm.advancedSearchPanelVisible = false;
            };

            dialogCtrl.search = function () {
              this.mainController.addSearchParameters();
              $mdDialog.hide();
              vm.advancedSearchPanelVisible = false;
            };
          },
          controllerAs: 'dialogCtrl',
          clickOutsideToClose: false,
          escapeToClose: false,
        });
      }
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

    this.showRemoveOldEmailsPanel = function (folder) {
        // Close sidenav on small devices
        if (!$mdMedia(sgConstant['gt-md']))
          $mdSidenav('left').close();

        $mdDialog.show({
          template: document.getElementById('removeOldEmails').innerHTML,
          parent: angular.element(document.body),
          controller: function () {
            var dialogCtrl = this;

            this.$onInit = function () {
              // Pass main controller
              this.mainController = vm;
              this.folder = folder;
              this.folderName = folder.$displayName;
            };

            dialogCtrl.closeDialog = function () {
              $mdDialog.hide();
            };
           
            dialogCtrl.apply = function () {
              console.log(this.mailbox);
              this.folder.cleanMailbox();
              // $mdDialog.hide();
            };
          },
          controllerAs: 'dialogCtrl',
          clickOutsideToClose: false,
          escapeToClose: false,
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

    this.isDroppableFolder = function(srcFolder, dstFolder) {
      return (dstFolder.id != srcFolder.id) && dstFolder.isWritable();
    };

    this.dragSelectedMessages = function(srcFolder, dstFolder, mode) {
      var dstId, messages, uids, clearMessageView, promise, success;

      dstId = '/' + dstFolder.id;
      messages = srcFolder.selectedMessages();
      if (messages.length === 0)
        messages = [srcFolder.selectedMessage()];
      uids = _.map(messages, 'uid');
      clearMessageView = (srcFolder.$selectedMessage && uids.indexOf(srcFolder.$selectedMessage) >= 0);

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
            .textContent(success)
            .position(sgConstant.toastPosition)
            .hideDelay(2000));
      });
    };

  }

  angular
    .module('SOGo.MailerUI')
    .controller('MailboxesController', MailboxesController);

  
})();

