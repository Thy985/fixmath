import '@testing-library/jest-dom';

global.AudioContext = class AudioContext {
  createAnalyser() { return {}; }
  createOscillator() { return {}; }
  createGain() { return {}; }
  decodeAudioData() { return Promise.resolve({}); }
};

global.OffscreenCanvas = class OffscreenCanvas {
  getContext() { return null; }
  convertToBlob() { return Promise.resolve(new Blob()); }
};
