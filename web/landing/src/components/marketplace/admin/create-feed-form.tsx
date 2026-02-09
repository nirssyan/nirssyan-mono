'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Plus } from 'lucide-react'
import { SourceInput } from './source-input'

interface Source {
  url: string
  name: string
  type: string
}

export function CreateFeedForm({ token }: { token: string }) {
  const router = useRouter()
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [feedType, setFeedType] = useState('SINGLE_POST')
  const [tagsInput, setTagsInput] = useState('')
  const [story, setStory] = useState('')
  const [sources, setSources] = useState<Source[]>([{ url: '', name: '', type: 'rss' }])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const updateSource = (index: number, field: keyof Source, value: string) => {
    setSources((prev) => prev.map((s, i) => (i === index ? { ...s, [field]: value } : s)))
  }

  const addSource = () => {
    setSources((prev) => [...prev, { url: '', name: '', type: 'rss' }])
  }

  const removeSource = (index: number) => {
    setSources((prev) => prev.filter((_, i) => i !== index))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (!name.trim()) {
      setError('Name is required')
      return
    }

    const validSources = sources.filter((s) => s.url.trim())
    if (validSources.length === 0) {
      setError('At least one source with URL is required')
      return
    }

    setLoading(true)

    try {
      const tags = tagsInput
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean)

      const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL}/marketplace`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          name: name.trim(),
          description: description.trim(),
          feed_type: feedType,
          tags,
          sources: validSources,
          story: story.trim(),
        }),
      })

      if (!res.ok) {
        const text = await res.text()
        throw new Error(text || 'Failed to create feed')
      }

      const data = await res.json()
      router.push(`/marketplace/${data.slug}`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create feed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div>
        <label htmlFor="name" className="mb-2 block text-sm font-medium text-white/70">
          Name *
        </label>
        <input
          id="name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          className="w-full rounded-xl border border-white/15 bg-white/[0.05] px-4 py-3 text-white placeholder-white/30 outline-none transition-colors focus:border-white/30"
          placeholder="My Awesome Feed"
        />
      </div>

      <div>
        <label htmlFor="description" className="mb-2 block text-sm font-medium text-white/70">
          Description
        </label>
        <textarea
          id="description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={3}
          className="w-full resize-none rounded-xl border border-white/15 bg-white/[0.05] px-4 py-3 text-white placeholder-white/30 outline-none transition-colors focus:border-white/30"
          placeholder="Brief description of the feed"
        />
      </div>

      <div>
        <label htmlFor="feedType" className="mb-2 block text-sm font-medium text-white/70">
          Feed Type
        </label>
        <select
          id="feedType"
          value={feedType}
          onChange={(e) => setFeedType(e.target.value)}
          className="w-full rounded-xl border border-white/15 bg-white/[0.05] px-4 py-3 text-white outline-none transition-colors focus:border-white/30"
        >
          <option value="SINGLE_POST">SINGLE_POST</option>
          <option value="DIGEST">DIGEST</option>
        </select>
      </div>

      <div>
        <label htmlFor="tags" className="mb-2 block text-sm font-medium text-white/70">
          Tags (comma-separated)
        </label>
        <input
          id="tags"
          type="text"
          value={tagsInput}
          onChange={(e) => setTagsInput(e.target.value)}
          className="w-full rounded-xl border border-white/15 bg-white/[0.05] px-4 py-3 text-white placeholder-white/30 outline-none transition-colors focus:border-white/30"
          placeholder="ai, tech, startups"
        />
      </div>

      <div>
        <label htmlFor="story" className="mb-2 block text-sm font-medium text-white/70">
          Personal Story (optional)
        </label>
        <textarea
          id="story"
          value={story}
          onChange={(e) => setStory(e.target.value)}
          rows={4}
          className="w-full resize-none rounded-xl border border-white/15 bg-white/[0.05] px-4 py-3 text-white placeholder-white/30 outline-none transition-colors focus:border-white/30"
          placeholder="Why did you create this feed?"
        />
      </div>

      <div>
        <div className="mb-3 flex items-center justify-between">
          <label className="text-sm font-medium text-white/70">Sources *</label>
          <button
            type="button"
            onClick={addSource}
            className="inline-flex items-center gap-1.5 rounded-lg border border-white/15 bg-white/[0.04] px-3 py-1.5 text-xs text-white/70 transition-colors hover:bg-white/10"
          >
            <Plus className="h-3.5 w-3.5" />
            Add source
          </button>
        </div>

        <div className="space-y-3">
          {sources.map((source, index) => (
            <SourceInput
              key={index}
              index={index}
              url={source.url}
              name={source.name}
              type={source.type}
              onUrlChange={(v) => updateSource(index, 'url', v)}
              onNameChange={(v) => updateSource(index, 'name', v)}
              onTypeChange={(v) => updateSource(index, 'type', v)}
              onRemove={() => removeSource(index)}
              canRemove={sources.length > 1}
            />
          ))}
        </div>
      </div>

      {error && (
        <p className="rounded-xl border border-red-400/30 bg-red-400/10 px-4 py-3 text-sm text-red-300">
          {error}
        </p>
      )}

      <button
        type="submit"
        disabled={loading}
        className="w-full rounded-xl bg-white px-4 py-3 text-sm font-medium text-black transition-all duration-200 hover:bg-white/90 disabled:opacity-50"
      >
        {loading ? 'Creating...' : 'Create Feed'}
      </button>
    </form>
  )
}
