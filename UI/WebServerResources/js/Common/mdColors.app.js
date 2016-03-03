/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/*
 * https://github.com/angular/material/issues/1269
 * https://gist.github.com/senthilprabhut/dd2147ebabc89bf223e7
 */

(function() {
  'use strict';

  var _$mdThemingProvider;

  angular
    .module('mdColors', ['ngMaterial'])
    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$mdThemingProvider'];
  function configure($mdThemingProvider) {
    _$mdThemingProvider = $mdThemingProvider;
  }
  
  /**
   * @ngInject
   */
  runBlock.$inject = ['$interpolate', '$document', '$log'];
  function runBlock($interpolate, $document, $log) {

    function buildCssSelectors(selectors) {
      var result = selectors.join('');
      return result;
    }

    var fgDefault = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-fg']) + ' { color:{{value}};}'),
        bgDefault = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-bg']) + ' { background-color:{{value}};}'),
        bdrDefault = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-bdr']) + ' { border-color:{{value}};}'),
        fgDefaultHue = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-{{hue}}','.md-fg']) + ' { color:{{value}};}'),
        bgDefaultHue = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-{{hue}}','.md-bg']) + ' { background-color:{{value}};}'),
        fgColor = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-{{palette}}','.md-fg']) + ' { color:{{value}};}'),
        bgColor = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-{{palette}}','.md-bg']) + ' { background-color:{{value}}; color:{{contrast}}; }'),
        bdrColor = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-{{palette}}','.md-bdr']) + ' { border-color:{{value}};}'),
        fgHue = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-{{palette}}.md-{{hue}}','.md-fg']) + ' { color:{{value}};}'),
        bgHue = $interpolate(buildCssSelectors(['.md-{{theme}}-theme','.md-{{palette}}.md-{{hue}}','.md-bg']) + ' { background-color:{{value}};}'),
        customSheet = getStyleSheet(),
        index = 0;

    // Clear out old rules from stylesheet
    while (customSheet.cssRules.length > 0 ) {
      customSheet.deleteRule(0);
    }
    angular.forEach(_$mdThemingProvider._THEMES, function(theme, themeName){
      // Add default selectors - primary is the default palette
      addRule(fgDefault, bgDefault, themeName, 'primary',
              _$mdThemingProvider._PALETTES[theme.colors.primary.name][theme.colors.primary.hues.default]);
      addRule(fgDefaultHue, bgDefaultHue, themeName, 'primary',
              _$mdThemingProvider._PALETTES[theme.colors.primary.name][theme.colors.primary.hues['hue-2'] ], 'hue-2');
      addRule(fgDefaultHue, bgDefaultHue, themeName, 'primary',
              _$mdThemingProvider._PALETTES[theme.colors.primary.name][theme.colors.primary.hues['hue-3'] ], 'hue-3');
      addRule(fgDefaultHue, bgDefaultHue, themeName, 'primary',
              _$mdThemingProvider._PALETTES[theme.colors.primary.name][theme.colors.primary.hues['hue-1'] ], 'hue-1');
      addBorderRule(bdrDefault, themeName, 'primary',
                    _$mdThemingProvider._PALETTES[theme.colors.primary.name][theme.colors.primary.hues.default]);

      // Add selectors for palettes - accent, background, primary and warn
      angular.forEach(theme.colors, function(color, paletteName){
        addRule(fgColor, bgColor, themeName, paletteName, _$mdThemingProvider._PALETTES[color.name][color.hues.default]);
        addBorderRule(bdrColor, themeName, paletteName, _$mdThemingProvider._PALETTES[color.name][color.hues.default]);
        addRule(fgHue, bgHue, themeName, paletteName, _$mdThemingProvider._PALETTES[color.name][color.hues['hue-2'] ], 'hue-2');
        addRule(fgHue, bgHue, themeName, paletteName, _$mdThemingProvider._PALETTES[color.name][color.hues['hue-3'] ], 'hue-3');
        addRule(fgHue, bgHue, themeName, paletteName, _$mdThemingProvider._PALETTES[color.name][color.hues['hue-1'] ], 'hue-1');
      });

      //$log.debug(_.map(customSheet.cssRules, 'cssText').join("\n"));
    });

    function addRule(fgInterpolate, bgInterpolate, themeName, paletteName, colorArray, hueName){
      // Set up interpolation functions to build css rules.
      if (!colorArray) return;
      var colorValue = 'rgb(' + colorArray.value[0] + ',' + colorArray.value[1] + ',' + colorArray.value[2] + ')',
          colorContrast = 'rgb(' + colorArray.contrast[0] + ',' + colorArray.contrast[1] + ',' + colorArray.contrast[2] + ')',
          context = {
            theme: themeName,
            palette: paletteName,
            value: colorValue,
            contrast: colorContrast,
            hue: hueName
          };

      // Insert foreground color rule
      customSheet.insertRule(fgInterpolate(context), index);
      index += 1;

      // Insert background color rule
      customSheet.insertRule(bgInterpolate(context), index);
      index += 1;
    }

    function addBorderRule(bdrInterpolate, themeName, paletteName, colorArray, hueName){
      // Set up interpolation functions to build css rule for border color.
      if (!colorArray) return;
      var colorValue = 'rgb(' + colorArray.value[0] + ',' + colorArray.value[1] + ',' + colorArray.value[2] + ')';

      customSheet.insertRule(bdrInterpolate({
        theme: themeName,
        palette: paletteName,
        value: colorValue,
        hue: hueName
      }), index);
      index += 1;
    }

    function getStyleSheet() {
      // function to add a dynamic style-sheet to the document
      var style = $document[0].head.querySelector('style[title="Dynamic-Generated-by-mdColors"]');
      if (style === null) {
        style = $document[0].createElement('style');
        style.title = 'Dynamic-Generated-by-mdColors';
        // WebKit hack... (not sure if still needed)
        style.appendChild($document[0].createTextNode(''));
        $document[0].head.appendChild(style);
      }
      return style.sheet;
    }
  }

})();
