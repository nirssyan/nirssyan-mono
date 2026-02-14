import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get appTitle;

  /// Sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign up button text
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Registration page title
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registration;

  /// Sign in page subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToAccount;

  /// Sign up page subtitle
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get createNewAccount;

  /// Google sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// Apple sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInWithApple;

  /// Email sign in button text
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get signInWithMagicLink;

  /// Title for magic link sent dialog
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// Magic link sent confirmation message
  ///
  /// In en, this message translates to:
  /// **'We sent you a sign-in link'**
  String get magicLinkSent;

  /// Instructions for using magic link
  ///
  /// In en, this message translates to:
  /// **'Click the link in your email to sign in'**
  String get magicLinkDescription;

  /// Button text to send magic link
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get continueWithEmail;

  /// Placeholder for email input field
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmail;

  /// Confirmation message shown on magic link sent page
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a sign-in link to your email'**
  String get magicLinkSentToEmail;

  /// Instructions for completing magic link sign in
  ///
  /// In en, this message translates to:
  /// **'Click the link in the email to sign in to your account'**
  String get clickLinkToSignIn;

  /// Header for spam folder warning
  ///
  /// In en, this message translates to:
  /// **'Can\'t find the email?'**
  String get cantFindEmail;

  /// Reminder to check spam folder for magic link email
  ///
  /// In en, this message translates to:
  /// **'Check your spam or junk folder'**
  String get checkSpamFolder;

  /// Button text to resend magic link email
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// Countdown text for resend button cooldown
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendEmailIn(int seconds);

  /// Divider text between options
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// Email field placeholder
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field placeholder
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Confirm password field placeholder
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// Error message for empty fields
  ///
  /// In en, this message translates to:
  /// **'Fill all fields'**
  String get fillAllFields;

  /// Error message for invalid email
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// Error message for mismatched passwords
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Text for switching to sign up
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccount;

  /// Text for switching to sign in
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get haveAccount;

  /// Home tab title
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Search tab title
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Create tab title
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get chats;

  /// Profile tab title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// News section title
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get news;

  /// All categories filter
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Technology category
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get technology;

  /// AI category
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get ai;

  /// Science category
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get science;

  /// Space category
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get space;

  /// Ecology category
  ///
  /// In en, this message translates to:
  /// **'Ecology'**
  String get ecology;

  /// Minutes ago format
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minutesAgo(int minutes);

  /// Hours ago format
  ///
  /// In en, this message translates to:
  /// **'{hours} h ago'**
  String hoursAgo(int hours);

  /// Days ago format
  ///
  /// In en, this message translates to:
  /// **'{days} d ago'**
  String daysAgo(int days);

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @techCrunch.
  ///
  /// In en, this message translates to:
  /// **'TechCrunch'**
  String get techCrunch;

  /// No description provided for @appleNews.
  ///
  /// In en, this message translates to:
  /// **'Apple News'**
  String get appleNews;

  /// No description provided for @scienceToday.
  ///
  /// In en, this message translates to:
  /// **'Science Today'**
  String get scienceToday;

  /// No description provided for @aiWeekly.
  ///
  /// In en, this message translates to:
  /// **'AI Weekly'**
  String get aiWeekly;

  /// No description provided for @ecoNews.
  ///
  /// In en, this message translates to:
  /// **'EcoNews'**
  String get ecoNews;

  /// No description provided for @spaceExplorer.
  ///
  /// In en, this message translates to:
  /// **'Space Explorer'**
  String get spaceExplorer;

  /// No description provided for @searchPage.
  ///
  /// In en, this message translates to:
  /// **'Search Page'**
  String get searchPage;

  /// No description provided for @chatsPage.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get chatsPage;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// App icon selector title
  ///
  /// In en, this message translates to:
  /// **'App Icon'**
  String get appIcon;

  /// Dark app icon label
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkIcon;

  /// Light app icon label
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightIcon;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @zenMode.
  ///
  /// In en, this message translates to:
  /// **'Zen Mode'**
  String get zenMode;

  /// No description provided for @zenModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide unread counters'**
  String get zenModeDescription;

  /// No description provided for @zenModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get zenModeEnabled;

  /// No description provided for @zenModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get zenModeDisabled;

  /// No description provided for @zenModeEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Unread counters are hidden'**
  String get zenModeEnabledDescription;

  /// No description provided for @zenModeDisabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Unread counters are visible'**
  String get zenModeDisabledDescription;

  /// No description provided for @zenModeInfo.
  ///
  /// In en, this message translates to:
  /// **'When zen mode is enabled, all unread counters and badges will be hidden throughout the app. This helps you focus on content without distractions from notifications.'**
  String get zenModeInfo;

  /// No description provided for @viewSettings.
  ///
  /// In en, this message translates to:
  /// **'View Settings'**
  String get viewSettings;

  /// No description provided for @imagePreviews.
  ///
  /// In en, this message translates to:
  /// **'Image Previews'**
  String get imagePreviews;

  /// No description provided for @imagePreviewsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show image previews in news feed'**
  String get imagePreviewsDescription;

  /// No description provided for @imagePreviewsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get imagePreviewsEnabled;

  /// No description provided for @imagePreviewsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get imagePreviewsDisabled;

  /// No description provided for @imagePreviewsEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Image previews are visible'**
  String get imagePreviewsEnabledDescription;

  /// No description provided for @imagePreviewsDisabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Image previews are hidden'**
  String get imagePreviewsDisabledDescription;

  /// No description provided for @imagePreviewsInfo.
  ///
  /// In en, this message translates to:
  /// **'When disabled, news cards will not show image/video previews, making the feed more compact and text-focused.'**
  String get imagePreviewsInfo;

  /// No description provided for @defaultContent.
  ///
  /// In en, this message translates to:
  /// **'Default Content'**
  String get defaultContent;

  /// No description provided for @defaultContentDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose what to show first'**
  String get defaultContentDescription;

  /// No description provided for @summaryFirstDescription.
  ///
  /// In en, this message translates to:
  /// **'Brief summary shown first'**
  String get summaryFirstDescription;

  /// No description provided for @fullTextFirstDescription.
  ///
  /// In en, this message translates to:
  /// **'Full text shown first'**
  String get fullTextFirstDescription;

  /// No description provided for @defaultContentInfo.
  ///
  /// In en, this message translates to:
  /// **'This setting swaps the order of content tabs. Choose whether you want to see the brief summary or full text first when opening a news article.'**
  String get defaultContentInfo;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// DeepSeek AI chat title
  ///
  /// In en, this message translates to:
  /// **'DeepSeek AI'**
  String get deepseekChat;

  /// AI Assistant subtitle
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// Placeholder for starting AI conversation
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with AI'**
  String get startConversation;

  /// Message input placeholder
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// Feed is coming
  ///
  /// In en, this message translates to:
  /// **'Feed is coming...'**
  String get aiIsTyping;

  /// Typing indicator variation 1
  ///
  /// In en, this message translates to:
  /// **'Building your feed'**
  String get feedTyping1;

  /// Typing indicator variation 2
  ///
  /// In en, this message translates to:
  /// **'Feed incoming'**
  String get feedTyping2;

  /// Typing indicator variation 3
  ///
  /// In en, this message translates to:
  /// **'Curating content'**
  String get feedTyping3;

  /// Typing indicator variation 4
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get feedTyping4;

  /// Typing indicator variation 5
  ///
  /// In en, this message translates to:
  /// **'Creating magic'**
  String get feedTyping5;

  /// Typing indicator variation 6
  ///
  /// In en, this message translates to:
  /// **'Just a sec'**
  String get feedTyping6;

  /// Typing indicator variation 7
  ///
  /// In en, this message translates to:
  /// **'Getting ready'**
  String get feedTyping7;

  /// Typing indicator variation 8
  ///
  /// In en, this message translates to:
  /// **'On it'**
  String get feedTyping8;

  /// Typing indicator variation 9
  ///
  /// In en, this message translates to:
  /// **'Brewing your feed'**
  String get feedTyping9;

  /// Typing indicator variation 10
  ///
  /// In en, this message translates to:
  /// **'Loading up'**
  String get feedTyping10;

  /// Typing indicator subtext variation 1
  ///
  /// In en, this message translates to:
  /// **'Hang tight'**
  String get feedSubtext1;

  /// Typing indicator subtext variation 2
  ///
  /// In en, this message translates to:
  /// **'Finding gems'**
  String get feedSubtext2;

  /// Typing indicator subtext variation 3
  ///
  /// In en, this message translates to:
  /// **'One moment'**
  String get feedSubtext3;

  /// Typing indicator subtext variation 4
  ///
  /// In en, this message translates to:
  /// **'Personalizing'**
  String get feedSubtext4;

  /// Typing indicator subtext variation 5
  ///
  /// In en, this message translates to:
  /// **'Almost ready'**
  String get feedSubtext5;

  /// Typing indicator subtext variation 6
  ///
  /// In en, this message translates to:
  /// **'Sorting content'**
  String get feedSubtext6;

  /// Typing indicator subtext variation 7
  ///
  /// In en, this message translates to:
  /// **'Just for you'**
  String get feedSubtext7;

  /// Typing indicator subtext variation 8
  ///
  /// In en, this message translates to:
  /// **'Working on it'**
  String get feedSubtext8;

  /// Typing indicator subtext variation 9
  ///
  /// In en, this message translates to:
  /// **'Stay with us'**
  String get feedSubtext9;

  /// Typing indicator subtext variation 10
  ///
  /// In en, this message translates to:
  /// **'Nearly done'**
  String get feedSubtext10;

  /// Send message button accessibility label
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// Label for AI comment view in dynamic views selector
  ///
  /// In en, this message translates to:
  /// **'AI Comment'**
  String get viewComment;

  /// Header for content views section with sparkle icon
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get viewOverview;

  /// Contact us section title in profile
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUs;

  /// Email copied notification title
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get emailCopied;

  /// Email copied notification message
  ///
  /// In en, this message translates to:
  /// **'Email address copied to clipboard'**
  String get emailCopiedMessage;

  /// Title for feed management action sheet
  ///
  /// In en, this message translates to:
  /// **'Feed Management'**
  String get feedManagement;

  /// Action to rename a feed
  ///
  /// In en, this message translates to:
  /// **'Rename Feed'**
  String get renameFeed;

  /// Action to unsubscribe from a feed
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteFeed;

  /// Confirmation dialog title for feed deletion
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unsubscribe from this feed?'**
  String get confirmDeleteFeed;

  /// Confirmation dialog message for feed deletion
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All posts from this feed will be removed from your timeline.'**
  String get confirmDeleteFeedMessage;

  /// Delete action button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Rename action button
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Placeholder for new feed name input
  ///
  /// In en, this message translates to:
  /// **'Enter new feed name'**
  String get enterNewName;

  /// Error message when feed name is empty
  ///
  /// In en, this message translates to:
  /// **'Feed name is required'**
  String get feedNameRequired;

  /// Success message for feed rename
  ///
  /// In en, this message translates to:
  /// **'Feed renamed successfully'**
  String get feedRenamed;

  /// Success message for feed deletion
  ///
  /// In en, this message translates to:
  /// **'Unsubscribed from feed'**
  String get feedDeleted;

  /// Error message for feed rename failure
  ///
  /// In en, this message translates to:
  /// **'Error renaming feed'**
  String get errorRenamingFeed;

  /// Error message for feed deletion failure
  ///
  /// In en, this message translates to:
  /// **'Error unsubscribing from feed'**
  String get errorDeletingFeed;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Action to mark all posts in feed as read
  ///
  /// In en, this message translates to:
  /// **'Read All'**
  String get readAllPosts;

  /// Success message showing number of posts marked as read
  ///
  /// In en, this message translates to:
  /// **'Marked {count} posts as read'**
  String postsMarkedAsRead(int count);

  /// Error message when marking posts as read fails
  ///
  /// In en, this message translates to:
  /// **'Error marking posts as read'**
  String get errorMarkingPostsAsRead;

  /// A label that shows the number of sources for a news item.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{No sources} =1{{count} source} other{{count} sources}}'**
  String sourceCount(int count);

  /// Title for empty state when no feeds are available
  ///
  /// In en, this message translates to:
  /// **'No feeds yet'**
  String get noFeedsTitle;

  /// Subtitle for empty state when no feeds are available
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first feed'**
  String get noFeedsSubtitle;

  /// Description for empty state when no feeds are available
  ///
  /// In en, this message translates to:
  /// **'Add your favorite sources and get personalized content powered by AI.'**
  String get noFeedsDescription;

  /// Button text to navigate to create tab from empty feeds state
  ///
  /// In en, this message translates to:
  /// **'Go to Create'**
  String get goToChat;

  /// Title shown when feed is being generated
  ///
  /// In en, this message translates to:
  /// **'Your feed is on the way'**
  String get feedOnTheWay;

  /// Description shown when feed is loading
  ///
  /// In en, this message translates to:
  /// **'We\'re gathering the best news for you'**
  String get feedLoadingDescription;

  /// Alternative text shown when feed is being generated
  ///
  /// In en, this message translates to:
  /// **'Generating your feed just for you'**
  String get feedGenerating;

  /// Session label for individual session titles
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get chat;

  /// Placeholder text when no sessions exist
  ///
  /// In en, this message translates to:
  /// **'Start creating'**
  String get startAConversation;

  /// Accessibility label for new session button
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get newChat;

  /// Delete action title for swipe action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteChat;

  /// Delete session action in overlay
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSession;

  /// Confirmation dialog title for session deletion
  ///
  /// In en, this message translates to:
  /// **'Delete Session?'**
  String get confirmDeleteChat;

  /// Confirmation dialog message for session deletion
  ///
  /// In en, this message translates to:
  /// **'This session and all its messages will be permanently deleted.'**
  String get confirmDeleteChatMessage;

  /// Success message when session is deleted (legacy)
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get chatDeleted;

  /// Success message when session is deleted
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionDeleted;

  /// Error message when session list fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading sessions'**
  String get errorLoadingChats;

  /// Error message when session list fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading sessions'**
  String get errorLoadingSessions;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Error message when session creation fails (legacy)
  ///
  /// In en, this message translates to:
  /// **'Error creating session'**
  String get errorCreatingChat;

  /// Error message when session creation fails
  ///
  /// In en, this message translates to:
  /// **'Error creating session'**
  String get errorCreatingSession;

  /// Error message when session deletion fails (legacy)
  ///
  /// In en, this message translates to:
  /// **'Error deleting session'**
  String get errorDeletingChat;

  /// Error message when session deletion fails
  ///
  /// In en, this message translates to:
  /// **'Error deleting session'**
  String get errorDeletingSession;

  /// Yesterday label for relative time
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Forgot password link text
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Reset password dialog title
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Reset password dialog message
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you instructions to reset your password.'**
  String get enterEmailToReset;

  /// Send button text
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Success message after password reset email sent
  ///
  /// In en, this message translates to:
  /// **'Password reset instructions sent'**
  String get resetPasswordSuccess;

  /// Success message details after password reset email sent
  ///
  /// In en, this message translates to:
  /// **'Check your email for instructions to reset your password.'**
  String get resetPasswordSuccessMessage;

  /// Generic success title
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Success message after password change
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed successfully!'**
  String get passwordChangedSuccessfully;

  /// Title for reset password page
  ///
  /// In en, this message translates to:
  /// **'Create New Password'**
  String get createNewPassword;

  /// Subtitle for reset password page
  ///
  /// In en, this message translates to:
  /// **'Enter your new password below'**
  String get enterNewPasswordBelow;

  /// New password field placeholder
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// Password requirements hint text
  ///
  /// In en, this message translates to:
  /// **'Min. 8 characters, including uppercase, lowercase, numbers, and special characters'**
  String get passwordRequirements;

  /// Link to return from reset password to sign in
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Generic error title
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Title for the sources modal in news detail page
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesModalTitle;

  /// Feedback title
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// Send feedback button text
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// Feedback modal title
  ///
  /// In en, this message translates to:
  /// **'Share Your Feedback'**
  String get shareYourFeedback;

  /// Feedback button subtitle in profile
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts with us'**
  String get shareYourThoughts;

  /// Feedback modal subtitle
  ///
  /// In en, this message translates to:
  /// **'We\'d love to hear your thoughts, suggestions, or any issues you\'ve encountered'**
  String get feedbackSubtitle;

  /// Feedback text field placeholder
  ///
  /// In en, this message translates to:
  /// **'Ideas, bugs, feedback...'**
  String get feedbackPlaceholder;

  /// Loading text when sending feedback
  ///
  /// In en, this message translates to:
  /// **'Sending feedback...'**
  String get sendingFeedback;

  /// Feedback sent success title
  ///
  /// In en, this message translates to:
  /// **'Thank You!'**
  String get feedbackSent;

  /// Feedback sent success message
  ///
  /// In en, this message translates to:
  /// **'Your feedback has been received. We appreciate you taking the time to help us improve!'**
  String get feedbackSentMessage;

  /// Error title when feedback fails to send
  ///
  /// In en, this message translates to:
  /// **'Error Sending Feedback'**
  String get feedbackError;

  /// Error message when feedback is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter your feedback'**
  String get feedbackEmpty;

  /// Character counter format
  ///
  /// In en, this message translates to:
  /// **'{count} / {max} characters'**
  String characterLimit(int count, int max);

  /// Auto-dismiss indicator text
  ///
  /// In en, this message translates to:
  /// **'Closing automatically'**
  String get closingAutomatically;

  /// Title shown when app services are temporarily unavailable
  ///
  /// In en, this message translates to:
  /// **'The app is taking a break'**
  String get appTakingBreak;

  /// Description shown when app services are temporarily unavailable
  ///
  /// In en, this message translates to:
  /// **'We\'ll be back soon. Please try again later.'**
  String get appTakingBreakDescription;

  /// Subtitle for View Settings menu item in profile
  ///
  /// In en, this message translates to:
  /// **'Customize your news feed'**
  String get viewSettingsSubtitle;

  /// Subtitle on View Settings page
  ///
  /// In en, this message translates to:
  /// **'Customize your news feed appearance'**
  String get viewSettingsPageSubtitle;

  /// Title for profile details page
  ///
  /// In en, this message translates to:
  /// **'Profile Details'**
  String get profileDetails;

  /// Button text for deleting account
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Title for account deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountConfirmTitle;

  /// Warning message for account deletion
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated data. This cannot be undone.'**
  String get deleteAccountConfirmMessage;

  /// Confirmation button text
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Loading message during account deletion
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get deleteAccountProcessing;

  /// Success message after account deletion
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// Error message for account deletion failure
  ///
  /// In en, this message translates to:
  /// **'Error deleting account'**
  String get deleteAccountError;

  /// Wait timer message
  ///
  /// In en, this message translates to:
  /// **'Please wait {seconds}s...'**
  String pleaseWaitSeconds(int seconds);

  /// Section title for dangerous actions like account deletion
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// Section title for account information
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInfo;

  /// Terms and privacy agreement text
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our {terms} and {privacy}'**
  String agreeToTerms(String terms, String privacy);

  /// Terms of Service link text
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Privacy Policy link text
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Error message when user hasn't agreed to terms
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms and Privacy Policy to continue'**
  String get mustAgreeToTerms;

  /// Prefix text for terms agreement
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get agreeToTermsPrefix;

  /// Conjunction text between terms and privacy
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andText;

  /// Title for feed creator form
  ///
  /// In en, this message translates to:
  /// **'Create Feed'**
  String get feedCreatorTitle;

  /// Label for prompt input field
  ///
  /// In en, this message translates to:
  /// **'Display format'**
  String get promptLabel;

  /// Hint for prompt input field
  ///
  /// In en, this message translates to:
  /// **'What kind of content do you want?'**
  String get promptHint;

  /// Label for sources input field
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesLabel;

  /// Hint for sources input field
  ///
  /// In en, this message translates to:
  /// **'@channel1, @channel2, https://...'**
  String get sourcesHint;

  /// Label for feed type selection
  ///
  /// In en, this message translates to:
  /// **'Feed Type'**
  String get feedTypeLabel;

  /// Single post feed type option
  ///
  /// In en, this message translates to:
  /// **'Individual Posts'**
  String get singlePostType;

  /// Description for single post type
  ///
  /// In en, this message translates to:
  /// **'Each post is shown separately'**
  String get singlePostTypeDescription;

  /// Digest feed type option
  ///
  /// In en, this message translates to:
  /// **'Digest'**
  String get digestType;

  /// Description for digest type
  ///
  /// In en, this message translates to:
  /// **'Posts are combined into a digest'**
  String get digestTypeDescription;

  /// Create feed button text
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createFeedButton;

  /// Loading text when creating feed
  ///
  /// In en, this message translates to:
  /// **'Creating your feed...'**
  String get creatingFeed;

  /// Loading text when creating digest
  ///
  /// In en, this message translates to:
  /// **'Creating your digest...'**
  String get creatingDigest;

  /// Short status text for feed item being created
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get feedItemCreating;

  /// Loading text when waiting for first post via WebSocket
  ///
  /// In en, this message translates to:
  /// **'Waiting for first post'**
  String get waitingForFirstPost;

  /// Timeout error title
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get timeout;

  /// Error when prompt is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a prompt'**
  String get promptRequired;

  /// Error when sources are empty
  ///
  /// In en, this message translates to:
  /// **'Please enter at least one source'**
  String get sourcesRequired;

  /// Title for digest duration selector
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get digestDuration;

  /// Minutes format for digest duration
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String digestMinutes(int count);

  /// Hours format for digest duration
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String digestHours(int count);

  /// Label for preset durations section
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// Reset button text
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Label for feed title field
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get feedTitle;

  /// Placeholder for feed title field
  ///
  /// In en, this message translates to:
  /// **'Give your feed a name'**
  String get feedTitlePlaceholder;

  /// Label for feed description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get feedDescription;

  /// Placeholder for feed description field
  ///
  /// In en, this message translates to:
  /// **'Describe what this feed is about'**
  String get feedDescriptionPlaceholder;

  /// Label for filters section in feed edit
  ///
  /// In en, this message translates to:
  /// **'Content Filters'**
  String get feedFilters;

  /// Filter option: remove duplicate posts
  ///
  /// In en, this message translates to:
  /// **'Remove duplicates'**
  String get filterDuplicates;

  /// Filter option: filter advertising content
  ///
  /// In en, this message translates to:
  /// **'Filter ads'**
  String get filterAds;

  /// Filter option: remove spam content
  ///
  /// In en, this message translates to:
  /// **'Remove spam'**
  String get filterSpam;

  /// Filter option: filter clickbait content
  ///
  /// In en, this message translates to:
  /// **'No clickbait'**
  String get filterClickbait;

  /// Label for feed tags field
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get feedTags;

  /// Placeholder for feed tags field
  ///
  /// In en, this message translates to:
  /// **'Add tags (up to 4)'**
  String get feedTagsPlaceholder;

  /// Error message when more than 4 tags are added
  ///
  /// In en, this message translates to:
  /// **'Maximum 4 tags allowed'**
  String get feedTagsLimitError;

  /// Error message when feed cannot be created yet
  ///
  /// In en, this message translates to:
  /// **'Feed is not ready to create'**
  String get feedNotReady;

  /// Success message after feed creation
  ///
  /// In en, this message translates to:
  /// **'Feed created successfully!'**
  String get feedCreatedSuccess;

  /// Digests tab title in home page
  ///
  /// In en, this message translates to:
  /// **'Digests'**
  String get digestsTab;

  /// Feeds tab title in home page
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get feedsTab;

  /// Empty state title when no digest feeds exist
  ///
  /// In en, this message translates to:
  /// **'No digests yet'**
  String get noDigestsTitle;

  /// Empty state hint text for digests tab
  ///
  /// In en, this message translates to:
  /// **'Create a digest feed to combine multiple sources into a single summary'**
  String get noDigestsHint;

  /// Empty state hint text for feeds tab
  ///
  /// In en, this message translates to:
  /// **'Create a feed to receive individual posts from your favorite sources'**
  String get noRegularFeedsHint;

  /// Button to link Telegram account
  ///
  /// In en, this message translates to:
  /// **'Link Telegram'**
  String get linkTelegram;

  /// Title when Telegram is already linked
  ///
  /// In en, this message translates to:
  /// **'Telegram linked'**
  String get telegramLinked;

  /// Subtitle for link telegram button
  ///
  /// In en, this message translates to:
  /// **'Receive notifications in Telegram'**
  String get linkTelegramSubtitle;

  /// Loading text when linking telegram
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get linkTelegramLoading;

  /// Error message when telegram link fails
  ///
  /// In en, this message translates to:
  /// **'Failed to get link. Please try again.'**
  String get linkTelegramError;

  /// Title for summarize confirmation modal
  ///
  /// In en, this message translates to:
  /// **'Summarize Unseen Posts?'**
  String get summarizeUnseenTitle;

  /// Message for summarize confirmation modal
  ///
  /// In en, this message translates to:
  /// **'Create an AI digest from {count} unseen posts in \"{feedName}\". This will mark them as seen.'**
  String summarizeUnseenMessage(int count, String feedName);

  /// Confirm button for summarize modal
  ///
  /// In en, this message translates to:
  /// **'Create Digest'**
  String get summarizeUnseenConfirm;

  /// Cancel button for summarize modal
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get summarizeUnseenCancel;

  /// Message when unread posts exceed limit for digest
  ///
  /// In en, this message translates to:
  /// **'Too many unread posts ({count}). Maximum for digest is {limit}. Read some posts to create a digest.'**
  String summarizeUnseenOverLimit(int count, int limit);

  /// Status text while preparing summarization
  ///
  /// In en, this message translates to:
  /// **'Preparing digest...'**
  String get summarizeStatusPreparing;

  /// Status text while collecting posts for summarization
  ///
  /// In en, this message translates to:
  /// **'Collecting posts...'**
  String get summarizeStatusCollecting;

  /// Status text while AI generates the digest
  ///
  /// In en, this message translates to:
  /// **'Generating digest...'**
  String get summarizeStatusGenerating;

  /// Status text when digest is ready
  ///
  /// In en, this message translates to:
  /// **'Digest ready!'**
  String get summarizeStatusReady;

  /// Status text when digest creation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create digest'**
  String get summarizeStatusFailed;

  /// Text shown when all posts have been loaded
  ///
  /// In en, this message translates to:
  /// **'No more posts'**
  String get noMorePosts;

  /// Banner text shown when app is offline and using cached data
  ///
  /// In en, this message translates to:
  /// **'Offline - showing cached data'**
  String get offlineMode;

  /// Title shown when a feed has been created but has no posts
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// Description shown when a feed has been created but has no posts
  ///
  /// In en, this message translates to:
  /// **'Posts will appear here once they are generated for this feed.'**
  String get noPostsYetDescription;

  /// Title for onboarding step 1 - Home tab
  ///
  /// In en, this message translates to:
  /// **'Feeds'**
  String get onboardingStep1Title;

  /// Description for onboarding step 1
  ///
  /// In en, this message translates to:
  /// **'Your feeds live here, separate tabs for regular feeds and digests.'**
  String get onboardingStep1Description;

  /// Title for onboarding step 2 - Create tab
  ///
  /// In en, this message translates to:
  /// **'Create Feed'**
  String get onboardingStep2Title;

  /// Description for onboarding step 2
  ///
  /// In en, this message translates to:
  /// **'Build your personalized feed. Your content — your rules.'**
  String get onboardingStep2Description;

  /// Title for onboarding step 3 - Feeds tab
  ///
  /// In en, this message translates to:
  /// **'Edit Feeds'**
  String get onboardingStep3Title;

  /// Description for onboarding step 3
  ///
  /// In en, this message translates to:
  /// **'Customize and adjust your feeds anytime.'**
  String get onboardingStep3Description;

  /// Title for onboarding step 4 - Profile tab
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get onboardingStep4Title;

  /// Description for onboarding step 4
  ///
  /// In en, this message translates to:
  /// **'Profile, theme, app settings and everything else — here.'**
  String get onboardingStep4Description;

  /// Skip button text in onboarding
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Next button text in onboarding
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Finish button text in onboarding
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get onboardingFinish;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email before signing in'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorInvalidLoginData.
  ///
  /// In en, this message translates to:
  /// **'Invalid login data'**
  String get authErrorInvalidLoginData;

  /// No description provided for @authErrorInvalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get authErrorInvalidEmailFormat;

  /// No description provided for @authErrorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later'**
  String get authErrorTooManyAttempts;

  /// No description provided for @authErrorSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get authErrorSignInFailed;

  /// No description provided for @authErrorSignInError.
  ///
  /// In en, this message translates to:
  /// **'Sign in error'**
  String get authErrorSignInError;

  /// No description provided for @authErrorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Email already registered'**
  String get authErrorEmailAlreadyRegistered;

  /// No description provided for @authErrorTooManySignUpAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many sign up attempts. Please try again later'**
  String get authErrorTooManySignUpAttempts;

  /// No description provided for @authErrorSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed'**
  String get authErrorSignUpFailed;

  /// No description provided for @authErrorSignUpError.
  ///
  /// In en, this message translates to:
  /// **'Sign up error'**
  String get authErrorSignUpError;

  /// No description provided for @authErrorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authErrorPasswordTooShort;

  /// No description provided for @authErrorPasswordNeedsUppercase.
  ///
  /// In en, this message translates to:
  /// **'Password must contain uppercase letters'**
  String get authErrorPasswordNeedsUppercase;

  /// No description provided for @authErrorPasswordNeedsLowercase.
  ///
  /// In en, this message translates to:
  /// **'Password must contain lowercase letters'**
  String get authErrorPasswordNeedsLowercase;

  /// No description provided for @authErrorPasswordNeedsNumbers.
  ///
  /// In en, this message translates to:
  /// **'Password must contain numbers'**
  String get authErrorPasswordNeedsNumbers;

  /// No description provided for @authErrorPasswordNeedsSpecialChars.
  ///
  /// In en, this message translates to:
  /// **'Password must contain special characters'**
  String get authErrorPasswordNeedsSpecialChars;

  /// No description provided for @authErrorGoogleCancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign in cancelled'**
  String get authErrorGoogleCancelled;

  /// No description provided for @authErrorGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with Google'**
  String get authErrorGoogleFailed;

  /// No description provided for @authErrorGoogleNoIdToken.
  ///
  /// In en, this message translates to:
  /// **'Could not get ID token from Google'**
  String get authErrorGoogleNoIdToken;

  /// No description provided for @authErrorGoogleError.
  ///
  /// In en, this message translates to:
  /// **'Google sign in error'**
  String get authErrorGoogleError;

  /// No description provided for @authErrorAppleCancelled.
  ///
  /// In en, this message translates to:
  /// **'Apple sign in cancelled'**
  String get authErrorAppleCancelled;

  /// No description provided for @authErrorAppleError.
  ///
  /// In en, this message translates to:
  /// **'Apple sign in error'**
  String get authErrorAppleError;

  /// No description provided for @authErrorOAuthCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign in cancelled'**
  String get authErrorOAuthCancelled;

  /// No description provided for @authErrorOAuthError.
  ///
  /// In en, this message translates to:
  /// **'OAuth sign in error'**
  String get authErrorOAuthError;

  /// No description provided for @authErrorOAuthTimeout.
  ///
  /// In en, this message translates to:
  /// **'Sign in timed out'**
  String get authErrorOAuthTimeout;

  /// No description provided for @authErrorSessionRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh session'**
  String get authErrorSessionRefreshFailed;

  /// No description provided for @authErrorSessionRefreshError.
  ///
  /// In en, this message translates to:
  /// **'Session refresh error'**
  String get authErrorSessionRefreshError;

  /// No description provided for @authErrorPasswordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send password reset'**
  String get authErrorPasswordResetFailed;

  /// No description provided for @authErrorPasswordResetError.
  ///
  /// In en, this message translates to:
  /// **'Password reset error'**
  String get authErrorPasswordResetError;

  /// No description provided for @authErrorPasswordUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change password'**
  String get authErrorPasswordUpdateFailed;

  /// No description provided for @authErrorPasswordUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Password change error'**
  String get authErrorPasswordUpdateError;

  /// No description provided for @authErrorNoDataToUpdate.
  ///
  /// In en, this message translates to:
  /// **'No data to update'**
  String get authErrorNoDataToUpdate;

  /// No description provided for @authErrorProfileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update profile'**
  String get authErrorProfileUpdateFailed;

  /// No description provided for @authErrorProfileUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Profile update error'**
  String get authErrorProfileUpdateError;

  /// No description provided for @authErrorNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'User not authenticated'**
  String get authErrorNotAuthenticated;

  /// No description provided for @authErrorAccountDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account'**
  String get authErrorAccountDeleteFailed;

  /// No description provided for @authErrorAccountDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Account deletion error'**
  String get authErrorAccountDeleteError;

  /// No description provided for @authErrorMagicLinkSendError.
  ///
  /// In en, this message translates to:
  /// **'Could not send sign in link'**
  String get authErrorMagicLinkSendError;

  /// No description provided for @authErrorMagicLinkError.
  ///
  /// In en, this message translates to:
  /// **'Sign in link error'**
  String get authErrorMagicLinkError;

  /// No description provided for @authErrorDemoLoginMissingToken.
  ///
  /// In en, this message translates to:
  /// **'Server error: missing token'**
  String get authErrorDemoLoginMissingToken;

  /// No description provided for @authErrorDemoLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Demo login failed'**
  String get authErrorDemoLoginFailed;

  /// No description provided for @authErrorDemoLoginConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Server connection error'**
  String get authErrorDemoLoginConnectionError;

  /// No description provided for @authErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get authErrorUserNotFound;

  /// No description provided for @authErrorEmailConfirmationError.
  ///
  /// In en, this message translates to:
  /// **'Could not send confirmation email'**
  String get authErrorEmailConfirmationError;

  /// No description provided for @authErrorNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection'**
  String get authErrorNetworkError;

  /// No description provided for @authErrorUnknownError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get authErrorUnknownError;

  /// No description provided for @authMessageCheckEmailForConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm registration'**
  String get authMessageCheckEmailForConfirmation;

  /// No description provided for @authMessagePasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset instructions sent to your email'**
  String get authMessagePasswordResetSent;

  /// No description provided for @authMessagePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get authMessagePasswordChanged;

  /// No description provided for @authMessageAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get authMessageAccountDeleted;

  /// No description provided for @authMessageCheckEmailForLink.
  ///
  /// In en, this message translates to:
  /// **'Check your email for the sign in link. It will arrive within a minute.'**
  String get authMessageCheckEmailForLink;

  /// No description provided for @authMessageConfirmationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation email sent'**
  String get authMessageConfirmationEmailSent;

  /// No description provided for @slideFeedTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'What feed to create?'**
  String get slideFeedTypeTitle;

  /// No description provided for @slideFeedTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how posts are displayed'**
  String get slideFeedTypeSubtitle;

  /// No description provided for @slideFeedTypeIndividualPosts.
  ///
  /// In en, this message translates to:
  /// **'Individual\nposts'**
  String get slideFeedTypeIndividualPosts;

  /// No description provided for @slideFeedTypeIndividualPostsDesc.
  ///
  /// In en, this message translates to:
  /// **'Each post separately'**
  String get slideFeedTypeIndividualPostsDesc;

  /// No description provided for @slideFeedTypeDigest.
  ///
  /// In en, this message translates to:
  /// **'Digest'**
  String get slideFeedTypeDigest;

  /// No description provided for @slideFeedTypeDigestDesc.
  ///
  /// In en, this message translates to:
  /// **'Combined into a summary'**
  String get slideFeedTypeDigestDesc;

  /// No description provided for @slideContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to get content?'**
  String get slideContentTitle;

  /// No description provided for @slideContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blogs, Telegram channels and RSS'**
  String get slideContentSubtitle;

  /// No description provided for @slideContentSourceHint.
  ///
  /// In en, this message translates to:
  /// **'@channel or https://...'**
  String get slideContentSourceHint;

  /// No description provided for @slideContentPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular:'**
  String get slideContentPopular;

  /// No description provided for @slideConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Content settings'**
  String get slideConfigTitle;

  /// No description provided for @slideConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How to process and what to filter'**
  String get slideConfigSubtitle;

  /// No description provided for @slideConfigProcessingStyle.
  ///
  /// In en, this message translates to:
  /// **'Processing style'**
  String get slideConfigProcessingStyle;

  /// No description provided for @slideConfigProcessingHint.
  ///
  /// In en, this message translates to:
  /// **'How AI will process the news'**
  String get slideConfigProcessingHint;

  /// No description provided for @slideConfigCustomStyle.
  ///
  /// In en, this message translates to:
  /// **'Custom style...'**
  String get slideConfigCustomStyle;

  /// No description provided for @slideConfigFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get slideConfigFilters;

  /// No description provided for @slideConfigFiltersHint.
  ///
  /// In en, this message translates to:
  /// **'What to remove from the feed'**
  String get slideConfigFiltersHint;

  /// No description provided for @slideConfigCustomFilter.
  ///
  /// In en, this message translates to:
  /// **'Custom filter...'**
  String get slideConfigCustomFilter;

  /// No description provided for @slideConfigAddCustom.
  ///
  /// In en, this message translates to:
  /// **'Add custom'**
  String get slideConfigAddCustom;

  /// No description provided for @slideFinalizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Almost done!'**
  String get slideFinalizeTitle;

  /// No description provided for @slideFinalizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review feed settings'**
  String get slideFinalizeSubtitle;

  /// No description provided for @slideFinalizeName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get slideFinalizeName;

  /// No description provided for @slideFinalizeSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get slideFinalizeSummary;

  /// No description provided for @slideFinalizeSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get slideFinalizeSave;

  /// No description provided for @slideFinalizeCreateFeed.
  ///
  /// In en, this message translates to:
  /// **'Create feed'**
  String get slideFinalizeCreateFeed;

  /// No description provided for @slideFinalizeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Give it a name'**
  String get slideFinalizeNameHint;

  /// No description provided for @slideFinalizeType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get slideFinalizeType;

  /// No description provided for @slideFinalizeIndividualPosts.
  ///
  /// In en, this message translates to:
  /// **'Individual posts'**
  String get slideFinalizeIndividualPosts;

  /// No description provided for @slideFinalizeDigest.
  ///
  /// In en, this message translates to:
  /// **'Digest'**
  String get slideFinalizeDigest;

  /// No description provided for @slideFinalizeFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get slideFinalizeFrequency;

  /// No description provided for @slideFinalizeSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get slideFinalizeSources;

  /// No description provided for @slideFinalizeStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get slideFinalizeStyle;

  /// No description provided for @slideFinalizeFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get slideFinalizeFilters;

  /// No description provided for @slideNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get slideNext;

  /// No description provided for @slideDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get slideDone;

  /// No description provided for @slideDigestFrequency.
  ///
  /// In en, this message translates to:
  /// **'Digest frequency'**
  String get slideDigestFrequency;

  /// No description provided for @slideDigestFrequencyHint.
  ///
  /// In en, this message translates to:
  /// **'How often to collect news'**
  String get slideDigestFrequencyHint;

  /// No description provided for @slideDigestEveryHour.
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get slideDigestEveryHour;

  /// No description provided for @slideDigestEvery3Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 3h'**
  String get slideDigestEvery3Hours;

  /// No description provided for @slideDigestEvery6Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 6h'**
  String get slideDigestEvery6Hours;

  /// No description provided for @slideDigestEvery12Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 12h'**
  String get slideDigestEvery12Hours;

  /// No description provided for @slideDigestDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get slideDigestDaily;

  /// No description provided for @slideDigestEvery2Days.
  ///
  /// In en, this message translates to:
  /// **'Every 2 days'**
  String get slideDigestEvery2Days;

  /// No description provided for @slideDigestCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get slideDigestCustom;

  /// No description provided for @slideDigestCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get slideDigestCancel;

  /// No description provided for @slidePostsPreview.
  ///
  /// In en, this message translates to:
  /// **'This is how posts will look'**
  String get slidePostsPreview;

  /// No description provided for @slideDailyDigest.
  ///
  /// In en, this message translates to:
  /// **'Daily Digest'**
  String get slideDailyDigest;

  /// No description provided for @slidePostsCombined.
  ///
  /// In en, this message translates to:
  /// **'3 posts combined'**
  String get slidePostsCombined;

  /// No description provided for @aiStyleBrief.
  ///
  /// In en, this message translates to:
  /// **'Brief'**
  String get aiStyleBrief;

  /// No description provided for @aiStyleEssence.
  ///
  /// In en, this message translates to:
  /// **'Essence'**
  String get aiStyleEssence;

  /// No description provided for @aiStyleFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get aiStyleFull;

  /// No description provided for @aiStyleCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get aiStyleCustom;

  /// No description provided for @aiStyleBriefDesc.
  ///
  /// In en, this message translates to:
  /// **'2-3 lines, just the main point'**
  String get aiStyleBriefDesc;

  /// No description provided for @aiStyleEssenceDesc.
  ///
  /// In en, this message translates to:
  /// **'Key facts and context'**
  String get aiStyleEssenceDesc;

  /// No description provided for @aiStyleFullDesc.
  ///
  /// In en, this message translates to:
  /// **'Full text with details'**
  String get aiStyleFullDesc;

  /// No description provided for @aiStyleCustomDesc.
  ///
  /// In en, this message translates to:
  /// **'Describe in your own words'**
  String get aiStyleCustomDesc;

  /// No description provided for @aiStyleHowToDisplay.
  ///
  /// In en, this message translates to:
  /// **'How to display?'**
  String get aiStyleHowToDisplay;

  /// No description provided for @aiStyleSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe to choose style'**
  String get aiStyleSwipeHint;

  /// No description provided for @aiStyleCustomStyle.
  ///
  /// In en, this message translates to:
  /// **'Custom style'**
  String get aiStyleCustomStyle;

  /// No description provided for @aiStyleCustomProcessingStyle.
  ///
  /// In en, this message translates to:
  /// **'Custom processing style'**
  String get aiStyleCustomProcessingStyle;

  /// No description provided for @aiStyleSwipeRight.
  ///
  /// In en, this message translates to:
  /// **'Swipe right'**
  String get aiStyleSwipeRight;

  /// No description provided for @aiStyleCustomPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'E.g.: plain, facts only'**
  String get aiStyleCustomPlaceholder;

  /// No description provided for @aiStyleChipNoAds.
  ///
  /// In en, this message translates to:
  /// **'no ads'**
  String get aiStyleChipNoAds;

  /// No description provided for @aiStyleChipNumbersOnly.
  ///
  /// In en, this message translates to:
  /// **'numbers only'**
  String get aiStyleChipNumbersOnly;

  /// No description provided for @aiStyleChipCasual.
  ///
  /// In en, this message translates to:
  /// **'casual tone'**
  String get aiStyleChipCasual;

  /// No description provided for @aiStyleHowToProcess.
  ///
  /// In en, this message translates to:
  /// **'How to process?'**
  String get aiStyleHowToProcess;

  /// No description provided for @aiStyleAiAdaptsHint.
  ///
  /// In en, this message translates to:
  /// **'AI will adapt text to your style'**
  String get aiStyleAiAdaptsHint;

  /// No description provided for @aiStylePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get aiStylePreview;

  /// No description provided for @aiStyleEnterAbove.
  ///
  /// In en, this message translates to:
  /// **'Enter your style above...'**
  String get aiStyleEnterAbove;

  /// No description provided for @aiStylePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Apple unveiled M4'**
  String get aiStylePreviewTitle;

  /// No description provided for @aiStylePreviewBrief.
  ///
  /// In en, this message translates to:
  /// **'New chip is 50% faster. Launching in November.'**
  String get aiStylePreviewBrief;

  /// No description provided for @aiStylePreviewEssence.
  ///
  /// In en, this message translates to:
  /// **'The new M4 chip is 50% faster than its predecessor. Available in November in the MacBook Pro and iMac lineup.'**
  String get aiStylePreviewEssence;

  /// No description provided for @aiStylePreviewFull.
  ///
  /// In en, this message translates to:
  /// **'Apple announced the new M4 processor at a special event. The chip is 50% faster than the M3, features improved neural engine and support for 32 GB RAM. Launch is planned for November in the MacBook Pro, iMac, and Mac mini lineup.'**
  String get aiStylePreviewFull;

  /// No description provided for @feedEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Feed'**
  String get feedEditTitle;

  /// No description provided for @feedEditName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get feedEditName;

  /// No description provided for @feedEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'Feed name'**
  String get feedEditNameHint;

  /// No description provided for @feedEditSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get feedEditSources;

  /// No description provided for @feedEditSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get feedEditSchedule;

  /// No description provided for @feedEditFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get feedEditFilters;

  /// No description provided for @feedEditFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter...'**
  String get feedEditFilterHint;

  /// No description provided for @feedEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get feedEditSave;

  /// No description provided for @feedEditFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get feedEditFailedToLoad;

  /// No description provided for @feedEditSourceAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Source already added'**
  String get feedEditSourceAlreadyAdded;

  /// No description provided for @feedEditNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get feedEditNetworkError;

  /// No description provided for @feedEditNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get feedEditNotFound;

  /// No description provided for @feedEditError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get feedEditError;

  /// No description provided for @feedEditFilterAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Filter already exists'**
  String get feedEditFilterAlreadyExists;

  /// No description provided for @feedEditEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get feedEditEnterName;

  /// No description provided for @feedEditWaitForValidation.
  ///
  /// In en, this message translates to:
  /// **'Wait for sources to be validated'**
  String get feedEditWaitForValidation;

  /// No description provided for @feedEditAddSource.
  ///
  /// In en, this message translates to:
  /// **'Add at least one source'**
  String get feedEditAddSource;

  /// No description provided for @feedEditFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get feedEditFailedToSave;

  /// No description provided for @feedEditDeleteFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete feed?'**
  String get feedEditDeleteFeedTitle;

  /// No description provided for @feedEditDeleteFeedMessage.
  ///
  /// In en, this message translates to:
  /// **'Feed \"{name}\" will be permanently deleted.'**
  String feedEditDeleteFeedMessage(String name);

  /// No description provided for @feedEditFailedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get feedEditFailedToDelete;

  /// No description provided for @feedEditEveryHour.
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get feedEditEveryHour;

  /// No description provided for @feedEditEvery3Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 3 hours'**
  String get feedEditEvery3Hours;

  /// No description provided for @feedEditEvery6Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 6 hours'**
  String get feedEditEvery6Hours;

  /// No description provided for @feedEditEvery12Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 12 hours'**
  String get feedEditEvery12Hours;

  /// No description provided for @feedEditOnceADay.
  ///
  /// In en, this message translates to:
  /// **'Once a day'**
  String get feedEditOnceADay;

  /// No description provided for @formSelectFeedType.
  ///
  /// In en, this message translates to:
  /// **'Select feed type'**
  String get formSelectFeedType;

  /// No description provided for @formAddSource.
  ///
  /// In en, this message translates to:
  /// **'Add at least one source'**
  String get formAddSource;

  /// No description provided for @formWaitForValidation.
  ///
  /// In en, this message translates to:
  /// **'Wait for sources to be validated'**
  String get formWaitForValidation;

  /// No description provided for @formAddValidSource.
  ///
  /// In en, this message translates to:
  /// **'Add at least one valid source'**
  String get formAddValidSource;

  /// No description provided for @formCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create feed. Check data and try again.'**
  String get formCreateFailed;

  /// No description provided for @formAuthError.
  ///
  /// In en, this message translates to:
  /// **'Authorization error. Please sign in again.'**
  String get formAuthError;

  /// No description provided for @formLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Limit reached. Limited availability for now.'**
  String get formLimitReached;

  /// No description provided for @formSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again later.'**
  String get formSomethingWentWrong;

  /// No description provided for @formServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error. Try again later.'**
  String get formServerError;

  /// No description provided for @formCreateError.
  ///
  /// In en, this message translates to:
  /// **'Could not create feed. Try again later.'**
  String get formCreateError;

  /// No description provided for @formNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your internet connection.'**
  String get formNetworkError;

  /// No description provided for @formUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again later.'**
  String get formUnexpectedError;

  /// No description provided for @previewFilterMode.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get previewFilterMode;

  /// No description provided for @previewDigestMode.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get previewDigestMode;

  /// No description provided for @previewCommentsMode.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get previewCommentsMode;

  /// No description provided for @previewReadMode.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get previewReadMode;

  /// No description provided for @previewDescription.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get previewDescription;

  /// No description provided for @previewPrompt.
  ///
  /// In en, this message translates to:
  /// **'PROMPT'**
  String get previewPrompt;

  /// No description provided for @previewUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get previewUnknown;

  /// No description provided for @previewSourcesCount.
  ///
  /// In en, this message translates to:
  /// **'SOURCES ({count})'**
  String previewSourcesCount(int count);

  /// No description provided for @previewFiltersCount.
  ///
  /// In en, this message translates to:
  /// **'FILTERS ({count})'**
  String previewFiltersCount(int count);

  /// No description provided for @previewSubscribing.
  ///
  /// In en, this message translates to:
  /// **'Subscribing...'**
  String get previewSubscribing;

  /// No description provided for @previewCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get previewCreating;

  /// No description provided for @previewSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get previewSubscribe;

  /// No description provided for @previewCreateFeed.
  ///
  /// In en, this message translates to:
  /// **'Create Feed'**
  String get previewCreateFeed;

  /// No description provided for @limitMoreFeaturesSoon.
  ///
  /// In en, this message translates to:
  /// **'More features coming soon'**
  String get limitMoreFeaturesSoon;

  /// No description provided for @limitGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get limitGotIt;

  /// No description provided for @limitSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources limit'**
  String get limitSourcesTitle;

  /// No description provided for @limitFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters limit'**
  String get limitFiltersTitle;

  /// No description provided for @limitStylesTitle.
  ///
  /// In en, this message translates to:
  /// **'Styles limit'**
  String get limitStylesTitle;

  /// No description provided for @limitFeedsTitle.
  ///
  /// In en, this message translates to:
  /// **'Feeds limit'**
  String get limitFeedsTitle;

  /// No description provided for @limitSourcesMessage.
  ///
  /// In en, this message translates to:
  /// **'Only {limit} sources per feed are available for now.'**
  String limitSourcesMessage(int limit);

  /// No description provided for @limitFiltersMessage.
  ///
  /// In en, this message translates to:
  /// **'Only {limit} filters per feed are available for now.'**
  String limitFiltersMessage(int limit);

  /// No description provided for @limitStylesMessage.
  ///
  /// In en, this message translates to:
  /// **'Only {limit} styles per feed are available for now.'**
  String limitStylesMessage(int limit);

  /// No description provided for @limitFeedsMessage.
  ///
  /// In en, this message translates to:
  /// **'Only {limit} feeds are available for now.'**
  String limitFeedsMessage(int limit);

  /// No description provided for @feedSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Feed saved successfully!'**
  String get feedSavedSuccess;

  /// No description provided for @addAtLeastOneSource.
  ///
  /// In en, this message translates to:
  /// **'Add at least one source'**
  String get addAtLeastOneSource;

  /// No description provided for @myFeeds.
  ///
  /// In en, this message translates to:
  /// **'My Feeds'**
  String get myFeeds;

  /// No description provided for @loadingError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get loadingError;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @noFeedsYet.
  ///
  /// In en, this message translates to:
  /// **'No feeds yet'**
  String get noFeedsYet;

  /// No description provided for @createFirstFeedHint.
  ///
  /// In en, this message translates to:
  /// **'Create your first feed to get personalized news powered by AI.'**
  String get createFirstFeedHint;

  /// No description provided for @createFeed.
  ///
  /// In en, this message translates to:
  /// **'Create Feed'**
  String get createFeed;

  /// No description provided for @shareImage.
  ///
  /// In en, this message translates to:
  /// **'Share image'**
  String get shareImage;

  /// No description provided for @shareImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share image'**
  String get shareImageFailed;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @imageSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Image saved to gallery'**
  String get imageSavedToGallery;

  /// No description provided for @noPermissionToSave.
  ///
  /// In en, this message translates to:
  /// **'No permission to save images'**
  String get noPermissionToSave;

  /// No description provided for @imageSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving image'**
  String get imageSaveError;

  /// No description provided for @cannotShare.
  ///
  /// In en, this message translates to:
  /// **'Cannot share'**
  String get cannotShare;

  /// No description provided for @noShareIdAvailable.
  ///
  /// In en, this message translates to:
  /// **'This article has no identifier for sharing.'**
  String get noShareIdAvailable;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open link: {href}'**
  String couldNotOpenLink(String href);

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to server. Check your internet connection.'**
  String get connectionError;

  /// No description provided for @feedCreationSlow.
  ///
  /// In en, this message translates to:
  /// **'Feed creation is taking longer than usual. Try refreshing later.'**
  String get feedCreationSlow;

  /// No description provided for @couldNotLoadNews.
  ///
  /// In en, this message translates to:
  /// **'Could not load news'**
  String get couldNotLoadNews;

  /// No description provided for @checkInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection'**
  String get checkInternetConnection;

  /// No description provided for @tryAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgainButton;

  /// No description provided for @unsafeUrl.
  ///
  /// In en, this message translates to:
  /// **'Unsafe URL'**
  String get unsafeUrl;

  /// No description provided for @unsafeUrlBlocked.
  ///
  /// In en, this message translates to:
  /// **'An attempt to navigate to a dangerous URL was blocked'**
  String get unsafeUrlBlocked;

  /// No description provided for @contentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load content'**
  String get contentLoadFailed;

  /// No description provided for @videoBlockedForSafety.
  ///
  /// In en, this message translates to:
  /// **'This video is blocked for your safety'**
  String get videoBlockedForSafety;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @loadingText.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingText;

  /// No description provided for @videoUnsafeUrl.
  ///
  /// In en, this message translates to:
  /// **'Unsafe URL'**
  String get videoUnsafeUrl;

  /// No description provided for @videoUnsafeMessage.
  ///
  /// In en, this message translates to:
  /// **'This video cannot be opened for your safety'**
  String get videoUnsafeMessage;

  /// No description provided for @videoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoTitle;

  /// No description provided for @urlEmpty.
  ///
  /// In en, this message translates to:
  /// **'URL is empty'**
  String get urlEmpty;

  /// No description provided for @urlInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL format'**
  String get urlInvalidFormat;

  /// No description provided for @urlDangerousProtocol.
  ///
  /// In en, this message translates to:
  /// **'Dangerous protocol: {scheme}://'**
  String urlDangerousProtocol(String scheme);

  /// No description provided for @urlOnlyHttpAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only https:// and http:// protocols are allowed'**
  String get urlOnlyHttpAllowed;

  /// No description provided for @urlUnsafeVideoUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'This video is from an unknown source and uses an insecure connection (http://)'**
  String get urlUnsafeVideoUnknownSource;

  /// No description provided for @urlUnsafeVideoUnknown.
  ///
  /// In en, this message translates to:
  /// **'This video is from an unknown source'**
  String get urlUnsafeVideoUnknown;

  /// No description provided for @feedBuilderStartCreating.
  ///
  /// In en, this message translates to:
  /// **'Start creating'**
  String get feedBuilderStartCreating;

  /// No description provided for @feedBuilderSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get feedBuilderSession;

  /// No description provided for @feedTypeIndividualPosts.
  ///
  /// In en, this message translates to:
  /// **'Individual Posts'**
  String get feedTypeIndividualPosts;

  /// No description provided for @feedTypeDigestLabel.
  ///
  /// In en, this message translates to:
  /// **'Digest'**
  String get feedTypeDigestLabel;

  /// No description provided for @feedTypeIndividualPostsDesc.
  ///
  /// In en, this message translates to:
  /// **'Each post is shown separately'**
  String get feedTypeIndividualPostsDesc;

  /// No description provided for @feedTypeDigestLabelDesc.
  ///
  /// In en, this message translates to:
  /// **'Posts are combined into a digest'**
  String get feedTypeDigestLabelDesc;

  /// No description provided for @configBriefSummary.
  ///
  /// In en, this message translates to:
  /// **'Brief summary'**
  String get configBriefSummary;

  /// No description provided for @configWithAnalysis.
  ///
  /// In en, this message translates to:
  /// **'With analysis'**
  String get configWithAnalysis;

  /// No description provided for @configOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get configOriginal;

  /// No description provided for @configKeyPointsOnly.
  ///
  /// In en, this message translates to:
  /// **'Key points only'**
  String get configKeyPointsOnly;

  /// No description provided for @configRemoveDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Remove duplicates'**
  String get configRemoveDuplicates;

  /// No description provided for @configFilterAds.
  ///
  /// In en, this message translates to:
  /// **'Filter ads'**
  String get configFilterAds;

  /// No description provided for @configRemoveSpam.
  ///
  /// In en, this message translates to:
  /// **'Remove spam'**
  String get configRemoveSpam;

  /// No description provided for @configNoClickbait.
  ///
  /// In en, this message translates to:
  /// **'No clickbait'**
  String get configNoClickbait;

  /// Error message when feed from deep link is not found
  ///
  /// In en, this message translates to:
  /// **'Feed not found'**
  String get feedNotFound;

  /// Message when user is already subscribed to the feed
  ///
  /// In en, this message translates to:
  /// **'Already subscribed'**
  String get alreadySubscribed;

  /// Error message when feed preview fails to load from deep link
  ///
  /// In en, this message translates to:
  /// **'Could not load feed'**
  String get feedLoadError;

  /// Error message when feed subscription fails
  ///
  /// In en, this message translates to:
  /// **'Could not subscribe to feed'**
  String get feedSubscribeError;

  /// Toggle label for analytics consent in settings
  ///
  /// In en, this message translates to:
  /// **'Analytics Tracking'**
  String get analyticsConsent;

  /// Description for analytics consent toggle
  ///
  /// In en, this message translates to:
  /// **'Help improve the app by sharing anonymous usage data'**
  String get analyticsConsentDescription;

  /// Error message when posts fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load posts'**
  String get errorLoadingPosts;

  /// Button text to retry loading
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
