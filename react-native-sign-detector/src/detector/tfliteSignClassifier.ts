import { loadTensorflowModel, type TensorflowModel } from 'react-native-fast-tflite';
import { Image } from 'react-native';

import { normalizeLandmarks } from './landmarkMath';
import type { HandLandmark, SignResult } from './types';

const SEQUENCE_FRAMES = 30;
const MINIMUM_CONFIDENCE = 0.78;

const staticModelAsset = require('../../../assets/ml/sign_landmark_classifier.tflite');
const sequenceModelAsset = require('../../../assets/ml/sign_sequence_classifier.tflite');
const staticLabelsAsset = require('../../../assets/ml/labels.txt');
const sequenceLabelsAsset = require('../../../assets/ml/sequence_labels.txt');

type LabelFilter = (label: string) => boolean;

async function readTextAsset(asset: number): Promise<string> {
  const resolved = Image.resolveAssetSource(asset);
  const response = await fetch(resolved.uri);
  return response.text();
}

export class TfliteSignClassifier {
  private staticModel: TensorflowModel | null = null;
  private sequenceModel: TensorflowModel | null = null;
  private labels: string[] = [];
  private sequenceLabels: string[] = [];
  private frameBuffer: number[][] = [];

  async load() {
    const [staticLabelsText, sequenceLabelsText] = await Promise.all([
      readTextAsset(staticLabelsAsset),
      readTextAsset(sequenceLabelsAsset)
    ]);

    this.labels = staticLabelsText
      .split('\n')
      .map((label) => label.trim())
      .filter(Boolean);
    this.sequenceLabels = sequenceLabelsText
      .split('\n')
      .map((label) => label.trim())
      .filter(Boolean);

    const [staticModel, sequenceModel] = await Promise.all([
      loadTensorflowModel(staticModelAsset, []),
      loadTensorflowModel(sequenceModelAsset, [])
    ]);

    this.staticModel = staticModel;
    this.sequenceModel = sequenceModel;
  }

  get isReady() {
    return this.staticModel != null && this.labels.length > 0;
  }

  classifyAlphabet(landmarks: HandLandmark[]) {
    return this.classify(
      landmarks,
      (label) => /^[A-Z]$/.test(label),
      'alphabet'
    );
  }

  classifyNumber(landmarks: HandLandmark[]) {
    return this.classify(
      landmarks,
      (label) => Number.isInteger(Number(label)),
      'number'
    );
  }

  classifyWordsFromHands(hands: HandLandmark[][] | null) {
    if (!hands || hands.length === 0) {
      return null;
    }

    return this.classify(
      hands[0],
      (label) => !/^[A-Z]$/.test(label) && !Number.isInteger(Number(label)),
      'word'
    );
  }

  pushFrameAndClassify(landmarks: HandLandmark[]) {
    if (!this.sequenceModel || this.sequenceLabels.length === 0) {
      return null;
    }

    const normalized = normalizeLandmarks(landmarks);
    if (normalized.length === 0) {
      return null;
    }

    this.frameBuffer.push(normalized);
    if (this.frameBuffer.length > SEQUENCE_FRAMES) {
      this.frameBuffer.shift();
    }
    if (this.frameBuffer.length < SEQUENCE_FRAMES) {
      return null;
    }

    return this.classifySequence();
  }

  resetSequenceBuffer() {
    this.frameBuffer = [];
  }

  private classify(
    landmarks: HandLandmark[],
    acceptsLabel: LabelFilter,
    type: SignResult['type']
  ): SignResult | null {
    if (!this.staticModel || this.labels.length === 0) {
      return null;
    }

    const normalized = normalizeLandmarks(landmarks);
    if (normalized.length === 0) {
      return null;
    }

    const input = Float32Array.from(normalized);
    const outputs = this.staticModel.runSync([input.buffer]);
    const scores = Array.from(new Float32Array(outputs[0] as ArrayBuffer));

    let bestIndex = -1;
    let bestConfidence = 0;
    const limit = Math.min(scores.length, this.labels.length);

    for (let i = 0; i < limit; i += 1) {
      const label = this.labels[i];
      if (!acceptsLabel(label)) {
        continue;
      }
      if (scores[i] > bestConfidence) {
        bestConfidence = scores[i];
        bestIndex = i;
      }
    }

    if (bestIndex === -1 || bestConfidence < MINIMUM_CONFIDENCE) {
      return null;
    }

    return {
      label: this.labels[bestIndex],
      confidence: bestConfidence,
      type,
      isModelConfidence: true
    };
  }

  private classifySequence(): SignResult | null {
    if (!this.sequenceModel || this.sequenceLabels.length === 0) {
      return null;
    }

    const flat = this.frameBuffer.flat();
    const input = Float32Array.from(flat);
    const outputs = this.sequenceModel.runSync([input.buffer]);
    const scores = Array.from(new Float32Array(outputs[0] as ArrayBuffer));

    let bestIndex = -1;
    let bestConfidence = 0;
    const limit = Math.min(scores.length, this.sequenceLabels.length);

    for (let i = 0; i < limit; i += 1) {
      if (scores[i] > bestConfidence) {
        bestConfidence = scores[i];
        bestIndex = i;
      }
    }

    if (bestIndex === -1 || bestConfidence < MINIMUM_CONFIDENCE) {
      return null;
    }

    return {
      label: this.sequenceLabels[bestIndex],
      confidence: bestConfidence,
      type: 'sequence',
      isModelConfidence: true
    };
  }
}
