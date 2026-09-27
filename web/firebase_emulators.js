// Called only by builds with FIREBASE_EMULATOR_HOST. Initialize the same Auth
// instance/options as FlutterFire before its asynchronous session restoration.
window.aikoPrepareFirebaseEmulator = async (options, host, version) => {
  if (!options.projectId.startsWith('demo-')) throw new Error('A demo project is required');
  const base = `https://www.gstatic.com/firebasejs/${version}`;
  const core = await import(`${base}/firebase-app.js`);
  const auth = await import(`${base}/firebase-auth.js`);
  const app = core.getApps().find(app => app.name === '[DEFAULT]') || core.initializeApp(options);
  const instance = auth.initializeAuth(app, {
    errorMap: auth.debugErrorMap,
    persistence: [auth.indexedDBLocalPersistence, auth.browserLocalPersistence, auth.browserSessionPersistence],
    popupRedirectResolver: auth.browserPopupRedirectResolver,
  });
  if (!instance.emulatorConfig) auth.connectAuthEmulator(instance, `http://${host}:9099`, {disableWarnings: true});
};
