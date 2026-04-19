import React from 'react';

// Componente base de skeleton con animación pulse
const SkeletonBase = ({ className = '' }) => (
  <div className={`animate-pulse bg-gray-200 rounded-lg ${className}`} />
);

// Skeleton para las 3 cards principales del Dashboard del cliente
export const DashboardSkeleton = () => (
  <div className="space-y-8 max-w-5xl mx-auto">
    {/* Header */}
    <div className="flex items-center justify-between mb-4">
      <SkeletonBase className="h-8 w-40" />
      <SkeletonBase className="h-9 w-32 rounded-lg" />
    </div>
    
    {/* 3 Cards principales */}
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      {[1, 2, 3].map(i => (
        <div key={i} className="bg-white rounded-xl border border-neutral-border p-6 space-y-3">
          <SkeletonBase className="h-4 w-24" />
          <SkeletonBase className="h-9 w-32" />
          <SkeletonBase className="h-5 w-28 rounded-full" />
        </div>
      ))}
    </div>

    {/* CTA Invertir más */}
    <div className="bg-white rounded-xl border border-neutral-border p-6">
      <div className="flex items-center justify-between">
        <div className="space-y-2">
          <SkeletonBase className="h-5 w-48" />
          <SkeletonBase className="h-4 w-36" />
        </div>
        <SkeletonBase className="h-10 w-32 rounded-lg" />
      </div>
    </div>

    {/* Sección inferior */}
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Solicitar retiro */}
      <div className="lg:col-span-1 bg-white rounded-xl border border-neutral-border p-6 space-y-4">
        <SkeletonBase className="h-5 w-36" />
        <div className="bg-gray-50 p-4 rounded-lg space-y-2">
          <SkeletonBase className="h-3 w-16" />
          <SkeletonBase className="h-8 w-24" />
        </div>
        <SkeletonBase className="h-10 w-full rounded-lg" />
        <SkeletonBase className="h-10 w-full rounded-lg" />
      </div>

      {/* Historial */}
      <div className="lg:col-span-2 space-y-3">
        <SkeletonBase className="h-5 w-44 mb-4" />
        {[1, 2, 3].map(i => (
          <div key={i} className="bg-white rounded-xl border border-neutral-border p-5 flex items-center justify-between">
            <div className="space-y-2">
              <SkeletonBase className="h-4 w-32" />
              <SkeletonBase className="h-3 w-40" />
            </div>
            <div className="text-right space-y-2">
              <SkeletonBase className="h-6 w-20 ml-auto" />
              <SkeletonBase className="h-5 w-16 rounded-full ml-auto" />
            </div>
          </div>
        ))}
      </div>
    </div>
  </div>
);

// Skeleton para las cards de usuarios en el admin
export const UserCardSkeleton = () => (
  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
    {[1, 2, 3, 4].map(i => (
      <div key={i} className="bg-white rounded-xl border border-neutral-border p-6 space-y-4">
        <div className="pr-8">
          <SkeletonBase className="h-5 w-40 mb-2" />
          <SkeletonBase className="h-3 w-48 mb-4" />
          <div className="flex gap-2 mb-4">
            <SkeletonBase className="h-6 w-24 rounded-full" />
            <SkeletonBase className="h-6 w-28 rounded-full" />
          </div>
          <SkeletonBase className="h-10 w-full rounded-lg" />
          <SkeletonBase className="h-8 w-full rounded-lg mt-2" />
        </div>
      </div>
    ))}
  </div>
);

// Skeleton para las cards de retiros en el admin
export const WithdrawalCardSkeleton = () => (
  <div className="space-y-4">
    {[1, 2, 3].map(i => (
      <div key={i} className="bg-white rounded-xl border border-neutral-border p-5 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex-1 space-y-2">
          <div className="flex items-center gap-2">
            <SkeletonBase className="h-5 w-32" />
            <SkeletonBase className="h-5 w-20 rounded-full" />
          </div>
          <SkeletonBase className="h-3 w-44" />
          <SkeletonBase className="h-3 w-36" />
        </div>
        <div className="flex items-center gap-3">
          <SkeletonBase className="h-8 w-24" />
          <SkeletonBase className="h-10 w-10 rounded-full" />
          <SkeletonBase className="h-10 w-10 rounded-full" />
        </div>
      </div>
    ))}
  </div>
);

export default SkeletonBase;
