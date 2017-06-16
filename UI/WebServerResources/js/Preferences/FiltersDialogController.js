/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  FiltersDialogController.$inject = ['$scope', '$window', '$mdDialog', 'filter', 'mailboxes', 'labels'];
  function FiltersDialogController($scope, $window, $mdDialog, filter, mailboxes, labels) {
    var vm = this,
        sieveCapabilities = $window.sieveCapabilities,
        forwardEnabled = $window.forwardEnabled,
        vacationEnabled = $window.vacationEnabled;

    vm.filter = filter;
    vm.mailboxes = mailboxes;
    vm.labels = labels;
    vm.cancel = cancel;
    vm.hasRulesAndActions = hasRulesAndActions;
    vm.save = save;
    vm.addMailFilterRule = addMailFilterRule;
    vm.removeMailFilterRule = removeMailFilterRule;
    vm.addMailFilterAction = addMailFilterAction;
    vm.removeMailFilterAction = removeMailFilterAction;

    vm.fieldLabels = {
      "subject": l("Subject"),
      "from": l("From"),
      "to": l("To"),
      "cc": l("Cc"),
      "to_or_cc": l("To or Cc"),
      "size": l("Size (Kb)"),
      "header": l("Header")
    };

    if (sieveCapabilities.indexOf("body") > -1)
      vm.fieldLabels.body = l("Body");

    vm.methodLabels = {
      "discard": l("Discard the message"),
      "keep": l("Keep the message"),
      "stop": l("Stop processing filter rules")
    };

    if (forwardEnabled)
      vm.methodLabels.redirect = l("Forward the message to");

    //if (vacationEnabled)
    //  vm.methodLabels.vacation = l("Send a vacation message");

    if (sieveCapabilities.indexOf("reject") > -1)
      vm.methodLabels.reject = l("Send a reject message");

    if (sieveCapabilities.indexOf("fileinto") > -1)
      vm.methodLabels.fileinto = l("File the message in");

    if (sieveCapabilities.indexOf("imapflags") > -1 || sieveCapabilities.indexOf("imap4flags") > -1)
      vm.methodLabels.addflag = l("Flag the message with");

    vm.numberOperatorLabels = {
      "under": l("is under"),
      "over": l("is over")
    };

    vm.textOperatorLabels = {
      "is": l("is"),
      "is_not": l("is not"),
      "contains": l("contains"),
      "contains_not": l("does not contain"),
      "matches": l("matches"),
      "matches_not": l("does not match")
    };

    if (sieveCapabilities.indexOf("regex") > -1) {
      vm.textOperatorLabels.regex = l("matches regex");
      vm.textOperatorLabels.regex_not = l("does not match regex");
    }

    vm.flagLabels = {
      "seen": l("Seen"),
      "deleted": l("Deleted"),
      "answered": l("Answered"),
      "flagged": l("Flagged"),
      "junk": l("Junk"),
      "not_junk": l("Not Junk")
    };
    
    function cancel() {
      $mdDialog.cancel();
    }

    function hasRulesAndActions() {
      var requirements = [ vm.filter.actions ];
      if (vm.filter.match != 'allmessages')
        // When matching all messages, no rules are required
        requirements.push(vm.filter.rules);
      return _.every(requirements, function(a) {
        return a && a.length > 0;
      });
    }
    
    function save(form) {
      $mdDialog.hide();
    }

    function addMailFilterRule(event) {
      if (!vm.filter.rules)
        vm.filter.rules = [];

      vm.filter.rules.push({ field: 'subject', operator: 'contains' });
    }
    
    function removeMailFilterRule(index) {
      vm.filter.rules.splice(index, 1);
    }
    
    function addMailFilterAction(event) {
      if (!vm.filter.actions)
        vm.filter.actions = [];

      vm.filter.actions.push({ method: 'discard' });
    }
    
    function removeMailFilterAction(index) {
      vm.filter.actions.splice(index, 1);
    }
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('FiltersDialogController', FiltersDialogController);

})();
