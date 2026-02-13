// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Chat';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get registration => 'Registration';

  @override
  String get signInToAccount => 'Sign in to your account';

  @override
  String get createNewAccount => 'Create a new account';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get signInWithMagicLink => 'Sign in with email';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String get magicLinkSent => 'We sent you a sign-in link';

  @override
  String get magicLinkDescription => 'Click the link in your email to sign in';

  @override
  String get continueWithEmail => 'Continue with email';

  @override
  String get enterYourEmail => 'Enter your email';

  @override
  String get magicLinkSentToEmail => 'We\'ve sent a sign-in link to your email';

  @override
  String get clickLinkToSignIn =>
      'Click the link in the email to sign in to your account';

  @override
  String get cantFindEmail => 'Can\'t find the email?';

  @override
  String get checkSpamFolder => 'Check your spam or junk folder';

  @override
  String get resendEmail => 'Resend email';

  @override
  String resendEmailIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get or => 'or';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get fillAllFields => 'Fill all fields';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get noAccount => 'Don\'t have an account? ';

  @override
  String get haveAccount => 'Already have an account? ';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get chats => 'Create';

  @override
  String get profile => 'Profile';

  @override
  String get news => 'Feed';

  @override
  String get all => 'All';

  @override
  String get technology => 'Technology';

  @override
  String get ai => 'AI';

  @override
  String get science => 'Science';

  @override
  String get space => 'Space';

  @override
  String get ecology => 'Ecology';

  @override
  String minutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours h ago';
  }

  @override
  String daysAgo(int days) {
    return '$days d ago';
  }

  @override
  String get products => 'Products';

  @override
  String get techCrunch => 'TechCrunch';

  @override
  String get appleNews => 'Apple News';

  @override
  String get scienceToday => 'Science Today';

  @override
  String get aiWeekly => 'AI Weekly';

  @override
  String get ecoNews => 'EcoNews';

  @override
  String get spaceExplorer => 'Space Explorer';

  @override
  String get searchPage => 'Search Page';

  @override
  String get chatsPage => 'Create';

  @override
  String get settings => 'Settings';

  @override
  String get appIcon => 'App Icon';

  @override
  String get darkIcon => 'Dark';

  @override
  String get lightIcon => 'Light';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get zenMode => 'Zen Mode';

  @override
  String get zenModeDescription => 'Hide unread counters';

  @override
  String get zenModeEnabled => 'Enabled';

  @override
  String get zenModeDisabled => 'Disabled';

  @override
  String get zenModeEnabledDescription => 'Unread counters are hidden';

  @override
  String get zenModeDisabledDescription => 'Unread counters are visible';

  @override
  String get zenModeInfo =>
      'When zen mode is enabled, all unread counters and badges will be hidden throughout the app. This helps you focus on content without distractions from notifications.';

  @override
  String get viewSettings => 'View Settings';

  @override
  String get imagePreviews => 'Image Previews';

  @override
  String get imagePreviewsDescription => 'Show image previews in news feed';

  @override
  String get imagePreviewsEnabled => 'Enabled';

  @override
  String get imagePreviewsDisabled => 'Disabled';

  @override
  String get imagePreviewsEnabledDescription => 'Image previews are visible';

  @override
  String get imagePreviewsDisabledDescription => 'Image previews are hidden';

  @override
  String get imagePreviewsInfo =>
      'When disabled, news cards will not show image/video previews, making the feed more compact and text-focused.';

  @override
  String get defaultContent => 'Default Content';

  @override
  String get defaultContentDescription => 'Choose what to show first';

  @override
  String get summaryFirstDescription => 'Brief summary shown first';

  @override
  String get fullTextFirstDescription => 'Full text shown first';

  @override
  String get defaultContentInfo =>
      'This setting swaps the order of content tabs. Choose whether you want to see the brief summary or full text first when opening a news article.';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get cancel => 'Cancel';

  @override
  String get account => 'Account';

  @override
  String get deepseekChat => 'DeepSeek AI';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get startConversation => 'Start a conversation with AI';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get aiIsTyping => 'Feed is coming...';

  @override
  String get feedTyping1 => 'Building your feed';

  @override
  String get feedTyping2 => 'Feed incoming';

  @override
  String get feedTyping3 => 'Curating content';

  @override
  String get feedTyping4 => 'Almost there';

  @override
  String get feedTyping5 => 'Creating magic';

  @override
  String get feedTyping6 => 'Just a sec';

  @override
  String get feedTyping7 => 'Getting ready';

  @override
  String get feedTyping8 => 'On it';

  @override
  String get feedTyping9 => 'Brewing your feed';

  @override
  String get feedTyping10 => 'Loading up';

  @override
  String get feedSubtext1 => 'Hang tight';

  @override
  String get feedSubtext2 => 'Finding gems';

  @override
  String get feedSubtext3 => 'One moment';

  @override
  String get feedSubtext4 => 'Personalizing';

  @override
  String get feedSubtext5 => 'Almost ready';

  @override
  String get feedSubtext6 => 'Sorting content';

  @override
  String get feedSubtext7 => 'Just for you';

  @override
  String get feedSubtext8 => 'Working on it';

  @override
  String get feedSubtext9 => 'Stay with us';

  @override
  String get feedSubtext10 => 'Nearly done';

  @override
  String get sendMessage => 'Send message';

  @override
  String get viewComment => 'AI Comment';

  @override
  String get viewOverview => 'Overview';

  @override
  String get contactUs => 'Contact us';

  @override
  String get emailCopied => 'Copied!';

  @override
  String get emailCopiedMessage => 'Email address copied to clipboard';

  @override
  String get feedManagement => 'Feed Management';

  @override
  String get renameFeed => 'Rename Feed';

  @override
  String get deleteFeed => 'Delete';

  @override
  String get confirmDeleteFeed =>
      'Are you sure you want to unsubscribe from this feed?';

  @override
  String get confirmDeleteFeedMessage =>
      'This action cannot be undone. All posts from this feed will be removed from your timeline.';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get enterNewName => 'Enter new feed name';

  @override
  String get feedNameRequired => 'Feed name is required';

  @override
  String get feedRenamed => 'Feed renamed successfully';

  @override
  String get feedDeleted => 'Unsubscribed from feed';

  @override
  String get errorRenamingFeed => 'Error renaming feed';

  @override
  String get errorDeletingFeed => 'Error unsubscribing from feed';

  @override
  String get save => 'Save';

  @override
  String get readAllPosts => 'Read All';

  @override
  String postsMarkedAsRead(int count) {
    return 'Marked $count posts as read';
  }

  @override
  String get errorMarkingPostsAsRead => 'Error marking posts as read';

  @override
  String sourceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sources',
      one: '$count source',
      zero: 'No sources',
    );
    return '$_temp0';
  }

  @override
  String get noFeedsTitle => 'No feeds yet';

  @override
  String get noFeedsSubtitle => 'Tap + to create your first feed';

  @override
  String get noFeedsDescription =>
      'Add your favorite sources and get personalized content powered by AI.';

  @override
  String get goToChat => 'Go to Create';

  @override
  String get feedOnTheWay => 'Your feed is on the way';

  @override
  String get feedLoadingDescription => 'We\'re gathering the best news for you';

  @override
  String get feedGenerating => 'Generating your feed just for you';

  @override
  String get chat => 'Session';

  @override
  String get startAConversation => 'Start creating';

  @override
  String get newChat => 'New Session';

  @override
  String get deleteChat => 'Delete';

  @override
  String get deleteSession => 'Delete';

  @override
  String get confirmDeleteChat => 'Delete Session?';

  @override
  String get confirmDeleteChatMessage =>
      'This session and all its messages will be permanently deleted.';

  @override
  String get chatDeleted => 'Session deleted';

  @override
  String get sessionDeleted => 'Session deleted';

  @override
  String get errorLoadingChats => 'Error loading sessions';

  @override
  String get errorLoadingSessions => 'Error loading sessions';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get errorCreatingChat => 'Error creating session';

  @override
  String get errorCreatingSession => 'Error creating session';

  @override
  String get errorDeletingChat => 'Error deleting session';

  @override
  String get errorDeletingSession => 'Error deleting session';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get enterEmailToReset =>
      'Enter your email address and we\'ll send you instructions to reset your password.';

  @override
  String get send => 'Send';

  @override
  String get resetPasswordSuccess => 'Password reset instructions sent';

  @override
  String get resetPasswordSuccessMessage =>
      'Check your email for instructions to reset your password.';

  @override
  String get success => 'Success';

  @override
  String get passwordChangedSuccessfully =>
      'Your password has been changed successfully!';

  @override
  String get createNewPassword => 'Create New Password';

  @override
  String get enterNewPasswordBelow => 'Enter your new password below';

  @override
  String get newPassword => 'New password';

  @override
  String get passwordRequirements =>
      'Min. 8 characters, including uppercase, lowercase, numbers, and special characters';

  @override
  String get backToSignIn => 'Back to Sign In';

  @override
  String get continueButton => 'Continue';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String get sourcesModalTitle => 'Sources';

  @override
  String get feedback => 'Feedback';

  @override
  String get sendFeedback => 'Send Feedback';

  @override
  String get shareYourFeedback => 'Share Your Feedback';

  @override
  String get shareYourThoughts => 'Share your thoughts with us';

  @override
  String get feedbackSubtitle =>
      'We\'d love to hear your thoughts, suggestions, or any issues you\'ve encountered';

  @override
  String get feedbackPlaceholder => 'Ideas, bugs, feedback...';

  @override
  String get sendingFeedback => 'Sending feedback...';

  @override
  String get feedbackSent => 'Thank You!';

  @override
  String get feedbackSentMessage =>
      'Your feedback has been received. We appreciate you taking the time to help us improve!';

  @override
  String get feedbackError => 'Error Sending Feedback';

  @override
  String get feedbackEmpty => 'Please enter your feedback';

  @override
  String characterLimit(int count, int max) {
    return '$count / $max characters';
  }

  @override
  String get closingAutomatically => 'Closing automatically';

  @override
  String get appTakingBreak => 'The app is taking a break';

  @override
  String get appTakingBreakDescription =>
      'We\'ll be back soon. Please try again later.';

  @override
  String get viewSettingsSubtitle => 'Customize your news feed';

  @override
  String get viewSettingsPageSubtitle => 'Customize your news feed appearance';

  @override
  String get profileDetails => 'Profile Details';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirmTitle => 'Delete Account?';

  @override
  String get deleteAccountConfirmMessage =>
      'This will permanently delete your account and all associated data. This cannot be undone.';

  @override
  String get yes => 'Yes';

  @override
  String get deleteAccountProcessing => 'Deleting account...';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get deleteAccountError => 'Error deleting account';

  @override
  String pleaseWaitSeconds(int seconds) {
    return 'Please wait ${seconds}s...';
  }

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get accountInfo => 'Account Information';

  @override
  String agreeToTerms(String terms, String privacy) {
    return 'By continuing, you agree to our $terms and $privacy';
  }

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get mustAgreeToTerms =>
      'Please agree to the Terms and Privacy Policy to continue';

  @override
  String get agreeToTermsPrefix => 'By continuing, you agree to our ';

  @override
  String get andText => ' and ';

  @override
  String get feedCreatorTitle => 'Create Feed';

  @override
  String get promptLabel => 'Display format';

  @override
  String get promptHint => 'What kind of content do you want?';

  @override
  String get sourcesLabel => 'Sources';

  @override
  String get sourcesHint => '@channel1, @channel2, https://...';

  @override
  String get feedTypeLabel => 'Feed Type';

  @override
  String get singlePostType => 'Individual Posts';

  @override
  String get singlePostTypeDescription => 'Each post is shown separately';

  @override
  String get digestType => 'Digest';

  @override
  String get digestTypeDescription => 'Posts are combined into a digest';

  @override
  String get createFeedButton => 'Create';

  @override
  String get creatingFeed => 'Creating your feed...';

  @override
  String get creatingDigest => 'Creating your digest...';

  @override
  String get feedItemCreating => 'Creating...';

  @override
  String get waitingForFirstPost => 'Waiting for first post';

  @override
  String get timeout => 'Timeout';

  @override
  String get promptRequired => 'Please enter a prompt';

  @override
  String get sourcesRequired => 'Please enter at least one source';

  @override
  String get digestDuration => 'Duration';

  @override
  String digestMinutes(int count) {
    return '$count min';
  }

  @override
  String digestHours(int count) {
    return '$count h';
  }

  @override
  String get presets => 'Presets';

  @override
  String get reset => 'Reset';

  @override
  String get feedTitle => 'Title';

  @override
  String get feedTitlePlaceholder => 'Give your feed a name';

  @override
  String get feedDescription => 'Description';

  @override
  String get feedDescriptionPlaceholder => 'Describe what this feed is about';

  @override
  String get feedFilters => 'Content Filters';

  @override
  String get filterDuplicates => 'Remove duplicates';

  @override
  String get filterAds => 'Filter ads';

  @override
  String get filterSpam => 'Remove spam';

  @override
  String get filterClickbait => 'No clickbait';

  @override
  String get feedTags => 'Tags';

  @override
  String get feedTagsPlaceholder => 'Add tags (up to 4)';

  @override
  String get feedTagsLimitError => 'Maximum 4 tags allowed';

  @override
  String get feedNotReady => 'Feed is not ready to create';

  @override
  String get feedCreatedSuccess => 'Feed created successfully!';

  @override
  String get digestsTab => 'Digests';

  @override
  String get feedsTab => 'Feeds';

  @override
  String get noDigestsTitle => 'No digests yet';

  @override
  String get noDigestsHint =>
      'Create a digest feed to combine multiple sources into a single summary';

  @override
  String get noRegularFeedsHint =>
      'Create a feed to receive individual posts from your favorite sources';

  @override
  String get linkTelegram => 'Link Telegram';

  @override
  String get telegramLinked => 'Telegram linked';

  @override
  String get linkTelegramSubtitle => 'Receive notifications in Telegram';

  @override
  String get linkTelegramLoading => 'Connecting...';

  @override
  String get linkTelegramError => 'Failed to get link. Please try again.';

  @override
  String get summarizeUnseenTitle => 'Summarize Unseen Posts?';

  @override
  String summarizeUnseenMessage(int count, String feedName) {
    return 'Create an AI digest from $count unseen posts in \"$feedName\". This will mark them as seen.';
  }

  @override
  String get summarizeUnseenConfirm => 'Create Digest';

  @override
  String get summarizeUnseenCancel => 'Cancel';

  @override
  String summarizeUnseenOverLimit(int count, int limit) {
    return 'Too many unread posts ($count). Maximum for digest is $limit. Read some posts to create a digest.';
  }

  @override
  String get summarizeStatusPreparing => 'Preparing digest...';

  @override
  String get summarizeStatusCollecting => 'Collecting posts...';

  @override
  String get summarizeStatusGenerating => 'Generating digest...';

  @override
  String get summarizeStatusReady => 'Digest ready!';

  @override
  String get summarizeStatusFailed => 'Failed to create digest';

  @override
  String get noMorePosts => 'No more posts';

  @override
  String get offlineMode => 'Offline - showing cached data';

  @override
  String get noPostsYet => 'No posts yet';

  @override
  String get noPostsYetDescription =>
      'Posts will appear here once they are generated for this feed.';

  @override
  String get onboardingStep1Title => 'Feeds';

  @override
  String get onboardingStep1Description =>
      'Your feeds live here, separate tabs for regular feeds and digests.';

  @override
  String get onboardingStep2Title => 'Create Feed';

  @override
  String get onboardingStep2Description =>
      'Build your personalized feed. Your content — your rules.';

  @override
  String get onboardingStep3Title => 'Edit Feeds';

  @override
  String get onboardingStep3Description =>
      'Customize and adjust your feeds anytime.';

  @override
  String get onboardingStep4Title => 'Settings';

  @override
  String get onboardingStep4Description =>
      'Profile, theme, app settings and everything else — here.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingFinish => 'Got it!';

  @override
  String get authErrorInvalidCredentials => 'Invalid email or password';

  @override
  String get authErrorEmailNotConfirmed =>
      'Please confirm your email before signing in';

  @override
  String get authErrorInvalidLoginData => 'Invalid login data';

  @override
  String get authErrorInvalidEmailFormat => 'Invalid email format';

  @override
  String get authErrorTooManyAttempts =>
      'Too many attempts. Please try again later';

  @override
  String get authErrorSignInFailed => 'Sign in failed';

  @override
  String get authErrorSignInError => 'Sign in error';

  @override
  String get authErrorEmailAlreadyRegistered => 'Email already registered';

  @override
  String get authErrorTooManySignUpAttempts =>
      'Too many sign up attempts. Please try again later';

  @override
  String get authErrorSignUpFailed => 'Sign up failed';

  @override
  String get authErrorSignUpError => 'Sign up error';

  @override
  String get authErrorPasswordTooShort =>
      'Password must be at least 8 characters';

  @override
  String get authErrorPasswordNeedsUppercase =>
      'Password must contain uppercase letters';

  @override
  String get authErrorPasswordNeedsLowercase =>
      'Password must contain lowercase letters';

  @override
  String get authErrorPasswordNeedsNumbers => 'Password must contain numbers';

  @override
  String get authErrorPasswordNeedsSpecialChars =>
      'Password must contain special characters';

  @override
  String get authErrorGoogleCancelled => 'Google sign in cancelled';

  @override
  String get authErrorGoogleFailed => 'Could not sign in with Google';

  @override
  String get authErrorGoogleNoIdToken => 'Could not get ID token from Google';

  @override
  String get authErrorGoogleError => 'Google sign in error';

  @override
  String get authErrorAppleCancelled => 'Apple sign in cancelled';

  @override
  String get authErrorAppleError => 'Apple sign in error';

  @override
  String get authErrorOAuthCancelled => 'Sign in cancelled';

  @override
  String get authErrorOAuthError => 'OAuth sign in error';

  @override
  String get authErrorOAuthTimeout => 'Sign in timed out';

  @override
  String get authErrorSessionRefreshFailed => 'Could not refresh session';

  @override
  String get authErrorSessionRefreshError => 'Session refresh error';

  @override
  String get authErrorPasswordResetFailed => 'Could not send password reset';

  @override
  String get authErrorPasswordResetError => 'Password reset error';

  @override
  String get authErrorPasswordUpdateFailed => 'Could not change password';

  @override
  String get authErrorPasswordUpdateError => 'Password change error';

  @override
  String get authErrorNoDataToUpdate => 'No data to update';

  @override
  String get authErrorProfileUpdateFailed => 'Could not update profile';

  @override
  String get authErrorProfileUpdateError => 'Profile update error';

  @override
  String get authErrorNotAuthenticated => 'User not authenticated';

  @override
  String get authErrorAccountDeleteFailed => 'Could not delete account';

  @override
  String get authErrorAccountDeleteError => 'Account deletion error';

  @override
  String get authErrorMagicLinkSendError => 'Could not send sign in link';

  @override
  String get authErrorMagicLinkError => 'Sign in link error';

  @override
  String get authErrorDemoLoginMissingToken => 'Server error: missing token';

  @override
  String get authErrorDemoLoginFailed => 'Demo login failed';

  @override
  String get authErrorDemoLoginConnectionError => 'Server connection error';

  @override
  String get authErrorUserNotFound => 'User not found';

  @override
  String get authErrorEmailConfirmationError =>
      'Could not send confirmation email';

  @override
  String get authErrorNetworkError => 'Network error. Check your connection';

  @override
  String get authErrorUnknownError => 'An unexpected error occurred';

  @override
  String get authMessageCheckEmailForConfirmation =>
      'Check your email to confirm registration';

  @override
  String get authMessagePasswordResetSent =>
      'Password reset instructions sent to your email';

  @override
  String get authMessagePasswordChanged => 'Password changed successfully';

  @override
  String get authMessageAccountDeleted => 'Account deleted';

  @override
  String get authMessageCheckEmailForLink =>
      'Check your email for the sign in link. It will arrive within a minute.';

  @override
  String get authMessageConfirmationEmailSent => 'Confirmation email sent';

  @override
  String get slideFeedTypeTitle => 'What feed to create?';

  @override
  String get slideFeedTypeSubtitle => 'Choose how posts are displayed';

  @override
  String get slideFeedTypeIndividualPosts => 'Individual\nposts';

  @override
  String get slideFeedTypeIndividualPostsDesc => 'Each post separately';

  @override
  String get slideFeedTypeDigest => 'Digest';

  @override
  String get slideFeedTypeDigestDesc => 'Combined into a summary';

  @override
  String get slideContentTitle => 'Where to get content?';

  @override
  String get slideContentSubtitle => 'Blogs, Telegram channels and RSS';

  @override
  String get slideContentSourceHint => '@channel or https://...';

  @override
  String get slideContentPopular => 'Popular:';

  @override
  String get slideConfigTitle => 'Content settings';

  @override
  String get slideConfigSubtitle => 'How to process and what to filter';

  @override
  String get slideConfigProcessingStyle => 'Processing style';

  @override
  String get slideConfigProcessingHint => 'How AI will process the news';

  @override
  String get slideConfigCustomStyle => 'Custom style...';

  @override
  String get slideConfigFilters => 'Filters';

  @override
  String get slideConfigFiltersHint => 'What to remove from the feed';

  @override
  String get slideConfigCustomFilter => 'Custom filter...';

  @override
  String get slideConfigAddCustom => 'Add custom';

  @override
  String get slideFinalizeTitle => 'Almost done!';

  @override
  String get slideFinalizeSubtitle => 'Review feed settings';

  @override
  String get slideFinalizeName => 'Name';

  @override
  String get slideFinalizeSummary => 'Summary';

  @override
  String get slideFinalizeSave => 'Save';

  @override
  String get slideFinalizeCreateFeed => 'Create feed';

  @override
  String get slideFinalizeNameHint => 'Give it a name';

  @override
  String get slideFinalizeType => 'Type';

  @override
  String get slideFinalizeIndividualPosts => 'Individual posts';

  @override
  String get slideFinalizeDigest => 'Digest';

  @override
  String get slideFinalizeFrequency => 'Frequency';

  @override
  String get slideFinalizeSources => 'Sources';

  @override
  String get slideFinalizeStyle => 'Style';

  @override
  String get slideFinalizeFilters => 'Filters';

  @override
  String get slideNext => 'Next';

  @override
  String get slideDone => 'Done';

  @override
  String get slideDigestFrequency => 'Digest frequency';

  @override
  String get slideDigestFrequencyHint => 'How often to collect news';

  @override
  String get slideDigestEveryHour => 'Every hour';

  @override
  String get slideDigestEvery3Hours => 'Every 3h';

  @override
  String get slideDigestEvery6Hours => 'Every 6h';

  @override
  String get slideDigestEvery12Hours => 'Every 12h';

  @override
  String get slideDigestDaily => 'Daily';

  @override
  String get slideDigestEvery2Days => 'Every 2 days';

  @override
  String get slideDigestCustom => 'Custom';

  @override
  String get slideDigestCancel => 'Cancel';

  @override
  String get slidePostsPreview => 'This is how posts will look';

  @override
  String get slideDailyDigest => 'Daily Digest';

  @override
  String get slidePostsCombined => '3 posts combined';

  @override
  String get aiStyleBrief => 'Brief';

  @override
  String get aiStyleEssence => 'Essence';

  @override
  String get aiStyleFull => 'Full';

  @override
  String get aiStyleCustom => 'Custom';

  @override
  String get aiStyleBriefDesc => '2-3 lines, just the main point';

  @override
  String get aiStyleEssenceDesc => 'Key facts and context';

  @override
  String get aiStyleFullDesc => 'Full text with details';

  @override
  String get aiStyleCustomDesc => 'Describe in your own words';

  @override
  String get aiStyleHowToDisplay => 'How to display?';

  @override
  String get aiStyleSwipeHint => 'Swipe to choose style';

  @override
  String get aiStyleCustomStyle => 'Custom style';

  @override
  String get aiStyleCustomProcessingStyle => 'Custom processing style';

  @override
  String get aiStyleSwipeRight => 'Swipe right';

  @override
  String get aiStyleCustomPlaceholder => 'E.g.: plain, facts only';

  @override
  String get aiStyleChipNoAds => 'no ads';

  @override
  String get aiStyleChipNumbersOnly => 'numbers only';

  @override
  String get aiStyleChipCasual => 'casual tone';

  @override
  String get aiStyleHowToProcess => 'How to process?';

  @override
  String get aiStyleAiAdaptsHint => 'AI will adapt text to your style';

  @override
  String get aiStylePreview => 'Preview';

  @override
  String get aiStyleEnterAbove => 'Enter your style above...';

  @override
  String get aiStylePreviewTitle => 'Apple unveiled M4';

  @override
  String get aiStylePreviewBrief =>
      'New chip is 50% faster. Launching in November.';

  @override
  String get aiStylePreviewEssence =>
      'The new M4 chip is 50% faster than its predecessor. Available in November in the MacBook Pro and iMac lineup.';

  @override
  String get aiStylePreviewFull =>
      'Apple announced the new M4 processor at a special event. The chip is 50% faster than the M3, features improved neural engine and support for 32 GB RAM. Launch is planned for November in the MacBook Pro, iMac, and Mac mini lineup.';

  @override
  String get feedEditTitle => 'Edit Feed';

  @override
  String get feedEditName => 'Name';

  @override
  String get feedEditNameHint => 'Feed name';

  @override
  String get feedEditSources => 'Sources';

  @override
  String get feedEditSchedule => 'Schedule';

  @override
  String get feedEditFilters => 'Filters';

  @override
  String get feedEditFilterHint => 'Filter...';

  @override
  String get feedEditSave => 'Save';

  @override
  String get feedEditFailedToLoad => 'Failed to load data';

  @override
  String get feedEditSourceAlreadyAdded => 'Source already added';

  @override
  String get feedEditNetworkError => 'Network error';

  @override
  String get feedEditNotFound => 'Not found';

  @override
  String get feedEditError => 'Error';

  @override
  String get feedEditFilterAlreadyExists => 'Filter already exists';

  @override
  String get feedEditEnterName => 'Enter a name';

  @override
  String get feedEditWaitForValidation => 'Wait for sources to be validated';

  @override
  String get feedEditAddSource => 'Add at least one source';

  @override
  String get feedEditFailedToSave => 'Failed to save';

  @override
  String get feedEditDeleteFeedTitle => 'Delete feed?';

  @override
  String feedEditDeleteFeedMessage(String name) {
    return 'Feed \"$name\" will be permanently deleted.';
  }

  @override
  String get feedEditFailedToDelete => 'Failed to delete';

  @override
  String get feedEditEveryHour => 'Every hour';

  @override
  String get feedEditEvery3Hours => 'Every 3 hours';

  @override
  String get feedEditEvery6Hours => 'Every 6 hours';

  @override
  String get feedEditEvery12Hours => 'Every 12 hours';

  @override
  String get feedEditOnceADay => 'Once a day';

  @override
  String get formSelectFeedType => 'Select feed type';

  @override
  String get formAddSource => 'Add at least one source';

  @override
  String get formWaitForValidation => 'Wait for sources to be validated';

  @override
  String get formAddValidSource => 'Add at least one valid source';

  @override
  String get formCreateFailed =>
      'Could not create feed. Check data and try again.';

  @override
  String get formAuthError => 'Authorization error. Please sign in again.';

  @override
  String get formLimitReached => 'Limit reached. Limited availability for now.';

  @override
  String get formSomethingWentWrong => 'Something went wrong. Try again later.';

  @override
  String get formServerError => 'Server error. Try again later.';

  @override
  String get formCreateError => 'Could not create feed. Try again later.';

  @override
  String get formNetworkError =>
      'Network error. Check your internet connection.';

  @override
  String get formUnexpectedError => 'Something went wrong. Try again later.';

  @override
  String get previewFilterMode => 'Filter';

  @override
  String get previewDigestMode => 'Summary';

  @override
  String get previewCommentsMode => 'Comments';

  @override
  String get previewReadMode => 'Read';

  @override
  String get previewDescription => 'DESCRIPTION';

  @override
  String get previewPrompt => 'PROMPT';

  @override
  String get previewUnknown => 'Unknown';

  @override
  String previewSourcesCount(int count) {
    return 'SOURCES ($count)';
  }

  @override
  String previewFiltersCount(int count) {
    return 'FILTERS ($count)';
  }

  @override
  String get previewSubscribing => 'Subscribing...';

  @override
  String get previewCreating => 'Creating...';

  @override
  String get previewSubscribe => 'Subscribe';

  @override
  String get previewCreateFeed => 'Create Feed';

  @override
  String get limitMoreFeaturesSoon => 'More features coming soon';

  @override
  String get limitGotIt => 'Got it';

  @override
  String get limitSourcesTitle => 'Sources limit';

  @override
  String get limitFiltersTitle => 'Filters limit';

  @override
  String get limitStylesTitle => 'Styles limit';

  @override
  String get limitFeedsTitle => 'Feeds limit';

  @override
  String limitSourcesMessage(int limit) {
    return 'Only $limit sources per feed are available for now.';
  }

  @override
  String limitFiltersMessage(int limit) {
    return 'Only $limit filters per feed are available for now.';
  }

  @override
  String limitStylesMessage(int limit) {
    return 'Only $limit styles per feed are available for now.';
  }

  @override
  String limitFeedsMessage(int limit) {
    return 'Only $limit feeds are available for now.';
  }

  @override
  String get feedSavedSuccess => 'Feed saved successfully!';

  @override
  String get addAtLeastOneSource => 'Add at least one source';

  @override
  String get myFeeds => 'My Feeds';

  @override
  String get loadingError => 'Failed to load';

  @override
  String get retryButton => 'Retry';

  @override
  String get noFeedsYet => 'No feeds yet';

  @override
  String get createFirstFeedHint =>
      'Create your first feed to get personalized news powered by AI.';

  @override
  String get createFeed => 'Create Feed';

  @override
  String get shareImage => 'Share image';

  @override
  String get shareImageFailed => 'Could not share image';

  @override
  String get saving => 'Saving...';

  @override
  String get imageSavedToGallery => 'Image saved to gallery';

  @override
  String get noPermissionToSave => 'No permission to save images';

  @override
  String get imageSaveError => 'Error saving image';

  @override
  String get cannotShare => 'Cannot share';

  @override
  String get noShareIdAvailable =>
      'This article has no identifier for sharing.';

  @override
  String couldNotOpenLink(String href) {
    return 'Could not open link: $href';
  }

  @override
  String get connectionError =>
      'Could not connect to server. Check your internet connection.';

  @override
  String get feedCreationSlow =>
      'Feed creation is taking longer than usual. Try refreshing later.';

  @override
  String get couldNotLoadNews => 'Could not load news';

  @override
  String get checkInternetConnection => 'Check your internet connection';

  @override
  String get tryAgainButton => 'Try again';

  @override
  String get unsafeUrl => 'Unsafe URL';

  @override
  String get unsafeUrlBlocked =>
      'An attempt to navigate to a dangerous URL was blocked';

  @override
  String get contentLoadFailed => 'Could not load content';

  @override
  String get videoBlockedForSafety => 'This video is blocked for your safety';

  @override
  String get closeButton => 'Close';

  @override
  String get loadingText => 'Loading...';

  @override
  String get videoUnsafeUrl => 'Unsafe URL';

  @override
  String get videoUnsafeMessage =>
      'This video cannot be opened for your safety';

  @override
  String get videoTitle => 'Video';

  @override
  String get urlEmpty => 'URL is empty';

  @override
  String get urlInvalidFormat => 'Invalid URL format';

  @override
  String urlDangerousProtocol(String scheme) {
    return 'Dangerous protocol: $scheme://';
  }

  @override
  String get urlOnlyHttpAllowed =>
      'Only https:// and http:// protocols are allowed';

  @override
  String get urlUnsafeVideoUnknownSource =>
      'This video is from an unknown source and uses an insecure connection (http://)';

  @override
  String get urlUnsafeVideoUnknown => 'This video is from an unknown source';

  @override
  String get feedBuilderStartCreating => 'Start creating';

  @override
  String get feedBuilderSession => 'Session';

  @override
  String get feedTypeIndividualPosts => 'Individual Posts';

  @override
  String get feedTypeDigestLabel => 'Digest';

  @override
  String get feedTypeIndividualPostsDesc => 'Each post is shown separately';

  @override
  String get feedTypeDigestLabelDesc => 'Posts are combined into a digest';

  @override
  String get configBriefSummary => 'Brief summary';

  @override
  String get configWithAnalysis => 'With analysis';

  @override
  String get configOriginal => 'Original';

  @override
  String get configKeyPointsOnly => 'Key points only';

  @override
  String get configRemoveDuplicates => 'Remove duplicates';

  @override
  String get configFilterAds => 'Filter ads';

  @override
  String get configRemoveSpam => 'Remove spam';

  @override
  String get configNoClickbait => 'No clickbait';

  @override
  String get feedNotFound => 'Feed not found';

  @override
  String get alreadySubscribed => 'Already subscribed';

  @override
  String get feedLoadError => 'Could not load feed';

  @override
  String get feedSubscribeError => 'Could not subscribe to feed';

  @override
  String get analyticsConsent => 'Analytics Tracking';

  @override
  String get analyticsConsentDescription =>
      'Help improve the app by sharing anonymous usage data';

  @override
  String get errorLoadingPosts => 'Failed to load posts';

  @override
  String get tapToRetry => 'Tap to retry';
}
