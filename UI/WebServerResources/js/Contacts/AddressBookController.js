/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBookController.$inject = ['$scope', '$q', '$window', '$state', '$timeout', '$mdDialog', '$mdToast', 'Account', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'sgHotkeys', 'stateAddressbooks', 'stateAddressbook'];
  function AddressBookController($scope, $q, $window, $state, $timeout, $mdDialog, $mdToast, Account, Card, AddressBook, Dialog, Settings, sgHotkeys, stateAddressbooks, stateAddressbook) {
    var vm = this, hotkeys = [];

    AddressBook.selectedFolder = stateAddressbook;

    vm.service = AddressBook;
    vm.selectedFolder = stateAddressbook;
    vm.selectCard = selectCard;
    vm.toggleCardSelection = toggleCardSelection;
    vm.newComponent = newComponent;
    vm.unselectCards = unselectCards;
    vm.confirmDeleteSelectedCards = confirmDeleteSelectedCards;
    vm.copySelectedCards = copySelectedCards;
    vm.moveSelectedCards = moveSelectedCards;
    vm.selectAll = selectAll;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
    vm.cancelSearch = cancelSearch;
    vm.newMessage = newMessage;
    vm.newMessageWithSelectedCards = newMessageWithSelectedCards;
    vm.newMessageWithRecipient = newMessageWithRecipient;
    vm.mode = { search: false, multiple: 0 };


    _registerHotkeys(hotkeys);

    $scope.$on('$destroy', function() {
      // Deregister hotkeys
      _.forEach(hotkeys, function(key) {
        sgHotkeys.deregisterHotkey(key);
      });
    });


    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: l('key_create_card'),
        description: l('Create a new address book card'),
        callback: angular.bind(vm, newComponent, 'card')
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('key_create_list'),
        description: l('Create a new list'),
        callback: angular.bind(vm, newComponent, 'list')
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'space',
        description: l('Toggle item'),
        callback: toggleCardSelection
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
      keys.push(sgHotkeys.createHotkey({
        key: 'backspace',
        description: l('Delete selected card or address book'),
        callback: confirmDeleteSelectedCards
      }));

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    function selectCard(card) {
      $state.go('app.addressbook.card.view', {cardId: card.id});
    }

    function toggleCardSelection($event, card) {
      if (!card) card = vm.selectedFolder.$selectedCard();
      card.selected = !card.selected;
      vm.mode.multiple += card.selected? 1 : -1;
      $event.preventDefault();
      $event.stopPropagation();
    }

    function newComponent(type) {
      $state.go('app.addressbook.new', { contactType: type });
    }

    function unselectCards() {
      _.forEach(vm.selectedFolder.$cards, function(card) {
        card.selected = false;
      });
      vm.mode.multiple = 0;
    }

    /**
     * User has pressed up arrow key
     */
    function _nextCard($event) {
      var index = vm.selectedFolder.$selectedCardIndex();

      if (angular.isDefined(index))
        index--;
      else
        // No message is selected, show oldest message
        index = vm.selectedFolder.$cards.length() - 1;

      if (index > -1)
        selectCard(vm.selectedFolder.$cards[index]);

      if (vm.selectedFolder.$topIndex > 0)
        vm.selectedFolder.$topIndex--;

      $event.preventDefault();

      return index;
    }

    /**
     * User has pressed the down arrow key
     */
    function _previousCard($event) {
      var index = vm.selectedFolder.$selectedCardIndex();

      if (angular.isDefined(index))
        index++;
      else
        // No message is selected, show newest
        index = 0;

      if (index < vm.selectedFolder.$cards.length)
        selectCard(vm.selectedFolder.$cards[index]);
      else
        index = -1;

      if (vm.selectedFolder.$topIndex < vm.selectedFolder.$cards.length)
        vm.selectedFolder.$topIndex++;

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

    function confirmDeleteSelectedCards($event) {
      var selectedCards = vm.selectedFolder.$selectedCards();

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
    }

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

    function copySelectedCards(folder) {
      _selectedCardsOperation('copy', folder);
    }

    function moveSelectedCards(folder) {
      _selectedCardsOperation('move', folder);
    }

    function selectAll() {
      _.forEach(vm.selectedFolder.$cards, function(card) {
        card.selected = true;
      });
      vm.mode.multiple = vm.selectedFolder.$cards.length;
    }

    function sort(field) {
      vm.selectedFolder.$filter('', { sort: field });
    }

    function sortedBy(field) {
      return AddressBook.$query.sort == field;
    }

    function cancelSearch() {
      vm.mode.search = false;
      vm.selectedFolder.$filter('');
    }

    function newMessage($event, recipients) {
      Account.$findAll().then(function(accounts) {
        var account = _.find(accounts, function(o) {
          if (o.id === 0)
            return o;
        });

        // We must initialize the Account with its mailbox
        // list before proceeding with message's creation
        account.$getMailboxes().then(function(mailboxes) {
          account.$newMessage().then(function(message) {
            angular.extend(message.editable, { to: recipients });
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
    }

    function newMessageWithRecipient($event, recipient, fn) {
      var recipients = [fn + ' <' + recipient + '>'];
      vm.newMessage($event, recipients);
      $event.stopPropagation();
      $event.preventDefault();
    }

    function newMessageWithSelectedCards($event) {
      var selectedCards = _.filter(vm.selectedFolder.$cards, function(card) { return card.selected; });
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
          vm.newMessage($event, recipients);
      });
    }
  }

  angular
    .module('SOGo.ContactsUI')
    .controller('AddressBookController', AddressBookController);
})();
