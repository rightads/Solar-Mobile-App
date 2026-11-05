import React, { useEffect } from 'react';

export default function Toast({ message, onClose }) {
  useEffect(() => {
    if (!message) return;
    const timer = setTimeout(() => {
      onClose();
    }, 4000);
    return () => clearTimeout(timer);
  }, [message, onClose]);

  if (!message) return null;

  return (
    <div
      className="solar-toast"
      style={{
        position: 'fixed',
        bottom: '24px',
        right: '24px',
        backgroundColor: '#0F1E33',
        color: '#FFFFFF',
        border: '1px solid rgba(245, 158, 11, 0.4)',
        padding: '14px 20px',
        borderRadius: '12px',
        boxShadow: '0 10px 30px rgba(0,0,0,0.8), 0 0 20px rgba(245, 158, 11, 0.2)',
        zIndex: 10000,
        fontSize: '0.88rem',
        fontFamily: "'Inter', sans-serif",
        display: 'flex',
        alignItems: 'center',
        gap: '10px',
        animation: 'fadeIn 0.3s ease-out'
      }}
    >
      <span style={{ color: '#10B981', fontSize: '1.1rem' }}>✓</span>
      <span>{message}</span>
    </div>
  );
}
