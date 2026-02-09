'use client'

import { useEffect, useState, useCallback } from 'react'
import {
  listMarketplaceFeeds,
  createMarketplaceFeed,
  updateMarketplaceFeed,
  deleteMarketplaceFeed,
  listTags,
  type MarketplaceFeed,
  type MarketplaceFeedSource,
  type Tag,
} from '@/lib/admin-api'
import { DataTable, type Column } from '@/components/admin/data-table'
import { ConfirmDialog } from '@/components/admin/confirm-dialog'
import { FormModal, FormField, inputClassName, selectClassName } from '@/components/admin/form-modal'

export default function MarketplacePage() {
  const [data, setData] = useState<MarketplaceFeed[]>([])
  const [allTags, setAllTags] = useState<Tag[]>([])
  const [loading, setLoading] = useState(true)

  const [formOpen, setFormOpen] = useState(false)
  const [editing, setEditing] = useState<MarketplaceFeed | null>(null)
  const [formLoading, setFormLoading] = useState(false)

  const [deleteTarget, setDeleteTarget] = useState<MarketplaceFeed | null>(null)
  const [deleteLoading, setDeleteLoading] = useState(false)

  const [name, setName] = useState('')
  const [feedType, setFeedType] = useState('SINGLE_POST')
  const [description, setDescription] = useState('')
  const [tags, setTags] = useState<string[]>([])
  const [sources, setSources] = useState<MarketplaceFeedSource[]>([{ name: '', url: '', type: 'rss' }])
  const [story, setStory] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const [feeds, tagList] = await Promise.all([listMarketplaceFeeds(), listTags()])
      setData(feeds)
      setAllTags(tagList)
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
    setFeedType('SINGLE_POST')
    setDescription('')
    setTags([])
    setSources([{ name: '', url: '', type: 'rss' }])
    setStory('')
    setFormOpen(true)
  }

  const openEdit = (item: MarketplaceFeed) => {
    setEditing(item)
    setName(item.name)
    setFeedType(item.type)
    setDescription(item.description ?? '')
    setTags(item.tags)
    setSources(item.sources.length > 0 ? item.sources : [{ name: '', url: '', type: 'rss' }])
    setStory(item.story ?? '')
    setFormOpen(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormLoading(true)
    try {
      const validSources = sources.filter((s) => s.url.trim())
      if (editing) {
        await updateMarketplaceFeed(editing.id, {
          name,
          feed_type: feedType,
          description: description || undefined,
          tags,
          sources: validSources,
          story: story || undefined,
        })
      } else {
        await createMarketplaceFeed({
          name,
          feed_type: feedType,
          description: description || undefined,
          tags,
          sources: validSources,
          story: story || undefined,
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
      await deleteMarketplaceFeed(deleteTarget.id)
      setDeleteTarget(null)
      load()
    } finally {
      setDeleteLoading(false)
    }
  }

  const updateSource = (index: number, field: keyof MarketplaceFeedSource, value: string) => {
    setSources((prev) => prev.map((s, i) => (i === index ? { ...s, [field]: value } : s)))
  }

  const addSource = () => setSources((prev) => [...prev, { name: '', url: '', type: 'rss' }])
  const removeSource = (index: number) => setSources((prev) => prev.filter((_, i) => i !== index))

  const toggleTag = (tagName: string) => {
    setTags((prev) =>
      prev.includes(tagName) ? prev.filter((t) => t !== tagName) : [...prev, tagName]
    )
  }

  const columns: Column<MarketplaceFeed>[] = [
    { key: 'name', header: 'Name' },
    {
      key: 'type',
      header: 'Type',
      render: (f) => (
        <span className="rounded-md bg-white/10 px-2 py-0.5 text-xs">{f.type}</span>
      ),
    },
    {
      key: 'tags',
      header: 'Tags',
      render: (f) => (
        <div className="flex flex-wrap gap-1">
          {f.tags.map((t) => (
            <span key={t} className="rounded bg-white/5 px-1.5 py-0.5 text-xs text-white/50">
              {t}
            </span>
          ))}
        </div>
      ),
    },
    {
      key: 'sources',
      header: 'Sources',
      render: (f) => <span className="text-white/50">{f.sources.length}</span>,
    },
    {
      key: 'created_at',
      header: 'Created',
      render: (f) => (
        <span className="text-xs text-white/40">
          {new Date(f.created_at).toLocaleDateString()}
        </span>
      ),
    },
  ]

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-white">Marketplace Feeds</h1>
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
        title={editing ? 'Edit Feed' : 'Create Feed'}
        onClose={() => setFormOpen(false)}
        onSubmit={handleSubmit}
        loading={formLoading}
      >
        <FormField label="Name">
          <input
            className={inputClassName}
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
        </FormField>

        <FormField label="Type">
          <select
            className={selectClassName}
            value={feedType}
            onChange={(e) => setFeedType(e.target.value)}
          >
            <option value="SINGLE_POST">SINGLE_POST</option>
            <option value="DIGEST">DIGEST</option>
          </select>
        </FormField>

        <FormField label="Description">
          <textarea
            className={`${inputClassName} min-h-[80px] resize-y`}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </FormField>

        <FormField label="Tags">
          <div className="flex flex-wrap gap-2">
            {allTags.map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => toggleTag(t.name)}
                className={`rounded-lg px-2.5 py-1 text-xs transition-colors ${
                  tags.includes(t.name)
                    ? 'bg-white/20 text-white'
                    : 'border border-white/10 text-white/40 hover:bg-white/5'
                }`}
              >
                {t.name}
              </button>
            ))}
          </div>
        </FormField>

        <FormField label="Sources">
          <div className="space-y-3">
            {sources.map((src, i) => (
              <div key={i} className="flex gap-2">
                <input
                  className={`${inputClassName} flex-1`}
                  placeholder="URL"
                  value={src.url}
                  onChange={(e) => updateSource(i, 'url', e.target.value)}
                />
                <input
                  className={`${inputClassName} w-28`}
                  placeholder="Name"
                  value={src.name}
                  onChange={(e) => updateSource(i, 'name', e.target.value)}
                />
                <select
                  className={`${selectClassName} w-24`}
                  value={src.type}
                  onChange={(e) => updateSource(i, 'type', e.target.value)}
                >
                  <option value="rss">rss</option>
                  <option value="telegram">telegram</option>
                  <option value="web">web</option>
                </select>
                {sources.length > 1 && (
                  <button
                    type="button"
                    onClick={() => removeSource(i)}
                    className="rounded-lg px-2 text-red-400/60 hover:bg-red-400/10 hover:text-red-400"
                  >
                    x
                  </button>
                )}
              </div>
            ))}
            <button
              type="button"
              onClick={addSource}
              className="text-xs text-white/40 hover:text-white/70"
            >
              + Add source
            </button>
          </div>
        </FormField>

        <FormField label="Story">
          <textarea
            className={`${inputClassName} min-h-[80px] resize-y`}
            value={story}
            onChange={(e) => setStory(e.target.value)}
          />
        </FormField>
      </FormModal>

      <ConfirmDialog
        open={!!deleteTarget}
        title="Delete Feed"
        message={`Delete "${deleteTarget?.name}"? This cannot be undone.`}
        onConfirm={handleDelete}
        onCancel={() => setDeleteTarget(null)}
        loading={deleteLoading}
      />
    </div>
  )
}
