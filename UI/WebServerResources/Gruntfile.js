module.exports = function(grunt) {
    grunt.initConfig({
        pkg: grunt.file.readJSON('package.json'),

        sass: {
            options: {
                loadPath: ['scss'],
                style: 'expanded'
            },
            dist: {
                files: {
                    'css/styles.css': 'scss/styles.scss'
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

    grunt.loadNpmTasks('grunt-contrib-sass');
    grunt.loadNpmTasks('grunt-contrib-watch');

    grunt.task.registerTask('static', function() {
        var options = {
            'src':        'bower_components',
            'js_dest':    'js/vendor/',
            'fonts_dest': 'fonts/',
            'css_dest':   'css/'
        };
        grunt.log.subhead('Copying JavaScript files');
        var js = [
            '<%= src %>/angular/angular{,.min}.js{,.map}',
            '<%= src %>/angular-animate/angular-animate{,.min}.js{,.map}',
            '<%= src %>/angular-sanitize/angular-sanitize{,.min}.js{,.map}',
            '<%= src %>/angular-aria/angular-aria{,.min}.js{,.map}',
            '<%= src %>/angular-material/angular-material{,.min}.js{,.map}',
            '<%= src %>/angular-ui-router/release/angular-ui-router{,.min}.js',
            '<%= src %>/angular-recursion/angular-recursion{,.min}.js',
            '<%= src %>/angular-vs-repeat/src/angular-vs-repeat{,.min}.js',
            '<%= src %>/angular-file-upload/angular-file-upload{,.min}.js{,map}',
            '<%= src %>/hammerjs/hammer{,.min}.js{,.map}',
            '<%= src %>/ng-tags-input/ng-tags-input{,.min}.js',
            '<%= src %>/angular-foundation/mm-foundation-tpls{,.min}.js',
            '<%= src %>/foundation/js/foundation{,.min}.js',
            '<%= src %>/ionic/release/js/ionic.bundle{,.min}.js',
            '<%= src %>/underscore/underscore-min.{js,map}'
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
        grunt.log.subhead('Copying font files');
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
        grunt.log.subhead('Copying CSS files');
        var css = [
            '<%= src %>/ng-tags-input/ng-tags-input*.css'
        ];
        for (var j = 0; j < css.length; j++) {
            var files = grunt.file.expand(grunt.template.process(css[j], {data: options}))
              for (var i = 0; i < files.length; i++) {
                  var src = files[i];
                  var paths = src.split('/');
                  var dest = options.css_dest + paths[paths.length-1];
                  grunt.file.copy(src, dest);
                  grunt.log.ok("copy " + src + " => " + dest);
              }
          }
    });
    grunt.task.registerTask('build', ['static', 'sass']);
    grunt.task.registerTask('default', ['build','watch']);
}
