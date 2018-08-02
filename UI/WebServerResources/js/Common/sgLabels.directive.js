/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgLabels - Load the localizable strings of the specified framework.
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {object} sgLabels - the framework name
   * @ngInject
   * @example:

  <md-dialog sg-labels="MailerUI"><!-- .. --></md-dialog>
  */
  sgLabels.$inject = ['sgSettings', 'Resource', '$window'];
  function sgLabels(Settings, Resource, $window) {
    return {
      restrict: 'A',
      link: sgLabelsLink
    };

    function sgLabelsLink(scope, element, attrs) {
      var framework = attrs.sgLabels;
      var resource = new Resource(Settings.activeUser('folderURL'), Settings.activeUser());
      if (!_.includes($window.labels._loadedFrameworks, framework)) {
        resource.post('labels', null, { framework: framework }).then(function(data) {
          var loadedFrameworks = $window.labels._loadedFrameworks;
          angular.extend($window.labels, data.labels);
          $window.labels._loadedFrameworks = _.concat($window.labels._loadedFrameworks, loadedFrameworks);
        });
      }
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgLabels', sgLabels);
})();
