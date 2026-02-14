export function openInAppWithStoreFallback(feedId: string, desktopDownloadLabel: string) {
  const deepLink = `makefeed://feed/${feedId}`
  const appStoreId = process.env.NEXT_PUBLIC_APP_STORE_ID
  const playStoreId = process.env.NEXT_PUBLIC_PLAY_STORE_ID || 'com.infatium'

  const appStoreUrl =
    appStoreId && appStoreId !== 'your_app_store_id_here'
      ? `https://apps.apple.com/app/id${appStoreId}`
      : 'https://apps.apple.com/search?term=infatium'
  const playStoreUrl = `https://play.google.com/store/apps/details?id=${playStoreId}`

  const userAgent = navigator.userAgent
  const isIOS = /iPhone|iPad|iPod/.test(userAgent)
  const isAndroid = /Android/.test(userAgent)

  const timeout = window.setTimeout(() => {
    cleanup()

    if (isIOS) {
      window.location.href = appStoreUrl
      return
    }

    if (isAndroid) {
      window.location.href = playStoreUrl
      return
    }

    alert(`${desktopDownloadLabel}\n\niOS: ${appStoreUrl}\n\nAndroid: ${playStoreUrl}`)
  }, 1500)

  const cleanup = () => {
    clearTimeout(timeout)
    document.removeEventListener('visibilitychange', onVisibilityChange)
    window.removeEventListener('blur', onBlur)
  }

  const onVisibilityChange = () => {
    if (document.hidden) cleanup()
  }
  const onBlur = () => cleanup()

  document.addEventListener('visibilitychange', onVisibilityChange)
  window.addEventListener('blur', onBlur)

  window.location.href = deepLink
}
