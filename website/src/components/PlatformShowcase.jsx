import React, { useState } from 'react';

export default function PlatformShowcase({ onOpenModal }) {
  const [activePlatform, setActivePlatform] = useState('windows');

  return (
    <section className="section showcase-section" id="showcase">
      <div className="container">
        <div className="section-badge">BUILT FOR DUAL ARCHITECTURE</div>
        <h2 className="section-title">One Unified Solar Engine. Two Powerhouse Experiences.</h2>
        <p className="section-subtitle">
          Whether managing hundreds of megawatts from your desktop multi-monitor setup or conducting rooftop site surveys with a phone in hand, SolarPro delivers unmatched speed.
        </p>

        {/* Platform Tab Selector */}
        <div className="showcase-tabs" id="showcase-tab-bar">
          <button
            className={`showcase-tab-btn ${activePlatform === 'windows' ? 'active' : ''}`}
            onClick={() => setActivePlatform('windows')}
          >
            <svg className="tab-svg" viewBox="0 0 24 24" fill="currentColor">
              <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.949-1.801"/>
            </svg>
            <span>Windows Desktop Command Center</span>
          </button>
          <button
            className={`showcase-tab-btn ${activePlatform === 'android' ? 'active' : ''}`}
            onClick={() => setActivePlatform('android')}
          >
            <svg className="tab-svg" viewBox="0 0 24 24" fill="currentColor">
              <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4114 13.8533 8.082 12 8.082s-3.5902.3294-5.1368.8677L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/>
            </svg>
            <span>Android Mobile &amp; Field Edition</span>
          </button>
        </div>

        {/* Windows Tab Content */}
        {activePlatform === 'windows' && (
          <div className="showcase-content-panel active" id="panel-windows">
            <div className="showcase-grid">
              <div className="showcase-text-col">
                <span className="sub-label gold">WINDOWS 10 &amp; 11 • 64-BIT COMMAND CENTER</span>
                <h3 className="panel-headline">Engineered for EPC Owners, Estimators &amp; Office Staff</h3>
                <p className="panel-desc">
                  Harness desktop-grade screen real estate to supervise multiple commercial and residential solar projects simultaneously. Designed with keyboard ergonomics, instantaneous search, and ledger verifications.
                </p>

                <ul className="feature-checklist">
                  <li>
                    <div className="check-icon">✓</div>
                    <div>
                      <strong>Omni-Search with <kbd>Ctrl + K</kbd></strong>
                      <p>Instantly pinpoint any lead, consumer phone number, inverter serial, or invoice in under 50ms.</p>
                    </div>
                  </li>
                  <li>
                    <div className="check-icon">✓</div>
                    <div>
                      <strong>High-Density Financial Approval Desk</strong>
                      <p>Review bank receipts, approve payment milestones, and disburse work orders with 1-click ledger audit.</p>
                    </div>
                  </li>
                  <li>
                    <div className="check-icon">✓</div>
                    <div>
                      <strong>KEDL Government Liaison Tracker</strong>
                      <p>Monitor name change requests, load enhancements, and net-metering status across all DISCOM zones.</p>
                    </div>
                  </li>
                  <li>
                    <div className="check-icon">✓</div>
                    <div>
                      <strong>Hardware Accelerated Performance</strong>
                      <p>Smooth 60 FPS rendering powered by native Flutter C++ engine with zero web-view overhead.</p>
                    </div>
                  </li>
                </ul>

                <div className="panel-cta-row">
                  <button
                    type="button"
                    className="btn btn-primary"
                    onClick={() => onOpenModal('windows')}
                  >
                    <svg className="icon-svg" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.949-1.801"/>
                    </svg>
                    <span>Download Windows Package (.EXE / .ZIP)</span>
                  </button>
                  <span className="panel-req">Requires Windows 10/11 64-bit • Standalone</span>
                </div>
              </div>

              <div className="showcase-visual-col">
                <div className="visual-card">
                  <div className="visual-card-glow"></div>
                  <div className="visual-header">
                    <span className="v-dot r"></span><span className="v-dot y"></span><span className="v-dot g"></span>
                    <span className="v-title">Multi-Column Project Matrix</span>
                  </div>
                  <div className="matrix-table">
                    <div className="matrix-row header">
                      <span>Customer / Site</span>
                      <span>Capacity</span>
                      <span>Current Stage</span>
                      <span>DISCOM / KEDL</span>
                      <span>Action</span>
                    </div>
                    <div className="matrix-row">
                      <span className="name">Rajesh Kumar <small>Dwarka</small></span>
                      <span className="bold">5.0 kW</span>
                      <span className="status-chip chip-gold">Structure Done</span>
                      <span className="status-chip chip-purp">Demand Paid</span>
                      <span className="action-link">Open File →</span>
                    </div>
                    <div className="matrix-row">
                      <span className="name">Sunita Devi <small>Janakpuri</small></span>
                      <span className="bold">3.2 kW</span>
                      <span className="status-chip chip-teal">Wiring Start</span>
                      <span className="status-chip chip-blue">Load Approved</span>
                      <span className="action-link">Open File →</span>
                    </div>
                    <div className="matrix-row">
                      <span className="name">Vikram Joshi <small>Rohini</small></span>
                      <span className="bold">7.5 kW</span>
                      <span className="status-chip chip-green">Grid Live ⚡</span>
                      <span className="status-chip chip-green">Net Metered</span>
                      <span className="action-link">Invoice PDF →</span>
                    </div>
                    <div className="matrix-row">
                      <span className="name">Priya Sharma <small>Pitampura</small></span>
                      <span className="bold">4.0 kW</span>
                      <span className="status-chip chip-warn">Survey Pending</span>
                      <span className="status-chip chip-gray">Not Started</span>
                      <span className="action-link">Assign Team →</span>
                    </div>
                  </div>
                  <div className="matrix-stats-bar">
                    <span>⚡ 4 Active Teams Dispatched</span>
                    <span>💰 ₹1,24,00,000 Portfolio</span>
                    <span>📄 98.4% On-Time Filing</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Android Tab Content */}
        {activePlatform === 'android' && (
          <div className="showcase-content-panel active" id="panel-android">
            <div className="showcase-grid">
              <div className="showcase-text-col">
                <span className="sub-label teal">ANDROID 8.0+ • FIELD TECHNICIAN &amp; CLIENT APP</span>
                <h3 className="panel-headline">Empower On-Site Installers &amp; Delight Solar Customers</h3>
                <p className="panel-desc">
                  Give your rooftop technicians an indispensable companion for geo-tagged photos, electrical diagrams, and offline checklist sync. Give your customers an inspiring window into their solar generation and bill savings.
                </p>

                <ul className="feature-checklist">
                  <li>
                    <div className="check-icon">✓</div>
                    <div>
                      <strong>Camera Uploads &amp; Rooftop Survey Tagging</strong>
                      <p>Technicians snap shadow analysis photos, structure earthing points, and inverter ratings directly to customer records.</p>
                    </div>
                  </li>
                  <li>
                    <div className="check-icon">✓</div>
                    <div>
                      <strong>Offline-First Resilience</strong>
                      <p>Works flawlessly on high roofs and remote village sites without cell service. Queues actions and syncs automatically when reconnected.</p>
                    </div>
                  </li>
                  <li>
                    <div className="check-icon">✓</div>
                    <div>
                      <strong>Customer Transparency Portal</strong>
                      <p>Rooftop owners monitor daily units generated, milestone progress bars, and download sanitized KEDL receipts with ease.</p>
                    </div>
                  </li>
                  <li>
                    <div className="check-icon">✓</div>
                    <div>
                      <strong>Direct WhatsApp Quote Generation</strong>
                      <p>Send branded solar estimates with kilowatt sizing and payback breakdowns straight to homeowners in 30 seconds.</p>
                    </div>
                  </li>
                </ul>

                <div className="panel-cta-row">
                  <button
                    type="button"
                    className="btn btn-teal"
                    onClick={() => onOpenModal('android')}
                  >
                    <svg className="icon-svg" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4114 13.8533 8.082 12 8.082s-3.5902.3294-5.1368.8677L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/>
                    </svg>
                    <span>Download Android APK / Google Play</span>
                  </button>
                  <span className="panel-req">Supports Android 8.0 to Android 15 • 42 MB</span>
                </div>
              </div>

              <div className="showcase-visual-col center-flex">
                <div className="mobile-dual-mockup">
                  {/* Technician View */}
                  <div className="phone-item">
                    <div className="phone-item-notch"></div>
                    <div className="phone-item-header">Technician Checklist</div>
                    <div className="phone-task-list">
                      <div className="p-task done">✓ Anchor Bolt Torque Check</div>
                      <div className="p-task done">✓ Earthing Pit Resistance: 2.1Ω</div>
                      <div className="p-task in-prog">⚡ DC Cable Conduit Sealing</div>
                      <div className="p-task">📷 Upload Rooftop Photos (4/6)</div>
                    </div>
                    <div className="p-cam-btn">📸 Snap Inspection Photo</div>
                  </div>

                  {/* Customer Live View */}
                  <div className="phone-item accent">
                    <div className="phone-item-notch"></div>
                    <div className="phone-item-header">Client Portal</div>
                    <div className="p-solar-circle">
                      <div className="p-kwh">28.4</div>
                      <small>kWh Today</small>
                    </div>
                    <div className="p-bill-cut">
                      <span>Grid Export: 19.8 units</span>
                      <strong>Bill Reduced by 86%</strong>
                    </div>
                    <div className="p-kedl-status">
                      <span>DISCOM Net-Meter: Approved ✓</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

      </div>
    </section>
  );
}
