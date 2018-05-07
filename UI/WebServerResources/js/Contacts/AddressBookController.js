/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBookController.$inject = ['$scope', '$q', '$window', '$state', '$timeout', '$mdDialog', '$mdToast', 'Account', 'Card', 'AddressBook', 'sgFocus', 'Dialog', 'sgSettings', 'sgHotkeys', 'stateAddressbooks', 'stateAddressbook'];
  function AddressBookController($scope, $q, $window, $state, $timeout, $mdDialog, $mdToast, Account, Card, AddressBook, focus, Dialog, Settings, sgHotkeys, stateAddressbooks, stateAddressbook) {
    var vm = this, hotkeys = [], sortLabels;

    sortLabels = {
      c_cn: 'Name',
      c_sn: 'Lastname',
      c_givenname: 'Firstname',
      c_mail: 'Email',
      c_screenname: 'Screen Name',
      c_o: 'Organization',
      c_telephonenumber: 'Preferred Phone'
    };

    this.$onInit = function() {
      AddressBook.selectedFolder = stateAddressbook;

      this.service = AddressBook;
      this.selectedFolder = stateAddressbook;
      this.mode = { search: false, multiple: 0 };


      _registerHotkeys(hotkeys);

      $scope.$on('$destroy', function() {
        // Deregister hotkeys
        _.forEach(hotkeys, function(key) {
          sgHotkeys.deregisterHotkey(key);
        });
      });
    };


    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_search'),
        description: l('Search'),
        callback: angular.bind(vm, vm.searchMode)
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('key_create_card'),
        description: l('Create a new address book card'),
        callback: angular.bind(vm, vm.newComponent, 'card')
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('key_create_list'),
        description: l('Create a new list'),
        callback: angular.bind(vm, vm.newComponent, 'list')
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'space',
        description: l('Toggle item'),
        callback: angular.bind(vm, vm.toggleCardSelection)
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'shift+space',
        description: l('Toggle range of items'),
        callback: angular.bind(vm, vm.toggleCardSelection)
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'up',
        description: l('View next item'),
        callback: _nextCard
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'down',
        description: l('View previous item'),
        callback: _previousCard
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'shift+up',
        description: l('Add next item to selection'),
        callback: _addNextCardToSelection
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'shift+down',
        description: l('Add previous item to selection'),
        callback: _addPreviousCardToSelection
      }));
      _.forEach(['backspace', 'delete'], function(hotkey) {
        keys.push(sgHotkeys.createHotkey({
          key: hotkey,
          description: l('Delete selected card or address book'),
          callback: angular.bind(vm, vm.confirmDeleteSelectedCards)
        }));
      });

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    this.centerIsClose = function(navController_centerIsClose) {
      // Allow the cards list to be hidden only if a card is selected
      return this.selectedFolder.hasSelectedCard() && !!navController_centerIsClose;
    };

    this.selectCard = function(card) {
      $state.go('app.addressbook.card.view', {cardId: card.id});
    };

    this.toggleCardSelection = function($event, card) {
      var folder = this.selectedFolder,
          selectedIndex, nextSelectedIndex, i;

      if (!card)
        card = folder.$selectedCard();
      card.selected = !card.selected;
      this.mode.multiple += card.selected? 1 : -1;

      // Select closest range of cards when shift key is pressed
      if ($event.shiftKey && folder.$selectedCount() > 1) {
        selectedIndex = folder.idsMap[card.id];
        // Search for next selected card above
        nextSelectedIndex = selectedIndex - 2;
        while (nextSelectedIndex >= 0 &&
               !folder.$cards[nextSelectedIndex].selected)
          nextSelectedIndex--;
        if (nextSelectedIndex < 0) {
          // Search for next selected card bellow
          nextSelectedIndex = selectedIndex + 2;
          while (nextSelectedIndex < folder.getLength() &&
                 !folder.$cards[nextSelectedIndex].selected)
            nextSelectedIndex++;
        }
        if (nextSelectedIndex >= 0 && nextSelectedIndex < folder.getLength()) {
          for (i = Math.min(selectedIndex, nextSelectedIndex);
               i <= Math.max(selectedIndex, nextSelectedIndex);
               i++)
            folder.$cards[i].selected = true;
        }
      }

      $event.preventDefault();
      $event.stopPropagation();
    };

    this.newComponent = function(type) {
      $state.go('app.addressbook.new', { contactType: type });
    };

    this.unselectCards = function() {
      _.forEach(this.selectedFolder.$cards, function(card) {
        card.selected = false;
      });
      this.mode.multiple = 0;
    };

    /**
     * User has pressed up arrow key
     */
    function _nextCard($event) {
      var index = vm.selectedFolder.$selectedCardIndex();

      if (angular.isDefined(index)) {
        index--;
        if (vm.selectedFolder.$topIndex > 0)
          vm.selectedFolder.$topIndex--;
      }
      else {
        // No card is selected, show oldest card
        index = vm.selectedFolder.$cards.length() - 1;
        vm.selectedFolder.$topIndex = vm.selectedFolder.getLength();
      }

      if (index > -1)
        vm.selectCard(vm.selectedFolder.$cards[index]);

      $event.preventDefault();

      return index;
    }

    /**
     * User has pressed the down arrow key
     */
    function _previousCard($event) {
      var index = vm.selectedFolder.$selectedCardIndex();

      if (angular.isDefined(index)) {
        index++;
        if (vm.selectedFolder.$topIndex < vm.selectedFolder.$cards.length)
          vm.selectedFolder.$topIndex++;
      }
      else
        // No card is selected, show newest
        index = 0;

      if (index < vm.selectedFolder.$cards.length)
        vm.selectCard(vm.selectedFolder.$cards[index]);
      else
        index = -1;

      $event.preventDefault();

      return index;
    }

    function _addNextCardToSelection($event) {
      var index;

      if (vm.selectedFolder.hasSelectedCard()) {
        index = _nextCard($event);
        if (index >= 0)
          toggleCardSelection($event, vm.selectedFolder.$cards[index]);
      }
    }

    function _addPreviousCardToSelection($event) {
      var index;

      if (vm.selectedFolder.hasSelectedCard()) {
        index = _previousCard($event);
        if (index >= 0)
          toggleCardSelection($event, vm.selectedFolder.$cards[index]);
      }
    }

    this.confirmDeleteSelectedCards = function($event) {
      var selectedCards = this.selectedFolder.$selectedCards();

      if (_.size(selectedCards) > 0)
        Dialog.confirm(l('Warning'),
                       l('Are you sure you want to delete the selected contacts?'),
                       { ok: l('Delete') })
        .then(function() {
          // User confirmed the deletion
          vm.selectedFolder.$deleteCards(selectedCards).then(function() {
            vm.mode.multiple = 0;
            if (!vm.selectedFolder.selectedCard)
              $state.go('app.addressbook');
          });
        });

      $event.preventDefault();
    };

    /**
     * @see AddressBooksController.dragSelectedCards
     */
    function _selectedCardsOperation(operation, dstId) {
      var srcFolder, allCards, cards, ids, clearCardView, promise, success;

      srcFolder = vm.selectedFolder;
      clearCardView = false;
      allCards = srcFolder.$selectedCards();
      cards = _.filter(allCards, function(card) {
        return card.$isCard();
      });

      if (cards.length != allCards.length)
        $mdToast.show(
          $mdToast.simple()
            .content(l("Lists can't be moved or copied."))
            .position('top right')
            .hideDelay(2000));

      if (cards.length) {
        if (operation == 'copy') {
          promise = srcFolder.$copyCards(cards, dstId);
          success = l('%{0} card(s) copied', cards.length);
        }
        else {
          promise = srcFolder.$moveCards(cards, dstId);
          success = l('%{0} card(s) moved', cards.length);
          // Check if currently displayed card will be moved
          ids = _.map(cards, 'id');
          clearCardView = (srcFolder.selectedCard && ids.indexOf(srcFolder.selectedCard) >= 0);
        }

        // Show success toast when action succeeds
        promise.then(function() {
          if (clearCardView)
            $state.go('app.addressbook');
          $mdToast.show(
            $mdToast.simple()
              .content(success)
              .position('top right')
              .hideDelay(2000));
        });
      }
    }

    this.copySelectedCards = function(folder) {
      _selectedCardsOperation('copy', folder);
    };

    this.moveSelectedCards = function(folder) {
      _selectedCardsOperation('move', folder);
    };

    this.selectAll = function() {
      _.forEach(this.selectedFolder.$cards, function(card) {
        card.selected = true;
      });
      this.mode.multiple = this.selectedFolder.$cards.length;
    };

    this.sort = function(field) {
      if (field) {
        this.selectedFolder.$filter('', { sort: field });
      }
      else {
        return sortLabels[AddressBook.$query.sort];
      }
    };

    this.sortedBy = function(field) {
      return AddressBook.$query.sort == field;
    };

    this.ascending = function() {
      return AddressBook.$query.asc;
    };

    this.searchMode = function() {
      vm.mode.search = true;
      focus('search');
    };

    this.cancelSearch = function() {
      this.mode.search = false;
      this.selectedFolder.$filter('');
    };

    this.newMessage = function($event, recipients, recipientsField) {
      Account.$findAll().then(function(accounts) {
        var account = _.find(accounts, function(o) {
          if (o.id === 0)
            return o;
        });

        // We must initialize the Account with its mailbox
        // list before proceeding with message's creation
        account.$getMailboxes().then(function(mailboxes) {
          account.$newMessage().then(function(message) {
            message.editable[recipientsField] = recipients;
            $mdDialog.show({
              parent: angular.element(document.body),
              targetEvent: $event,
              clickOutsideToClose: false,
              escapeToClose: false,
              templateUrl: '../Mail/UIxMailEditor',
              controller: 'MessageEditorController',
              controllerAs: 'editor',
              locals: {
                stateAccount: account,
                stateMessage: message
              }
            });
          });
        });
      });
    };

    this.newMessageWithRecipient = function($event, recipient, fn) {
      var recipients = [fn + ' <' + recipient + '>'];
      this.newMessage($event, recipients, 'to');
      $event.stopPropagation();
      $event.preventDefault();
    };

    this.newMessageWithSelectedCards = function($event, recipientsField) {
      var selectedCards = _.filter(this.selectedFolder.$cards, function(card) { return card.selected; });
      var promises = [], recipients = [];

      _.forEach(selectedCards, function(card) {
        if (card.$isList({expandable: true})) {
          // If the list's members were already fetch, use them
          if (angular.isDefined(card.refs) && card.refs.length) {
            _.forEach(card.refs, function(ref) {
              if (ref.email.length)
                recipients.push(ref.$shortFormat());
            });
          }
          else {
            promises.push(card.$reload().then(function(card) {
              _.forEach(card.refs, function(ref) {
                if (ref.email.length)
                  recipients.push(ref.$shortFormat());
              });
            }));
          }
        }
        else if (card.c_mail.length) {
          recipients.push(card.$shortFormat());
        }
      });

      $q.all(promises).then(function() {
        recipients = _.uniq(recipients);
        if (recipients.length)
          vm.newMessage($event, recipients, recipientsField);
      });
    };

    this.newListWithSelectedCards = function() {
      var selectedCards = _.filter(this.selectedFolder.$cards, function(card) { return card.selected; });
      var promises = [], refs = [];

      _.forEach(selectedCards, function(card) {
        if (card.$isList({expandable: true})) {
          // If the list's members were already fetch, use them
          if (angular.isDefined(card.refs) && card.refs.length) {
            _.forEach(card.refs, function(ref) {
              if (ref.email.length)
                refs.push(ref);
            });
          }
          else {
            promises.push(card.$reload().then(function(card) {
              _.forEach(card.refs, function(ref) {
                if (ref.email.length)
                  refs.push(ref);
              });
            }));
          }
        }
        else if (card.$$email && card.$$email.length) {
          refs.push(card);
        }
      });

      $q.all(promises).then(function() {
        refs = _.uniqBy(_.map(refs, function(o) {
          return { reference: o.id || o.reference, email: o.$$email || o.email };
        }), 'reference');
        if (refs.length)
          $state.go('app.addressbook.new', { contactType: 'list', refs: refs });
      });
    };

  }

  angular
    .module('SOGo.ContactsUI')
    .controller('AddressBookController', AddressBookController);
})();
