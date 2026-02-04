declare global {
  interface Window {
    ym?: (id: number, method: string, ...args: unknown[]) => void
  }
}

export interface YandexMetrikaConfig {
  id: string
  enabled: boolean
}

export const yandexMetrikaConfig: YandexMetrikaConfig = {
  id: process.env.NEXT_PUBLIC_YANDEX_METRIKA_ID || '',
  enabled: Boolean(
    process.env.NEXT_PUBLIC_YANDEX_METRIKA_ID &&
    process.env.NEXT_PUBLIC_ENABLE_YANDEX_METRIKA === 'true'
  ),
}

function getYm(): typeof window.ym | null {
  if (typeof window === 'undefined' || !window.ym) return null
  return window.ym
}

function getMetrikaId(): number {
  return Number(yandexMetrikaConfig.id)
}

export function reachGoal(goalName: string, params?: Record<string, unknown>) {
  const ym = getYm()
  if (!ym || !yandexMetrikaConfig.enabled) return

  if (params) {
    ym(getMetrikaId(), 'reachGoal', goalName, params)
  } else {
    ym(getMetrikaId(), 'reachGoal', goalName)
  }
}

export function hit(url: string, options?: { title?: string; referer?: string }) {
  const ym = getYm()
  if (!ym || !yandexMetrikaConfig.enabled) return

  ym(getMetrikaId(), 'hit', url, options)
}

export function params(visitParams: Record<string, unknown>) {
  const ym = getYm()
  if (!ym || !yandexMetrikaConfig.enabled) return

  ym(getMetrikaId(), 'params', visitParams)
}

export function userParams(userParams: Record<string, unknown>) {
  const ym = getYm()
  if (!ym || !yandexMetrikaConfig.enabled) return

  ym(getMetrikaId(), 'userParams', userParams)
}

export function isYandexMetrikaEnabled(): boolean {
  return yandexMetrikaConfig.enabled
}
