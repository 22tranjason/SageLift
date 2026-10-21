const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { test } = require('node:test');
const vm = require('node:vm');

const index = readFileSync('web/index.html', 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
const bootstrap = readFileSync('web/flutter_bootstrap.js', 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

async function indexScript({ online = true, requested = '14-old', stored = null } = {}) {
  let asset;
  const storage = new Map([['workout', 'untouched'], ['sagelift.loaded-build.v1', stored]]);
  const context = {
    URL, AbortController, setTimeout, clearTimeout, location: { href: `https://example.test/SageLift/?sagelift-build=${requested}#/today` },
    document: { baseURI: 'https://example.test/SageLift/', createElement: () => ({}),
      body: { appendChild: (script) => { asset = script.src; } } },
    localStorage: { getItem: (key) => storage.get(key) },
    fetch: async (url, options) => {
      assert.equal(url.origin + url.pathname, 'https://example.test/SageLift/version.json');
      assert.ok(url.searchParams.has('cacheBust'));
      assert.equal(options.cache, 'no-store');
      if (!online) throw new Error('Offline');
      return { ok: true, json: async () => ({ buildId: '15-new' }) };
    },
  };
  await vm.runInNewContext(index, context);
  assert.equal(storage.get('workout'), 'untouched');
  return asset;
}

test('fresh version selects a new bootstrap even when document requests an older release', async () => {
  assert.equal(await indexScript(), 'https://example.test/SageLift/flutter_bootstrap.js?sagelift-build=15-new');
});

test('offline launch retains requested or last successfully loaded release', async () => {
  assert.match(await indexScript({ online: false }), /sagelift-build=14-old$/);
  assert.match(await indexScript({ online: false, requested: '', stored: '15-saved' }), /sagelift-build=15-saved$/);
});

test('bootstrap versions executable assets and records release only after entrypoint loads', async () => {
  const storage = new Map([['workout', 'untouched']]);
  const builds = [{ mainJsPath: 'main.dart.js' }, { mainWasmPath: 'main.dart.wasm', jsSupportRuntimePath: 'main.dart.mjs' }];
  let options;
  vm.runInNewContext(bootstrap, {
    URL, document: { baseURI: 'https://example.test/SageLift/',
      currentScript: { src: 'https://example.test/SageLift/flutter_bootstrap.js?sagelift-build=15-new' } },
    _flutter: { buildConfig: { builds }, loader: { load: (value) => { options = value; } } },
    localStorage: { setItem: (key, value) => storage.set(key, value) },
  });
  for (const build of builds) {
    for (const path of Object.values(build)) {
      assert.match(path, /^https:\/\/example.test\/SageLift\/main\.dart\.(js|wasm|mjs)\?sagelift-build=15-new$/);
    }
  }
  assert.equal(storage.has('sagelift.loaded-build.v1'), false);
  let started = false;
  await options.onEntrypointLoaded({ initializeEngine: async () => ({ runApp: async () => { started = true; } }) });
  assert.equal(started, true);
  assert.equal(storage.get('sagelift.loaded-build.v1'), '15-new');
  assert.equal(storage.get('workout'), 'untouched');
});
