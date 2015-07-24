/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true, newcap: false */
  'use strict';

  /**
   * sgAvatarImage - An avatar directive that returns un img element with either a local URL (if sg-src is specified)
   * or a Gravatar URL built from the Gravatar factory.
   * Based on http://blog.lingohub.com/2014/08/better-ux-with-angularjs-directives/.
   * @memberof SOGo.Common
   * @example:
     <sg-avatar-image sg-email="test@email.com" size="50"></sg-avatar-image>
  */
  function sgAvatarImage() {
    return {
      restrict: 'AE',
      replace: true,
      scope: {
        size: '@',
        email: '=sgEmail',
        src: '=sgSrc'
      },
      template: '<img ng-src="{{vm.url}}"/>',
      bindToController: true,
      controller: 'sgAvatarImageController',
      controllerAs: 'vm'
    };
  }

  /**
   * @ngInject
   */
  sgAvatarImageController.$inject = ['$scope', '$element', 'Gravatar'];
  function sgAvatarImageController($scope, $element, Gravatar) {
    var vm = this;

    $scope.$watch('vm.email', function(email) {
      if (email && !vm.url) {
        vm.url = Gravatar(email, vm.size);
      }
    });

    // If sg-src is defined, watch the expression for the URL of a local image
    if ('sg-src' in $element[0].attributes) {
      $scope.$watch('vm.src', function(src) {
        if (src) {
          vm.url = src;
        }
      });
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgAvatarImage', sgAvatarImage)
    .controller('sgAvatarImageController', sgAvatarImageController);
})();
