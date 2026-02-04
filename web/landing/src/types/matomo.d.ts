type MatomoCommand =
  | ['trackPageView']
  | ['trackPageView', string]
  | ['trackEvent', string, string]
  | ['trackEvent', string, string, string]
  | ['trackEvent', string, string, string, number]
  | ['trackLink', string, string]
  | ['setCustomUrl', string]
  | ['setDocumentTitle', string]
  | ['setReferrerUrl', string]
  | ['setUserId', string]
  | ['resetUserId']
  | ['requireConsent']
  | ['setConsentGiven']
  | ['rememberConsentGiven']
  | ['forgetConsentGiven']
  | ['requireCookieConsent']
  | ['setCookieConsentGiven']
  | ['rememberCookieConsentGiven']
  | ['forgetCookieConsentGiven']
  | ['setTrackerUrl', string]
  | ['setSiteId', string]
  | ['enableLinkTracking']
  | ['disableCookies']

declare global {
  interface Window {
    _paq: MatomoCommand[]
  }
}

export {}
