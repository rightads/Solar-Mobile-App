import React from 'react';

export default function ComparisonTable() {
  return (
    <section className="section comparison-section">
      <div className="container">
        <div className="section-badge">WHY SOLARPRO</div>
        <h2 className="section-title">The Clear Advantage for Solar Contractors</h2>
        <p className="section-subtitle">
          See why traditional spreadsheets and generic CRMs fail for solar EPC execution.
        </p>

        <div className="comparison-table-wrapper">
          <table className="comparison-table">
            <thead>
              <tr>
                <th>Workflow Capability</th>
                <th>Traditional Solar Operations</th>
                <th className="highlight-col">SolarPro Enterprise</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>KEDL &amp; DISCOM Net-Metering</strong></td>
                <td className="bad">❌ Lost physical copies, missed demand deadlines</td>
                <td className="good highlight-col">✓ Step-by-step digital liaison tracking with automated alerts</td>
              </tr>
              <tr>
                <td><strong>Milestone Payment Verification</strong></td>
                <td className="bad">❌ Manual WhatsApp screenshots and cashier confusion</td>
                <td className="good highlight-col">✓ Instant cashier approval flow with branded PDF receipts</td>
              </tr>
              <tr>
                <td><strong>Field Crew Dispatch</strong></td>
                <td className="bad">❌ Phone calls and misplaced BOM parts on site</td>
                <td className="good highlight-col">✓ Specialized Team assignments (Structure, Electrical, Civil)</td>
              </tr>
              <tr>
                <td><strong>Customer Transparency</strong></td>
                <td className="bad">❌ Daily angry phone calls asking &quot;When will net-meter arrive?&quot;</td>
                <td className="good highlight-col">✓ Self-service Client Portal with live milestone progression</td>
              </tr>
              <tr>
                <td><strong>Platform Availability</strong></td>
                <td className="bad">❌ Clunky web spreadsheets or mobile-only apps</td>
                <td className="good highlight-col">✓ Dual native power: Windows 64-bit command center &amp; Android app</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
