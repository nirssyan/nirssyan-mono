'use client'

import { useEffect, useState, useCallback } from 'react'
import {
  listSuggestions,
  createSuggestion,
  updateSuggestion,
  deleteSuggestion,
  type Suggestion,
  type SuggestionName,
} from '@/lib/admin-api'
import { DataTable, type Column } from '@/components/admin/data-table'
import { ConfirmDialog } from '@/components/admin/confirm-dialog'
import { FormModal, FormField, inputClassName, selectClassName } from '@/components/admin/form-modal'

const TYPES = ['filter', 'view', 'source'] as const

export default function SuggestionsPage() {
  const [data, setData] = useState<Suggestion[]>([])
  const [loading, setLoading] = useState(true)
  const [typeFilter, setTypeFilter] = useState('')

  const [formOpen, setFormOpen] = useState(false)
  const [editing, setEditing] = useState<Suggestion | null>(null)
  const [formLoading, setFormLoading] = useState(false)

  const [deleteTarget, setDeleteTarget] = useState<Suggestion | null>(null)
  const [deleteLoading, setDeleteLoading] = useState(false)

  const [nameRu, setNameRu] = useState('')
  const [nameEn, setNameEn] = useState('')
  const [sType, setSType] = useState<string>('filter')
  const [sourceType, setSourceType] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const items = await listSuggestions(typeFilter || undefined)
      setData(items)
    } finally {
      setLoading(false)
    }
  }, [typeFilter])

  useEffect(() => {
    load()
  }, [load])

  const openCreate = () => {
    setEditing(null)
    setNameRu('')
    setNameEn('')
    setSType('filter')
    setSourceType('')
    setFormOpen(true)
  }

  const openEdit = (item: Suggestion) => {
    setEditing(item)
    setNameRu(item.name.ru)
    setNameEn(item.name.en)
    setSType(item.type)
    setSourceType(item.source_type ?? '')
    setFormOpen(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormLoading(true)
    try {
      const name: SuggestionName = { ru: nameRu, en: nameEn }
      if (editing) {
        await updateSuggestion(editing.id, {
          name,
          source_type: sourceType || undefined,
        })
      } else {
        await createSuggestion({
          type: sType,
          name,
          source_type: sourceType || undefined,
        })
      }
      setFormOpen(false)
      load()
    } finally {
      setFormLoading(false)
    }
  }

  const handleDelete = async () => {
    if (!deleteTarget) return
    setDeleteLoading(true)
    try {
      await deleteSuggestion(deleteTarget.id)
      setDeleteTarget(null)
      load()
    } finally {
      setDeleteLoading(false)
    }
  }

  const columns: Column<Suggestion>[] = [
    { key: 'name_ru', header: 'Name (RU)', render: (s) => s.name.ru },
    { key: 'name_en', header: 'Name (EN)', render: (s) => s.name.en },
    {
      key: 'type',
      header: 'Type',
      render: (s) => (
        <span className="rounded-md bg-white/10 px-2 py-0.5 text-xs">{s.type}</span>
      ),
    },
    { key: 'source_type', header: 'Source Type', render: (s) => s.source_type ?? '—' },
  ]

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white">Suggestions</h1>
        <button
          onClick={openCreate}
          className="rounded-lg bg-white px-4 py-2 text-sm font-medium text-black transition-colors hover:bg-white/90"
        >
          Create
        </button>
      </div>

      <div className="mb-4 flex gap-2">
        <button
          onClick={() => setTypeFilter('')}
          className={`rounded-lg px-3 py-1.5 text-xs transition-colors ${
            !typeFilter ? 'bg-white/15 text-white' : 'text-white/50 hover:bg-white/5'
          }`}
        >
          All
        </button>
        {TYPES.map((t) => (
          <button
            key={t}
            onClick={() => setTypeFilter(t)}
            className={`rounded-lg px-3 py-1.5 text-xs transition-colors ${
              typeFilter === t ? 'bg-white/15 text-white' : 'text-white/50 hover:bg-white/5'
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      <DataTable
        columns={columns}
        data={data}
        loading={loading}
        onEdit={openEdit}
        onDelete={setDeleteTarget}
      />

      <FormModal
        open={formOpen}
        title={editing ? 'Edit Suggestion' : 'Create Suggestion'}
        onClose={() => setFormOpen(false)}
        onSubmit={handleSubmit}
        loading={formLoading}
      >
        <FormField label="Name (RU)">
          <input
            className={inputClassName}
            value={nameRu}
            onChange={(e) => setNameRu(e.target.value)}
            required
          />
        </FormField>
        <FormField label="Name (EN)">
          <input
            className={inputClassName}
            value={nameEn}
            onChange={(e) => setNameEn(e.target.value)}
            required
          />
        </FormField>
        {!editing && (
          <FormField label="Type">
            <select
              className={selectClassName}
              value={sType}
              onChange={(e) => setSType(e.target.value)}
            >
              {TYPES.map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
          </FormField>
        )}
        <FormField label="Source Type (optional)">
          <input
            className={inputClassName}
            value={sourceType}
            onChange={(e) => setSourceType(e.target.value)}
            placeholder="e.g. telegram, rss"
          />
        </FormField>
      </FormModal>

      <ConfirmDialog
        open={!!deleteTarget}
        title="Delete Suggestion"
        message={`Delete "${deleteTarget?.name.ru || deleteTarget?.name.en}"? This cannot be undone.`}
        onConfirm={handleDelete}
        onCancel={() => setDeleteTarget(null)}
        loading={deleteLoading}
      />
    </div>
  )
}
