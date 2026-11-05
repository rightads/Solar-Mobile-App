import React from 'react';
import logoImg from '../assets/logo.png';

export default function Footer({ onOpenModal }) {
  return (
    <footer className="footer">
      <div className="container footer-container">
        <div className="footer-brand-col">
          <div className="footer-brand">
            <img src={logoImg} alt="Logo" className="footer-logo" />
            <span>SolarPro Enterprise</span>
          </div>
          <p className="footer-tagline">
            Powering India&apos;s rooftop solar revolution with cutting-edge software for EPC contractors, installers, and modern clients.
          </p>
          <div className="footer-cluster-info">
            <span>● Production VPS: <code>82.29.165.43:8000</code></span>
          </div>
        </div>

        <div className="footer-links-col">
          <h4>PLATFORMS</h4>
          <ul>
            <li>
              <button
                type="button"
                className="footer-link-btn"
                onClick={() => onOpenModal('windows')}
              >
                Windows 64-bit Desktop
              </button>
            </li>
            <li>
              <button
                type="button"
                className="footer-link-btn"
                onClick={() => onOpenModal('android')}
              >
                Android Mobile APK
              </button>
            </li>
            <li>
              <a
                href="http://82.29.165.43:8000/docs"
                target="_blank"
                rel="noopener noreferrer"
              >
                REST API Swagger
              </a>
            </li>
            <li>
              <a href="#showcase">Client Web Portal</a>
            </li>
          </ul>
        </div>

        <div className="footer-links-col">
          <h4>MODULES</h4>
          <ul>
            <li><a href="#features">KEDL Net Metering</a></li>
            <li><a href="#features">Milestone Invoicing</a></li>
            <li><a href="#features">Team Work Matrix</a></li>
            <li><a href="#features">Warehouse Inventory</a></li>
          </ul>
        </div>

        <div className="footer-links-col">
          <h4>RESOURCES</h4>
          <ul>
            <li><a href="#calculator">Solar ROI Calculator</a></li>
            <li><a href="#faq">System Compatibility</a></li>
            <li><a href="#downloads">Release Notes v1.5.0</a></li>
            <li><a href="#navbar">Back to Top ↑</a></li>
          </ul>
        </div>
      </div>

      <div className="footer-bottom-bar">
        <div className="container footer-bottom-inner">
          <div>© 2026 SolarPro Enterprise Management. All Rights Reserved.</div>
          <div className="footer-badges">
            <span className="f-pill">v1.0.0 Stable</span>
            <span className="f-pill live">Cloud Connected</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
