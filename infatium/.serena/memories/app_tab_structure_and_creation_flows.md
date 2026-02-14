# App Tab Structure and Creation Flows

## Main Tab Structure (MainTabScaffold)

The app has a 4-tab bottom navigation structure:

1. **Tab 0 - Home** (MyHomePage)
   - News feed display
   - Can navigate to Create tab

2. **Tab 1 - Create** (FeedBuilderTabPage)
   - Progressive feed creation form (ProgressiveFeedForm)
   - Creates feeds (single posts or digests) from sources
   - Uses slides for step-by-step creation flow

3. **Tab 2 - Feeds Manager** (FeedsManagerPage)
   - Manage subscribed feeds
   - Edit and delete feeds

4. **Tab 3 - Profile** (ProfilePage)
   - User settings and preferences

## FeedBuilderTabPage Structure (Tab 1 - The "Create" Tab)

### Main Component:
- **ProgressiveFeedForm** - 4-slide progressive form for creating feeds:
  - Slide 1: Feed type selection (SINGLE_POST or DIGEST) + frequency for digests
  - Slide 2: Sources input (Telegram channels, RSS feeds)
  - Slide 3: Configuration (AI views + filters)
  - Slide 4: Preview and create

## Feed Creation Flow

### Step 1: User navigates to Create tab
- Shows ProgressiveFeedForm
- User progresses through 4 slides

### Step 2: User fills out form
- Feed type selection
- Sources input with validation
- AI views and filters configuration
- Optional: title, description, tags

### Step 3: User submits form
- Calls `_handleFeedFormSubmit()` in FeedBuilderTabPageState
- Location: lib/pages/feed_builder_tab_page.dart:66-167

### Step 4: Feed Creation
- For new feeds: `FeedBuilderService.createFeedDirect()`
  - Single API call to POST /feeds/create
  - Returns feedId on success
- For editing existing feeds: `FeedBuilderService.updateExistingFeed()`
  - PATCH /feeds/{feedId}

### Step 5: Navigation After Creation
- Shows loading overlay on Home tab via NavigationService
- Waits for first post via WebSocket
- User sees their new feed on Home tab

## Key Files

- **lib/navigation/main_tab_scaffold.dart** - Main tab structure (4 tabs)
- **lib/pages/feed_builder_tab_page.dart** - Tab 1 with ProgressiveFeedForm
- **lib/pages/feed_builder_page.dart** - Legacy chat-style feed builder (FeedBuilderPage)
- **lib/pages/feed_builder_list_page.dart** - List of all sessions (FeedBuilderListPage)
- **lib/widgets/progressive_feed_form.dart** - 4-slide form for creating feeds
- **lib/widgets/feed_slides/*.dart** - Individual slide components

## Navigation Service Integration

MainTabScaffold exposes public methods:
- `navigateToHome()` - Switch to Tab 0
- `navigateToHomeWithRefresh()` - Switch to Tab 0 and refresh feeds
- `navigateToHomeWithPendingFeed()` - Show loading overlay while waiting for feed
- Uses `_onTabTapped()` to switch tabs

## State Management

FeedBuilderStateService maintains:
- `_activeSessionId` - currently selected session
- `_activeSession` - FeedBuilderSession object
- `_showingSessionList` - whether FeedBuilderListPage is shown
- All state is cached for persistence across tab switches

## Model Classes (lib/models/feed_builder_models.dart)

- **FeedBuilderSession** - Represents a feed creation session (formerly Chat)
- **FeedBuilderMessage** - Message in a session (formerly ChatMessage)
- **FeedPreview** - Preview data for a feed being created
- **FeedType** - Enum for SINGLE_POST or DIGEST
- **SourceItem** - Source URL with type info
