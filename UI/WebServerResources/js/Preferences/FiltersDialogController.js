/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  FiltersDialogController.$inject = ['$scope', '$mdDialog', 'filter', 'mailboxes', 'labels'];
  function FiltersDialogController($scope, $mdDialog, filter, mailboxes, labels) {
    $scope.filter = filter;
    $scope.mailboxes = mailboxes;
    $scope.labels = labels;

    $scope.fieldLabels = {
      "subject": l("Subject"),
      "from": l("From"),
      "to": l("To"),
      "cc": l("Cc"),
      "to_or_cc": l("To or Cc"),
      "size": l("Size (Kb)"),
      "header": l("Header"),
      "body": l("Body")
    };

    $scope.methodLabels = {
      "addflag": l("Flag the message with:"),                         
      "discard": l("Discard the message"),
      "fileinto": l("File the message in:"),
      "keep": l("Keep the message"),
      "redirect": l("Forward the message to:"),
      "reject": l("Send a reject message:"),
      "vacation": l("Send a vacation message"),
      "stop": l("Stop processing filter rules")
    };

    $scope.numberOperatorLabels = {
      "under": l("is under"),
      "over": l("is over")
    };

    $scope.textOperatorLabels = {
      "is": l("is"),
      "is_not": l("is not"),
      "contains": l("contains"),
      "contains_not": l("does not contain"),
      "matches": l("matches"),
      "matches_not": l("does not match"),
      "regex": l("matches regex"),
      "regex_not": l("does not match regex")
    };

    $scope.flagLabels = {
      "seen": l("Seen"),
      "deleted": l("Deleted"),
      "answered": l("Answered"),
      "flagged": l("Flagged"),
      "junk": l("Junk"),
      "not_junk": l("Not Junk")
    };
    
    $scope.cancel = function() {
      $mdDialog.cancel();
    };
    
    $scope.save = function() {
      $mdDialog.hide();
    };
    
    $scope.addMailFilterRule = function(event) {
      if (!$scope.filter.rules)
        $scope.filter.rules = [];

      $scope.filter.rules.push({});
    };
    
    $scope.removeMailFilterRule = function(index) {
      $scope.filter.rules.splice(index, 1);
    };
    
    $scope.addMailFilterAction = function(event) {
      if (!$scope.filter.actions)
        $scope.filter.actions = [];

      $scope.filter.actions.push({});
    };
    
    $scope.removeMailFilterAction = function(index) {
      $scope.filter.actions.splice(index, 1);
    };
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('FiltersDialogController', FiltersDialogController);

})();
