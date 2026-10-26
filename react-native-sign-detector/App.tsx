import React from 'react';
import { SafeAreaView, StatusBar, StyleSheet } from 'react-native';

import { SignDetectorScreen } from './src/ui/SignDetectorScreen';

export default function App() {
  return (
    <SafeAreaView style={styles.root}>
      <StatusBar barStyle="light-content" backgroundColor="#05070b" />
      <SignDetectorScreen />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#05070b'
  }
});
