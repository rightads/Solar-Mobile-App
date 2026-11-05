import React from 'react';

export default function FeaturesBento() {
  return (
    <section className="section features-section" id="features">
      <div className="container">
        <div className="section-badge">FULL-STACK SOLAR ENGINE</div>
        <h2 className="section-title">Everything Solar EPCs Need to Scale to Hundreds of Sites</h2>
        <p className="section-subtitle">
          No more juggling disconnected WhatsApp groups, lost paper challans, and missed KEDL filing deadlines.
        </p>

        <div className="bento-grid">
          
          {/* Bento Card 1: DISCOM & KEDL (Large) */}
          <div className="bento-card bento-wide">
            <div className="bento-icon gold-bg">📑</div>
            <div className="bento-content">
              <span className="card-pill">PROPRIETARY DISCOM WORKFLOW</span>
              <h3>KEDL &amp; Net-Metering Liaison Tracker</h3>
              <p>
                Track the entire bureaucratic pipeline with zero guesswork. From Initial Sanction and Name Change files to Load Extensions, Demand Notes, CEIG Electrical Inspections, and Bi-directional Net-Meter installations.
              </p>
              <div className="bento-workflow-tags">
                <span>Sanction Raised</span> → <span>Demand Paid</span> → <span>Feasibility Check</span> → <span>Net-Meter Live</span>
              </div>
            </div>
          </div>

          {/* Bento Card 2: Payments */}
          <div className="bento-card">
            <div className="bento-icon teal-bg">💳</div>
            <div className="bento-content">
              <span className="card-pill">FINANCIAL LEDGER</span>
              <h3>Milestone Payment Engine</h3>
              <p>
                Configure automated instalment schedules: 20% Advance, 40% Structure, 30% Inverter &amp; BOS, 10% Grid Handover. Real-time cashier verification and instant branded PDF receipts.
              </p>
            </div>
          </div>

          {/* Bento Card 3: Teams & Work Assignments */}
          <div className="bento-card">
            <div className="bento-icon purp-bg">👷‍♂️</div>
            <div className="bento-content">
              <span className="card-pill">CREW DISPATCH</span>
              <h3>Team Work Assignments</h3>
              <p>
                Deploy specialized crews (Structure, Electrical, and Civil) with exact bill of materials, safety guidelines, and GPS tracking.
              </p>
            </div>
          </div>

          {/* Bento Card 4: Inventory & Warehouse */}
          <div className="bento-card">
            <div className="bento-icon blue-bg">📦</div>
            <div className="bento-content">
              <span className="card-pill">STOCK CONTROL</span>
              <h3>BOS &amp; Module Inventory</h3>
              <p>
                Real-time tracking of monocrystalline Tier-1 solar panels, string &amp; micro inverters, solar DC cables, MC4 connectors, and aluminum mounting rails.
              </p>
            </div>
          </div>

          {/* Bento Card 5: High Performance Cloud (Wide) */}
          <div className="bento-card bento-wide">
            <div className="bento-icon green-bg">⚡</div>
            <div className="bento-content">
              <span className="card-pill">ENTERPRISE CLOUD ARCHITECTURE</span>
              <h3>Real-Time Cloud Backend with 104+ Micro-Endpoints</h3>
              <p>
                Backed by an asynchronous FastAPI infrastructure deployed on high-availability cloud servers. Sub-100ms latency, automatic database migrations, JWT authentication, and bank-grade SSL encryption.
              </p>
              <div className="bento-metrics-row">
                <div className="b-stat"><strong>99.98%</strong><span>Cloud Uptime</span></div>
                <div className="b-stat"><strong>&lt; 45ms</strong><span>API Ping</span></div>
                <div className="b-stat"><strong>104</strong><span>REST Endpoints</span></div>
                <div className="b-stat"><strong>AES-256</strong><span>Data Encryption</span></div>
              </div>
            </div>
          </div>

          {/* Bento Card 6: Customer Portal */}
          <div className="bento-card">
            <div className="bento-icon gold-bg">☀️</div>
            <div className="bento-content">
              <span className="card-pill">CUSTOMER RETENTION</span>
              <h3>Transparent Client Portal</h3>
              <p>
                Give rooftop solar owners a branded portal to view live plant performance, warranty cards, AMC renewal dates, and raise 1-tap support tickets.
              </p>
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
