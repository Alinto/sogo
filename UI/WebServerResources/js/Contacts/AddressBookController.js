/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBookController.$inject = ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$mdDialog', 'sgFocus', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'stateAddressbooks', 'stateAddressbook'];
  function AddressBookController($state, $scope, $rootScope, $stateParams, $timeout, $mdDialog, focus, Card, AddressBook, Dialog, Settings, stateAddressbooks, stateAddressbook) {
      var currentAddressbook;

      $rootScope.currentFolder = stateAddressbook;

      $scope.newComponent = function(ev) {
        $mdDialog.show({
          parent: angular.element(document.body),
          targetEvent: ev,
          clickOutsideToClose: true,
          escapeToClose: true,
          template: [
            '<md-dialog aria-label="Create component">',
            '  <md-content>',
            '    <div layout="column">',
            '      <md-button ng-click="createContact()">',
            '        ' + l('Contact'),
            '      </md-button>',
            '      <md-button ng-click="createList()">',
            '        ' + l('List'),
            '      </md-button>',
            '    </div>',
            '  </md-content>',
            '</md-dialog>'
          ].join(''),
          locals: {
            state: $state
          },
          controller: ComponentDialogController
        });
        function ComponentDialogController(scope, $mdDialog, state) {
          scope.createContact = function() {
            state.go('app.addressbook.new', { addressbookId: $scope.currentFolder.id, contactType: 'card' });
            $mdDialog.hide();
          }
          scope.createList = function() {
            state.go('app.addressbook.new', { addressbookId: $scope.currentFolder.id, contactType: 'list' });
            $mdDialog.hide();
          }
        }
      };
    }

  angular
    .module('SOGo.ContactsUI')  
    .controller('AddressBookController', AddressBookController);                                    
})();
