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
    grunt.registerTask('js', function(dev) {
        var options = {
            'src':        'bower_components',
            'dest':       'js/vendor/',
            'min':        (dev? '' : '.min')
        };
        var vendor = [
            '<%= src %>/angular/angular<%= min %>.js',
            '<%= src %>/angular-sanitize/angular-sanitize<%= min %>.js',
            '<%= src %>/angular-ui-router/release/angular-ui-router<%= min %>.js',
            '<%= src %>/angular-foundation/mm-foundation-tpls<%= min %>.js',
            '<%= src %>/foundation/js/foundation<%= min %>.js',
            '<%= src %>/ionic/release/js/ionic<%= min %>.js',
            '<%= src %>/underscore/underscore-min.js'
        ];
        for (var i = 0; i < vendor.length; i++) {
            var src = grunt.template.process(vendor[i], {data: options});
            var paths = src.split('/');
            var dest = options.dest + paths[paths.length-1];
            grunt.file.copy(src, dest);
            grunt.log.ok("copy " + src + " => " + dest);
        }
    });
}
