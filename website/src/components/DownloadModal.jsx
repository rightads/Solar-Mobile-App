import React, { useEffect } from 'react';

export default function DownloadModal({ platform, onClose, onDownload }) {
  const OFFICIAL_RELEASES = {
    android: 'https://github.com/rightads/Solar-Mobile-App/releases/download/Android/SolarPro-Android-v1.5.0.apk',
    windows: 'https://github.com/rightads/Solar-Mobile-App/releases/download/Windows/SolarPro-Windows-x64-v1.0.0.zip'
  };

  useEffect(() => {
    if (!platform) return;

    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };

    document.body.style.overflow = 'hidden';
    window.addEventListener('keydown', handleKeyDown);

    return () => {
      document.body.style.overflow = '';
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [platform, onClose]);

  if (!platform) return null;

  const handleBackdropClick = (e) => {
    if (e.target.id === 'download-modal') {
      onClose();
    }
  };

  return (
    <div className="modal-overlay open" id="download-modal" onClick={handleBackdropClick}>
      <div className="modal-box">
        <button
          type="button"
          className="modal-close-btn"
          onClick={onClose}
          aria-label="Close modal"
        >
          ✕
        </button>

        {/* Modal Content: Windows */}
        {platform === 'windows' && (
          <div className="modal-body" id="modal-content-windows">
            <div className="modal-header">
              <div className="modal-icon-badge win">
                <svg viewBox="0 0 24 24" fill="currentColor" className="m-svg">
                  <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.949-1.801"/>
                </svg>
              </div>
              <div>
                <h3>Download SolarPro for Windows</h3>
                <span className="m-ver">v1.0.0 • 64-bit Desktop Command Center</span>
              </div>
            </div>

            <div className="modal-instructions">
              <h4>🚀 Quick 3-Step Setup:</h4>
              <ol>
                <li>Click the download button below to get the official <code>SolarPro-Windows-x64-v1.0.0.zip</code> package (~16 MB).</li>
                <li>Extract the ZIP archive to any folder on your PC (e.g. <code>C:\SolarPro</code> or Desktop).</li>
                <li>Double-click <strong><code>solar_pro.exe</code></strong> to launch the app immediately!</li>
              </ol>
            </div>

            <div className="modal-checksum">
              <span className="chk-label">Package Verification:</span>
              <code>SHA-256: B764009B57F3B2B1F364A0EEB0F779DBDC5F04E28AA126353B54D7C3194B0E29</code>
            </div>

            <div className="modal-actions">
              <a
                href={OFFICIAL_RELEASES.windows}
                className="btn btn-primary btn-block btn-lg"
                onClick={() => onDownload('windows')}
              >
                <svg className="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                  <polyline points="7 10 12 15 17 10"></polyline>
                  <line x1="12" y1="15" x2="12" y2="3"></line>
                </svg>
                <span>Download Windows ZIP (15.4 MB)</span>
              </a>
            </div>
          </div>
        )}

        {/* Modal Content: Android */}
        {platform === 'android' && (
          <div className="modal-body" id="modal-content-android">
            <div className="modal-header">
              <div className="modal-icon-badge android">
                <svg viewBox="0 0 24 24" fill="currentColor" className="m-svg">
                  <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4114 13.8533 8.082 12 8.082s-3.5902.3294-5.1368.8677L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/>
                </svg>
              </div>
              <div>
                <h3>Download SolarPro for Android</h3>
                <span className="m-ver">v1.5.0 • Mobile &amp; Field Companion</span>
              </div>
            </div>

            <div className="qr-download-row">
              <div className="qr-box">
                <svg className="qr-svg" viewBox="0 0 100 100" fill="currentColor">
                  <path d="M10,10 h30 v30 h-30 z M15,15 v20 h20 v-20 z M20,20 h10 v10 h-10 z"/>
                  <path d="M60,10 h30 v30 h-30 z M65,15 v20 h20 v-20 z M70,20 h10 v10 h-10 z"/>
                  <path d="M10,60 h30 v30 h-30 z M15,65 v20 h20 v-20 z M20,70 h10 v10 h-10 z"/>
                  <rect x="50" y="10" width="5" height="15"/>
                  <rect x="10" y="50" width="20" height="5"/>
                  <rect x="50" y="50" width="10" height="10"/>
                  <rect x="65" y="55" width="15" height="5"/>
                  <rect x="85" y="50" width="5" height="20"/>
                  <rect x="50" y="70" width="15" height="5"/>
                  <rect x="70" y="75" width="20" height="15"/>
                  <rect x="50" y="85" width="10" height="5"/>
                </svg>
                <span className="qr-caption">Scan with Phone Camera</span>
              </div>
              <div className="qr-instructions">
                <h4>📲 Installation Instructions:</h4>
                <ul>
                  <li>Scan the QR code or tap the direct download button on your Android phone.</li>
                  <li>When prompted, allow <em>&quot;Install from Unknown Sources&quot;</em> for your browser.</li>
                  <li>Open <code>SolarPro-Android-v1.5.0.apk</code> and tap <strong>Install</strong>.</li>
                </ul>
              </div>
            </div>

            <div className="modal-checksum" style={{ marginTop: '-10px', marginBottom: '16px' }}>
              <span className="chk-label">Package Verification:</span>
              <code>Release Tag: Android • SolarPro-Android-v1.5.0.apk</code>
            </div>

            <div className="modal-actions">
              <a
                href={OFFICIAL_RELEASES.android}
                className="btn btn-teal btn-block btn-lg"
                onClick={() => onDownload('android')}
              >
                <svg className="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                  <polyline points="7 10 12 15 17 10"></polyline>
                  <line x1="12" y1="15" x2="12" y2="3"></line>
                </svg>
                <span>Download Android Package (.APK • 61.7 MB)</span>
              </a>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
