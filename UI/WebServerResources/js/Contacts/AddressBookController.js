/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBookController.$inject = ['$state', '$mdDialog', 'sgFocus', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'stateAddressbooks', 'stateAddressbook'];
  function AddressBookController($state, $mdDialog, focus, Card, AddressBook, Dialog, Settings, stateAddressbooks, stateAddressbook) {
    var vm = this;

    AddressBook.selectedFolder = stateAddressbook;

    vm.selectedFolder = stateAddressbook;
    vm.selectCard = selectCard;
    vm.newComponent = newComponent;
    vm.notSelectedComponent = notSelectedComponent;
    vm.unselectCards = unselectCards;
    vm.confirmDeleteSelectedCards = confirmDeleteSelectedCards;
    
    function selectCard(card) {
      $state.go('app.addressbook.card.view', {addressbookId: stateAddressbook.id, cardId: card.id});
    }
    
    function newComponent(ev) {
      $mdDialog.show({
        parent: angular.element(document.body),
        targetEvent: ev,
        clickOutsideToClose: true,
        escapeToClose: true,
        template: [
          '<md-dialog aria-label="' + l('Create component') + '">',
          '  <md-content>',
          '    <div layout="column">',
          '      <md-button ng-click="create(\'card\')">',
          '        ' + l('Contact'),
          '      </md-button>',
          '      <md-button ng-click="create(\'list\')">',
          '        ' + l('List'),
          '      </md-button>',
          '    </div>',
          '  </md-content>',
          '</md-dialog>'
        ].join(''),
        locals: {
          state: $state,
          addressbookId: vm.selectedFolder.id
        },
        controller: ComponentDialogController
      });
      
      /**
       * @ngInject
       */
      ComponentDialogController.$inject = ['scope', '$mdDialog', 'state', 'addressbookId'];
      function ComponentDialogController(scope, $mdDialog, state, addressbookId) {
        scope.create = function(type) {
          $mdDialog.hide();
          state.go('app.addressbook.new', { addressbookId: addressbookId, contactType: type });
        }
      }
    }

    function notSelectedComponent(currentCard, type) {
      return (currentCard && currentCard.tag == type && !currentCard.selected);
    }

    function unselectCards() {
      _.each(vm.selectedFolder.cards, function(card) { card.selected = false; });
    }
    
    function confirmDeleteSelectedCards() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected contacts?'))
        .then(function() {
          // User confirmed the deletion
          var selectedCards = _.filter(vm.selectedFolder.cards, function(card) { return card.selected });
          vm.selectedFolder.$deleteCards(selectedCards);
        },  function(data, status) {
          // Delete failed
        });
    }
  }

  angular
    .module('SOGo.ContactsUI')  
    .controller('AddressBookController', AddressBookController);                                    
})();
