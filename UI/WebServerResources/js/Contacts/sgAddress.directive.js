/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name sgAddress
   * @memberof ContactsUI
   * @desc Directive to format a postal address.
   * @ngInject
   */
  function sgAddress() {
    return {
      restrict: 'A',
      scope: { data: '=sgAddress' },
      controller: ['$scope', function($scope) {
        $scope.addressLines = function(data) {
          var lines = [],
              locality_region = [];
          if (data.street) lines.push(data.street);
          if (data.street2) lines.push(data.street2);
          if (data.locality) locality_region.push(data.locality);
          if (data.region) locality_region.push(data.region);
          if (locality_region.length > 0) lines.push(locality_region.join(', '));
          if (data.country) lines.push(data.country);
          if (data.postalcode) lines.push(data.postalcode);
          return lines.join('<br>');
        };
      }],
      template: '<address ng-bind-html="addressLines(data)"></address>'
    };
  }
  
  angular
    .module('SOGo.Common')
    .directive('sgAddress', sgAddress);
})();
