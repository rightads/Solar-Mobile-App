import React from 'react';

export default function DownloadCenter({ userPlatform, onOpenModal, onDownload }) {
  const OFFICIAL_RELEASES = {
    android: 'https://github.com/rightads/Solar-Mobile-App/releases/download/Android/SolarPro-Android-v1.5.0.apk',
    windows: 'https://github.com/rightads/Solar-Mobile-App/releases/download/Windows/SolarPro-Windows-x64-v1.0.0.zip'
  };

  const isAndroid = userPlatform === 'android';
  const isWindows = userPlatform === 'windows';

  return (
    <section className="section downloads-section" id="downloads">
      <div className="container">
        <div className="section-badge">OFFICIAL DOWNLOAD HUB</div>
        <h2 className="section-title">Get SolarPro v1.0.0 Now</h2>
        <p className="section-subtitle">
          Experience lightning fast solar management on your Windows PC and Android phones. Choose your platform below.
        </p>

        <div className="download-cards-grid">
          
          {/* Windows Download Card */}
          <div className="dl-platform-card win-card" id="card-windows">
            <div className="card-badge win">
              {isWindows ? 'DETECTED FOR YOUR PC (WINDOWS 64-BIT)' : 'RECOMMENDED FOR DESKTOP'}
            </div>
            <div className="dl-platform-header">
              <div className="dl-icon-box win-icon-box">
                <svg viewBox="0 0 24 24" fill="currentColor" className="card-platform-svg">
                  <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.949-1.801"/>
                </svg>
              </div>
              <div>
                <h3>SolarPro for Windows</h3>
                <span className="dl-version-tag">Version 1.0.0 Stable (64-bit)</span>
              </div>
            </div>

            <p className="dl-card-desc">
              Complete enterprise edition with multi-column project matrix, high-speed ledger approval, DISCOM tracker, and keyboard shortcuts.
            </p>

            <div className="dl-specs-list">
              <div className="spec-row">
                <span>Operating System</span>
                <strong>Windows 11 / Windows 10 (64-bit)</strong>
              </div>
              <div className="spec-row">
                <span>Binary Architecture</span>
                <strong>x64 Native MSVC</strong>
              </div>
              <div className="spec-row">
                <span>Package Size</span>
                <strong>~16 MB (Self-contained)</strong>
              </div>
              <div className="spec-row">
                <span>Cloud Telemetry</span>
                <strong className="green-txt">Cloud Engine Connected</strong>
              </div>
            </div>

            <div className="dl-action-group">
              <a
                href={OFFICIAL_RELEASES.windows}
                className="btn btn-download-card win-main-btn"
                id="btn-win-download-file"
                onClick={() => onDownload('windows')}
              >
                <svg className="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                  <polyline points="7 10 12 15 17 10"></polyline>
                  <line x1="12" y1="15" x2="12" y2="3"></line>
                </svg>
                <span>Download Windows Package (.ZIP • 15.4 MB)</span>
              </a>
              
              <button
                type="button"
                className="btn btn-outline-win"
                onClick={() => onOpenModal('windows')}
              >
                Installation Instructions &amp; SHA256
              </button>
            </div>
          </div>

          {/* Android Download Card */}
          <div className="dl-platform-card android-card" id="card-android">
            <div className="card-badge android">
              {isAndroid ? 'DETECTED FOR YOUR DEVICE (ANDROID)' : 'FIELD & CLIENT COMPANION'}
            </div>
            <div className="dl-platform-header">
              <div className="dl-icon-box android-icon-box">
                <svg viewBox="0 0 24 24" fill="currentColor" className="card-platform-svg">
                  <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4114 13.8533 8.082 12 8.082s-3.5902.3294-5.1368.8677L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/>
                </svg>
              </div>
              <div>
                <h3>SolarPro for Android</h3>
                <span className="dl-version-tag">Version 1.5.0 Stable (APK)</span>
              </div>
            </div>

            <p className="dl-card-desc">
              Equip on-site installation crews and rooftop solar clients with instant status tracking, photo verification, and real-time generation graphs.
            </p>

            <div className="dl-specs-list">
              <div className="spec-row">
                <span>Operating System</span>
                <strong>Android 8.0 (Oreo) to Android 15</strong>
              </div>
              <div className="spec-row">
                <span>Distribution</span>
                <strong>Direct APK &amp; Google Play</strong>
              </div>
              <div className="spec-row">
                <span>Features</span>
                <strong>Camera, GPS, Offline Storage</strong>
              </div>
              <div className="spec-row">
                <span>Target Hardware</span>
                <strong>Universal ARM64 / armeabi-v7a</strong>
              </div>
            </div>

            <div className="dl-action-group">
              <a
                href={OFFICIAL_RELEASES.android}
                className="btn btn-download-card android-main-btn"
                id="btn-android-download-file"
                onClick={() => onDownload('android')}
              >
                <svg className="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                  <polyline points="7 10 12 15 17 10"></polyline>
                  <line x1="12" y1="15" x2="12" y2="3"></line>
                </svg>
                <span>Download Android APK (61.7 MB)</span>
              </a>
              
              <button
                type="button"
                className="btn btn-outline-android"
                onClick={() => onOpenModal('android')}
              >
                How to Install APK on Phone
              </button>
            </div>
          </div>

        </div>

        {/* Live API Status Bar */}
        <div className="api-health-banner">
          <div className="api-left">
            <span className="pulse-dot green"></span>
            <div>
              <strong>SolarPro Cloud Production Cluster</strong>
              <span>Encrypted HTTPS API · TLS 1.2+</span>
            </div>
          </div>
          <div className="api-right">
            <span className="api-badge">Status: 200 OK</span>
            <span className="api-badge">Secured</span>
          </div>
        </div>

      </div>
    </section>
  );
}
