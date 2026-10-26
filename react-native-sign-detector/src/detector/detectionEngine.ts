import type { DetectionMode, HandLandmark, MotionCategory, SignResult } from './types';
import { TfliteSignClassifier } from './tfliteSignClassifier';

const ruleFirstAlphabetLabels = new Set(['G', 'H', 'I', 'J', 'L', 'R', 'S', 'U', 'V', 'W', 'Y', 'Z']);

export class DetectionEngine {
  private classifier = new TfliteSignClassifier();
  private captureHits: SignResult[] = [];

  async load() {
    await this.classifier.load();
  }

  classifyFrame(
    primaryHand: HandLandmark[],
    hands: HandLandmark[][] | null,
    mode: DetectionMode,
    motionCategory: MotionCategory
  ): SignResult | null {
    switch (mode) {
      case 'az': {
        const sequenceHit = this.classifier.pushFrameAndClassify(primaryHand);
        const tfliteHit = this.classifier.classifyAlphabet(primaryHand);
        return this.chooseAlphabetHit(tfliteHit, sequenceHit);
      }
      case 'num':
        return this.classifier.classifyNumber(primaryHand);
      case 'words':
        return (
          this.classifier.classifyWordsFromHands(hands) ??
          this.classifier.pushFrameAndClassify(primaryHand)
        );
      case 'motion':
        return this.classifyMotionFrame(primaryHand, hands, motionCategory);
    }
  }

  trackCaptureHit(hit: SignResult | null) {
    if (!hit) {
      return;
    }

    const minimumConfidence = hit.label === 'J' || hit.label === 'Z' ? 0.7 : 0.76;
    if (hit.confidence < minimumConfidence) {
      return;
    }

    this.captureHits.push(hit);
    if (this.captureHits.length > 36) {
      this.captureHits.shift();
    }
  }

  bestCapturedHit() {
    if (this.captureHits.length === 0) {
      return null;
    }

    const grouped = new Map<string, SignResult[]>();
    for (const hit of this.captureHits) {
      const bucket = grouped.get(hit.label) ?? [];
      bucket.push(hit);
      grouped.set(hit.label, bucket);
    }

    let best: SignResult | null = null;
    let bestScore = 0;

    for (const hits of grouped.values()) {
      const topHit = hits.reduce((a, b) => (a.confidence >= b.confidence ? a : b));
      const repeatScore = Math.min(hits.length / 6, 0.18);
      const modelBonus = topHit.isModelConfidence ? 0.04 : 0;
      const score = topHit.confidence + repeatScore + modelBonus;

      if (score > bestScore) {
        bestScore = score;
        best = topHit;
      }
    }

    return best;
  }

  resetCapture() {
    this.captureHits = [];
    this.classifier.resetSequenceBuffer();
  }

  private classifyMotionFrame(
    primaryHand: HandLandmark[],
    hands: HandLandmark[][] | null,
    motionCategory: MotionCategory
  ) {
    if (motionCategory === 'az') {
      const sequenceHit = this.classifier.pushFrameAndClassify(primaryHand);
      if (sequenceHit && (sequenceHit.label === 'J' || sequenceHit.label === 'Z')) {
        return { ...sequenceHit, type: 'alphabet' as const };
      }
      return this.classifier.classifyAlphabet(primaryHand);
    }

    if (motionCategory === 'num') {
      return this.classifier.classifyNumber(primaryHand);
    }

    const sequenceHit = this.classifier.pushFrameAndClassify(primaryHand);
    if (sequenceHit && sequenceHit.label === 'hello') {
      return { ...sequenceHit, type: 'word' as const };
    }

    return this.classifier.classifyWordsFromHands(hands);
  }

  private chooseAlphabetHit(tfliteHit: SignResult | null, sequenceHit: SignResult | null) {
    if (sequenceHit && (sequenceHit.label === 'J' || sequenceHit.label === 'Z')) {
      return { ...sequenceHit, type: 'alphabet' as const };
    }

    if (tfliteHit && ruleFirstAlphabetLabels.has(tfliteHit.label)) {
      return tfliteHit;
    }

    return tfliteHit;
  }
}
