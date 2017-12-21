/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Dialog
   * @constructor
   */
  function Dialog() {
  }

  /**
   * @name alert
   * @desc Show an alert dialog box with a single "OK" button
   * @param {string} title
   * @param {string} content
   */
  Dialog.alert = function(title, content) {
    var alert = this.$modal.alert()
        .title(title)
        .htmlContent(content)
        .ok(l('OK'))
        .multiple(true);
    this.$modal.show(alert);
  };

  /**
   * @name confirm
   * @desc Show a confirmation dialog box with buttons 'Cancel' and 'OK'
   * @param {string} title
   * @param {string} content
   * @returns a promise that resolves if the user has clicked on the 'OK' button
   */
  Dialog.confirm = function(title, content, options) {
    var confirm = this.$modal.confirm()
        .title(title)
        .htmlContent(content)
        .ok((options && options.ok)? options.ok : l('OK'))
        .cancel((options && options.cancel)? options.cancel : l('Cancel'));
    return this.$modal.show(confirm);
  };

  /**
   * @name prompt
   * @desc Show a primpt dialog box with a input text field and the 'Cancel' and 'OK' buttons
   * @param {string} title
   * @param {string} label
   * @param {object} [options] - use a different input type by setting 'inputType'
   * @returns a promise that resolves with the input field value
   */
  Dialog.prompt = function(title, label, options) {
    var o = options || {},
        id = title.asCSSIdentifier(),
        d = this.$q.defer();

    this.$modal.show({
      parent: angular.element(document.body),
      clickOutsideToClose: true,
      escapeToClose: true,
      template: [
        '<md-dialog flex="50" flex-xs="90">',
        '  <form name="' + id + 'Form" ng-submit="ok()">',
        '    <md-dialog-content class="md-dialog-content" layout="column">',
        '      <h2 class="md-title" ng-bind="title"></h2>',
        '      <md-input-container>',
        '        <label>' + label + '</label>',
        '        <input type="' + (o.inputType || 'text') + '"',
        '               aria-label="' + title + '"',
        '               ng-model="name" md-autofocus="true" required />',
        '      </md-input-container>',
        '    </md-dialog-content>',
        '    <md-dialog-actions>',
        '      <md-button ng-click="cancel()">',
        '        ' + l('Cancel'),
        '      </md-button>',
        '      <md-button type="submit" class="md-primary" ng-disabled="' + id + 'Form.$invalid">',
        '        ' + l('OK'),
        '      </md-button>',
        '    </md-dialog-actions>',
        '  </form>',
        '</md-dialog>'
      ].join(''),
      controller: PromptDialogController
    });

    /**
     * @ngInject
     */
    PromptDialogController.$inject = ['scope', '$mdDialog'];
    function PromptDialogController(scope, $mdDialog) {
      scope.title = title;
      scope.name = "";
      scope.cancel = function() {
        d.reject();
        $mdDialog.hide();
      };
      scope.ok = function() {
        d.resolve(scope.name);
        $mdDialog.hide();
      };
    }

    return d.promise;
  };

  /**
   * @memberof Dialog
   * @desc The factory we'll register as Dialog in the Angular module SOGo.Common
   * @ngInject
   */
  DialogService.$inject = ['$q', '$mdDialog'];
  function DialogService($q, $mdDialog) {
    angular.extend(Dialog, { $q: $q , $modal: $mdDialog });

    return Dialog; // return constructor
  }

  /* Factory registration in Angular module */
  angular
    .module('SOGo.Common')
    .factory('Dialog', DialogService);

})();
