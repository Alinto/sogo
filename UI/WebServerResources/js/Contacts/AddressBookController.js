/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBookController.$inject = ['$scope', '$state', '$timeout', '$mdDialog', 'sgFocus', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'stateAddressbooks', 'stateAddressbook'];
  function AddressBookController($scope, $state, $timeout, $mdDialog, focus, Card, AddressBook, Dialog, Settings, stateAddressbooks, stateAddressbook) {
    var vm = this;

    AddressBook.selectedFolder = stateAddressbook;

    vm.selectedFolder = stateAddressbook;
    vm.selectCard = selectCard;
    vm.newComponent = newComponent;
    vm.notSelectedComponent = notSelectedComponent;
    vm.unselectCards = unselectCards;
    vm.confirmDeleteSelectedCards = confirmDeleteSelectedCards;
    vm.selectAll = selectAll;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
    vm.cancelSearch = cancelSearch;
    vm.mode = { search: false };
    
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
      _.each(vm.selectedFolder.cards, function(card) { card.selected = false; });
    }
    
    function confirmDeleteSelectedCards() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected contacts?'))
        .then(function() {
          // User confirmed the deletion
          var selectedCards = _.filter(vm.selectedFolder.cards, function(card) { return card.selected; });
          vm.selectedFolder.$deleteCards(selectedCards);
          delete vm.selectedFolder.selectedCard;
        },  function(data, status) {
          // Delete failed
        });
    }

    function selectAll() {
      _.each(vm.selectedFolder.cards, function(card) {
        card.selected = true;
      });
    }

    function sort(field) {
      vm.selectedFolder.$filter('', { sort: field });
    }

    function sortedBy(field) {
      return vm.selectedFolder.$query.sort == field;
    }

    function cancelSearch() {
      vm.mode.search = false;
      vm.selectedFolder.$filter('');
    }
  }

  angular
    .module('SOGo.ContactsUI')  
    .controller('AddressBookController', AddressBookController);                                    
})();
