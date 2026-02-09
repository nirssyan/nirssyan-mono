'use client'

export interface Column<T> {
  key: string
  header: string
  render?: (item: T) => React.ReactNode
}

interface DataTableProps<T> {
  columns: Column<T>[]
  data: T[]
  loading?: boolean
  onEdit?: (item: T) => void
  onDelete?: (item: T) => void
}

export function DataTable<T extends { id: string }>({
  columns,
  data,
  loading,
  onEdit,
  onDelete,
}: DataTableProps<T>) {
  if (loading) {
    return (
      <div className="flex h-40 items-center justify-center text-white/50">Loading...</div>
    )
  }

  if (data.length === 0) {
    return (
      <div className="flex h-40 items-center justify-center text-white/50">No data</div>
    )
  }

  return (
    <div className="overflow-x-auto rounded-xl border border-white/10">
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-white/10 bg-white/[0.03]">
            {columns.map((col) => (
              <th key={col.key} className="px-4 py-3 font-medium text-white/70">
                {col.header}
              </th>
            ))}
            {(onEdit || onDelete) && (
              <th className="px-4 py-3 text-right font-medium text-white/70">Actions</th>
            )}
          </tr>
        </thead>
        <tbody>
          {data.map((item) => (
            <tr key={item.id} className="border-b border-white/5 hover:bg-white/[0.02]">
              {columns.map((col) => (
                <td key={col.key} className="px-4 py-3 text-white/80">
                  {col.render
                    ? col.render(item)
                    : String((item as Record<string, unknown>)[col.key] ?? '')}
                </td>
              ))}
              {(onEdit || onDelete) && (
                <td className="px-4 py-3 text-right">
                  <div className="flex justify-end gap-2">
                    {onEdit && (
                      <button
                        onClick={() => onEdit(item)}
                        className="rounded-lg px-3 py-1 text-xs text-white/60 transition-colors hover:bg-white/10 hover:text-white"
                      >
                        Edit
                      </button>
                    )}
                    {onDelete && (
                      <button
                        onClick={() => onDelete(item)}
                        className="rounded-lg px-3 py-1 text-xs text-red-400/70 transition-colors hover:bg-red-400/10 hover:text-red-400"
                      >
                        Delete
                      </button>
                    )}
                  </div>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
