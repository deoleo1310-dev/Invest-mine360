import React from 'react';

export const Badge = ({ children, variant = 'default', className = '' }) => {
  const variants = {
    default: "bg-neutral-bg text-neutral-text",
    primary: "bg-primary-light text-primary-dark",
    success: "bg-status-success/10 text-status-success",
    warning: "bg-status-warning/20 text-yellow-700",
    error: "bg-status-error/10 text-status-error",
  };

  return (
    <span className={`px-2.5 py-1 rounded-full text-xs font-semibold ${variants[variant]} ${className}`}>
      {children}
    </span>
  );
};
