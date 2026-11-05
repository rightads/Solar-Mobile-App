import React from 'react';
import logoImg from '../assets/logo.png';

export default function Hero({ onOpenModal }) {
  return (
    <section className="hero-section" id="hero">
      <div className="container hero-container">
        
        {/* Release Announcement Pill */}
        <div className="hero-pill-badge" id="hero-release-pill">
          <span className="pill-sparkle">⚡</span>
          <span className="pill-text"><strong>v1.0.0 Now Live</strong> for Windows 10/11 &amp; Android</span>
          <span className="pill-arrow">→</span>
        </div>

        {/* Hero Heading */}
        <h1 className="hero-title">
          The Modern Operating System for <br />
          <span className="gradient-text gold-teal-gradient">Solar EPCs &amp; Installers</span>
        </h1>

        {/* Hero Description */}
        <p className="hero-description">
          Manage high-volume rooftop solar projects from lead inquiry to DISCOM KEDL net-metering approvals, field team dispatch, and automated milestone billing — with native multi-platform power.
        </p>

        {/* Primary Download Buttons Row */}
        <div className="download-action-group" id="hero-download-buttons">
          
          {/* Windows Download Button */}
          <button
            type="button"
            className="btn-download-hero win-btn"
            id="hero-win-download"
            onClick={() => onOpenModal('windows')}
          >
            <div className="btn-icon-col">
              <svg className="platform-icon" viewBox="0 0 24 24" fill="currentColor">
                <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.949-1.801"/>
              </svg>
            </div>
            <div className="btn-text-col">
              <span className="btn-subtext">Free Release • 64-bit</span>
              <span className="btn-maintext">Download for Windows</span>
              <span className="btn-tag">Windows 10 / 11 • Desktop Console</span>
            </div>
            <div className="btn-arrow-col">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" className="arrow-svg">
                <line x1="5" y1="12" x2="19" y2="12"></line>
                <polyline points="12 5 19 12 12 19"></polyline>
              </svg>
            </div>
          </button>

          {/* Android Download Button */}
          <button
            type="button"
            className="btn-download-hero android-btn"
            id="hero-android-download"
            onClick={() => onOpenModal('android')}
          >
            <div className="btn-icon-col">
              <svg className="platform-icon" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4114 13.8533 8.082 12 8.082s-3.5902.3294-5.1368.8677L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/>
              </svg>
            </div>
            <div className="btn-text-col">
              <span className="btn-subtext">Direct APK &amp; Mobile</span>
              <span className="btn-maintext">Download for Android</span>
              <span className="btn-tag">Android 8.0+ • Field &amp; Client App</span>
            </div>
            <div className="btn-arrow-col">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" className="arrow-svg">
                <line x1="5" y1="12" x2="19" y2="12"></line>
                <polyline points="12 5 19 12 12 19"></polyline>
              </svg>
            </div>
          </button>

        </div>

        {/* Hero Trust Markers */}
        <div className="hero-trust-bar">
          <div className="trust-item">
            <svg viewBox="0 0 20 20" fill="currentColor" className="trust-check"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>
            <span>DISCOM &amp; KEDL Compliant</span>
          </div>
          <div className="trust-item">
            <svg viewBox="0 0 20 20" fill="currentColor" className="trust-check"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>
            <span>Offline-First Field Sync</span>
          </div>
          <div className="trust-item">
            <svg viewBox="0 0 20 20" fill="currentColor" className="trust-check"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>
            <span>Sub-100ms Cloud Engine</span>
          </div>
          <div className="trust-item">
            <svg viewBox="0 0 20 20" fill="currentColor" className="trust-check"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg>
            <span>Zero Subscription Trial</span>
          </div>
        </div>

        {/* Hero Interactive Dual Preview Mockup */}
        <div className="hero-mockup-wrapper" id="hero-mockup">
          
          <div className="mockup-glow"></div>

          {/* Main Desktop Frame */}
          <div className="desktop-frame">
            <div className="window-titlebar">
              <div className="traffic-lights">
                <span className="light red"></span>
                <span className="light yellow"></span>
                <span className="light green"></span>
              </div>
              <div className="window-title">SolarPro Enterprise • Operations Console (Windows 64-bit)</div>
              <div className="window-badges">
                <span className="win-pill">Backend API: Connected</span>
              </div>
            </div>

            <div className="desktop-app-inner">
              {/* Sidebar */}
              <div className="mock-sidebar">
                <div className="mock-sidebar-brand">
                  <img src={logoImg} alt="Logo" className="mini-logo" />
                  <div>
                    <div className="mini-title">SolarPro</div>
                    <div className="mini-status">● Live Cloud</div>
                  </div>
                </div>
                <div className="mock-nav-list">
                  <div className="mock-nav-item active"><span className="m-icon">📊</span> Dashboard</div>
                  <div className="mock-nav-item"><span className="m-icon">👥</span> Leads <span className="m-badge teal">12</span></div>
                  <div className="mock-nav-item"><span className="m-icon">🏢</span> Customers <span className="m-badge gold">48</span></div>
                  <div className="mock-nav-item"><span className="m-icon">💳</span> Payments <span className="m-badge warn">3</span></div>
                  <div className="mock-nav-item"><span className="m-icon">🔨</span> Work Teams</div>
                  <div className="mock-nav-item"><span className="m-icon">📑</span> KEDL Liaison <span className="m-badge purp">4</span></div>
                  <div className="mock-nav-item"><span className="m-icon">📦</span> Stock Inventory</div>
                  <div className="mock-nav-item"><span className="m-icon">🎧</span> Service Tickets</div>
                </div>
                <div className="mock-user-card">
                  <div className="mock-avatar">AS</div>
                  <div className="mock-user-text">
                    <strong>Aryan Singh</strong>
                    <span>SolarPro Admin</span>
                  </div>
                </div>
              </div>

              {/* Content Area */}
              <div className="mock-content">
                <div className="mock-header">
                  <div className="mock-header-title">
                    <h2>Operations Dashboard</h2>
                    <span>Enterprise Command Center • Live Telemetry</span>
                  </div>
                  <div className="mock-search-box">
                    🔍 Search leads, projects, serials... <kbd>Ctrl K</kbd>
                  </div>
                  <div className="mock-quick-actions">
                    <span className="mock-btn-lead">+ Add Lead</span>
                    <span className="mock-btn-client">Client View ↗</span>
                  </div>
                </div>

                <div className="mock-kpi-grid">
                  <div className="mock-card kpi-card">
                    <div className="kpi-top">Total Revenue <span className="kpi-icon gold">₹</span></div>
                    <div className="kpi-value gold-txt">₹1.24 Cr</div>
                    <div className="kpi-sub green-txt">↑ +18.4% this month</div>
                  </div>
                  <div className="mock-card kpi-card">
                    <div className="kpi-top">Active Systems <span className="kpi-icon teal">☀️</span></div>
                    <div className="kpi-value teal-txt">48 Plants</div>
                    <div className="kpi-sub green-txt">↑ +6 commissioned</div>
                  </div>
                  <div className="mock-card kpi-card">
                    <div className="kpi-top">KEDL Net Files <span className="kpi-icon purp">📄</span></div>
                    <div className="kpi-value purp-txt">14 Active</div>
                    <div className="kpi-sub gold-txt">3 Net approved</div>
                  </div>
                  <div className="mock-card kpi-card">
                    <div className="kpi-top">Pending Verification <span className="kpi-icon warn">⏳</span></div>
                    <div className="kpi-value warn-txt">₹3.45 L</div>
                    <div className="kpi-sub warn-txt">3 queues pending</div>
                  </div>
                </div>

                <div className="mock-dual-board">
                  <div className="mock-board-col">
                    <div className="board-header">Active Execution Pipeline</div>
                    <div className="board-item">
                      <span className="dot gold"></span>
                      <div className="b-details">
                        <strong>Rajesh Kumar • 5 kW On-Grid</strong>
                        <span>Structure &amp; Inverter Mounted • Sector 21</span>
                      </div>
                      <span className="b-tag green">Structure 100%</span>
                    </div>
                    <div className="board-item">
                      <span className="dot teal"></span>
                      <div className="b-details">
                        <strong>Sunita Devi • 3 kW Rooftop</strong>
                        <span>Team B Dispatched • Janakpuri</span>
                      </div>
                      <span className="b-tag yellow">Wiring in Progress</span>
                    </div>
                  </div>
                  <div className="mock-board-col">
                    <div className="board-header">DISCOM &amp; KEDL Approvals</div>
                    <div className="board-item">
                      <span className="dot purp"></span>
                      <div className="b-details">
                        <strong>Vikram Joshi • Net File #2981</strong>
                        <span>Demand Note Paid: ₹12,500</span>
                      </div>
                      <span className="b-tag purp">Meter Install Awaited</span>
                    </div>
                    <div className="board-item">
                      <span className="dot warn"></span>
                      <div className="b-details">
                        <strong>Priya Sharma • Load Enhancement</strong>
                        <span>File Submitted to KEDL Substation</span>
                      </div>
                      <span className="b-tag warn">Doc Verification</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Floating Mobile Phone Overlay (Android) */}
          <div className="floating-phone-frame" id="phone-mockup">
            <div className="phone-notch"></div>
            <div className="phone-screen">
              <div className="phone-status-bar">
                <span>09:41</span>
                <span>5G 📶 100%</span>
              </div>
              <div className="phone-header">
                <div className="ph-avatar">AS</div>
                <div>
                  <div className="ph-name">My Solar System</div>
                  <div className="ph-loc">5 kW • Dwarka Sec 21</div>
                </div>
                <span className="ph-badge">LIVE</span>
              </div>

              {/* Solar Graph Card */}
              <div className="phone-card solar-stat-card">
                <div className="solar-row">
                  <div>
                    <span className="ph-label">Today's Generation</span>
                    <div className="ph-big-val">28.4 <small>kWh</small></div>
                  </div>
                  <div className="ph-sun-anim">☀️</div>
                </div>
                <div className="ph-mini-chart">
                  <span className="bar" style={{ height: '35%' }}></span>
                  <span className="bar" style={{ height: '60%' }}></span>
                  <span className="bar" style={{ height: '85%' }}></span>
                  <span className="bar" style={{ height: '100%' }}></span>
                  <span className="bar" style={{ height: '90%' }}></span>
                  <span className="bar" style={{ height: '65%' }}></span>
                  <span className="bar" style={{ height: '40%' }}></span>
                </div>
                <div className="ph-stat-footer">
                  <span>🌱 18.2 kg CO₂ Saved</span>
                  <span>💰 ₹227 Saved Today</span>
                </div>
              </div>

              {/* Milestone Tracker */}
              <div className="phone-card milestone-card">
                <div className="ms-title">Installation Milestones</div>
                <div className="ms-step done">✓ Site Feasibility Survey</div>
                <div className="ms-step done">✓ Structure &amp; Panel Mounting</div>
                <div className="ms-step active">⚡ Inverter &amp; Grid Interconnection</div>
                <div className="ms-step future">⏳ KEDL Net-Meter Replacement</div>
              </div>
            </div>
          </div>

          {/* Floating Metric Floaties */}
          <div className="floating-pill pill-top-right">
            <span className="fl-icon">⚡</span>
            <div>
              <strong>Instant Field Dispatch</strong>
              <span>Team A assigned to Sector 21</span>
            </div>
          </div>

          <div className="floating-pill pill-bottom-left">
            <span className="fl-icon green">✓</span>
            <div>
              <strong>Payment Verified</strong>
              <span>₹50,000 Milestone 2 Received</span>
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
