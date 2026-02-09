'use client'

import { useEffect, useState, useCallback } from 'react'
import { listTags, createTag, updateTag, deleteTag, type Tag } from '@/lib/admin-api'
import { DataTable, type Column } from '@/components/admin/data-table'
import { ConfirmDialog } from '@/components/admin/confirm-dialog'
import { FormModal, FormField, inputClassName } from '@/components/admin/form-modal'

function toSlug(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-zа-яё0-9]+/gi, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^-|-$/g, '')
}

export default function TagsPage() {
  const [data, setData] = useState<Tag[]>([])
  const [loading, setLoading] = useState(true)

  const [formOpen, setFormOpen] = useState(false)
  const [editing, setEditing] = useState<Tag | null>(null)
  const [formLoading, setFormLoading] = useState(false)

  const [deleteTarget, setDeleteTarget] = useState<Tag | null>(null)
  const [deleteLoading, setDeleteLoading] = useState(false)

  const [name, setName] = useState('')
  const [slug, setSlug] = useState('')
  const [autoSlug, setAutoSlug] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      setData(await listTags())
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const openCreate = () => {
    setEditing(null)
    setName('')
    setSlug('')
    setAutoSlug(true)
    setFormOpen(true)
  }

  const openEdit = (item: Tag) => {
    setEditing(item)
    setName(item.name)
    setSlug(item.slug)
    setAutoSlug(false)
    setFormOpen(true)
  }

  const handleNameChange = (v: string) => {
    setName(v)
    if (autoSlug) setSlug(toSlug(v))
  }

  const handleSlugChange = (v: string) => {
    setAutoSlug(false)
    setSlug(v)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormLoading(true)
    try {
      if (editing) {
        await updateTag(editing.id, { name, slug })
      } else {
        await createTag({ name, slug })
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
      await deleteTag(deleteTarget.id)
      setDeleteTarget(null)
      load()
    } finally {
      setDeleteLoading(false)
    }
  }

  const columns: Column<Tag>[] = [
    { key: 'name', header: 'Name' },
    {
      key: 'slug',
      header: 'Slug',
      render: (t) => <code className="text-xs text-white/50">{t.slug}</code>,
    },
  ]

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white">Tags</h1>
        <button
          onClick={openCreate}
          className="rounded-lg bg-white px-4 py-2 text-sm font-medium text-black transition-colors hover:bg-white/90"
        >
          Create
        </button>
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
        title={editing ? 'Edit Tag' : 'Create Tag'}
        onClose={() => setFormOpen(false)}
        onSubmit={handleSubmit}
        loading={formLoading}
      >
        <FormField label="Name">
          <input
            className={inputClassName}
            value={name}
            onChange={(e) => handleNameChange(e.target.value)}
            required
          />
        </FormField>
        <FormField label="Slug">
          <input
            className={inputClassName}
            value={slug}
            onChange={(e) => handleSlugChange(e.target.value)}
            required
          />
        </FormField>
      </FormModal>

      <ConfirmDialog
        open={!!deleteTarget}
        title="Delete Tag"
        message={`Delete tag "${deleteTarget?.name}"? This will also remove it from all users.`}
        onConfirm={handleDelete}
        onCancel={() => setDeleteTarget(null)}
        loading={deleteLoading}
      />
    </div>
  )
}
