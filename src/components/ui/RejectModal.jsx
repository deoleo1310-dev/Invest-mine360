import React, { useState, useEffect } from 'react';
import { X, Loader2 } from 'lucide-react';

export const RejectModal = ({ isOpen, onClose, onConfirm, withdrawal }) => {
  const [comment, setComment] = useState('');
  const [loading, setLoading] = useState(false);

  // Reset cuando se cierra
  useEffect(() => {
    if (!isOpen) {
      setComment('');
    }
  }, [isOpen]);

  const handleSubmit = async () => {
    if (!comment.trim()) {
      alert('Debes proporcionar un motivo de rechazo');
      return;
    }

    setLoading(true);
    await onConfirm(comment.trim());
    setLoading(false);
    setComment('');
  };

  // Cerrar con Escape
  useEffect(() => {
    const handleEscape = (e) => {
      if (e.key === 'Escape' && isOpen && !loading) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [isOpen, loading, onClose]);

  if (!isOpen || !withdrawal) return null;

  return (
    <div 
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-200"
      onClick={(e) => {
        if (e.target === e.currentTarget && !loading) {
          onClose();
        }
      }}
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md animate-in zoom-in-95 duration-200">
        
        {/* HEADER */}
        <div className="flex items-center justify-between p-5 border-b border-neutral-border">
          <h3 className="text-lg font-bold text-neutral-text">Rechazar Retiro</h3>
          <button 
            onClick={onClose}
            disabled={loading}
            className="text-neutral-gray hover:text-neutral-text p-1 rounded-full hover:bg-neutral-bg disabled:opacity-50 transition-colors"
          >
            <X size={20} />
          </button>
        </div>
        
        {/* BODY */}
        <div className="p-5 space-y-4">
          
          {/* INFO DEL RETIRO */}
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 space-y-2">
            <div className="flex justify-between">
              <span className="text-sm font-medium text-red-900">Usuario:</span>
              <span className="text-sm text-red-800 font-semibold">
                {withdrawal?.profiles?.full_name || 'N/A'}
              </span>
            </div>
            
            <div className="flex justify-between">
              <span className="text-sm font-medium text-red-900">Email:</span>
              <span className="text-sm text-red-700">
                {withdrawal?.profiles?.email || 'N/A'}
              </span>
            </div>
            
            <div className="pt-2 mt-2 border-t border-red-200">
              <div className="flex justify-between items-center">
                <span className="text-sm font-medium text-red-900">Monto a Rechazar:</span>
                <span className="text-2xl font-bold text-red-600">
                  ${Number(withdrawal?.monto || 0).toLocaleString('es-DO', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                  })}
                </span>
              </div>
            </div>
          </div>

          {/* CAMPO DE COMENTARIO */}
          <div>
            <label className="block text-sm font-medium text-neutral-text mb-2">
              Motivo del Rechazo <span className="text-red-500">*</span>
            </label>
            <textarea
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              placeholder="Ej: Fondos insuficientes, datos bancarios incorrectos, documentación pendiente..."
              rows={4}
              disabled={loading}
              className="w-full px-4 py-3 rounded-lg border border-neutral-border focus:ring-2 focus:ring-red-500/20 focus:border-red-500 outline-none resize-none transition-colors disabled:opacity-50"
              maxLength={500}
            />
            
            <div className="flex justify-between mt-1">
              <p className="text-xs text-neutral-gray">
                Este comentario será visible para el usuario
              </p>
              <span className="text-xs text-neutral-gray">
                {comment.length}/500
              </span>
            </div>
          </div>

          {/* BOTONES */}
          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="flex-1 px-4 py-2.5 rounded-lg border border-neutral-border hover:bg-neutral-bg transition-colors disabled:opacity-50 font-medium"
            >
              Cancelar
            </button>
            <button
              type="button"
              onClick={handleSubmit}
              disabled={loading || !comment.trim()}
              className="flex-1 px-4 py-2.5 rounded-lg bg-red-600 text-white hover:bg-red-700 disabled:opacity-50 transition-colors flex items-center justify-center gap-2 font-medium"
            >
              {loading ? (
                <>
                  <Loader2 className="animate-spin" size={18} />
                  <span>Rechazando...</span>
                </>
              ) : (
                'Confirmar Rechazo'
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};