/*
 * Nexus Consumers – native bridge injected into every first-party page.
 *
 * Exposes `window.NexusApp` so the website can use native features:
 *
 *   if (window.NexusApp) {
 *     const code   = await NexusApp.scanQr();                       // QR / barcode text or null
 *     const image  = await NexusApp.pickImage({ source: 'camera', crop: true });
 *                    // → { dataUrl, fileName, mimeType, size } or null
 *     await NexusApp.share({ text: 'Hello', url: location.href });
 *     await NexusApp.openPdf('https://example.com/statement.pdf');
 *     await NexusApp.download('https://example.com/report.xlsx', 'report.xlsx');
 *     const ok     = await NexusApp.biometric('Confirm withdrawal'); // true / false
 *     const device = await NexusApp.deviceInfo();
 *     const push   = await NexusApp.pushToken();                    // { fcm, onesignal }
 *     NexusApp.setReferralCode('ABC123');   // used by "Share referral link"
 *     NexusApp.setUserId('42');             // links OneSignal to the user
 *     NexusApp.logout();                    // native logout (clears session)
 *   }
 *
 * It also:
 *   - converts blob: downloads into native downloads,
 *   - reports login-form submissions for "Remember login" (only on HTTPS pages
 *     of the website; the app ignores other origins).
 */
(function () {
  'use strict';
  if (window.NexusApp) return;

  var ready = new Promise(function (resolve) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      resolve();
      return;
    }
    window.addEventListener('flutterInAppWebViewPlatformReady', function () { resolve(); }, { once: true });
  });

  function call(name, payload) {
    return ready.then(function () {
      return window.flutter_inappwebview.callHandler(name, payload === undefined ? null : payload);
    });
  }

  window.NexusApp = Object.freeze({
    isApp: true,
    platform: 'android',
    scanQr: function () { return call('nexusScanQr'); },
    pickImage: function (options) { return call('nexusPickImage', options || {}); },
    share: function (data) { return call('nexusShare', data || {}); },
    openPdf: function (url) { return call('nexusOpenPdf', { url: String(url) }); },
    download: function (url, fileName) {
      return call('nexusDownload', { url: String(url), fileName: fileName || null });
    },
    biometric: function (reason) { return call('nexusBiometric', { reason: reason || null }); },
    deviceInfo: function () { return call('nexusDeviceInfo'); },
    pushToken: function () { return call('nexusPushToken'); },
    setReferralCode: function (code) { return call('nexusSetReferralCode', { code: String(code || '') }); },
    setUserId: function (id) { return call('nexusSetUserId', { id: String(id || '') }); },
    logout: function () { return call('nexusLogout'); }
  });

  // ---- blob: downloads -----------------------------------------------------
  function saveBlob(href, fileName) {
    return fetch(href)
      .then(function (r) { return r.blob(); })
      .then(function (blob) {
        return new Promise(function (resolve) {
          var reader = new FileReader();
          reader.onloadend = function () {
            resolve(call('nexusDownloadBase64', {
              data: reader.result,
              fileName: fileName || 'download',
              mimeType: blob.type || null
            }));
          };
          reader.readAsDataURL(blob);
        });
      });
  }
  window.__nexusSaveBlob = saveBlob;

  document.addEventListener('click', function (event) {
    var anchor = event.target && event.target.closest
      ? event.target.closest('a[href^="blob:"], a[href^="data:"][download]')
      : null;
    if (!anchor) return;
    event.preventDefault();
    event.stopPropagation();
    var name = anchor.getAttribute('download') || 'download';
    if (anchor.href.indexOf('data:') === 0) {
      call('nexusDownloadBase64', { data: anchor.href, fileName: name, mimeType: null });
    } else {
      saveBlob(anchor.href, name);
    }
  }, true);

  // ---- Remember login -----------------------------------------------------------
  var USER_SELECTOR = [
    'input[type="email"]',
    'input[autocomplete="username"]',
    'input[name*="user" i]',
    'input[name*="email" i]',
    'input[name*="phone" i]',
    'input[name*="mobile" i]',
    'input[type="tel"]',
    'input[type="text"]'
  ].join(',');

  function captureCredentials(root) {
    var scope = root || document;
    var password = scope.querySelector('input[type="password"]');
    if (!password || !password.value) return;
    var container = password.form || scope;
    var user = container.querySelector(USER_SELECTOR);
    if (!user || !user.value) return;
    call('nexusSaveCredentials', { username: user.value, password: password.value });
  }

  document.addEventListener('submit', function (event) { captureCredentials(event.target); }, true);
  document.addEventListener('click', function (event) {
    var button = event.target && event.target.closest
      ? event.target.closest('button, input[type="submit"], [role="button"]')
      : null;
    if (!button) return;
    var form = button.form || (button.closest && button.closest('form'));
    if (form && form.querySelector('input[type="password"]')) {
      captureCredentials(form);
    } else if (!form && document.querySelector('input[type="password"]')) {
      captureCredentials(document);
    }
  }, true);
})();
