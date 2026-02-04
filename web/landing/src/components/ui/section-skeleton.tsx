export function SectionSkeleton() {
  return (
    <div className="relative min-h-[400px] sm:min-h-[600px] flex items-center justify-center bg-black/20">
      <div className="animate-pulse space-y-4 w-full max-w-4xl px-4">
        <div className="h-8 bg-white/10 rounded w-3/4 mx-auto" />
        <div className="h-4 bg-white/5 rounded w-1/2 mx-auto" />
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-8">
          <div className="h-48 bg-white/5 rounded" />
          <div className="h-48 bg-white/5 rounded" />
        </div>
      </div>
    </div>
  )
}
