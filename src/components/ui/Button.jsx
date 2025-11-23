import React from 'react';

export const Button = ({ children, variant = 'primary', className = '', ...props }) => {
  const baseStyles = "px-4 py-2 rounded-lg font-medium transition-all duration-200 flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed";
  
  const variants = {
    primary: "bg-primary text-white hover:bg-primary-dark shadow-md hover:shadow-lg",
    secondary: "bg-white text-neutral-text border border-neutral-border hover:bg-neutral-bg",
    success: "bg-status-success text-white hover:opacity-90 shadow-md",
    danger: "bg-status-error text-white hover:opacity-90 shadow-md",
    ghost: "bg-transparent text-neutral-gray hover:text-primary hover:bg-primary-light/20",
  };

  return (
    <button 
      className={`${baseStyles} ${variants[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
};
