'use client'

import { useState, useRef, useCallback } from 'react'
import { motion } from 'framer-motion'
import Image from 'next/image'

type ImageComparisonSliderProps = {
  beforeImage: string
  afterImage: string
  beforeLabel?: string
  afterLabel?: string
}

export function ImageComparisonSlider({
  beforeImage,
  afterImage,
  beforeLabel = 'Before',
  afterLabel = 'After',
}: ImageComparisonSliderProps) {
  const [sliderPosition, setSliderPosition] = useState(50)
  const [isDragging, setIsDragging] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)

  const handleMove = useCallback(
    (clientY: number) => {
      if (!containerRef.current) return

      const rect = containerRef.current.getBoundingClientRect()
      const y = clientY - rect.top
      const percentage = Math.max(0, Math.min(100, (y / rect.height) * 100))
      setSliderPosition(percentage)
    },
    []
  )

  const handleMouseDown = () => setIsDragging(true)
  const handleMouseUp = () => setIsDragging(false)

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging) return
    handleMove(e.clientY)
  }

  const handleTouchMove = (e: React.TouchEvent) => {
    handleMove(e.touches[0].clientY)
  }

  return (
    <div
      ref={containerRef}
      className="relative w-full aspect-[9/16] max-w-[400px] mx-auto rounded-[2.5rem] overflow-hidden cursor-ns-resize select-none bg-black/20"
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleMouseUp}
    >
      {/* After image (bottom layer) */}
      <div className="absolute inset-0">
        <Image
          src={afterImage}
          alt={afterLabel}
          fill
          className="object-cover object-top"
          draggable={false}
        />
      </div>

      {/* Before image (top layer, clipped) */}
      <div
        className="absolute inset-0 overflow-hidden"
        style={{ clipPath: `inset(0 0 ${100 - sliderPosition}% 0)` }}
      >
        <Image
          src={beforeImage}
          alt={beforeLabel}
          fill
          className="object-cover object-top"
          draggable={false}
        />
      </div>

      {/* Slider line */}
      <motion.div
        className="absolute left-0 right-0 h-1 bg-white shadow-lg z-10"
        style={{ top: `${sliderPosition}%`, transform: 'translateY(-50%)' }}
        animate={{
          boxShadow: isDragging
            ? '0 0 20px rgba(255,255,255,0.8)'
            : '0 0 10px rgba(255,255,255,0.4)'
        }}
      />

      {/* Slider handle */}
      <motion.div
        className="absolute left-1/2 z-20 cursor-ns-resize"
        style={{ top: `${sliderPosition}%`, transform: 'translate(-50%, -50%)' }}
        onMouseDown={handleMouseDown}
        onTouchStart={handleMouseDown}
        whileHover={{ scale: 1.1 }}
        whileTap={{ scale: 0.95 }}
      >
        <div className="w-12 h-12 rounded-full bg-white/90 backdrop-blur-sm border-2 border-white shadow-xl flex items-center justify-center">
          <div className="flex flex-col items-center gap-0.5">
            <svg className="w-3 h-3 text-black/60" fill="currentColor" viewBox="0 0 24 24">
              <path d="M7.41 15.41L12 10.83l4.59 4.58L18 14l-6-6-6 6z" />
            </svg>
            <svg className="w-3 h-3 text-black/60" fill="currentColor" viewBox="0 0 24 24">
              <path d="M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6z" />
            </svg>
          </div>
        </div>
      </motion.div>

      {/* Labels */}
      <motion.div
        className="absolute top-4 left-1/2 -translate-x-1/2 px-3 py-1.5 rounded-full bg-black/60 backdrop-blur-sm text-white text-xs font-medium"
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: sliderPosition > 15 ? 1 : 0, y: 0 }}
      >
        {beforeLabel}
      </motion.div>
      <motion.div
        className="absolute bottom-4 left-1/2 -translate-x-1/2 px-3 py-1.5 rounded-full bg-white/90 backdrop-blur-sm text-black text-xs font-medium"
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: sliderPosition < 85 ? 1 : 0, y: 0 }}
      >
        {afterLabel}
      </motion.div>
    </div>
  )
}
