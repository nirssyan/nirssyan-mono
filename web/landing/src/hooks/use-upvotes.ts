'use client'

import { useCallback, useEffect, useState } from 'react'

const STORAGE_KEY = 'infatium_upvotes'
const VOTED_KEY = 'infatium_voted'

interface UseUpvotesReturn {
  votes: Record<string, number>
  toggleVote: (feedId: string) => void
  getVotes: (feedId: string) => number
  hasVoted: (feedId: string) => boolean
  mounted: boolean
}

export function useUpvotes(initialVotesMap: Record<string, number>): UseUpvotesReturn {
  const [votes, setVotes] = useState<Record<string, number>>(initialVotesMap)
  const [votedIds, setVotedIds] = useState<Set<string>>(new Set())
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    try {
      const storedVotes = localStorage.getItem(STORAGE_KEY)
      const storedVoted = localStorage.getItem(VOTED_KEY)

      if (storedVotes) {
        const parsed = JSON.parse(storedVotes) as Record<string, number>
        setVotes((prev) => ({ ...prev, ...parsed }))
      }

      if (storedVoted) {
        const parsed = JSON.parse(storedVoted) as string[]
        setVotedIds(new Set(parsed))
      }
    } catch {
      // ignore corrupted localStorage
    }

    setMounted(true)
  }, [])

  const toggleVote = useCallback(
    (feedId: string) => {
      setVotedIds((prev) => {
        const next = new Set(prev)
        const wasVoted = next.has(feedId)

        if (wasVoted) {
          next.delete(feedId)
        } else {
          next.add(feedId)
        }

        setVotes((prevVotes) => {
          const delta = wasVoted ? -1 : 1
          const updated = { ...prevVotes, [feedId]: (prevVotes[feedId] ?? 0) + delta }

          try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(updated))
          } catch {
            // quota exceeded
          }

          return updated
        })

        try {
          localStorage.setItem(VOTED_KEY, JSON.stringify([...next]))
        } catch {
          // quota exceeded
        }

        return next
      })
    },
    [],
  )

  const getVotes = useCallback((feedId: string) => votes[feedId] ?? 0, [votes])

  const hasVoted = useCallback((feedId: string) => votedIds.has(feedId), [votedIds])

  return { votes, toggleVote, getVotes, hasVoted, mounted }
}
