import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraFormat,
  useCameraPermission,
  useFrameProcessor
} from 'react-native-vision-camera';
import { runOnJS, useSharedValue } from 'react-native-reanimated';

import { DetectionEngine } from '../detector/detectionEngine';
import { smoothHands } from '../detector/landmarkMath';
import type {
  DetectionMode,
  DetectorStatus,
  HandLandmark,
  MotionCategory,
  SignResult
} from '../detector/types';
import {
  detectHandLandmarks,
  hasHandLandmarkerPlugin
} from '../vision/handLandmarkerFrameProcessor';

const PREPARE_SECONDS = 5;
const PROCESS_EVERY_MS = 100;

export function SignDetectorScreen() {
  const device = useCameraDevice('front');
  const format = useCameraFormat(device, [
    { videoResolution: { width: 640, height: 480 } },
    { fps: 30 }
  ]);
  const { hasPermission, requestPermission } = useCameraPermission();

  const engine = useMemo(() => new DetectionEngine(), []);
  const lastFrameAt = useSharedValue(0);
  const previousHands = useRef<HandLandmark[][] | null>(null);
  const armedRef = useRef(false);
  const modeRef = useRef<DetectionMode>('words');
  const motionCategoryRef = useRef<MotionCategory>('words');

  const [status, setStatus] = useState<DetectorStatus>('loading-models');
  const [mode, setMode] = useState<DetectionMode>('words');
  const [motionCategory, setMotionCategory] = useState<MotionCategory>('words');
  const [hands, setHands] = useState<HandLandmark[][] | null>(null);
  const [currentHit, setCurrentHit] = useState<SignResult | null>(null);
  const [sentence, setSentence] = useState('');
  const [currentWord, setCurrentWord] = useState('');
  const [countdown, setCountdown] = useState(0);
  const [isArmed, setIsArmed] = useState(false);
  const [captureMessage, setCaptureMessage] = useState('Press Start, then sign clearly.');

  useEffect(() => {
    modeRef.current = mode;
    engine.resetCapture();
    setCurrentHit(null);
  }, [engine, mode]);

  useEffect(() => {
    motionCategoryRef.current = motionCategory;
    engine.resetCapture();
    setCurrentHit(null);
  }, [engine, motionCategory]);

  useEffect(() => {
    let mounted = true;

    async function init() {
      try {
        setStatus('loading-models');
        await engine.load();

        if (!hasHandLandmarkerPlugin()) {
          setStatus('native-plugin-missing');
          return;
        }

        setStatus('requesting-camera');
        const granted = hasPermission || (await requestPermission());
        if (!mounted) {
          return;
        }
        setStatus(granted ? 'camera-ready' : 'camera-denied');
      } catch (error) {
        console.warn('Detector init failed:', error);
        if (mounted) {
          setStatus('error');
        }
      }
    }

    init();
    return () => {
      mounted = false;
    };
  }, [engine, hasPermission, requestPermission]);

  const onLandmarks = useCallback(
    (detectedHands: HandLandmark[][]) => {
      const smoothed = smoothHands(detectedHands.length > 0 ? detectedHands : null, previousHands.current);
      previousHands.current = smoothed;
      setHands(smoothed);

      const primaryHand = detectedHands[0];
      if (!armedRef.current || !primaryHand) {
        return;
      }

      const hit = engine.classifyFrame(
        primaryHand,
        detectedHands,
        modeRef.current,
        motionCategoryRef.current
      );

      engine.trackCaptureHit(hit);
      setCurrentHit(hit);
    },
    [engine]
  );

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';
      const now = Date.now();
      if (now - lastFrameAt.value < PROCESS_EVERY_MS) {
        return;
      }
      lastFrameAt.value = now;
      const result = detectHandLandmarks(frame);
      runOnJS(onLandmarks)(result.hands);
    },
    [lastFrameAt, onLandmarks]
  );

  const startSigning = useCallback(() => {
    engine.resetCapture();
    setCurrentHit(null);
    setCaptureMessage('Get ready...');
    armedRef.current = false;
    setIsArmed(false);
    setCountdown(PREPARE_SECONDS);

    let remaining = PREPARE_SECONDS;
    const timer = setInterval(() => {
      remaining -= 1;
      setCountdown(remaining);
      if (remaining <= 0) {
        clearInterval(timer);
        armedRef.current = true;
        setIsArmed(true);
        setCaptureMessage('Signing... press Finish when done.');
      }
    }, 1000);
  }, [engine]);

  const finishSigning = useCallback(() => {
    armedRef.current = false;
    setIsArmed(false);
    setCountdown(0);
    const best = engine.bestCapturedHit();
    engine.resetCapture();
    setCurrentHit(best);

    if (!best) {
      setCaptureMessage('No clear sign detected. Try again.');
      return;
    }

    setCaptureMessage(`Captured ${best.label}`);
    if (modeRef.current === 'az' || (modeRef.current === 'motion' && motionCategoryRef.current === 'az')) {
      setCurrentWord((word: string) => `${word}${best.label}`);
      return;
    }

    setSentence((value: string) => `${value}${value ? ' ' : ''}${best.label}`);
  }, [engine]);

  const clearAll = useCallback(() => {
    engine.resetCapture();
    setSentence('');
    setCurrentWord('');
    setCurrentHit(null);
    setCaptureMessage('Press Start, then sign clearly.');
  }, [engine]);

  if (status !== 'camera-ready' || !device) {
    return <DetectorStatusView status={status} hasDevice={Boolean(device)} />;
  }

  const handVisible = hands != null && hands.length > 0;

  return (
    <View style={styles.container}>
      <Camera
        style={StyleSheet.absoluteFill}
        device={device}
        format={format}
        isActive
        fps={30}
        pixelFormat="yuv"
        frameProcessor={frameProcessor}
      />
      <View style={styles.topBar}>
        <ModeButton label="Words" active={mode === 'words'} onPress={() => setMode('words')} />
        <ModeButton label="A-Z" active={mode === 'az'} onPress={() => setMode('az')} />
        <ModeButton label="0-9" active={mode === 'num'} onPress={() => setMode('num')} />
        <ModeButton label="Motion" active={mode === 'motion'} onPress={() => setMode('motion')} />
      </View>
      {mode === 'motion' ? (
        <View style={styles.motionBar}>
          <ModeButton label="Words" active={motionCategory === 'words'} onPress={() => setMotionCategory('words')} />
          <ModeButton label="A-Z" active={motionCategory === 'az'} onPress={() => setMotionCategory('az')} />
          <ModeButton label="0-9" active={motionCategory === 'num'} onPress={() => setMotionCategory('num')} />
        </View>
      ) : null}
      <View style={styles.badge}>
        <Text style={[styles.prediction, { color: hitColor(currentHit) }]}>
          {currentHit?.label ?? (handVisible ? '...' : 'NO HAND')}
        </Text>
        <Text style={styles.badgeMeta}>
          {currentHit ? `${Math.round(currentHit.confidence * 100)}% model confidence` : captureMessage}
        </Text>
        <View style={styles.confidenceTrack}>
          <View
            style={[
              styles.confidenceFill,
              {
                width: `${Math.round((currentHit?.confidence ?? 0) * 100)}%`,
                backgroundColor: hitColor(currentHit)
              }
            ]}
          />
        </View>
      </View>
      {countdown > 0 ? (
        <View style={styles.countdownOverlay}>
          <Text style={styles.countdown}>{countdown}</Text>
          <Text style={styles.countdownText}>Position your hand in the frame</Text>
        </View>
      ) : null}
      <View style={styles.bottomPanel}>
        <Text style={styles.sentence}>
          {sentence || currentWord || captureMessage}
        </Text>
        {currentWord ? <Text style={styles.currentWord}>{currentWord}</Text> : null}
        <View style={styles.actions}>
          <ActionButton label={isArmed ? 'Finish Sign' : 'Start Sign'} accent onPress={isArmed ? finishSigning : startSigning} />
          <ActionButton label="Space" onPress={() => setCurrentWord((word: string) => `${word} `)} />
          <ActionButton label="Commit" onPress={() => {
            if (!currentWord.trim()) return;
            setSentence((value: string) => `${value}${value ? ' ' : ''}${currentWord.trim()}`);
            setCurrentWord('');
          }} />
          <ActionButton label="Clear" onPress={clearAll} />
        </View>
      </View>
    </View>
  );
}

