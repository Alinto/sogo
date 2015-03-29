module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    compass: {
      dist: {
        options: {
          sassDir: 'scss',
          cssDir: 'css',
          specify: 'scss/styles.scss',
          outputStyle: 'compact', // will be compressed by postcss
          environment: 'production'
        }
      },
      dev: {
        options: {
          force: true,
          sassDir: 'scss',
          cssDir: 'css',
          importPath: [
            'bower_components/compass-mixins/lib',
            'bower_components/compass-breakpoint/stylesheets',
            'bower_components/breakpoint-slicer/stylesheets',
            'bower_components/breakpoint-slicer/stylesheets/breakpoint-slicer',
            'bower_components/sassy-maps/sass'
          ],
          noLineComments: true,
          sourcemap: true,
          specify: 'scss/styles.scss',
          raw: 'sass_options = {:cache => false\n}',
          outputStyle: 'expanded'
        }
      }
    },
    sass: {
      options: {
        require: 'SassyJSON',
        noCache: true,
        loadPath: ['scss', 'bower_components/compass-mixins/lib',
                   'bower_components/compass-breakpoint/stylesheets',
                   'bower_components/breakpoint-slicer/stylesheets',
                   'bower_components/sassy-maps/sass',
                   'node_modules/SassyJSON/dist'
        ],
        style: 'expanded'
      },
      dist: {
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
    watch: {
      grunt: {files: ['Gruntfile.js']},

      sass: {
        files: 'scss/**/*.scss',
        tasks: ['sass']
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-sass');
  grunt.loadNpmTasks('grunt-postcss');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-compass');

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
      '<%= src %>/angular-recursion/angular-recursion{,.min}.js',
      '<%= src %>/angular-vs-repeat/src/angular-vs-repeat{,.min}.js',
      '<%= src %>/angular-file-upload/angular-file-upload{,.min}.js{,map}',
      '<%= src %>/ng-tags-input/ng-tags-input{,.min}.js',
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
      '<%= src %>/ionic/release/fonts/ionicons.*',
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
    grunt.log.subhead('Copying CSS files');
    var css = [
      '<%= src %>/ng-tags-input/ng-tags-input*.css' // This is no longer needed, ng-tags css is integrated to scss
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
  });
  grunt.task.registerTask('build', ['static', 'sass']);
  grunt.task.registerTask('default', ['build', 'watch']);
  grunt.task.registerTask('css', ['sass', 'postcss:dev']);
  grunt.task.registerTask('sass-compass', ['compass:dev', 'postcss']);
};
