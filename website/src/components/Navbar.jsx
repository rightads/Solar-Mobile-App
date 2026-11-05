import React, { useState, useEffect } from 'react';
import logoImg from '../assets/logo.png';

export default function Navbar({ pingMs, onOpenModal, onDownload }) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  // Close mobile menu on outside click or resize
  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth > 992) {
        setMobileMenuOpen(false);
      }
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const closeMenu = () => setMobileMenuOpen(false);

  return (
    <header className="navbar" id="navbar">
      <div className="nav-container">
        <a href="#" className="brand-logo" id="nav-brand" onClick={closeMenu}>
          <div className="brand-icon-wrapper">
            <img src={logoImg} alt="SolarPro Logo" className="brand-logo-img" />
          </div>
          <div className="brand-text-col">
            <div className="brand-name">
              SolarPro<span className="brand-badge">ENTERPRISE</span>
            </div>
            <span className="brand-slogan">Solar Energy Operating Suite</span>
          </div>
        </a>

        {/* Live API Pill */}
        <div
          className="nav-status-pill"
          id="nav-status"
          title="Connected to SolarPro Cloud Infrastructure"
        >
          <span className="pulse-dot"></span>
          <span className="status-label">Cloud Engine Live</span>
          <span className="status-latency" id="ping-text">{pingMs}ms</span>
        </div>

        {/* Navigation Links */}
        <nav className="nav-links">
          <a href="#features" className="nav-link">Features</a>
          <a href="#showcase" className="nav-link">Apps Showcase</a>
          <a href="#calculator" className="nav-link">Solar ROI</a>
          <a href="#downloads" className="nav-link">Download</a>
          <a href="#faq" className="nav-link">FAQ</a>
        </nav>

        {/* Nav CTA Actions */}
        <div className="nav-actions">
          <a href="#downloads" className="btn btn-nav-download" id="nav-btn-download">
            <svg className="icon-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
              <polyline points="7 10 12 15 17 10"></polyline>
              <line x1="12" y1="15" x2="12" y2="3"></line>
            </svg>
            <span>Get SolarPro</span>
          </a>
        </div>

        {/* Mobile Hamburger Button */}
        <button
          className={`mobile-menu-btn ${mobileMenuOpen ? 'open' : ''}`}
          id="mobile-toggle"
          aria-label="Toggle Navigation Menu"
          aria-expanded={mobileMenuOpen}
          onClick={() => setMobileMenuOpen(prev => !prev)}
        >
          <span></span>
          <span></span>
          <span></span>
        </button>
      </div>

      {/* Mobile Dropdown Menu */}
      <div className={`mobile-menu-dropdown ${mobileMenuOpen ? 'open' : ''}`} id="mobile-dropdown">
        <div className="mob-status-row">
          <span className="pulse-dot"></span>
          <span className="status-label">Cloud Engine Live</span>
          <span className="status-latency">{pingMs}ms</span>
        </div>
        <a href="#features" className="mob-link" onClick={closeMenu}>
          <span className="m-nav-icon">✨</span> Features &amp; Modules
        </a>
        <a href="#showcase" className="mob-link" onClick={closeMenu}>
          <span className="m-nav-icon">🖥️</span> Windows &amp; Android Apps
        </a>
        <a href="#calculator" className="mob-link" onClick={closeMenu}>
          <span className="m-nav-icon">☀️</span> Solar ROI Calculator
        </a>
        <a href="#downloads" className="mob-link" onClick={closeMenu}>
          <span className="m-nav-icon">📥</span> Download Center
        </a>
        <a href="#faq" className="mob-link" onClick={closeMenu}>
          <span className="m-nav-icon">💬</span> FAQ
        </a>
        <div className="mob-cta-row">
          <a
            href="https://github.com/xxKrishna2609xx/Solar-Mobile-App/releases/download/Android/SolarPro-Android-v1.0.0.apk"
            className="btn btn-teal btn-block"
            onClick={() => {
              onDownload('android');
              closeMenu();
            }}
          >
            <svg className="icon-svg" viewBox="0 0 24 24" fill="currentColor">
              <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4114 13.8533 8.082 12 8.082s-3.5902.3294-5.1368.8677L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/>
            </svg>
            <span>Download Android APK (54 MB)</span>
          </a>
          <a
            href="https://github.com/xxKrishna2609xx/Solar-Mobile-App/releases/download/Windows/SolarPro-Windows-x64-v1.0.0.zip"
            className="btn btn-primary btn-block"
            onClick={() => {
              onDownload('windows');
              closeMenu();
            }}
          >
            <svg className="icon-svg" viewBox="0 0 24 24" fill="currentColor">
              <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.949-1.801"/>
            </svg>
            <span>Download Windows ZIP (15 MB)</span>
          </a>
        </div>
      </div>
    </header>
  );
}
