/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /**
   * sgIMIP - A directive to handle IMIP actions on emails
   * @memberof SOGo.MailerUI
   * @example:

   */
  function sgImip() {
    return {
      restrict: 'A',
      link: link,
      controller: 'sgImipController'
    };

    function link(scope, iElement, attrs, ctrl) {
      ctrl.pathToAttachment = attrs.sgImipPath;
    }
  }

  /**
   * @ngInject
   */
  sgImipController.$inject = ['$scope', 'User'];
  function sgImipController($scope, User) {
    var vm = this;

    $scope.delegateInvitation = false;
    $scope.delegatedTo = '';
    $scope.searchText = '';

    $scope.userFilter = function($query) {
      return User.$filter($query);
    };

    $scope.iCalendarAction = function(action) {
      var data;

      if (action == 'delegate') {
        data = {
          receiveUpdates: false,
          delegatedTo: $scope.delegatedTo.c_email
        };
      }

      $scope.viewer.message.$imipAction(vm.pathToAttachment, action, data);
    };
  }

  angular
    .module('SOGo.MailerUI')
    .controller('sgImipController', sgImipController)
    .directive('sgImip', sgImip);
})();

