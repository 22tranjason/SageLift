{{flutter_js}}
{{flutter_build_config}}

(() => {
  const bootstrap = document.currentScript;
  const buildId = bootstrap && new URL(bootstrap.src).searchParams.get('sagelift-build');
  if (buildId) {
    for (const build of _flutter.buildConfig.builds) {
      // The loader resolves these relative paths against document.baseURI.
      // Keep the release query on every executable entrypoint, including Wasm.
      for (const key of ['mainJsPath', 'mainWasmPath', 'jsSupportRuntimePath']) {
        if (build[key]) {
          const entrypoint = new URL(build[key], document.baseURI);
          entrypoint.searchParams.set('sagelift-build', buildId);
          build[key] = entrypoint.href;
        }
      }
    }
  }
  _flutter.loader.load({
    onEntrypointLoaded: async (initializer) => {
      if (buildId) {
        try { localStorage.setItem('sagelift.loaded-build.v1', buildId); } catch (_) {}
      }
      const engine = await initializer.initializeEngine();
      await engine.runApp();
    },
  });
})();
