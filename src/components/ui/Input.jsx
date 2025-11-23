import React from 'react';

export const Input = ({ label, error, className = '', ...props }) => {
  return (
    <div className={`flex flex-col gap-1.5 ${className}`}>
      {label && <label className="text-sm font-medium text-neutral-gray">{label}</label>}
      <input 
        className={`px-4 py-2.5 rounded-lg border bg-white focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all ${error ? 'border-status-error' : 'border-neutral-border'}`}
        {...props}
      />
      {error && <span className="text-xs text-status-error">{error}</span>}
    </div>
  );
};
