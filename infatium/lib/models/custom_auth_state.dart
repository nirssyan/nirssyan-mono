import 'custom_auth_models.dart';

/// Custom auth state for auth event stream.
class CustomAuthState {
  final CustomAuthEvent event;
  final CustomAuthSession? session;

  CustomAuthState(this.event, this.session);
}

/// Custom auth events.
enum CustomAuthEvent {
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  passwordRecovery,
}
