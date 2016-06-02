/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgToggleGrid - Convert the tiles of a grid to toggle buttons
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {string} [sgToggleGridAttr] - the attribute that specifies if an object is enabled (toggled)
   * @ngInject
   * @example:

    <md-grid-list md-cols="7" md-row-height="1:1"
                  ng-model="editor.event.repeat.days"
                  sg-toggle-grid sg-toggle-grid-attr="day">..</md-grid-list>
  */
  sgToggleGrid.$inject = ['$parse', '$mdUtil'];
  function sgToggleGrid($parse, $mdUtil) {
    return {
      restrict: 'A',
      require: '?ngModel',
      compile: compile
    };

    function compile(tElement, tAttrs) {
      return function postLink(scope, element, attr, ngModelCtrl) {
        var tiles = tElement.find('md-grid-tile'),
            tile,
            i,
            modelDays,
            modelAttr,
            toggleClass;

        ngModelCtrl = ngModelCtrl || $mdUtil.fakeNgModel();
        ngModelCtrl.$render = render;

        toggleClass = function() {
          // Toggle class on click event and call toggle function
          var tile = angular.element(this),
              day = tile.attr('value');
          tile.toggleClass('sg-active');
          toggle(day);
        };

        for (i = 0; i < tiles.length; i++) {
          tile = angular.element(tiles[i]);
          tile.addClass('sg-icon-button');
          tile.find('figure').addClass('md-icon');
          tile.on('click', toggleClass);
        }

        function render() {
          var flattenedDays = ngModelCtrl.$viewValue;
          modelDays = ngModelCtrl.$viewValue;
          if (tAttrs.sgToggleGridAttr) {
            modelAttr = tAttrs.sgToggleGridAttr;
            flattenedDays = _.map(ngModelCtrl.$viewValue, tAttrs.sgToggleGridAttr);
          }
          _.forEach(tiles, function(o) {
            var tile = angular.element(o);
            if (_.includes(flattenedDays, tile.attr('value'))) {
              tile.addClass('sg-active');
            }
          });
        }

        function toggle(day) {
          var i = _.findIndex(modelDays, function(o) {
            if (modelAttr)
              return o[modelAttr] == day;
            else
              return o == day;
          });
          if (i < 0) {
            if (modelAttr) {
              var o = {};
              o[modelAttr] = day;
              modelDays.push(o);
            }
            else
              modelDays.push(day);
          }
          else
            modelDays.splice(i, 1);

          scope.$apply(function() {
            ngModelCtrl.$setViewValue(modelDays);
            ngModelCtrl.$setDirty();
          });
        }
      };
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgToggleGrid', sgToggleGrid);
})();
