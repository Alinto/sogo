/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  configure.$inject = ['$mdThemingProvider'];
  function configure($mdThemingProvider) {

    $mdThemingProvider.registerStyles([
      '.foreground-1 { color: "{{foreground-1}}" }',
      '.foreground-2 { color: "{{foreground-2}}" }',
      '.foreground-3 { color: "{{foreground-3}}" }',
      '.foreground-4 { color: "{{foreground-4}}" }',
      '.background-contrast { color: "{{background-contrast}}" }',
      '.background-contrast-secondary { color: "{{background-contrast-secondary}}" }',
      '.background-default { background-color: "{{background-default}}" }',
    ].join(''));

    $mdThemingProvider.generateThemesOnDemand(false);
  }

  /**
   * @ngInject
   */
  ThemePreviewController.$inject = ['$mdTheming', '$mdColors'];
  function ThemePreviewController($mdTheming, $mdColors) {
    this.defaultTheme = $mdTheming.THEMES[$mdTheming.defaultTheme()];
    this.jsonDefaultTheme = JSON.stringify(this.defaultTheme, undefined, 2);
    this.getColor = $mdColors.getThemeColor;
  }

  angular
    .module('SOGo.AdministrationUI')
    .config(configure)
    .controller('ThemePreviewController', ThemePreviewController);

})();
