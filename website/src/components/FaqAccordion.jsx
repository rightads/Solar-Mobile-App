import React, { useState } from 'react';

const FAQ_DATA = [
  {
    question: 'Can I use SolarPro on Windows and Android with the same account?',
    answer:
      'Yes, absolutely. SolarPro synchronizes all data in real-time across both platforms via our secure cloud backend. You can create a lead on your Windows desktop at the office, and your field technician will immediately see the site address on their Android phone.'
  },
  {
    question: 'How does SolarPro handle KEDL and DISCOM net-metering processes?',
    answer:
      'SolarPro features a dedicated KEDL workflow engine with custom fields for Consumer Numbers, Substation Divisions, Demand Note Generation, Fee Proofs, Electrical Inspectorate (CEIG) approvals, and Bi-directional Meter installation dates.'
  },
  {
    question: 'What are the system requirements for the Windows desktop app?',
    answer:
      'SolarPro runs smoothly on any modern Windows PC running Windows 10 or Windows 11 (64-bit). Minimum 4GB RAM and 200MB free disk space. No external database or heavy prerequisites required.'
  },
  {
    question: 'Does the Android app work when technicians are offline on roofs?',
    answer:
      'Yes. The Android companion app is built with local caching. Technicians can check off tasks, capture site survey notes, and take installation photos offline. The moment their phone detects an internet connection, all changes sync automatically.'
  },
  {
    question: 'How is customer and payment data secured?',
    answer:
      'All network communications between SolarPro clients and our backend are encrypted with TLS 1.3. User authentication relies on secure JWT tokens, and role-based permissions ensure technicians only access designated site tasks while financial data is restricted to admins.'
  }
];

export default function FaqAccordion() {
  const [openIndex, setOpenIndex] = useState(0);

  const toggle = (index) => {
    setOpenIndex(prev => (prev === index ? null : index));
  };

  return (
    <section className="section faq-section" id="faq">
      <div className="container">
        <div className="section-badge">GOT QUESTIONS?</div>
        <h2 className="section-title">Frequently Asked Questions</h2>
        <p className="section-subtitle">
          Everything you need to know about getting started with SolarPro.
        </p>

        <div className="faq-accordion" id="faq-accordion">
          {FAQ_DATA.map((item, index) => {
            const isOpen = openIndex === index;
            return (
              <div key={index} className={`faq-item ${isOpen ? 'active' : ''}`}>
                <button
                  type="button"
                  className="faq-question"
                  onClick={() => toggle(index)}
                  aria-expanded={isOpen}
                >
                  <span>{item.question}</span>
                  <span className="faq-chevron">{isOpen ? '▴' : '▾'}</span>
                </button>
                {isOpen && (
                  <div className="faq-answer">
                    <p>{item.answer}</p>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
