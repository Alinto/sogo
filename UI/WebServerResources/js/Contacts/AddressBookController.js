/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBookController.$inject = ['$scope', '$q', '$window', '$state', '$timeout', '$mdDialog', 'Account', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'stateAddressbooks', 'stateAddressbook'];
  function AddressBookController($scope, $q, $window, $state, $timeout, $mdDialog, Account, Card, AddressBook, Dialog, Settings, stateAddressbooks, stateAddressbook) {
    var vm = this;

    AddressBook.selectedFolder = stateAddressbook;

    vm.service = AddressBook;
    vm.selectedFolder = stateAddressbook;
    vm.selectCard = selectCard;
    vm.toggleCardSelection = toggleCardSelection;
    vm.newComponent = newComponent;
    vm.unselectCards = unselectCards;
    vm.confirmDeleteSelectedCards = confirmDeleteSelectedCards;
    vm.copySelectedCards = copySelectedCards;
    vm.selectAll = selectAll;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
    vm.cancelSearch = cancelSearch;
    vm.newMessage = newMessage;
    vm.newMessageWithSelectedCards = newMessageWithSelectedCards;
    vm.newMessageWithRecipient = newMessageWithRecipient;
    vm.mode = { search: false, multiple: 0 };
    
    function selectCard(card) {
      $state.go('app.addressbook.card.view', {cardId: card.id});
    }
    
    function toggleCardSelection($event, card) {
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
    
    function confirmDeleteSelectedCards() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected contacts?'),
                     { ok: l('Delete') })
        .then(function() {
          // User confirmed the deletion
          var selectedCards = _.filter(vm.selectedFolder.$cards, function(card) { return card.selected; });
          vm.selectedFolder.$deleteCards(selectedCards);
          delete vm.selectedFolder.selectedCard;
        });
    }

    function copySelectedCards(folder) {
      var selectedCards = _.filter(vm.selectedFolder.$cards, function(card) { return card.selected; });
      vm.selectedFolder.$copyCards(selectedCards, folder).then(function() {
        // TODO: refresh target addressbook?
      });
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
