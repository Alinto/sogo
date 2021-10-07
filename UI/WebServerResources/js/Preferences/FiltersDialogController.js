/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoPreferences */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  FiltersDialogController.$inject = ['$scope', '$window', '$mdDialog', 'Dialog', 'filter', 'mailboxes', 'labels', 'validateForwardAddress', 'Preferences'];
  function FiltersDialogController($scope, $window, $mdDialog, Dialog, filter, mailboxes, labels, validateForwardAddress, Preferences) {
    var vm = this,
        sieveCapabilities = $window.sieveCapabilities,
        forwardEnabled = $window.forwardEnabled,
        vacationEnabled = $window.vacationEnabled;

    this.filter = filter;
    this.mailboxes = mailboxes;
    this.labels = labels;

    this.fieldLabels = {
      "subject": l("Subject"),
      "from": l("From"),
      "to": l("To"),
      "cc": l("Cc"),
      "to_or_cc": l("To or Cc"),
      "size": l("Size (Kb)"),
      "header": l("Header")
    };

    if (sieveCapabilities.indexOf("body") > -1)
      this.fieldLabels.body = l("Body");

    this.methodLabels = {
      "discard": l("Discard the message"),
      "keep": l("Keep the message"),
      "stop": l("Stop processing filter rules")
    };

    if (forwardEnabled)
      this.methodLabels.redirect = l("Forward the message to");

    //if (vacationEnabled)
    //  this.methodLabels.vacation = l("Send a vacation message");

    if (sieveCapabilities.indexOf("reject") > -1)
      this.methodLabels.reject = l("Send a reject message");

    if (sieveCapabilities.indexOf("fileinto") > -1)
      this.methodLabels.fileinto = l("File the message in");

    if (sieveCapabilities.indexOf("imapflags") > -1 || sieveCapabilities.indexOf("imap4flags") > -1)
      this.methodLabels.addflag = l("Flag the message with");

    this.methods = [
      "fileinto",
      "addflag",
      "stop",
      "keep",
      "discard",
      "redirect",
      "reject"
    ];
    this.methods = _.intersection(this.methods, _.keys(this.methodLabels));

    this.numberOperatorLabels = {
      "under": l("is under"),
      "over": l("is over")
    };

    this.textOperatorLabels = {
      "is": l("is"),
      "is_not": l("is not"),
      "contains": l("contains"),
      "contains_not": l("does not contain"),
      "matches": l("matches"),
      "matches_not": l("does not match")
    };

    if (sieveCapabilities.indexOf("regex") > -1) {
      this.textOperatorLabels.regex = l("matches regex");
      this.textOperatorLabels.regex_not = l("does not match regex");
    }

    this.cancel = function () {
      $mdDialog.cancel();
    };

    this.hasRulesAndActions = function () {
      var requirements = [ this.filter.actions ];
      if (this.filter.match != 'allmessages')
        // When matching all messages, no rules are required
        requirements.push(this.filter.rules);
      return _.every(requirements, function(a) {
        return a && a.length > 0;
      });
    };

    this.save = function (form) {
      var i;

      this.invalid = false;

      // We do some sanity checks
      if (this.filter.actions) {
        try {
          _.forEach(_.filter(this.filter.actions, { 'method': 'redirect' }), function (action) {
            validateForwardAddress(action.argument);
          });
        } catch (err) {
          //Dialog.alert(l('Error'), err);
          this.invalid = err.message;
          return false;
        }
      }
      $mdDialog.hide();
    };

    this.addMailFilterRule = function (event) {
      if (!this.filter.rules)
        this.filter.rules = [];

      this.filter.rules.push({ field: 'subject', operator: 'contains' });
    };

    this.removeMailFilterRule = function (index) {
      this.filter.rules.splice(index, 1);
    };
    
    this.addMailFilterAction = function (event) {
      if (!this.filter.actions)
        this.filter.actions = [];

      this.filter.actions.push({ method: 'fileinto' });
    };
    
    this.removeMailFilterAction = function (index) {
      this.filter.actions.splice(index, 1);
    };
  }

  angular
    .module('SOGo.PreferencesUI')
    .controller('FiltersDialogController', FiltersDialogController);

})();
