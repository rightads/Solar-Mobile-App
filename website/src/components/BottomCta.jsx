import React from 'react';

export default function BottomCta({ onOpenModal }) {
  return (
    <section className="bottom-cta-section">
      <div className="container">
        <div className="cta-box">
          <div className="cta-glow"></div>
          <h2>Ready to Power Up Your Solar Operations?</h2>
          <p>
            Join leading solar EPC contractors and installers who manage hundreds of rooftop solar installations with SolarPro.
          </p>
          <div className="cta-buttons-row">
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => onOpenModal('windows')}
            >
              <svg className="icon-svg" viewBox="0 0 24 24" fill="currentColor">
                <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.949-1.801"/>
              </svg>
              <span>Download for Windows</span>
            </button>
            <button
              type="button"
              className="btn btn-teal"
              onClick={() => onOpenModal('android')}
            >
              <svg className="icon-svg" viewBox="0 0 24 24" fill="currentColor">
                <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4114 13.8533 8.082 12 8.082s-3.5902.3294-5.1368.8677L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/>
              </svg>
              <span>Download for Android</span>
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
