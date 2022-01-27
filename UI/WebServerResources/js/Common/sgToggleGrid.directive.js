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
  sgToggleGrid.$inject = ['$parse', '$mdUtil', '$mdColors'];
  function sgToggleGrid($parse, $mdUtil, $mdColors) {
    return {
      restrict: 'A',
      require: ['mdGridList', '?ngModel'],
      compile: compile
    };

    function compile(tElement, tAttrs) {
      var CLASS_ACTIVE = 'md-default-theme md-accent md-bg md-bdr';
      return function postLink(scope, element, attr, controllers) {
        var tiles = tElement.find('md-grid-tile'),
            label = tElement.parent().children()[0],
            tile,
            ngModelCtrl,
            i,
            modelDays = [],
            modelAttr,
            toggleClass;

        ngModelCtrl = controllers[1] || $mdUtil.fakeNgModel();
        ngModelCtrl.$render = render;
        ngModelCtrl.$isEmpty = function(value) {
          return !value || value.length === 0;
        };

        scope.$watch(function() {
          return ngModelCtrl.$invalid;
        }, setInvalid);

        tAttrs.$observe('required', function(value) {
          angular.element(label).toggleClass('md-required', !!value);
          ngModelCtrl.$validate();
        });

        toggleClass = function() {
          // Toggle class on click event and call toggle function
          var tile = angular.element(this),
              day = tile.attr('value');
          tile.toggleClass(CLASS_ACTIVE);
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
              tile.addClass(CLASS_ACTIVE);
            }
          });
          ngModelCtrl.$validate();
        }

        function setInvalid() {
          var invalid = ngModelCtrl.$invalid;
          if (invalid) {
            element.addClass('sg-toggle-grid-invalid');
            if (label.tagName == 'LABEL') {
              label.style.color = $mdColors.getThemeColor('warn');
            }
          }
          else {
            element.removeClass('sg-toggle-grid-invalid');
            if (label.tagName == 'LABEL') {
              label.style.color = '';
            }
          }
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
            ngModelCtrl.$validate();
          });
        }
      };
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgToggleGrid', sgToggleGrid);
})();
