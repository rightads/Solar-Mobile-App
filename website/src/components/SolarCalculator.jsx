import React, { useState } from 'react';

export default function SolarCalculator({ onOpenModal }) {
  const [bill, setBill] = useState(6500);
  const [area, setArea] = useState(450);
  const [connectionType, setConnectionType] = useState('residential');

  // Calculation parameters based on Indian standard solar norms
  const tariffPerUnit = connectionType === 'residential' ? 8.0 : 10.5;
  const unitsNeededPerMonth = bill / tariffPerUnit;
  const kwByBill = unitsNeededPerMonth / 120;
  const kwByArea = area / 90;

  let rawKw = Math.min(kwByBill, kwByArea);
  const recommendedKw = Math.max(1.0, Math.min(50.0, Math.round(rawKw * 10) / 10));

  const monthlyUnits = Math.round(recommendedKw * 120);
  const monthlySavings = Math.min(bill, Math.round(monthlyUnits * tariffPerUnit));
  const lifetimeSavings = Math.round(monthlySavings * 12 * 25 * 1.15);

  let lifetimeText = '';
  if (lifetimeSavings >= 10000000) {
    lifetimeText = `₹${(lifetimeSavings / 10000000).toFixed(2)} Cr`;
  } else {
    lifetimeText = `₹${(lifetimeSavings / 100000).toFixed(1)} Lakhs`;
  }

  const co2Tons = Math.round(recommendedKw * 27);
  const estimatedCost = recommendedKw * 55000;
  const annualSavings = monthlySavings * 12;
  const paybackYears = (estimatedCost / Math.max(1, annualSavings)).toFixed(1);

  return (
    <section className="section calculator-section" id="calculator">
      <div className="container">
        <div className="section-badge">INTERACTIVE SIZING TOOL</div>
        <h2 className="section-title">Calculate Your Solar Savings &amp; Capacity in Seconds</h2>
        <p className="section-subtitle">
          See how SolarPro helps estimators and consumers instantly compute system size, capital investment, and 25-year electricity bill savings.
        </p>

        <div className="calc-card">
          {/* Controls Column */}
          <div className="calc-controls-col">
            {/* Slider 1: Monthly Bill */}
            <div className="slider-group">
              <div className="slider-label-row">
                <label htmlFor="bill-slider">Current Monthly Electricity Bill</label>
                <div className="slider-val-badge">
                  ₹<span id="bill-display">{bill.toLocaleString('en-IN')}</span>/mo
                </div>
              </div>
              <input
                type="range"
                id="bill-slider"
                min="1000"
                max="40000"
                step="500"
                value={bill}
                onChange={(e) => setBill(parseInt(e.target.value, 10))}
                className="custom-slider"
              />
              <div className="slider-minmax">
                <span>₹1,000</span>
                <span>₹20,000</span>
                <span>₹40,000+</span>
              </div>
            </div>

            {/* Slider 2: Roof Area */}
            <div className="slider-group">
              <div className="slider-label-row">
                <label htmlFor="area-slider">Available Shadow-Free Rooftop Area</label>
                <div className="slider-val-badge">
                  <span id="area-display">{area.toLocaleString('en-IN')}</span> sq. ft
                </div>
              </div>
              <input
                type="range"
                id="area-slider"
                min="100"
                max="2500"
                step="50"
                value={area}
                onChange={(e) => setArea(parseInt(e.target.value, 10))}
                className="custom-slider"
              />
              <div className="slider-minmax">
                <span>100 sq.ft</span>
                <span>1,200 sq.ft</span>
                <span>2,500+ sq.ft</span>
              </div>
            </div>

            {/* Connection Type Switcher */}
            <div className="connection-group">
              <label className="conn-label">Power Connection Type</label>
              <div className="conn-pill-group">
                <button
                  type="button"
                  className={`conn-pill ${connectionType === 'residential' ? 'active' : ''}`}
                  onClick={() => setConnectionType('residential')}
                >
                  🏠 Residential Rooftop
                </button>
                <button
                  type="button"
                  className={`conn-pill ${connectionType === 'commercial' ? 'active' : ''}`}
                  onClick={() => setConnectionType('commercial')}
                >
                  🏢 Commercial / Industrial
                </button>
              </div>
            </div>

            <div className="calc-hint">
              💡 Calculated with standard Indian solar irradiance (~4.5 peak sun hours/day) and average grid tariff of ₹{tariffPerUnit.toFixed(2)}/unit.
            </div>
          </div>

          {/* Results Display Column */}
          <div className="calc-results-col">
            <div className="results-top-badge">RECOMMENDED SOLARPRO SYSTEM</div>

            <div className="results-kpi-highlight">
              <div className="res-num">
                <span id="res-kw">{recommendedKw.toFixed(1)}</span> <span className="unit">kW</span>
              </div>
              <div className="res-lbl">Recommended System Capacity (Grid-Tied)</div>
            </div>

            <div className="calc-metrics-grid">
              <div className="res-tile">
                <span className="r-icon">⚡</span>
                <div>
                  <span className="r-label">Monthly Generation</span>
                  <strong id="res-kwh">{monthlyUnits.toLocaleString('en-IN')} Units</strong>
                </div>
              </div>
              <div className="res-tile">
                <span className="r-icon gold">💰</span>
                <div>
                  <span className="r-label">Monthly Bill Savings</span>
                  <strong id="res-savings">₹{monthlySavings.toLocaleString('en-IN')}/mo</strong>
                </div>
              </div>
              <div className="res-tile">
                <span className="r-icon green">📈</span>
                <div>
                  <span className="r-label">25-Yr Lifetime Savings</span>
                  <strong id="res-lifetime" className="green-txt">{lifetimeText}</strong>
                </div>
              </div>
              <div className="res-tile">
                <span className="r-icon teal">🌱</span>
                <div>
                  <span className="r-label">CO₂ Offset (25 Years)</span>
                  <strong id="res-co2">{co2Tons} Metric Tons</strong>
                </div>
              </div>
            </div>

            <div className="payback-banner">
              <span>⏱️ Estimated Payback Period: <strong id="res-payback">{paybackYears} Years</strong></span>
            </div>

            <button
              type="button"
              className="btn btn-primary btn-block"
              onClick={() => onOpenModal('windows')}
            >
              Get SolarPro to Manage This Project →
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
