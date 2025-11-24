/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React from "react";
import { motion } from "framer-motion";

const SkeletonLoader: React.FC<{ className?: string }> = ({
  className = "",
}) => <div className={`animate-pulse bg-gray-200 rounded ${className}`} />;

// Hero Section Skeleton
export const HeroSkeleton: React.FC = () => (
  <header className="relative pt-32 pb-20 md:pt-48 md:pb-32 px-6 overflow-hidden min-h-[90vh] flex flex-col justify-center">
    <div className="max-w-7xl mx-auto text-center relative z-10">
      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8 }}
      >
        <SkeletonLoader className="inline-block mb-6 h-8 w-48 rounded-full" />
        <div className="space-y-4 mb-8">
          <SkeletonLoader className="h-16 md:h-20 lg:h-24 w-full max-w-4xl mx-auto" />
          <SkeletonLoader className="h-16 md:h-20 lg:h-24 w-full max-w-3xl mx-auto" />
        </div>
        <SkeletonLoader className="h-6 md:h-8 w-full max-w-2xl mx-auto mb-10" />
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 60, scale: 0.95 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ delay: 0.3, duration: 1 }}
        className="mt-16 md:mt-24 relative mx-auto max-w-6xl"
      >
        <div className="relative bg-white/40 backdrop-blur-md rounded-2xl p-2 border border-white/50 shadow-2xl">
          <SkeletonLoader className="aspect-video rounded-xl w-full" />
        </div>
      </motion.div>
    </div>
  </header>
);

// Ecosystem Section Skeleton
export const EcosystemSkeleton: React.FC = () => (
  <section className="py-20 md:py-32 bg-linear-to-br from-gray-50 to-white">
    <div className="max-w-7xl mx-auto px-6">
      <div className="text-center mb-16">
        <SkeletonLoader className="h-12 w-64 mx-auto mb-4" />
        <SkeletonLoader className="h-6 w-96 mx-auto" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {[1, 2, 3].map((i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="bg-white p-8 rounded-2xl shadow-sm border border-gray-200 relative group"
          >
            <div className="flex items-center gap-4 mb-4">
              <SkeletonLoader className="w-12 h-12 rounded-xl" />
              <SkeletonLoader className="h-6 w-24" />
            </div>
            <SkeletonLoader className="h-4 w-full mb-2" />
            <SkeletonLoader className="h-4 w-3/4" />
          </motion.div>
        ))}
      </div>
    </div>
  </section>
);

// Features Section Skeleton
export const FeaturesSkeleton: React.FC = () => (
  <section className="py-20 md:py-32 overflow-hidden bg-white/80 backdrop-blur-sm">
    <div className="max-w-7xl mx-auto px-6 space-y-32">
      {[1, 2].map((i) => (
        <div
          key={i}
          className="grid grid-cols-1 lg:grid-cols-2 gap-16 md:gap-24 items-center"
        >
          <div className="order-2 lg:order-1">
            <SkeletonLoader className="aspect-4/3 rounded-2xl w-full" />
          </div>
          <div className="order-1 lg:order-2">
            <SkeletonLoader className="h-6 w-32 mb-4 rounded-full" />
            <SkeletonLoader className="h-12 w-full mb-4" />
            <div className="space-y-3">
              <SkeletonLoader className="h-4 w-full" />
              <SkeletonLoader className="h-4 w-full" />
              <SkeletonLoader className="h-4 w-3/4" />
            </div>
          </div>
        </div>
      ))}
    </div>
  </section>
);

