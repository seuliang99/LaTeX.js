#!/usr/local/bin/lsc -cj

name: 'latex.js'
description: 'JavaScript LaTeX to HTML5 translator'
version: '0.11.1'

author:
    'name': 'Michael Brade'
    'email': 'brade@kde.org'

keywords:
    'pegjs'
    'latex'
    'parser'
    'html5'

bin:
    'latex.js': './bin/latex.js'

main:
    'dist/index.js'

browser:
    'dist/latex.min.js'

files:
    'bin/latex.js'

    'dist/index.js'
    'dist/index.js.map'
    'dist/latex-parser.js'
    'dist/latex-parser.js.map'
    'dist/latex.ltx.js'
    'dist/latex.ltx.js.map'
    'dist/symbols.js'
    'dist/symbols.js.map'
    'dist/generator.js'
    'dist/generator.js.map'
    'dist/html-generator.js'
    'dist/html-generator.js.map'
    'dist/documentclasses/'
    'dist/packages/'
    'dist/css/'
    'dist/fonts/'
    'dist/js/'
    'dist/latex.min.js'
    'dist/latex.min.js.map'
    'dist/latex.component.js'


scripts:
    clean: 'rimraf dist bin test/coverage docs/js/playground.bundle.*;'
    build: "
        npm run devbuild;
        cd dist;
        uglifyjs latex-parser.js  -cm --source-map 'includeSources,url=\"./latex-parser.js.map\"' -o latex-parser.js;

        echo -n index latex.ltx symbols generator html-generator |
                        xargs -d' ' -P8 -I{} uglifyjs {}.js              -cm --source-map 'content=inline,includeSources,url=\"./{}.js.map\"' -o {}.js;

        ls documentclasses/ | xargs -P8 -I{} uglifyjs documentclasses/{} -cm --source-map 'content=inline,includeSources,url=\"./{}.map\"' -o documentclasses/{};
        ls packages/        | xargs -P8 -I{} uglifyjs packages/{}        -cm --source-map 'content=inline,includeSources,url=\"./{}.map\"' -o packages/{};

        cd ..;
    "
    devbuild: "
        rimraf dist/**/*.js.map;
        mkdirp dist/documentclasses;
        mkdirp dist/packages;
        mkdirp dist/css;
        mkdirp dist/js;
        mkdirp dist/fonts;
        rsync -a src/css/ dist/css/;
        rsync -a src/fonts/ dist/fonts/;
        rsync -a node_modules/katex/dist/fonts/*.woff dist/fonts/;
        rsync -a src/js/ dist/js/;
        cp src/latex.component.js dist/;
        lsc -c -m embedded -o dist src/plugin-pegjs.ls src/symbols.ls src/generator.ls src/html-generator.ls &
        lsc -c -m embedded -p src/latex.ltx.ls > dist/latex.ltx.js &
        lsc -c -m embedded -p src/types.ls > dist/types.js &
        lsc -c -m embedded -o dist/documentclasses src/documentclasses/ &
        lsc -c -m embedded -o dist/packages src/packages/;
        wait;
        pegjs -o dist/latex-parser.js --plugin ./dist/plugin-pegjs src/latex-parser.pegjs;
        babel -o dist/latex-parser.js dist/latex-parser.js;
        babel -o dist/index.js -s inline src/index.js;

        mkdirp bin;
        lsc -bc --no-header -m embedded -p src/cli.ls > bin/latex.js;
        chmod a+x bin/latex.js;

        webpack --config-name latex.js
    "
    docs:  'npm run devbuild && webpack --config-name playground'
    pgcc:  "google-closure-compiler --compilation_level SIMPLE \
                                    --externs src/externs.js \
                                    --js_output_file docs/js/playground.bundle.min.js docs/js/playground.bundle.js;"

    test:  'mocha test/*.ls;'
    iron:  'iron-node node_modules/.bin/_mocha test/*.ls;'

    testc: "
        nyc ./node_modules/.bin/mocha -i -g screenshot --reporter mocha-junit-reporter --reporter-options mochaFile=./test/test-results.xml test/*.ls &&
        mocha -g screenshot --reporter mocha-junit-reporter --reporter-options mochaFile=./test/screenshots/test-results.xml test/*.ls;
    "
    cover: 'nyc report --reporter=html --reporter=text --reporter=lcovonly --report-dir=test/coverage && codecov;'

babel:
    presets:
        * '@babel/preset-env'
            targets:
                node: 'current'
                browsers: '> 0.5%, not dead'
        ...

    plugins:
        '@babel/syntax-object-rest-spread'
        ...


dependencies:
    'he': '1.2.x'
    'katex': '0.10.0'
    '@svgdotjs/svg.js': '3.x',
    'svgdom': 'https://github.com/michael-brade/svgdom'

    'hypher': '0.x'
    'hyphenation.en-us': '*'
    'hyphenation.de': '*'

    'lodash': '4.x'
    'commander': '2.20.x'
    'stdin': '*'
    'fs-extra': '7.x'
    'js-beautify': '1.9.x'

    #'cheerio': '0.x'
    #'xmldom': '^0.1.19'

devDependencies:
    'livescript': 'https://github.com/michael-brade/LiveScript'

    ### building

    'pegjs': '0.10.x'
    'mkdirp': '0.5.x'
    'rimraf': '2.6.x'
    'uglify-js': '3.5.x'
    'tmp': '0.x'


    ### bundling

    'webpack': '4.x'
    'webpack-cli': '3.x'
    'webpack-closure-compiler': '2.x'
    'babel-loader': '8.0.x'
    'source-map-loader': '0.2.x'
    'copy-webpack-plugin': '5.x'

    '@babel/node': '7.2.x'
    '@babel/cli': '7.4.x'
    '@babel/core': '7.4.x'
    '@babel/register': '7.4.x'
    '@babel/preset-env': '7.4.x'
    '@babel/plugin-syntax-object-rest-spread': '7.2.x'


    ### testing

    'mocha': '6.x'
    'mocha-junit-reporter': '1.21.x'
    'chai': '4.x'
    'chai-as-promised': '7.x'
    'slugify': '1.3.x'
    'decache': '4.5.x'

    'puppeteer': '1.14.x'
    'puppeteer-firefox': '0.x'
    'pixelmatch': '4.0.x'

    'nyc': '13.x'
    'codecov': '3.x'


repository:
    type: 'git'
    url: 'git+https://github.com/michael-brade/LaTeX.js.git'

license: 'MIT'

bugs:
    url: 'https://github.com/michael-brade/LaTeX.js/issues'

homepage: 'https://latex.js.org'

engines:
    node: '>= 8.0'
