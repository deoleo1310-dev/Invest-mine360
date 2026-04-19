import React from 'react';
import { AlertTriangle, Loader2 } from 'lucide-react';

export const ConfirmModal = ({ 
  isOpen, 
  onClose, 
  onConfirm, 
  title = '¿Estás seguro?',
  message = '',
  confirmText = 'Confirmar',
  cancelText = 'Cancelar',
  variant = 'warning', // 'warning' | 'danger' | 'success'
  loading = false
}) => {
  if (!isOpen) return null;

  const variantStyles = {
    warning: {
      icon: 'bg-amber-100 text-amber-600',
      button: 'bg-amber-500 hover:bg-amber-600 focus:ring-amber-300'
    },
    danger: {
      icon: 'bg-red-100 text-red-600',
      button: 'bg-red-500 hover:bg-red-600 focus:ring-red-300'
    },
    success: {
      icon: 'bg-green-100 text-green-600',
      button: 'bg-green-500 hover:bg-green-600 focus:ring-green-300'
    }
  };

  const styles = variantStyles[variant] || variantStyles.warning;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Overlay */}
      <div 
        className="absolute inset-0 bg-black/50 backdrop-blur-sm animate-in fade-in duration-200" 
        onClick={!loading ? onClose : undefined} 
      />
      
      {/* Modal */}
      <div className="relative bg-white rounded-2xl shadow-2xl max-w-md w-full animate-in zoom-in-95 duration-200 overflow-hidden">
        <div className="p-6">
          {/* Icon */}
          <div className={`w-12 h-12 rounded-full ${styles.icon} flex items-center justify-center mx-auto mb-4`}>
            <AlertTriangle size={24} />
          </div>

          {/* Title */}
          <h3 className="text-lg font-bold text-neutral-text text-center mb-2">
            {title}
          </h3>

          {/* Message */}
          {message && (
            <p className="text-sm text-neutral-gray text-center whitespace-pre-line leading-relaxed">
              {message}
            </p>
          )}
        </div>

        {/* Actions */}
        <div className="flex gap-3 p-4 bg-gray-50 border-t border-neutral-border">
          <button
            onClick={onClose}
            disabled={loading}
            className="flex-1 px-4 py-2.5 rounded-lg border border-neutral-border text-neutral-text font-medium hover:bg-gray-100 transition-colors disabled:opacity-50"
          >
            {cancelText}
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            className={`flex-1 px-4 py-2.5 rounded-lg text-white font-medium transition-colors focus:ring-2 focus:ring-offset-2 disabled:opacity-70 flex items-center justify-center gap-2 ${styles.button}`}
          >
            {loading ? (
              <>
                <Loader2 className="animate-spin" size={16} />
                Procesando...
              </>
            ) : (
              confirmText
            )}
          </button>
        </div>
      </div>
    </div>
  );
};
