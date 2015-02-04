(function () {
    "use strict";

    //module global to keep an reference to the dynamic style sheet
    var customSheet;
    //module global to available color pallettes
    var colorStore = {};
    
    angular
        .module('mdColors',['ngMaterial'])
        .service("ThemeColors", ThemeColors)
        .config(configColors)
        .run(loadDefaults);
        
    configColors.$inject = ['$mdThemingProvider'];
    function configColors($mdThemingProvider) {
        //fetch the colores out of the themeing provider
        //console.log($mdThemingProvider._THEMES.default.colors.primary.name)
        Object.keys($mdThemingProvider._PALETTES).forEach(parsePallete);
        return;
        
        // clone the pallete colors to the colorStore var
        function parsePallete(palleteName) {
            var pallete = $mdThemingProvider._PALETTES[palleteName];
            var colors  = [];
            colorStore[palleteName]=colors;
            Object.keys(pallete).forEach(copyColors);
            return ;
            
            function copyColors(colorName) {
                // use an regex to look for hex colors, ignore the rest
                if (/#[0-9A-Fa-f]{6}|0-9A-Fa-f]{8}\b/.exec(pallete[colorName])) {
                    colors.push({color:colorName,value:pallete[colorName]});
                }
            }
        }
    }
    
    loadDefaults.$inject=['ThemeColors'];
    function loadDefaults(ThemeColors) {
        // this sets the default that is stored in the config-fase into the service!
        ThemeColors.themes=Object.keys(colorStore);
        ThemeColors.loadColors('amber');
    }
    
    ThemeColors.$inject = ['$interpolate'];
    function ThemeColors ($interpolate) {
        // wrap all of the above up in a reusable service.
        var service        = this;
        service.theme      = 'amber';
        service.colors     = [];
        service.themes     = [];
        service.loadColors = loadColors;
        
        return service;
        
        function loadColors(newPallete) {
            service.theme=newPallete;
            service.colors=colorStore[newPallete];
            createStyleSheet();    
        }
        
        function createStyleSheet () {
            var colors = service.colors;
            var fg, bg;
            if (typeof customSheet === 'undefined') {
                // use closure for caching the styleSheet
                newStyleSheet();
            } else {
                // remove existing rules
                // TODO: look into disabling/enabling pre-build style-guides
                //       in stead of delete and recreate!
                while (customSheet.cssRules.length > 0 ) {
                    customSheet.deleteRule(0);
                }
            }
    
            // set up interpolation functions to build css rules.
            fg  = $interpolate('.md-fg-{{color}} { color:{{value}};}');
            bg  = $interpolate('.md-bg-{{color}} { background-color:{{value}};}');
    
            colors.forEach(function (color) {
                // insert foreground color rule
                customSheet.insertRule(fg(color));
                // insert background color rule
                customSheet.insertRule(bg(color));
            });
        }
    }        
        
    function newStyleSheet() {
        // function to ad an dynamic style-sheet to the document
        var style   = document.createElement("style");
        style.title = 'Dynamic Generated my Angular-Material';
        // WebKit hack... (not sure if still needed)
        style.appendChild(document.createTextNode(""));

        document.head.appendChild(style);
        // store the sheet in the closure for reuse
        // creating a new sheet is a 'costly' operation, and I
        // just need one.
        customSheet = style.sheet;
        return style.sheet;
    }

}());