// Hardware Section Skeleton
export const HardwareSkeleton: React.FC = () => (
  <section className="py-20 md:py-32 bg-linear-to-br from-white to-gray-50">
    <div className="max-w-7xl mx-auto px-6">
      <div className="text-center mb-16">
        <SkeletonLoader className="h-12 w-64 mx-auto mb-4" />
        <SkeletonLoader className="h-6 w-96 mx-auto" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {[1, 2, 3].map((i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="bg-white p-8 rounded-2xl shadow-sm border border-gray-200"
          >
            <div className="flex items-center gap-4 mb-4">
              <SkeletonLoader className="w-12 h-12 rounded-xl" />
              <SkeletonLoader className="h-6 w-32" />
            </div>
            <SkeletonLoader className="h-4 w-full mb-2" />
            <SkeletonLoader className="h-4 w-3/4" />
          </motion.div>
        ))}
      </div>
    </div>
  </section>
);

// Catalog Section Skeleton
export const CatalogSkeleton: React.FC = () => (
  <section className="py-20 md:py-32 bg-white">
    <div className="max-w-7xl mx-auto px-6">
      <div className="text-center mb-16">
        <SkeletonLoader className="h-12 w-64 mx-auto mb-4" />
        <SkeletonLoader className="h-6 w-96 mx-auto" />
      </div>

      {/* Filter buttons */}
      <div className="flex justify-center gap-4 mb-12">
        {[1, 2, 3].map((i) => (
          <SkeletonLoader key={i} className="h-10 w-24 rounded-xl" />
        ))}
      </div>

      {/* Product grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {[1, 2, 3, 4, 5, 6].map((i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="bg-white p-6 rounded-2xl shadow-sm border border-gray-200 group cursor-pointer"
          >
            <SkeletonLoader className="aspect-square w-full rounded-xl mb-4" />
            <SkeletonLoader className="h-6 w-3/4 mb-2" />
            <SkeletonLoader className="h-4 w-full mb-1" />
            <SkeletonLoader className="h-4 w-2/3 mb-4" />
            <div className="flex gap-2">
              <SkeletonLoader className="h-6 w-16 rounded-full" />
              <SkeletonLoader className="h-6 w-16 rounded-full" />
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  </section>
);

// Pricing Section Skeleton
export const PricingSkeleton: React.FC = () => (
  <section className="py-20 md:py-32 bg-linear-to-br from-gray-50 to-white">
    <div className="max-w-7xl mx-auto px-6">
      <div className="text-center mb-16">
        <SkeletonLoader className="h-12 w-64 mx-auto mb-4" />
        <SkeletonLoader className="h-6 w-96 mx-auto" />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
        {[1, 2, 3].map((i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="bg-white p-8 rounded-2xl shadow-sm border border-gray-200 relative"
          >
            <SkeletonLoader className="h-6 w-16 absolute top-4 right-4 rounded" />
            <SkeletonLoader className="h-8 w-32 mb-4" />
            <div className="flex items-baseline gap-2 mb-4">
              <SkeletonLoader className="h-12 w-20" />
              <SkeletonLoader className="h-6 w-16" />
            </div>
            <SkeletonLoader className="h-4 w-full mb-2" />
            <SkeletonLoader className="h-4 w-3/4 mb-6" />
            <div className="space-y-3">
              {[1, 2, 3, 4].map((j) => (
                <SkeletonLoader key={j} className="h-4 w-full" />
              ))}
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  </section>
);

// Contact Section Skeleton
export const ContactSkeleton: React.FC = () => (
  <section className="py-20 md:py-32 bg-white">
    <div className="max-w-4xl mx-auto px-6 text-center">
      <SkeletonLoader className="h-12 w-64 mx-auto mb-4" />
      <SkeletonLoader className="h-6 w-96 mx-auto mb-12" />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-2xl mx-auto">
        <div className="text-left">
          <SkeletonLoader className="h-5 w-24 mb-2" />
          <SkeletonLoader className="h-10 w-full rounded-xl" />
        </div>
        <div className="text-left">
          <SkeletonLoader className="h-5 w-24 mb-2" />
          <SkeletonLoader className="h-10 w-full rounded-xl" />
        </div>
      </div>

      <SkeletonLoader className="h-12 w-32 mx-auto mt-8 rounded-xl" />
    </div>
  </section>
);
