/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  FiltersDialogController.$inject = ['$scope', '$mdDialog', 'filter', 'mailboxes', 'labels', 'sieveCapabilities'];
  function FiltersDialogController($scope, $mdDialog, filter, mailboxes, labels, sieveCapabilities) {
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
      "header": l("Header")
    };

    if (sieveCapabilities.indexOf("body") > -1)
      $scope.fieldLabels.body = l("Body");

    $scope.methodLabels = {
      "discard": l("Discard the message"),
      "keep": l("Keep the message"),
      "redirect": l("Forward the message to:"),
      "vacation": l("Send a vacation message"),
      "stop": l("Stop processing filter rules")
    };

    if (sieveCapabilities.indexOf("reject") > -1)
      $scope.methodLabels.reject = l("Send a reject message:");

    if (sieveCapabilities.indexOf("fileinto") > -1)
      $scope.methodLabels.fileinto = l("File the message in:");

    if (sieveCapabilities.indexOf("imapflags") > -1 || sieveCapabilities.indexOf("imap4flags") > -1)
      $scope.methodLabels.addflag = l("Flag the message with:");

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
      "matches_not": l("does not match")
    };

    if (sieveCapabilities.indexOf("regex") > -1) {
      $scope.textOperatorLabels.regex = l("matches regex");
      $scope.textOperatorLabels.regex_not = l("does not match regex");
    }

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
