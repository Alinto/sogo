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
    vm.notSelectedComponent = notSelectedComponent;
    vm.unselectCards = unselectCards;
    vm.confirmDeleteSelectedCards = confirmDeleteSelectedCards;
    vm.saveSelectedCards = saveSelectedCards;
    vm.copySelectedCards = copySelectedCards;
    vm.selectAll = selectAll;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
    vm.cancelSearch = cancelSearch;
    vm.newMessage = newMessage;
    vm.newMessageWithSelectedCards = newMessageWithSelectedCards;
    vm.newMessageWithRecipient = newMessageWithRecipient;
    vm.mode = { search: false };
    
    function selectCard(card) {
      $state.go('app.addressbook.card.view', {addressbookId: stateAddressbook.id, cardId: card.id});
    }
    
    function toggleCardSelection($event, card) {
      card.selected = !card.selected;
      $event.preventDefault();
      $event.stopPropagation();
    }

    function newComponent(ev) {
      $mdDialog.show({
        parent: angular.element(document.body),
        targetEvent: ev,
        clickOutsideToClose: true,
        escapeToClose: true,
        template: [
          '<md-dialog aria-label="' + l('Create component') + '">',
          '  <md-dialog-content>',
          '    <div layout="column">',
          '      <md-button ng-click="create(\'card\')">',
          '        ' + l('Contact'),
          '      </md-button>',
          '      <md-button ng-click="create(\'list\')">',
          '        ' + l('List'),
          '      </md-button>',
          '    </div>',
          '  </md-dialog-content>',
          '</md-dialog>'
        ].join(''),
        locals: {
          addressbookId: vm.selectedFolder.id
        },
        controller: ComponentDialogController
      });
      
      /**
       * @ngInject
       */
      ComponentDialogController.$inject = ['scope', '$mdDialog', '$state', 'addressbookId'];
      function ComponentDialogController(scope, $mdDialog, $state, addressbookId) {
        scope.create = function(type) {
          $mdDialog.hide();
          $state.go('app.addressbook.new', { addressbookId: addressbookId, contactType: type });
        };
      }
    }

    function notSelectedComponent(currentCard, type) {
      return (currentCard && currentCard.c_component == type && !currentCard.selected);
    }

    function unselectCards() {
      _.forEach(vm.selectedFolder.$cards, function(card) { card.selected = false; });
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

    function saveSelectedCards() {
      var selectedCards = _.filter(vm.selectedFolder.$cards, function(card) { return card.selected; });
      var selectedUIDs = _.map(selectedCards, 'id');
      $window.location.href = ApplicationBaseURL + '/' + vm.selectedFolder.id + '/export?uid=' + selectedUIDs.join('&uid=');
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
        var account = _.filter(accounts, function(o) {
          if (o.id === 0)
            return o;
        })[0];

        // We must initialize the Account with its mailbox
        // list before proceeding with message's creation
        account.$getMailboxes().then(function(mailboxes) {
          account.$newMessage().then(function(message) {
            $mdDialog.show({
              parent: angular.element(document.body),
              targetEvent: $event,
              clickOutsideToClose: false,
              escapeToClose: false,
              templateUrl: '../Mail/UIxMailEditor',
              controller: 'MessageEditorController',
              controllerAs: 'editor',
              locals: {
                stateAccounts: accounts,
                stateMessage: message,
                stateRecipients: recipients
              }
            });
          });
        });
      });
    }

    function newMessageWithRecipient($event, recipient, fn) {
      var recipients = [{full: fn + ' <' + recipient + '>'}];
      vm.newMessage($event, recipients);
      $event.stopPropagation();
      $event.preventDefault();
    }

    function newMessageWithSelectedCards($event) {
      var selectedCards = _.filter(vm.selectedFolder.$cards, function(card) { return card.selected; });
      var promises = [], recipients = [];

      _.forEach(selectedCards, function(card) {
        if (card.c_component == 'vcard' && card.c_mail.length) {
          recipients.push({full: card.c_cn + ' <' + card.c_mail + '>'});
        }
        else if (card.$isList()) {
          // If the list's members were already fetch, use them
          if (angular.isDefined(card.refs) && card.refs.length) {
            _.forEach(card.refs, function(ref) {
              if (ref.email.length)
                recipients.push({full: ref.c_cn + ' <' + ref.email + '>'});
            });
          }
          else {
            promises.push(vm.selectedFolder.$getCard(card.id).then(function(card) {
              return card.$futureCardData.then(function(data) {
                _.forEach(data.refs, function(ref) {
                  if (ref.email.length)
                    recipients.push({full: ref.c_cn + ' <' + ref.email + '>'});
                });
              });
            }));
          }
        }
      });

      $q.all(promises).then(function() {
        if (recipients.length)
          vm.newMessage($event, recipients);
      });
    }
  }

  angular
    .module('SOGo.ContactsUI')  
    .controller('AddressBookController', AddressBookController);                                    
})();
