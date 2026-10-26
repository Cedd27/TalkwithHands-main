const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const config = getDefaultConfig(__dirname);

module.exports = mergeConfig(config, {
  projectRoot: __dirname,
  watchFolders: [path.resolve(__dirname, '..')],
  resolver: {
    assetExts: [...config.resolver.assetExts, 'tflite', 'txt']
  }
});
