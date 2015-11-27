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
      scope: {
        size: '@',
        email: '=sgEmail',
        src: '=sgSrc'
      },
      template: '<img ng-src="{{vm.url}}"/>',
      link: link,
      bindToController: true,
      controller: 'sgAvatarImageController',
      controllerAs: 'vm'
    };
  }

  function link(scope, element, attrs, controller) {
    var el = element[0],
        className = el.className,
        imgElement = element.find('img'),
        img = imgElement[0];

    if (attrs.size) {
      imgElement.attr('width', attrs.size);
      imgElement.attr('height', attrs.size);
    }

    imgElement.bind('error', function() {
      // Error while loading external link; insert a generic avatar
      controller.insertGenericAvatar(img);
    });
  }

  /**
   * @ngInject
   */
  sgAvatarImageController.$inject = ['$scope', '$element', 'Preferences', 'Gravatar'];
  function sgAvatarImageController($scope, $element, Preferences, Gravatar) {
    var vm = this;

    $scope.$watch('vm.email', function(email) {

      Preferences.ready().then(function() {
        var img = $element.find('img')[0];
        if (!email && !vm.genericAvatar) {
          // If no email is specified, insert a generic avatar
          vm.insertGenericAvatar(img);
        }
        else if (email && !vm.url) {
          if (vm.genericAvatar) {
            // Remove generic avatar and restore visibility of image
            vm.genericAvatar.parentNode.removeChild(vm.genericAvatar);
            delete vm.genericAvatar;
            img.classList.remove('ng-hide');
          }
          vm.url = Gravatar(email, vm.size, Preferences.defaults.SOGoAlternateAvatar);
        }
      });
    });

    // If sg-src is defined, watch the expression for the URL of a local image
    if ('sg-src' in $element[0].attributes) {
      $scope.$watch('vm.src', function(src) {
        if (src) {
          vm.url = src;
        }
      });
    }

    vm.insertGenericAvatar = function(img) {
      var avatar;

      if (!vm.genericAvatar) {
        avatar = document.createElement('md-icon');
        avatar.className = 'material-icons icon-person';
        img.classList.add('ng-hide');
        vm.genericAvatar = img.parentNode.insertBefore(avatar, img);
      }
    };
  }

  angular
    .module('SOGo.Common')
    .directive('sgAvatarImage', sgAvatarImage)
    .controller('sgAvatarImageController', sgAvatarImageController);
})();
