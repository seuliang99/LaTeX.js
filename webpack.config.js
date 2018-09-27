const path = require('path');

module.exports = [{
    name: 'playground',
    mode: 'production',
    devtool: 'source-map',

    entry: './docs/.vuepress/public/js/playground.js',

    output: {
        path: path.resolve(__dirname, 'docs/.vuepress/public/js'),
        filename: 'playground.bundle.min.js',
        libraryTarget: 'window',
        library: 'Playground'
    },
    resolve: {
        modules: [path.resolve(__dirname, "dist"), "node_modules"]
    },
    module: {
        rules: [
            {
                test: /\.js$/,
                use: 'source-map-loader',
                enforce: 'pre'
            },
            {
                test: /\.js$/,
                exclude: /(node_modules)/,
                use: 'babel-loader'
            }
        ]
    },
    performance: {
        maxEntrypointSize: 600000,
        maxAssetSize: 600000
    }
}, {
    name: 'latex.js',
    mode: 'production',
    devtool: 'source-map',

    entry: './dist/index.js',

    output: {
        filename: 'latex.min.js',
        libraryTarget: "umd",
        library: "latexjs",
        umdNamedDefine: true
    },
    module: {
        rules: [
            {
                test: /\.js$/,
                use: 'source-map-loader',
                enforce: 'pre'
            },
            {
                test: /\.js$/,
                exclude: /(node_modules)/,
                use: 'babel-loader'
            }
        ]
    },
    performance: {
        maxEntrypointSize: 600000,
        maxAssetSize: 600000
    }
}];
