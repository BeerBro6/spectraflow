(function () {
  'use strict';

  var _ctx = null;
  var _source = null;
  var _filters = [];
  var _gainNode = null;
  var _initialized = false;
  var _audioEl = null;

  // ── Intercept document.createElement so crossOrigin is set BEFORE src ──────
  var _origCreate = document.createElement.bind(document);
  document.createElement = function (tag) {
    var el = _origCreate(tag);
    if (typeof tag === 'string') {
      var t = tag.toLowerCase();
      if (t === 'audio' || t === 'video') {
        el.crossOrigin = 'anonymous';
        _audioEl = el;
        console.log('[SpectraEq] Audio element created — crossOrigin=anonymous set.');
      }
    }
    return el;
  };

  // ── Fallback: MutationObserver for elements added to DOM ─────────────────
  new MutationObserver(function (muts) {
    muts.forEach(function (mut) {
      mut.addedNodes.forEach(function (node) {
        if (node.nodeType !== 1) return;
        var tag = (node.tagName || '').toLowerCase();
        if (tag === 'audio' || tag === 'video') {
          if (!node.crossOrigin) {
            node.crossOrigin = 'anonymous';
            console.log('[SpectraEq] DOM audio element patched with crossOrigin.');
          }
          if (!_audioEl) _audioEl = node;
        }
      });
    });
  }).observe(document.documentElement, { childList: true, subtree: true });

  // ── Initialize AudioContext and attach BiquadFilter chain ─────────────────
  function _init() {
    if (_initialized) {
      if (_ctx && _ctx.state === 'suspended') _ctx.resume();
      return true;
    }
    var el = _audioEl
      || document.querySelector('audio')
      || document.querySelector('video');

    if (!el) {
      console.warn('[SpectraEq] No audio element yet. Play a track first, then apply EQ.');
      return false;
    }
    if (!el.crossOrigin) {
      el.crossOrigin = 'anonymous';
      console.warn('[SpectraEq] crossOrigin set late — do a hard refresh (Ctrl+Shift+R) if EQ has no effect.');
    }
    try {
      _ctx = new (window.AudioContext || window.webkitAudioContext)();
      _source = _ctx.createMediaElementSource(el);
      _gainNode = _ctx.createGain();
      _gainNode.gain.value = 1.0;
      _source.connect(_gainNode);
      _gainNode.connect(_ctx.destination);
      _initialized = true;
      console.log('[SpectraEq] AudioContext connected. EQ is LIVE.');
      return true;
    } catch (e) {
      console.error('[SpectraEq] Init failed:', e.name, '—', e.message);
      if (e.name === 'SecurityError') {
        console.error('[SpectraEq] CORS blocked createMediaElementSource. Do a HARD refresh (Ctrl+Shift+R) so the audio element loads with crossOrigin=anonymous from the start.');
      }
      return false;
    }
  }

  function _disconnectAll() {
    try { if (_source) _source.disconnect(); } catch (_) {}
    _filters.forEach(function (f) { try { f.disconnect(); } catch (_) {} });
    _filters = [];
    try { if (_gainNode) _gainNode.disconnect(); } catch (_) {}
  }

  // ── Public API exposed on window.SpectraEq ────────────────────────────────
  window.SpectraEq = {
    init: function () {
      var ok = _init();
      console.log('[SpectraEq] init() ->', ok);
      return ok;
    },

    applyBands: function (bands, preamp) {
      console.log('[SpectraEq] applyBands() — bands:', (bands ? bands.length : 0), 'preamp:', preamp + 'dB');
      if (!_init()) return;
      if (_ctx.state === 'suspended') _ctx.resume();

      _disconnectAll();

      var gain = Math.pow(10, (preamp || 0) / 20);
      _gainNode.gain.value = gain;

      if (!bands || bands.length === 0) {
        _source.connect(_gainNode);
        _gainNode.connect(_ctx.destination);
        console.log('[SpectraEq] Flat passthrough active.');
        return;
      }

      var prev = _source;
      bands.forEach(function (band) {
        var f = _ctx.createBiquadFilter();
        var type = (band.type || 'PK').toUpperCase();
        if (type === 'LSC') { f.type = 'lowshelf'; }
        else if (type === 'HSC') { f.type = 'highshelf'; }
        else { f.type = 'peaking'; f.Q.value = band.q || 1.0; }
        f.frequency.value = band.frequency;
        f.gain.value = band.gain;
        prev.connect(f);
        prev = f;
        _filters.push(f);
      });

      prev.connect(_gainNode);
      _gainNode.connect(_ctx.destination);
      console.log('[SpectraEq] ' + bands.length + ' EQ bands live. Preamp linearGain=' + gain.toFixed(3));
    },

    setEnabled: function (enabled) {
      console.log('[SpectraEq] setEnabled:', enabled);
      if (!_initialized) { _init(); return; }
      if (_ctx.state === 'suspended') _ctx.resume();
      _disconnectAll();
      if (!enabled) {
        _source.connect(_ctx.destination);
        console.log('[SpectraEq] EQ bypassed — flat signal.');
      } else {
        _source.connect(_gainNode);
        _gainNode.connect(_ctx.destination);
        console.log('[SpectraEq] EQ re-enabled.');
      }
    },

    reset: function () {
      console.log('[SpectraEq] reset()');
      if (!_initialized) return;
      this.applyBands([], 0);
    },

    status: function () {
      return {
        initialized: _initialized,
        audioEl: _audioEl ? (_audioEl.tagName + ' crossOrigin=' + _audioEl.crossOrigin + ' src=' + (_audioEl.currentSrc || '?')) : 'none',
        ctxState: _ctx ? _ctx.state : 'no context',
        activeFilters: _filters.length
      };
    }
  };

  console.log('[SpectraEq] Bridge ready. createElement patched for crossOrigin.');
})();
