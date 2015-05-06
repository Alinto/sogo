/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgGravatarImage - A simple Gravatar directive (based on http://blog.lingohub.com/2014/08/better-ux-with-angularjs-directives/)
   * @memberof SOGo.Common
   * @example:
     <sg-gravatar-image email="test@email.com" size="50"></sg-gravatar-image>
  */

  sgGravatarImage.$inject = ['Gravatar'];
  function sgGravatarImage(Gravatar) {
    return {
      restrict: 'AE',
      replace: true,
      required: 'email',
      template: '<img ng-src="{{url}}" />',
      link: function(scope, element, attrs) {
        var size = attrs.size;
        attrs.$observe('email', function(value) {
          if (!value) { return; }
          scope.url = Gravatar(value, size);
        });
      }
    };
  }

  angular
    .module('SOGo.Common')
    .directive('sgGravatarImage', sgGravatarImage);
})();