function DetectorStatusView({ status, hasDevice }: { status: DetectorStatus; hasDevice: boolean }) {
  const message = !hasDevice
    ? 'No front camera found.'
    : status === 'native-plugin-missing'
      ? 'Missing native MediaPipe frame processor: detectHandLandmarks.'
      : status === 'camera-denied'
        ? 'Camera permission denied.'
        : status === 'error'
          ? 'Detector failed to initialize.'
          : 'Loading detector...';

  return (
    <View style={styles.status}>
      <ActivityIndicator color="#00e5cc" size="large" />
      <Text style={styles.statusText}>{message}</Text>
    </View>
  );
}

function ModeButton({ label, active, onPress }: { label: string; active: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[styles.modeButton, active && styles.modeButtonActive]}>
      <Text style={[styles.modeText, active && styles.modeTextActive]}>{label}</Text>
    </Pressable>
  );
}

function ActionButton({ label, accent, onPress }: { label: string; accent?: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[styles.actionButton, accent && styles.actionButtonAccent]}>
      <Text style={[styles.actionText, accent && styles.actionTextAccent]}>{label}</Text>
    </Pressable>
  );
}

function hitColor(hit: SignResult | null) {
  if (!hit) {
    return '#00e5cc';
  }
  if (hit.confidence > 0.82) {
    return '#00e5cc';
  }
  if (hit.confidence > 0.7) {
    return '#ffcc00';
  }
  return '#ff7744';
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#05070b'
  },
  status: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
    padding: 28,
    backgroundColor: '#05070b'
  },
  statusText: {
    color: 'rgba(255,255,255,0.72)',
    fontSize: 15,
    textAlign: 'center'
  },
  topBar: {
    position: 'absolute',
    top: 12,
    left: 12,
    right: 12,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center'
  },
  motionBar: {
    position: 'absolute',
    top: 54,
    left: 12,
    right: 12,
    flexDirection: 'row',
    gap: 8,
    justifyContent: 'center'
  },
  modeButton: {
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 8,
    backgroundColor: 'rgba(0,0,0,0.64)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.18)'
  },
  modeButtonActive: {
    backgroundColor: 'rgba(0,229,204,0.18)',
    borderColor: 'rgba(0,229,204,0.68)'
  },
  modeText: {
    color: 'rgba(255,255,255,0.72)',
    fontWeight: '700',
    fontSize: 12
  },
  modeTextActive: {
    color: '#00e5cc'
  },
  badge: {
    position: 'absolute',
    top: 98,
    right: 14,
    width: 174,
    padding: 12,
    borderRadius: 12,
    backgroundColor: 'rgba(0,0,0,0.82)',
    borderWidth: 2,
    borderColor: 'rgba(0,229,204,0.64)'
  },
  prediction: {
    fontSize: 32,
    fontWeight: '900',
    lineHeight: 36
  },
  badgeMeta: {
    marginTop: 3,
    color: 'rgba(255,255,255,0.62)',
    fontSize: 11
  },
  confidenceTrack: {
    marginTop: 8,
    height: 4,
    borderRadius: 3,
    backgroundColor: 'rgba(255,255,255,0.16)',
    overflow: 'hidden'
  },
  confidenceFill: {
    height: 4
  },
  countdownOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.48)'
  },
  countdown: {
    color: '#00e5cc',
    fontSize: 72,
    fontWeight: '900'
  },
  countdownText: {
    color: 'white',
    fontSize: 17,
    fontWeight: '700'
  },
  bottomPanel: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    padding: 12,
    paddingBottom: 16,
    backgroundColor: 'rgba(0,0,0,0.88)',
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.08)'
  },
  sentence: {
    minHeight: 44,
    color: 'white',
    fontSize: 16,
    lineHeight: 22,
    padding: 12,
    borderRadius: 8,
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderWidth: 1,
    borderColor: 'rgba(0,229,204,0.28)'
  },
  currentWord: {
    marginTop: 8,
    color: '#00e5cc',
    fontSize: 15,
    fontWeight: '800'
  },
  actions: {
    marginTop: 10,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8
  },
  actionButton: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.14)'
  },
  actionButtonAccent: {
    backgroundColor: 'rgba(0,229,204,0.18)',
    borderColor: 'rgba(0,229,204,0.64)'
  },
  actionText: {
    color: 'rgba(255,255,255,0.72)',
    fontWeight: '700',
    fontSize: 12
  },
  actionTextAccent: {
    color: '#00e5cc'
  }
});
