// Load Grunt
module.exports = function(grunt) {
  var js_files = {
    'js/Common.js': ['js/Common/*.app.js', 'js/Common/*.filter.js', 'js/Common/*Controller.js', 'js/Common/*.service.js', 'js/Common/*.directive.js', 'js/Common/utils.js'],
    'js/Main.js': ['js/Main/Main.app.js'],
    'js/Scheduler.services.js': ['js/Scheduler/*.service.js', 'js/Scheduler/*Controller.js', 'js/Scheduler/*.directive.js'],
    'js/Scheduler.js': ['js/Scheduler/Scheduler.app.js'],
    'js/Contacts.services.js': ['js/Contacts/*.service.js'],
    'js/Contacts.js': ['js/Contacts/Contacts.app.js', 'js/Contacts/*Controller.js', 'js/Contacts/*.directive.js'],
    'js/Mailer.services.js': ['js/Mailer/*.service.js', 'js/Mailer/*Controller.js', 'js/Mailer/*.directive.js'],
    'js/Mailer.js': ['js/Mailer/Mailer.app.js'],
    'js/Mailer.app.popup.js': ['js/Mailer/Mailer.popup.js'],
    'js/Preferences.services.js': ['js/Preferences/*.service.js'],
    'js/Preferences.js': ['js/Preferences/Preferences.app.js', 'js/Preferences/*Controller.js'],
    'js/Administration.services.js': ['js/Administration/*.service.js'],
    'js/Administration.js': ['js/Administration/Administration.app.js', 'js/Administration/*Controller.js']

  };
  var custom_vendor_files = {
    'js/vendor/angular-file-upload.min.js': ['bower_components/angular-file-upload/dist/angular-file-upload.js', 'js/Common/angular-file-upload.trump.js'],
    'js/vendor/FileSaver.min.js': ['bower_components/FileSaver/dist/FileSaver.js']
  };

  require('time-grunt')(grunt);

  // Tasks
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
      target: {
        files: {
          'css/styles.css': 'scss/styles.scss',
          'css/no-animation.css': 'scss/core/no-animation.scss'
        },
      },
    },
    postcss: {
      target: {
        options: {
          map: true,
          processors: [
            // See angular-material/gulp/util.js
            require('autoprefixer')({
              browsers: [
                'last 2 versions',
                'not ie <= 10',
                'not ie_mob <= 10',
                'last 4 Android versions',
                'Safari >= 8'
              ]
            })
          ]
        },
        src: ['css/styles.css', 'css/no-animation.css']
      }
    },
    cssmin: {
      options: {
        sourceMap: true,
      },
      target: {
        files: {
          'css/styles.css': 'css/styles.css',
          'css/no-animation.css': 'css/no-animation.css'
        }
      }
    },
    jshint: {
      files: [].concat(Object.keys(js_files).map(function(v) { return js_files[v]; }))
    },
    uglify: {
      options: {
        sourceMap: true
      },
      dist: {
        options: {
          compress: true,
          sourceMapIncludeSources: true
        },
        files: js_files
      },
      dev: {
        options: {
          compress: false,
          mangle: false,
        },
        files: js_files
      },
      vendor: {
        options: {
          compress: true,
        },
        files: custom_vendor_files,
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

  // Load Grunt plugins
  grunt.loadNpmTasks('grunt-sass');
  grunt.loadNpmTasks('grunt-postcss');
  grunt.loadNpmTasks('grunt-contrib-cssmin');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-watch');

  // Register Grunt tasks
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
      '<%= src %>/angular-cookies/angular-cookies{,.min}.js{,.map}',
      '<%= src %>/angular-messages/angular-messages{,.min}.js{,.map}',
      '<%= src %>/angular-material/angular-material{,.min}.js',
      '<%= src %>/angular-ui-router/release/angular-ui-router{,.min}.js{,.map}',
      //'<%= src %>/ng-file-upload/ng-file-upload{,.min}.js{,map}',
      '<%= src %>/ng-sortable/dist/ng-sortable.min.js{,map}',
      '<%= src %>/lodash/dist/lodash{,.min}.js'
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
    /*
    grunt.log.subhead('Copying font files');
    var fonts = [
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
    */
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
    grunt.task.run('uglify:vendor');
  });
  grunt.task.registerTask('build', ['static', 'uglify:dist', 'sass', 'postcss', 'cssmin']);
  // Tasks for developers
  grunt.task.registerTask('default', ['watch']);
  grunt.task.registerTask('css', ['sass', 'postcss']);
  grunt.task.registerTask('js', ['jshint', 'uglify:dev']);
  grunt.task.registerTask('dev', ['css', 'js']);
};
