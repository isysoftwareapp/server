/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  X,
  ChevronLeft,
  ChevronRight,
  Check,
  ZoomIn,
  ShoppingCart,
  Phone,
  Mail,
  Download,
  Share2,
  Star,
  Package,
  Truck,
  Shield,
} from "lucide-react";
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
  const [isImageFullscreen, setIsImageFullscreen] = useState(false);
  const [imageZoom, setImageZoom] = useState(false);

  const allImages =
    product.images && product.images.length > 0
      ? [product.image, ...product.images]
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
    <>
      {/* Main Modal */}
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-md p-4 overflow-y-auto">
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          className="bg-white rounded-3xl max-w-7xl w-full shadow-2xl relative max-h-[95vh] overflow-hidden flex flex-col"
        >
          {/* Header Bar */}
          <div className="sticky top-0 z-20 bg-white/95 backdrop-blur-lg border-b border-gray-100 px-8 py-4 flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="px-3 py-1.5 rounded-full bg-gradient-to-r from-[#498FB3] to-[#7FB3D1] text-white text-xs font-bold uppercase tracking-wider">
                {product.category}
              </div>
              <div className="flex items-center gap-1">
                <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                <span className="ml-2 text-sm text-gray-600 font-medium">
                  5.0 (Premium)
                </span>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <button className="p-2 hover:bg-gray-100 rounded-full transition-colors group">
                <Share2 className="w-5 h-5 text-gray-600 group-hover:text-[#498FB3]" />
              </button>
              <button className="p-2 hover:bg-gray-100 rounded-full transition-colors group">
                <Download className="w-5 h-5 text-gray-600 group-hover:text-[#498FB3]" />
              </button>
              <button
                onClick={onClose}
                className="p-2 hover:bg-gray-100 rounded-full transition-colors"
              >
                <X className="w-5 h-5 text-gray-600" />
              </button>
            </div>
          </div>

          {/* Scrollable Content */}
          <div className="overflow-y-auto flex-1">
            <div className="grid grid-cols-1 lg:grid-cols-5 gap-0">
              {/* Left: Image Gallery - Takes 3 columns */}
              <div className="lg:col-span-3 bg-gradient-to-br from-gray-50 to-white p-8 lg:p-12">
                <div className="space-y-6 sticky top-0">
                  {/* Main Image */}
                  <div className="relative aspect-square bg-white rounded-3xl overflow-hidden shadow-2xl border border-gray-100 group">
                    <AnimatePresence mode="wait">
                      <motion.img
                        key={currentImageIndex}
                        src={allImages[currentImageIndex]}
                        alt={product.name}
                        className={`w-full h-full object-cover cursor-zoom-in transition-transform duration-300 ${
                          imageZoom ? "scale-150" : "scale-100"
                        }`}
                        initial={{ opacity: 0, scale: 0.95 }}
                        animate={{ opacity: 1, scale: imageZoom ? 1.5 : 1 }}
                        exit={{ opacity: 0, scale: 0.95 }}
                        transition={{ duration: 0.3 }}
                        onClick={() => setIsImageFullscreen(true)}
                        onMouseEnter={() => setImageZoom(true)}
                        onMouseLeave={() => setImageZoom(false)}
                      />
                    </AnimatePresence>

                    {/* Zoom Indicator */}
                    <div className="absolute top-4 right-4 bg-black/60 backdrop-blur-sm text-white px-3 py-2 rounded-full text-xs font-bold flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <ZoomIn className="w-3 h-3" />
                      Click to zoom
                    </div>

                    {/* Navigation Arrows */}
                    {allImages.length > 1 && (
                      <>
                        <button
                          onClick={prevImage}
                          className="absolute left-4 top-1/2 -translate-y-1/2 bg-white hover:bg-gray-50 rounded-full p-3 shadow-2xl transition-all opacity-0 group-hover:opacity-100 hover:scale-110"
                        >
                          <ChevronLeft className="w-6 h-6 text-gray-800" />
                        </button>
                        <button
                          onClick={nextImage}
                          className="absolute right-4 top-1/2 -translate-y-1/2 bg-white hover:bg-gray-50 rounded-full p-3 shadow-2xl transition-all opacity-0 group-hover:opacity-100 hover:scale-110"
                        >
                          <ChevronRight className="w-6 h-6 text-gray-800" />
                        </button>

                        {/* Image Counter */}
                        <div className="absolute bottom-6 left-1/2 -translate-x-1/2 bg-black/80 backdrop-blur-sm text-white px-4 py-2 rounded-full text-sm font-bold">
                          {currentImageIndex + 1} / {allImages.length}
                        </div>
                      </>
                    )}
                  </div>

                  {/* Thumbnail Grid */}
                  {allImages.length > 1 && (
                    <div className="grid grid-cols-6 gap-3">
                      {allImages.map((img, idx) => (
                        <motion.button
                          key={idx}
                          onClick={() => setCurrentImageIndex(idx)}
                          whileHover={{ scale: 1.05 }}
                          whileTap={{ scale: 0.95 }}
                          className={`aspect-square rounded-xl overflow-hidden border-3 transition-all ${
                            idx === currentImageIndex
                              ? "border-[#498FB3] shadow-lg ring-2 ring-[#498FB3]/30"
                              : "border-gray-200 hover:border-gray-300"
                          }`}
                        >
                          <img
                            src={img}
                            alt={`${product.name} ${idx + 1}`}
                            className="w-full h-full object-cover"
                          />
                        </motion.button>
                      ))}
                    </div>
                  )}

                  {/* Feature Badges */}
                  <div className="flex flex-wrap gap-3 pt-4">
                    <div className="flex items-center gap-2 bg-white px-4 py-3 rounded-xl border border-gray-200 shadow-sm">
                      <Package className="w-4 h-4 text-[#498FB3]" />
                      <span className="text-sm font-bold text-gray-700">
                        Premium Quality
                      </span>
                    </div>
                    <div className="flex items-center gap-2 bg-white px-4 py-3 rounded-xl border border-gray-200 shadow-sm">
                      <Truck className="w-4 h-4 text-[#498FB3]" />
                      <span className="text-sm font-bold text-gray-700">
                        Free Installation
                      </span>
                    </div>
                    <div className="flex items-center gap-2 bg-white px-4 py-3 rounded-xl border border-gray-200 shadow-sm">
                      <Shield className="w-4 h-4 text-[#498FB3]" />
                      <span className="text-sm font-bold text-gray-700">
                        2 Year Warranty
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Right: Product Details - Takes 2 columns */}
              <div className="lg:col-span-2 p-8 lg:p-12 space-y-8">
                {/* Product Title */}
                <div className="space-y-4">
                  <h1 className="text-4xl lg:text-5xl font-black text-gray-900 leading-tight">
                    {product.name}
                  </h1>
                  <p className="text-lg text-gray-600 leading-relaxed">
                    {product.description}
                  </p>
                </div>

                {/* Pricing Cards */}
                <div className="grid grid-cols-1 gap-4">
                  {product.pricePurchase && (
                    <motion.div
                      whileHover={{ scale: 1.02 }}
                      className="bg-gradient-to-br from-[#498FB3] via-[#5FA1C7] to-[#7FB3D1] text-white rounded-2xl p-6 shadow-xl"
                    >
                      <div className="flex items-center justify-between mb-2">
                        <p className="text-sm font-bold uppercase tracking-wider opacity-90">
                          Purchase Price
                        </p>
                        <ShoppingCart className="w-5 h-5 opacity-90" />
                      </div>
                      <p className="text-4xl font-black mb-1">
                        ฿ {product.pricePurchase}
                      </p>
                      <p className="text-xs opacity-80">One-time payment</p>
                    </motion.div>
                  )}
                  {product.priceRent && (
                    <motion.div
                      whileHover={{ scale: 1.02 }}
                      className="bg-gradient-to-br from-gray-800 via-gray-700 to-gray-900 text-white rounded-2xl p-6 shadow-xl"
                    >
                      <div className="flex items-center justify-between mb-2">
                        <p className="text-sm font-bold uppercase tracking-wider opacity-90">
                          Rental Price
                        </p>
                        <Package className="w-5 h-5 opacity-90" />
                      </div>
                      <p className="text-4xl font-black mb-1">
                        ฿ {product.priceRent}
                      </p>
                      <p className="text-xs opacity-80">per month (flexible)</p>
                    </motion.div>
                  )}
                </div>

                {/* Variants Section */}
                {product.variants && product.variants.length > 0 && (
                  <div className="space-y-6">
                    {product.variants.map((variant) => (
                      <div key={variant.id}>
                        <label className="block text-sm font-black text-gray-900 mb-4 uppercase tracking-wider">
                          {variant.name}
                        </label>
                        <div className="space-y-3">
                          {variant.options.map((option) => {
                            const isSelected =
                              getSelectedOption(variant.id) === option.id;
                            return (
                              <motion.button
                                key={option.id}
                                onClick={() =>
                                  handleVariantSelect(variant.id, option.id)
                                }
                                whileHover={{ scale: 1.02 }}
                                whileTap={{ scale: 0.98 }}
                                className={`w-full p-5 rounded-xl border-2 transition-all text-left ${
                                  isSelected
                                    ? "border-[#498FB3] bg-gradient-to-br from-[#498FB3]/10 to-[#7FB3D1]/10 shadow-lg"
                                    : "border-gray-200 hover:border-gray-300 bg-white hover:shadow-md"
                                }`}
                              >
                                <div className="flex items-center justify-between">
                                  <div className="flex-1">
                                    <div className="font-black text-gray-900 flex items-center gap-2 mb-2">
                                      {option.name}
                                      {isSelected && (
                                        <Check className="w-5 h-5 text-[#498FB3]" />
                                      )}
                                    </div>
                                    <div className="flex gap-4 text-sm">
                                      <span className="text-gray-600">
                                        Buy:{" "}
                                        <span className="font-bold text-gray-900">
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
                              </motion.button>
                            );
                          })}
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                {/* Specs */}
                {product.specs && product.specs.length > 0 && (
                  <div>
                    <h3 className="text-xl font-black text-gray-900 mb-4 uppercase tracking-wider">
                      Technical Specifications
                    </h3>
                    <div className="bg-gradient-to-br from-gray-50 to-gray-100 rounded-2xl p-6 space-y-1 border border-gray-200">
                      {product.specs.map((spec, idx) => (
                        <div
                          key={idx}
                          className="flex items-start gap-3 text-sm py-3 px-2 hover:bg-white rounded-lg transition-colors"
                        >
                          <div className="w-2 h-2 bg-[#498FB3] rounded-full mt-1.5 shrink-0"></div>
                          <span className="text-gray-700 font-medium">
                            {spec}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Action Buttons */}
                <div className="space-y-3 pt-4">
                  <motion.button
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    className="w-full bg-gradient-to-r from-[#498FB3] to-[#7FB3D1] hover:from-[#3d7a9a] hover:to-[#498FB3] text-white font-black py-5 px-6 rounded-xl transition-all shadow-xl hover:shadow-2xl flex items-center justify-center gap-3 text-lg"
                  >
                    <ShoppingCart className="w-5 h-5" />
                    Request Quote
                  </motion.button>
                  <div className="grid grid-cols-2 gap-3">
                    <motion.button
                      whileHover={{ scale: 1.02 }}
                      whileTap={{ scale: 0.98 }}
                      className="border-2 border-gray-300 hover:border-[#498FB3] hover:bg-[#498FB3]/5 text-gray-900 font-bold py-4 px-4 rounded-xl transition-all flex items-center justify-center gap-2"
                    >
                      <Phone className="w-4 h-4" />
                      Call Us
                    </motion.button>
                    <motion.button
                      whileHover={{ scale: 1.02 }}
                      whileTap={{ scale: 0.98 }}
                      className="border-2 border-gray-300 hover:border-[#498FB3] hover:bg-[#498FB3]/5 text-gray-900 font-bold py-4 px-4 rounded-xl transition-all flex items-center justify-center gap-2"
                    >
                      <Mail className="w-4 h-4" />
                      Email
                    </motion.button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Fullscreen Image Modal */}
      <AnimatePresence>
        {isImageFullscreen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[60] bg-black/95 backdrop-blur-lg flex items-center justify-center p-4"
            onClick={() => setIsImageFullscreen(false)}
          >
            <button
              onClick={() => setIsImageFullscreen(false)}
              className="absolute top-6 right-6 bg-white/10 hover:bg-white/20 rounded-full p-3 transition-colors"
            >
              <X className="w-6 h-6 text-white" />
            </button>
            <motion.img
              initial={{ scale: 0.9 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0.9 }}
              src={allImages[currentImageIndex]}
              alt={product.name}
              className="max-w-full max-h-full object-contain rounded-2xl shadow-2xl"
              onClick={(e) => e.stopPropagation()}
            />
            {allImages.length > 1 && (
              <>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    prevImage();
                  }}
                  className="absolute left-6 top-1/2 -translate-y-1/2 bg-white/20 hover:bg-white/30 rounded-full p-4 transition-colors"
                >
                  <ChevronLeft className="w-8 h-8 text-white" />
                </button>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    nextImage();
                  }}
                  className="absolute right-6 top-1/2 -translate-y-1/2 bg-white/20 hover:bg-white/30 rounded-full p-4 transition-colors"
                >
                  <ChevronRight className="w-8 h-8 text-white" />
                </button>
              </>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};

export default ProductDetailModal;
