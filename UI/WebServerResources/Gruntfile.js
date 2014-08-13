module.exports = function(grunt) {
    grunt.initConfig({
        pkg: grunt.file.readJSON('package.json'),

        sass: {
            options: {
                includePaths: ['bower_components/foundation/scss',
                               'bower_components/ionic/scss']
            },
            dist: {
                options: {
                    // outputStyle: 'compressed'
                    outputStyle: 'expanded'
                },
                files: {
                    'css/app.css': 'scss/app.scss',
                    'css/SOGoRootPage.css': 'scss/SOGoRootPage.scss',
                    'css/ContactsUI.css': 'scss/ContactsUI.scss',
                    'css/mobile.css': 'scss/mobile.scss'
                }        
            }
        },

        watch: {
            grunt: { files: ['Gruntfile.js'] },

            sass: {
                files: 'scss/**/*.scss',
                tasks: ['sass']
            }
        }
    });

    grunt.loadNpmTasks('grunt-sass');
    grunt.loadNpmTasks('grunt-contrib-watch');

    grunt.registerTask('build', ['sass']);
    grunt.registerTask('default', ['build','watch']);
    grunt.registerTask('static', function(dev) {
        var options = {
            'src':        'bower_components',
            'js_dest':    'js/vendor/',
            'fonts_dest': 'fonts/',
            'min':        (dev? '' : '.min')
        };
        var js = [
            '<%= src %>/angular/angular<%= min %>.js',
            '<%= src %>/angular-sanitize/angular-sanitize<%= min %>.js',
            '<%= src %>/angular-ui-router/release/angular-ui-router<%= min %>.js',
            '<%= src %>/angular-foundation/mm-foundation-tpls<%= min %>.js',
            '<%= src %>/foundation/js/foundation<%= min %>.js',
            '<%= src %>/ionic/release/js/ionic<%= min %>.js',
            '<%= src %>/underscore/underscore-min.*'
        ];
        for (var j = 0; j < js.length; j++) {
            var files = grunt.file.expand(grunt.template.process(js[j], {data: options}))
            for (var i = 0; i < files.length; i++) {
                var src = files[i];
                var paths = src.split('/');
                var dest = options.js_dest + paths[paths.length-1];
                grunt.file.copy(src, dest);
                grunt.log.ok("copy " + src + " => " + dest);
            }
        }
        var fonts = grunt.file.expand(
            grunt.template.process('<%= src %>/ionic/release/fonts/ionicons.*',
                                   {data: options})
        );
        for (var i = 0; i < fonts.length; i++) {
            var src = fonts[i];
            var paths = src.split('/');
            var dest = options.fonts_dest + paths[paths.length-1];
            grunt.file.copy(src, dest);
            grunt.log.ok("copy " + src + " => " + dest);
        }
    });
}
