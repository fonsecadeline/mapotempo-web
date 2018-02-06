'use strict';

const {environment} = require('@rails/webpacker');

const webpack = require('webpack');
const path = require('path');

const erb = require('./loaders/erb');

environment.loaders.append('erb', erb);

// Add an ProvidePlugin
environment.plugins.set('Provide', new webpack.ProvidePlugin({
    PNotify: 'pnotify'
  })
);

const config = environment.toWebpackConfig();

config.resolve.alias = {
  jquery: path.resolve(__dirname, '..', '..', 'node_modules/jquery/src/jquery')
};

module.exports = environment;
