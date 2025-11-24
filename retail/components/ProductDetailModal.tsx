/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, ChevronLeft, ChevronRight, Check } from "lucide-react";
import { ProductItem } from "../types";

interface ProductDetailModalProps {
  product: ProductItem;
  onClose: () => void;
}

const ProductDetailModal: React.FC<ProductDetailModalProps> = ({
  product,
  onClose,
}) => {
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [selectedVariants, setSelectedVariants] = useState<
    Record<string, string>
  >({});

  const allImages =
    product.images && product.images.length > 0
      ? product.images
      : [product.image];

  const nextImage = () => {
    setCurrentImageIndex((prev) => (prev + 1) % allImages.length);
  };

  const prevImage = () => {
    setCurrentImageIndex(
      (prev) => (prev - 1 + allImages.length) % allImages.length
    );
  };

  const handleVariantSelect = (variantId: string, optionId: string) => {
    setSelectedVariants((prev) => ({
      ...prev,
      [variantId]: optionId,
    }));
  };

  const getSelectedOption = (variantId: string) => {
    return selectedVariants[variantId];
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 overflow-y-auto">
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 20 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 20 }}
        className="bg-white rounded-3xl max-w-5xl w-full shadow-2xl relative max-h-[90vh] overflow-y-auto"
      >
        {/* Close Button */}
        <button
          onClick={onClose}
          className="absolute top-6 right-6 z-10 bg-white hover:bg-gray-100 rounded-full p-2 shadow-lg transition-colors"
        >
          <X className="w-5 h-5 text-gray-600" />
        </button>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 p-8">
          {/* Left: Image Slider */}
          <div className="space-y-4">
            <div className="relative aspect-square bg-gray-100 rounded-2xl overflow-hidden group">
              <AnimatePresence mode="wait">
                <motion.img
                  key={currentImageIndex}
                  src={allImages[currentImageIndex]}
                  alt={product.name}
                  className="w-full h-full object-cover"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.3 }}
                />
              </AnimatePresence>

              {/* Navigation Arrows */}
              {allImages.length > 1 && (
                <>
                  <button
                    onClick={prevImage}
                    className="absolute left-4 top-1/2 -translate-y-1/2 bg-white/90 hover:bg-white rounded-full p-2 shadow-lg transition-all opacity-0 group-hover:opacity-100"
                  >
                    <ChevronLeft className="w-5 h-5 text-gray-800" />
                  </button>
                  <button
                    onClick={nextImage}
                    className="absolute right-4 top-1/2 -translate-y-1/2 bg-white/90 hover:bg-white rounded-full p-2 shadow-lg transition-all opacity-0 group-hover:opacity-100"
                  >
                    <ChevronRight className="w-5 h-5 text-gray-800" />
                  </button>

                  {/* Image Counter */}
                  <div className="absolute bottom-4 left-1/2 -translate-x-1/2 bg-black/70 text-white px-3 py-1 rounded-full text-xs font-bold">
                    {currentImageIndex + 1} / {allImages.length}
                  </div>
                </>
              )}
            </div>

            {/* Thumbnail Strip */}
            {allImages.length > 1 && (
              <div className="flex gap-2 overflow-x-auto pb-2">
                {allImages.map((img, idx) => (
                  <button
                    key={idx}
                    onClick={() => setCurrentImageIndex(idx)}
                    className={`w-20 h-20 rounded-lg overflow-hidden border-2 transition-all shrink-0 ${
                      idx === currentImageIndex
                        ? "border-[#498FB3] scale-105"
                        : "border-gray-200 hover:border-gray-300"
                    }`}
                  >
                    <img
                      src={img}
                      alt={`${product.name} ${idx + 1}`}
                      className="w-full h-full object-cover"
                    />
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Right: Product Info */}
          <div className="space-y-6">
            <div>
              <div className="inline-block mb-3 px-3 py-1 rounded-full bg-gray-100 text-gray-600 text-xs font-bold uppercase tracking-wider">
                {product.category}
              </div>
              <h2 className="text-3xl md:text-4xl font-bold text-slate-900 mb-4">
                {product.name}
              </h2>
              <p className="text-gray-600 leading-relaxed text-lg">
                {product.description}
              </p>
            </div>

            {/* Base Pricing */}
            <div className="grid grid-cols-2 gap-4 p-6 bg-gray-50 rounded-2xl border border-gray-200">
              <div className="text-center">
                <div className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">
                  Purchase
                </div>
                <div className="text-2xl font-bold text-slate-900">
                  ฿ {product.pricePurchase}
                </div>
              </div>
              <div className="text-center">
                <div className="text-xs font-bold text-[#498FB3] uppercase tracking-wider mb-2">
                  Rent / Month
                </div>
                <div className="text-2xl font-bold text-[#498FB3]">
                  ฿ {product.priceRent}
                </div>
              </div>
            </div>

            {/* Variants Section */}
            {product.variants && product.variants.length > 0 && (
              <div className="space-y-6">
                {product.variants.map((variant) => (
                  <div key={variant.id} className="space-y-3">
                    <h4 className="text-sm font-bold text-gray-700 uppercase tracking-wider">
                      {variant.name}
                    </h4>
                    <div className="space-y-2">
                      {variant.options.map((option) => {
                        const isSelected =
                          getSelectedOption(variant.id) === option.id;
                        return (
                          <button
                            key={option.id}
                            onClick={() =>
                              handleVariantSelect(variant.id, option.id)
                            }
                            className={`w-full p-4 rounded-xl border-2 transition-all text-left ${
                              isSelected
                                ? "border-[#498FB3] bg-[#ADE8F4]/10"
                                : "border-gray-200 hover:border-gray-300 bg-white"
                            }`}
                          >
                            <div className="flex items-center justify-between">
                              <div className="flex-1">
                                <div className="font-bold text-slate-900 flex items-center gap-2">
                                  {option.name}
                                  {isSelected && (
                                    <Check className="w-4 h-4 text-[#498FB3]" />
                                  )}
                                </div>
                                <div className="flex gap-4 mt-1 text-sm">
                                  <span className="text-gray-600">
                                    Buy:{" "}
                                    <span className="font-bold">
                                      ฿{option.priceBuy}
                                    </span>
                                  </span>
                                  <span className="text-[#498FB3]">
                                    Rent:{" "}
                                    <span className="font-bold">
                                      ฿{option.priceRent}/mo
                                    </span>
                                  </span>
                                </div>
                              </div>
                            </div>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            )}

            {/* Specs */}
            {product.specs && product.specs.length > 0 && (
              <div className="space-y-3">
                <h4 className="text-sm font-bold text-gray-700 uppercase tracking-wider">
                  Technical Specifications
                </h4>
                <div className="space-y-2">
                  {product.specs.map((spec, idx) => (
                    <div
                      key={idx}
                      className="flex items-start gap-3 text-sm text-gray-600"
                    >
                      <div className="w-1.5 h-1.5 bg-[#498FB3] rounded-full mt-2 shrink-0"></div>
                      <span>{spec}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Action Buttons */}
            <div className="pt-6 border-t border-gray-200 flex gap-3">
              <button className="flex-1 bg-black text-white py-4 rounded-xl font-bold hover:bg-[#498FB3] transition-colors">
                Request Quote
              </button>
              <button className="flex-1 border-2 border-black text-black py-4 rounded-xl font-bold hover:bg-black hover:text-white transition-colors">
                Contact Sales
              </button>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  );
};

export default ProductDetailModal;
