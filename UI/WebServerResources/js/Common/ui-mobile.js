/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for common UI services for mobile theme */

(function() {
  'use strict';

  /**
   * @name Dialog
   * @constructor
   */
  function Dialog() {
  }

  Dialog.alert = function(title, content) {
    var alertPopup = this.$ionicPopup.alert({
      title: title,
      template: content
    });
    return alertPopup;
  };

  Dialog.confirm = function(title, content) {
    var confirmPopup = this.$ionicPopup.confirm({
      title: title,
      template: content
    });
    return confirmPopup;
  };

  Dialog.prompt = function(title, content) {
    var promptPopup = this.$ionicPopup.prompt({
      title: title,
      inputPlaceholder: content
    });
    return promptPopup;
  };

  /**
   * @memberof Dialog
   * @desc The factory we'll register as sgDialog in the Angular module SOGo.UIMobile
   */
  Dialog.$factory = ['$ionicPopup', function($ionicPopup) {
    angular.extend(Dialog, { $ionicPopup: $ionicPopup });

    return Dialog; // return constructor
  }];

  /* Angular module instanciation */
  angular.module('SOGo.UIMobile', ['ionic', 'RecursionHelper'])

  /* Factory registration in Angular module */
    .factory('sgDialog', Dialog.$factory)

  /*
   * sgFolderTree - Provides hierarchical folders tree
   * @memberof SOGo.UIDesktop
   * @restrict element
   * @see https://github.com/marklagendijk/angular-recursion
   * @example:

     <sg-folder-tree data-ng-repeat="folder in folders track by folder.id"
                     data-sg-root="account"
                     data-sg-folder="folder"
                     data-sg-set-folder="setCurrentFolder"><!-- tree --></sg-folder-tree>
  */
    .directive("sgFolderTree", function(RecursionHelper) {
      return {
        restrict: "E",
        scope: {
          root: '=sgRoot',
          folder: '=sgFolder',
          setFolder: '=sgSetFolder'
        },
        template:
          '<ion-item option-buttons="buttons" class="item-icon-left item-icon-right"' +
          '          ng-click="setFolder(root, folder)">' +
          '  <i class="icon ion-folder"><!-- mailbox --></i>{{folder.name}}' +
          '  <i class="icon ion-ios7-arrow-right"><!-- right arrow icon --></i>' +
          '  <ion-option-button class="button-info"' +
          '                     ng-click="edit(folder)">{{"Edit" | loc}}</ion-option-button>' +
          '</ion-item>' +
          '<div>' +
          '  <span ng-repeat="child in folder.children track by child.id">' +
          '    <sg-folder-tree sg-root="root" sg-folder="child" sg-set-folder="setFolder"></sg-folder-tree>' +
          '  </span>' +
          '</div>',
        compile: function(element) {
          return RecursionHelper.compile(element, function(scope, iElement, iAttrs, controller, transcludeFn) {
            var level = scope.folder.path.split('/').length - 1;
            iElement.find('ion-item').addClass('childLevel' + level);
          });
        }
      };
    });

})();
