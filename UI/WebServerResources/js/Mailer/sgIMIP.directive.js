/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgIMIP - A directive to handle IMIP actions on emails
   * @memberof SOGo.MailerUI
   * @ngInject
   * @example:

   */
  function sgImip() {
    return {
      restrict: 'A',
      link: link,
      controller: controller
    };

    function link(scope, iElement, attrs, ctrl) {
      ctrl.pathToAttachment = attrs.sgImipPath;
    }

    controller.$inject = ['$scope', 'User'];
    
    function controller($scope, User) {
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
          data = {receiveUpdates: false,
                  delegatedTo: $scope.delegatedTo.c_email};
        }

        $scope.message.$imipAction(vm.pathToAttachment, action, data);
      };
    }
  }
    
  angular
    .module('SOGo.MailerUI')
    .directive('sgImip', sgImip);
})();

