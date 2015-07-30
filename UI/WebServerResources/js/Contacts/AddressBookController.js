/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBookController.$inject = ['$scope', '$state', '$timeout', '$mdDialog', 'sgFocus', 'Card', 'AddressBook', 'Dialog', 'Preferences', 'sgSettings', 'stateAddressbooks', 'stateAddressbook'];
  function AddressBookController($scope, $state, $timeout, $mdDialog, focus, Card, AddressBook, Dialog, Preferences, Settings, stateAddressbooks, stateAddressbook) {
    var vm = this;

    AddressBook.selectedFolder = stateAddressbook;

    vm.selectedFolder = stateAddressbook;
    vm.selectCard = selectCard;
    vm.newComponent = newComponent;
    vm.notSelectedComponent = notSelectedComponent;
    vm.unselectCards = unselectCards;
    vm.confirmDeleteSelectedCards = confirmDeleteSelectedCards;
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

    // Start the address book refresh timer based on user's preferences
    Preferences.ready().then(function() {
      var refreshViewCheck = Preferences.defaults.SOGoRefreshViewCheck;
      if (refreshViewCheck && refreshViewCheck != 'manually') {
        var interval;
        if (refreshViewCheck == "once_per_hour")
          interval = 3600;
        else if (refreshViewCheck == "every_minute")
          interval = 60;
        else {
          interval = parseInt(refreshViewCheck.substr(6)) * 60;
        }

        var f = angular.bind(vm.selectedFolder, AddressBook.prototype.$reload);
        $timeout(f, interval*1000);
      }
    });
  }

  angular
    .module('SOGo.ContactsUI')  
    .controller('AddressBookController', AddressBookController);                                    
})();
