module.exports = function(grunt) {
  var js_files = {
    'js/Common.js': ['js/Common/Common.app.js', 'js/Common/*.filter.js', 'js/Common/*Controller.js', 'js/Common/*.service.js', 'js/Common/*.directive.js'],
    'js/Scheduler.js': ['js/Scheduler/*.js'],
    'js/Contacts.js': ['js/Contacts/*.js'],
    'js/Mailer.js': ['js/Mailer/*.js'],
    'js/Preferences.js': ['js/Preferences/*service.js', 'js/Preferences/*Controller.js']
  };
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    sass: {
      options: {
        sourceMap: true,
        outFile: 'css/styles.css',
        noCache: true,
        includePaths: ['scss/',
                       'bower_components/breakpoint-sass/stylesheets/'
        ]
      },
      dist: {
        files: {
          'css/styles.css': 'scss/styles.scss'
        },
        options: {
          outputStyle: 'compressed'
        }
      },
      dev: {
        files: {
          'css/styles.css': 'scss/styles.scss'
        }
      }
    },
    postcss: {
      dist: {
        options: {
          map: false,
          processors: [
            require('autoprefixer-core')({browsers: '> 1%, last 2 versions, last 3 Firefox versions'}).postcss,
            // minifier
            require('csswring').postcss
          ]
          // We may consider using css grace (https://github.com/cssdream/cssgrace) for larger support
        },
        src: 'css/styles.css'
      },
      dev: {
        options: {
          map: true,
          processors: [
            require('autoprefixer-core')({browsers: '> 1%, last 2 versions, last 3 Firefox versions'}).postcss
          ]
          // We may consider using css grace (https://github.com/cssdream/cssgrace) for larger support

        },
        src: 'css/styles.css'
      }
    },
    concat_sourcemap: {
      dist: {
        options: {
          sourcesContent: false
        },
        files: js_files
      },
      dev: {
        options: {
          sourcesContent: true
        },
        files: js_files
      }
    },
    watch: {
      grunt: {
        files: ['Gruntfile.js']
      },
      sass: {
        files: 'scss/**/*.scss',
        tasks: ['sass']
      },
      js: {
        files: Object.keys(js_files).map(function(key) { return js_files[key]; }),
        tasks: ['js']
      }
    }
  });

  grunt.loadNpmTasks('grunt-sass');
  grunt.loadNpmTasks('grunt-postcss');
  grunt.loadNpmTasks('grunt-concat-sourcemap');
  grunt.loadNpmTasks('grunt-contrib-watch');

  grunt.task.registerTask('static', function() {
    var options = {
      'src': 'bower_components',
      'js_dest': 'js/vendor/',
      'fonts_dest': 'fonts/',
      'css_dest': 'css/'
    };
    grunt.log.subhead('Copying JavaScript files');
    var js = [
      '<%= src %>/angular/angular{,.min}.js{,.map}',
      '<%= src %>/angular-animate/angular-animate{,.min}.js{,.map}',
      '<%= src %>/angular-sanitize/angular-sanitize{,.min}.js{,.map}',
      '<%= src %>/angular-aria/angular-aria{,.min}.js{,.map}',
      '<%= src %>/angular-material/angular-material{,.min}.js{,.map}',
      '<%= src %>/angular-ui-router/release/angular-ui-router{,.min}.js',
      '<%= src %>/ui-router-extras/release/ct-ui-router-extras{,.min}.js',
      '<%= src %>/angular-recursion/angular-recursion{,.min}.js',
      '<%= src %>/angular-vs-repeat/src/angular-vs-repeat{,.min}.js',
      '<%= src %>/angular-file-upload/angular-file-upload{,.min}.js{,map}',
      //'<%= src %>/ng-file-upload/ng-file-upload{,.min}.js{,map}',
      '<%= src %>/underscore/underscore-min.{js,map}'
    ];
    for (var j = 0; j < js.length; j++) {
      var files = grunt.file.expand(grunt.template.process(js[j], {data: options}));
      for (var i = 0; i < files.length; i++) {
        var src = files[i];
        var paths = src.split('/');
        var dest = options.js_dest + paths[paths.length - 1];
        grunt.file.copy(src, dest);
        grunt.log.ok("copy " + src + " => " + dest);
      }
    }
    grunt.log.subhead('Copying font files');
    var fonts = [
      '<%= src %>/material-design-iconic-font/fonts/Material-Design-Iconic-Font.*'
    ];
    for (var j = 0; j < fonts.length; j++) {
      var files = grunt.file.expand(grunt.template.process(fonts[j], {data: options}));
      for (var i = 0; i < files.length; i++) {
        var src = files[i];
        var paths = src.split('/');
        var dest = options.fonts_dest + paths[paths.length - 1];
        grunt.file.copy(src, dest);
        grunt.log.ok("copy " + src + " => " + dest);
      }
    }
    /*
    grunt.log.subhead('Copying CSS files');
    var css = [
    ];
    for (var j = 0; j < css.length; j++) {
      var files = grunt.file.expand(grunt.template.process(css[j], {data: options}));
      for (var i = 0; i < files.length; i++) {
        var src = files[i];
        var paths = src.split('/');
        var dest = options.css_dest + paths[paths.length - 1];
        grunt.file.copy(src, dest);
        grunt.log.ok("copy " + src + " => " + dest);
      }
    }
    */
  });
  grunt.task.registerTask('build', ['static', 'concat_sourcemap:dist', 'sass:dist', 'postcss:dist']);
  // Tasks for developers
  grunt.task.registerTask('default', ['watch']);
  grunt.task.registerTask('css', ['sass:dev', 'postcss:dev']);
  grunt.task.registerTask('js', ['concat_sourcemap:dev']);
  grunt.task.registerTask('dev', ['css', 'js']);
};
