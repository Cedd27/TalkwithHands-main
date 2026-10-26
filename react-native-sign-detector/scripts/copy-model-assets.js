const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const source = path.join(root, 'assets', 'ml');
const target = path.join(__dirname, '..', 'assets', 'ml');

fs.mkdirSync(target, { recursive: true });

for (const name of [
  'sign_landmark_classifier.tflite',
  'sign_sequence_classifier.tflite',
  'labels.txt',
  'sequence_labels.txt'
]) {
  fs.copyFileSync(path.join(source, name), path.join(target, name));
}

console.log(`Copied model assets to ${target}`);
