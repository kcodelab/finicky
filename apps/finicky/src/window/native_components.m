#import "native_components.h"

@interface RouteDraft : NSObject
@property(nonatomic, copy) NSString* routeID;
@property(nonatomic, copy) NSString* patterns;
@property(nonatomic, copy) NSString* browserName;
@property(nonatomic, copy) NSString* profile;
@end

@implementation RouteDraft
@end

@interface RoutePatternsTextView : NSTextView
@property(nonatomic, copy) NSString* routeID;
@end

@implementation RoutePatternsTextView
@end

@interface RouteButton : NSButton
@property(nonatomic, copy) NSString* routeID;
@end

@implementation RouteButton
@end

@interface RoutePopupButton : NSPopUpButton
@property(nonatomic, copy) NSString* routeID;
@end

@implementation RoutePopupButton
@end

@interface FinickyNativeTabContainerView ()
@property(nonatomic, strong) NSTabView* tabView;
@end

@implementation FinickyNativeTabContainerView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _tabView = [[NSTabView alloc] initWithFrame:self.bounds];
        _tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self addSubview:_tabView];
    }
    return self;
}

- (void)addTabWithIdentifier:(NSString*)identifier label:(NSString*)label view:(NSView*)view {
    NSTabViewItem* tab = [[NSTabViewItem alloc] initWithIdentifier:identifier];
    tab.label = label;
    tab.view = view;
    [self.tabView addTabViewItem:tab];
}

@end

@interface FinickyNativeICloudCardView ()
@property(nonatomic, strong) NSTextField* titleLabel;
@property(nonatomic, strong) NSTextField* subtitleLabel;
@property(nonatomic, strong) NSTextField* statusLabel;
@property(nonatomic, strong) NSTextField* configPathLabel;
@property(nonatomic, strong) NSTextField* cloudPathLabel;
@property(nonatomic, strong) NSTextField* resultLabel;
@property(nonatomic, strong) NSButton* actionButton;
@property(nonatomic, assign) BOOL enabled;
@property(nonatomic, assign) BOOL loading;
@end

@implementation FinickyNativeICloudCardView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSBox* card = [[NSBox alloc] initWithFrame:self.bounds];
        card.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        card.boxType = NSBoxCustom;
        card.borderType = NSLineBorder;
        card.borderColor = [NSColor separatorColor];
        card.cornerRadius = 12.0;
        card.fillColor = [NSColor controlBackgroundColor];
        card.contentViewMargins = NSMakeSize(14, 12);
        card.titlePosition = NSNoTitle;

        NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, self.bounds.size.width - 28, self.bounds.size.height - 24)];
        stack.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.spacing = 6;
        stack.alignment = NSLayoutAttributeLeading;

        _titleLabel = [NSTextField labelWithString:@"Cloud Sync (iCloud)"];
        _titleLabel.font = [NSFont boldSystemFontOfSize:13];
        [stack addArrangedSubview:_titleLabel];

        _subtitleLabel = [NSTextField labelWithString:@"Sync config via iCloud Drive across your Apple devices."];
        _subtitleLabel.textColor = [NSColor secondaryLabelColor];
        _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _subtitleLabel.usesSingleLineMode = NO;
        _subtitleLabel.maximumNumberOfLines = 2;
        [stack addArrangedSubview:_subtitleLabel];

        _statusLabel = [NSTextField labelWithString:@"Status: Loading..."];
        _statusLabel.textColor = [NSColor labelColor];
        [stack addArrangedSubview:_statusLabel];

        _configPathLabel = [NSTextField labelWithString:@""];
        _configPathLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
        _configPathLabel.textColor = [NSColor tertiaryLabelColor];
        _configPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [stack addArrangedSubview:_configPathLabel];

        _cloudPathLabel = [NSTextField labelWithString:@""];
        _cloudPathLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
        _cloudPathLabel.textColor = [NSColor tertiaryLabelColor];
        _cloudPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [stack addArrangedSubview:_cloudPathLabel];

        _resultLabel = [NSTextField labelWithString:@""];
        _resultLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _resultLabel.usesSingleLineMode = NO;
        _resultLabel.maximumNumberOfLines = 2;
        [stack addArrangedSubview:_resultLabel];

        _actionButton = [NSButton buttonWithTitle:@"Enable iCloud Sync" target:self action:@selector(onToggle:)];
        _actionButton.bezelStyle = NSBezelStyleRounded;
        [stack addArrangedSubview:_actionButton];

        card.contentView = stack;
        [self addSubview:card];
    }
    return self;
}

- (void)onToggle:(id)sender {
    if (self.onToggleRequested) {
        self.onToggleRequested();
    }
}

- (void)updateWithEnabled:(BOOL)enabled configPath:(NSString*)configPath cloudPath:(NSString*)cloudPath error:(NSString*)error {
    self.enabled = enabled;
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Status: %@", enabled ? @"Enabled" : @"Disabled"];
    self.configPathLabel.stringValue = configPath.length > 0 ? [NSString stringWithFormat:@"Config Path: %@", configPath] : @"";
    self.cloudPathLabel.stringValue = cloudPath.length > 0 ? [NSString stringWithFormat:@"iCloud Target: %@", cloudPath] : @"";
    if (error.length > 0) {
        self.resultLabel.stringValue = error;
        self.resultLabel.textColor = [NSColor systemRedColor];
    }
    [self refreshToggleButton];
}

- (void)updateResultMessage:(NSString*)message backupPath:(NSString*)backupPath error:(NSString*)error {
    if (error.length > 0) {
        self.resultLabel.stringValue = error;
        self.resultLabel.textColor = [NSColor systemRedColor];
        return;
    }

    NSMutableArray<NSString*>* lines = [[NSMutableArray alloc] init];
    if (message.length > 0) {
        [lines addObject:message];
    }
    if (backupPath.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"Backup: %@", backupPath]];
    }
    self.resultLabel.stringValue = [lines componentsJoinedByString:@"\n"];
    self.resultLabel.textColor = [NSColor secondaryLabelColor];
}

- (void)setToggleLoading:(BOOL)loading {
    self.loading = loading;
    [self refreshToggleButton];
}

- (void)refreshToggleButton {
    self.actionButton.enabled = !self.loading;
    if (self.loading) {
        self.actionButton.title = self.enabled ? @"Disabling..." : @"Enabling...";
    } else {
        self.actionButton.title = self.enabled ? @"Disable iCloud Sync" : @"Enable iCloud Sync";
    }
}

@end

@interface FinickyNativePreviewPanelView ()
@property(nonatomic, strong) NSTextView* textView;
@end

@implementation FinickyNativePreviewPanelView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSBox* card = [[NSBox alloc] initWithFrame:self.bounds];
        card.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        card.boxType = NSBoxCustom;
        card.borderType = NSLineBorder;
        card.borderColor = [NSColor separatorColor];
        card.cornerRadius = 12.0;
        card.fillColor = [NSColor controlBackgroundColor];
        card.contentViewMargins = NSMakeSize(12, 10);
        card.titlePosition = NSNoTitle;

        NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, self.bounds.size.width - 24, self.bounds.size.height - 20)];
        stack.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.spacing = 8;
        stack.alignment = NSLayoutAttributeLeading;

        NSTextField* title = [NSTextField labelWithString:@"Config Preview"];
        title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        [stack addArrangedSubview:title];

        NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, self.bounds.size.width - 24, self.bounds.size.height - 36)];
        scroll.hasVerticalScroller = YES;
        scroll.hasHorizontalScroller = YES;
        scroll.borderType = NSBezelBorder;

        _textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, self.bounds.size.width - 24, self.bounds.size.height - 36)];
        _textView.editable = NO;
        _textView.automaticQuoteSubstitutionEnabled = NO;
        _textView.font = [NSFont userFixedPitchFontOfSize:12];
        scroll.documentView = _textView;

        [stack addArrangedSubview:scroll];
        card.contentView = stack;
        [self addSubview:card];
    }
    return self;
}

- (void)setContent:(NSString*)content {
    self.textView.string = content ?: @"";
}

@end

@interface FinickyNativeConfigFormView () <NSTextViewDelegate>
@property(nonatomic, strong) NSPopUpButton* defaultBrowserPopup;
@property(nonatomic, strong) NSTextField* configPathLabel;
@property(nonatomic, strong) NSStackView* routeRowsContainer;
@property(nonatomic, strong) NSButton* formatButton;
@property(nonatomic, strong) NSButton* saveButton;
@property(nonatomic, strong) NSTextField* builderErrorLabel;
@property(nonatomic, strong) NSTextField* builderStatusLabel;
@property(nonatomic, strong) FinickyNativeICloudCardView* cloudCard;
@property(nonatomic, strong) FinickyNativePreviewPanelView* previewPanel;

@property(nonatomic, strong) NSArray* browserOptions;
@property(nonatomic, strong) NSArray* chromiumProfileGroups;
@property(nonatomic, strong) NSMutableArray<RouteDraft*>* routeDrafts;
@property(nonatomic, copy) NSString* selectedDefaultBrowser;
@end

@implementation FinickyNativeConfigFormView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _browserOptions = @[];
        _chromiumProfileGroups = @[];
        _routeDrafts = [[NSMutableArray alloc] init];
        _selectedDefaultBrowser = @"";

        NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:self.bounds];
        scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        scroll.hasVerticalScroller = YES;
        scroll.hasHorizontalScroller = NO;

        NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width, 1500)];
        content.autoresizingMask = NSViewWidthSizable;

        NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(20, 20, frameRect.size.width - 40, 1460)];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.spacing = 16;
        stack.alignment = NSLayoutAttributeLeading;
        stack.autoresizingMask = NSViewWidthSizable;

        NSTextField* title = [NSTextField labelWithString:@"Config Builder"];
        title.font = [NSFont boldSystemFontOfSize:22];
        [stack addArrangedSubview:title];

        NSTextField* subtitle = [NSTextField labelWithString:@"Create routing rules visually and generate a valid Finicky config file."];
        subtitle.textColor = [NSColor secondaryLabelColor];
        [stack addArrangedSubview:subtitle];

        NSBox* builderCard = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 56, 132)];
        builderCard.boxType = NSBoxCustom;
        builderCard.borderType = NSLineBorder;
        builderCard.borderColor = [NSColor separatorColor];
        builderCard.cornerRadius = 12.0;
        builderCard.fillColor = [NSColor controlBackgroundColor];
        builderCard.contentViewMargins = NSMakeSize(14, 12);
        builderCard.titlePosition = NSNoTitle;

        NSStackView* builderStack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 84, 106)];
        builderStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        builderStack.spacing = 8;
        builderStack.alignment = NSLayoutAttributeLeading;

        NSStackView* defaultRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        defaultRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        defaultRow.spacing = 12;

        NSTextField* defaultLabel = [NSTextField labelWithString:@"Default Browser:"];
        defaultLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
        [defaultRow addArrangedSubview:defaultLabel];

        _defaultBrowserPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 280, 26) pullsDown:NO];
        [_defaultBrowserPopup setTarget:self];
        [_defaultBrowserPopup setAction:@selector(onDefaultBrowserChanged:)];
        _defaultBrowserPopup.font = [NSFont systemFontOfSize:13];
        [defaultRow addArrangedSubview:_defaultBrowserPopup];
        [builderStack addArrangedSubview:defaultRow];

        _configPathLabel = [NSTextField labelWithString:@"Generated file path: (loading...)"];
        _configPathLabel.textColor = [NSColor tertiaryLabelColor];
        _configPathLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
        _configPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [builderStack addArrangedSubview:_configPathLabel];
        builderCard.contentView = builderStack;
        [stack addArrangedSubview:builderCard];

        _cloudCard = [[FinickyNativeICloudCardView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 56, 176)];
        __unsafe_unretained typeof(self) weakSelf = self;
        _cloudCard.onToggleRequested = ^{
            if (weakSelf.onICloudToggleRequested) {
                weakSelf.onICloudToggleRequested();
            }
        };
        [stack addArrangedSubview:_cloudCard];

        NSStackView* routeHeader = [[NSStackView alloc] initWithFrame:NSZeroRect];
        routeHeader.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        routeHeader.spacing = 12;

        NSTextField* routeTitle = [NSTextField labelWithString:@"Routes"];
        routeTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
        [routeHeader addArrangedSubview:routeTitle];

        NSButton* addRouteButton = [NSButton buttonWithTitle:@"Add Route" target:self action:@selector(onAddRoute:)];
        addRouteButton.bezelStyle = NSBezelStyleRounded;
        [routeHeader addArrangedSubview:addRouteButton];
        [stack addArrangedSubview:routeHeader];

        _routeRowsContainer = [[NSStackView alloc] initWithFrame:NSZeroRect];
        _routeRowsContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
        _routeRowsContainer.spacing = 12;
        [stack addArrangedSubview:_routeRowsContainer];

        NSStackView* actionRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        actionRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        actionRow.spacing = 10;

        _formatButton = [NSButton buttonWithTitle:@"Format" target:self action:@selector(onFormat:)];
        _formatButton.bezelStyle = NSBezelStyleRounded;
        _saveButton = [NSButton buttonWithTitle:@"Save and Activate" target:self action:@selector(onSave:)];
        _saveButton.bezelStyle = NSBezelStyleTexturedRounded;
        _saveButton.keyEquivalent = @"\r";

        [actionRow addArrangedSubview:_formatButton];
        [actionRow addArrangedSubview:_saveButton];
        [stack addArrangedSubview:actionRow];

        _builderErrorLabel = [NSTextField labelWithString:@""];
        _builderErrorLabel.textColor = [NSColor systemRedColor];
        [stack addArrangedSubview:_builderErrorLabel];

        _builderStatusLabel = [NSTextField labelWithString:@""];
        _builderStatusLabel.textColor = [NSColor systemGreenColor];
        [stack addArrangedSubview:_builderStatusLabel];

        _previewPanel = [[FinickyNativePreviewPanelView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 56, 360)];
        [stack addArrangedSubview:_previewPanel];

        [content addSubview:stack];
        scroll.documentView = content;
        [self addSubview:scroll];

        [self ensureAtLeastOneRoute];
        [self rebuildRouteRows];
    }
    return self;
}

- (void)updateICloudWithEnabled:(BOOL)enabled configPath:(NSString*)configPath cloudPath:(NSString*)cloudPath error:(NSString*)error {
    [self.cloudCard updateWithEnabled:enabled configPath:configPath cloudPath:cloudPath error:error];
}

- (void)setICloudToggleLoading:(BOOL)loading {
    [self.cloudCard setToggleLoading:loading];
}

- (void)setICloudResultMessage:(NSString*)message backupPath:(NSString*)backupPath error:(NSString*)error {
    [self.cloudCard updateResultMessage:message backupPath:backupPath error:error];
}

- (void)setBrowserOptions:(NSArray*)browserOptions {
    _browserOptions = [browserOptions isKindOfClass:[NSArray class]] ? browserOptions : @[];
    [self refreshDefaultBrowserPopup];
    [self rebuildRouteRows];
}

- (void)setChromiumProfileGroups:(NSArray*)profileGroups {
    _chromiumProfileGroups = [profileGroups isKindOfClass:[NSArray class]] ? profileGroups : @[];
    [self rebuildRouteRows];
}

- (void)setConfigPath:(NSString*)configPath {
    if (configPath.length > 0) {
        self.configPathLabel.stringValue = [NSString stringWithFormat:@"Generated file path: %@", configPath];
    } else {
        self.configPathLabel.stringValue = @"Generated file path: (will use default path)";
    }
}

- (void)applyDraft:(NSDictionary*)draft {
    if (![draft isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSString* defaultBrowser = draft[@"defaultBrowser"];
    if ([defaultBrowser isKindOfClass:[NSString class]]) {
        self.selectedDefaultBrowser = defaultBrowser;
    }

    [self.routeDrafts removeAllObjects];
    NSArray* routes = draft[@"routes"];
    if ([routes isKindOfClass:[NSArray class]]) {
        for (id routeObj in routes) {
            if (![routeObj isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            NSDictionary* routeDict = (NSDictionary*)routeObj;
            RouteDraft* route = [[RouteDraft alloc] init];
            route.routeID = [[NSUUID UUID] UUIDString];

            NSString* browser = routeDict[@"browser"];
            route.browserName = [browser isKindOfClass:[NSString class]] ? browser : @"";

            NSString* profile = routeDict[@"profile"];
            route.profile = [self resolveDraftProfileForBrowser:route.browserName profile:([profile isKindOfClass:[NSString class]] ? profile : @"")];

            NSArray* patterns = routeDict[@"patterns"];
            if ([patterns isKindOfClass:[NSArray class]]) {
                NSMutableArray<NSString*>* cleaned = [[NSMutableArray alloc] init];
                for (id pattern in patterns) {
                    if ([pattern isKindOfClass:[NSString class]]) {
                        [cleaned addObject:(NSString*)pattern];
                    }
                }
                route.patterns = [cleaned componentsJoinedByString:@", "];
            } else {
                route.patterns = @"";
            }

            [self.routeDrafts addObject:route];
        }
    }

    [self ensureAtLeastOneRoute];
    [self refreshDefaultBrowserPopup];
    [self rebuildRouteRows];
}

- (void)setBuilderError:(NSString*)errorText {
    self.builderErrorLabel.stringValue = errorText ?: @"";
}

- (void)setBuilderStatus:(NSString*)statusText {
    self.builderStatusLabel.stringValue = statusText ?: @"";
}

- (void)setPreviewLoading:(BOOL)loading {
    self.formatButton.enabled = !loading;
    self.formatButton.title = loading ? @"Formatting..." : @"Format";
}

- (void)setSaveLoading:(BOOL)loading {
    self.saveButton.enabled = !loading;
    self.saveButton.title = loading ? @"Saving..." : @"Save and Activate";
}

- (void)setPreviewContent:(NSString*)content {
    [self.previewPanel setContent:content ?: @""];
}

- (NSDictionary*)buildRequestPayloadWithError:(NSString*__autoreleasing*)errorMessage {
    self.builderErrorLabel.stringValue = @"";
    self.builderStatusLabel.stringValue = @"";

    NSString* defaultBrowser = self.defaultBrowserPopup.titleOfSelectedItem ?: @"";
    defaultBrowser = [defaultBrowser stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (defaultBrowser.length == 0 || [defaultBrowser isEqualToString:@"(No browsers found)"]) {
        NSString* msg = @"Default browser is required";
        if (errorMessage) {
            *errorMessage = msg;
        }
        return nil;
    }

    NSMutableArray* routes = [[NSMutableArray alloc] init];
    for (RouteDraft* route in self.routeDrafts) {
        NSString* browser = [route.browserName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSArray* patterns = [self sanitizePatterns:route.patterns ?: @""];
        if (browser.length == 0 || patterns.count == 0) {
            continue;
        }

        [routes addObject:@{
            @"patterns": patterns,
            @"browser": browser,
            @"profile": route.profile ?: @"",
        }];
    }

    if (routes.count == 0) {
        NSString* msg = @"Add at least one valid route rule";
        if (errorMessage) {
            *errorMessage = msg;
        }
        return nil;
    }

    return @{
        @"request": @{
            @"defaultBrowser": defaultBrowser,
            @"routes": routes,
        }
    };
}

- (void)onDefaultBrowserChanged:(id)sender {
    self.selectedDefaultBrowser = self.defaultBrowserPopup.titleOfSelectedItem ?: @"";
}

- (void)onAddRoute:(id)sender {
    RouteDraft* route = [[RouteDraft alloc] init];
    route.routeID = [[NSUUID UUID] UUIDString];
    route.patterns = @"";
    route.browserName = @"";
    route.profile = @"";
    [self.routeDrafts addObject:route];
    [self rebuildRouteRows];
}

- (void)onFormat:(id)sender {
    if (self.onFormatRequested) {
        self.onFormatRequested();
    }
}

- (void)onSave:(id)sender {
    if (self.onSaveRequested) {
        self.onSaveRequested();
    }
}

- (RouteDraft*)routeForID:(NSString*)routeID {
    for (RouteDraft* route in self.routeDrafts) {
        if ([route.routeID isEqualToString:routeID]) {
            return route;
        }
    }
    return nil;
}

- (void)ensureAtLeastOneRoute {
    if (self.routeDrafts.count > 0) {
        return;
    }

    RouteDraft* route = [[RouteDraft alloc] init];
    route.routeID = [[NSUUID UUID] UUIDString];
    route.patterns = @"";
    route.browserName = @"";
    route.profile = @"";
    [self.routeDrafts addObject:route];
}

- (BOOL)browserSupportsProfiles:(NSString*)browserName {
    for (id item in self.browserOptions) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString* name = item[@"appName"];
        if ([name isKindOfClass:[NSString class]] && [name isEqualToString:browserName]) {
            return [item[@"supportsProfiles"] boolValue];
        }
    }
    return NO;
}

- (NSArray*)profilesForBrowser:(NSString*)browserName {
    for (id item in self.chromiumProfileGroups) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString* appName = item[@"appName"];
        if ([appName isKindOfClass:[NSString class]] && [appName isEqualToString:browserName]) {
            NSArray* profiles = item[@"profiles"];
            if ([profiles isKindOfClass:[NSArray class]]) {
                return profiles;
            }
        }
    }
    return @[];
}

- (NSString*)resolveDraftProfileForBrowser:(NSString*)browserName profile:(NSString*)profile {
    NSString* rawProfile = [profile isKindOfClass:[NSString class]] ? profile : @"";
    if (rawProfile.length == 0) {
        return @"";
    }

    NSArray* profiles = [self profilesForBrowser:browserName];
    if (profiles.count == 0) {
        return rawProfile;
    }

    for (id item in profiles) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString* path = [item[@"path"] isKindOfClass:[NSString class]] ? item[@"path"] : @"";
        NSString* name = [item[@"name"] isKindOfClass:[NSString class]] ? item[@"name"] : @"";
        if ([path isEqualToString:rawProfile] || [name isEqualToString:rawProfile]) {
            return path.length > 0 ? path : rawProfile;
        }
    }

    return rawProfile;
}

- (void)clearRouteRowsView {
    NSArray* current = [self.routeRowsContainer.arrangedSubviews copy];
    for (NSView* view in current) {
        [self.routeRowsContainer removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

- (void)rebuildRouteRows {
    [self clearRouteRowsView];

    NSInteger rowIndex = 1;
    for (RouteDraft* route in self.routeDrafts) {
        NSBox* routeCard = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 860, 226)];
        routeCard.boxType = NSBoxCustom;
        routeCard.borderType = NSLineBorder;
        routeCard.borderColor = [NSColor separatorColor];
        routeCard.cornerRadius = 10.0;
        routeCard.fillColor = [NSColor controlBackgroundColor];
        routeCard.contentViewMargins = NSMakeSize(12, 10);
        routeCard.titlePosition = NSNoTitle;

        NSStackView* cardStack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 832, 202)];
        cardStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        cardStack.spacing = 9;
        cardStack.alignment = NSLayoutAttributeLeading;

        NSStackView* header = [[NSStackView alloc] initWithFrame:NSZeroRect];
        header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        header.spacing = 10;

        NSTextField* routeTitle = [NSTextField labelWithString:[NSString stringWithFormat:@"Route %ld", (long)rowIndex]];
        routeTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        [header addArrangedSubview:routeTitle];

        RouteButton* removeButton = [[RouteButton alloc] initWithFrame:NSMakeRect(0, 0, 76, 24)];
        removeButton.title = @"Remove";
        removeButton.bezelStyle = NSBezelStyleRounded;
        removeButton.target = self;
        removeButton.action = @selector(onRemoveRoute:);
        removeButton.routeID = route.routeID;
        [header addArrangedSubview:removeButton];
        [cardStack addArrangedSubview:header];

        NSTextField* patternsLabel = [NSTextField labelWithString:@"Website patterns (comma or newline separated)"];
        [cardStack addArrangedSubview:patternsLabel];

        NSScrollView* patternsScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 810, 72)];
        patternsScroll.hasVerticalScroller = YES;
        patternsScroll.borderType = NSBezelBorder;

        RoutePatternsTextView* patternsText = [[RoutePatternsTextView alloc] initWithFrame:NSMakeRect(0, 0, 810, 72)];
        patternsText.routeID = route.routeID;
        patternsText.delegate = self;
        patternsText.string = route.patterns ?: @"";
        patternsText.font = [NSFont systemFontOfSize:12];
        patternsText.automaticQuoteSubstitutionEnabled = NO;
        patternsScroll.documentView = patternsText;
        [cardStack addArrangedSubview:patternsScroll];

        NSStackView* browserRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        browserRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        browserRow.spacing = 10;

        [browserRow addArrangedSubview:[NSTextField labelWithString:@"Browser:"]];

        RoutePopupButton* browserPopup = [[RoutePopupButton alloc] initWithFrame:NSMakeRect(0, 0, 220, 26) pullsDown:NO];
        browserPopup.routeID = route.routeID;
        browserPopup.target = self;
        browserPopup.action = @selector(onRouteBrowserChanged:);

        [browserPopup addItemWithTitle:@"Select browser"];
        for (id item in self.browserOptions) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSString* appName = item[@"appName"];
                if ([appName isKindOfClass:[NSString class]]) {
                    [browserPopup addItemWithTitle:appName];
                }
            }
        }

        if (route.browserName.length > 0) {
            [browserPopup selectItemWithTitle:route.browserName];
        } else {
            [browserPopup selectItemAtIndex:0];
        }
        [browserRow addArrangedSubview:browserPopup];

        if ([self browserSupportsProfiles:route.browserName]) {
            [browserRow addArrangedSubview:[NSTextField labelWithString:@"Profile:"]];

            RoutePopupButton* profilePopup = [[RoutePopupButton alloc] initWithFrame:NSMakeRect(0, 0, 320, 26) pullsDown:NO];
            profilePopup.routeID = route.routeID;
            profilePopup.target = self;
            profilePopup.action = @selector(onRouteProfileChanged:);

            [profilePopup addItemWithTitle:@"No profile"];
            [[profilePopup lastItem] setRepresentedObject:@""];

            NSArray* profiles = [self profilesForBrowser:route.browserName];
            for (id p in profiles) {
                if (![p isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSString* name = p[@"name"];
                NSString* path = p[@"path"];
                if (![name isKindOfClass:[NSString class]] || ![path isKindOfClass:[NSString class]]) {
                    continue;
                }
                [profilePopup addItemWithTitle:[NSString stringWithFormat:@"%@ (%@)", name, path]];
                [[profilePopup lastItem] setRepresentedObject:path];
            }

            if (route.profile.length > 0) {
                BOOL selected = NO;
                for (NSMenuItem* item in profilePopup.itemArray) {
                    if ([[item.representedObject description] isEqualToString:route.profile]) {
                        [profilePopup selectItem:item];
                        selected = YES;
                        break;
                    }
                }
                if (!selected) {
                    [profilePopup selectItemAtIndex:0];
                }
            } else {
                [profilePopup selectItemAtIndex:0];
            }

            [browserRow addArrangedSubview:profilePopup];
        }

        [cardStack addArrangedSubview:browserRow];
        routeCard.contentView = cardStack;
        [self.routeRowsContainer addArrangedSubview:routeCard];
        rowIndex += 1;
    }
}

- (void)refreshDefaultBrowserPopup {
    [self.defaultBrowserPopup removeAllItems];

    NSMutableArray<NSString*>* names = [[NSMutableArray alloc] init];
    for (id item in self.browserOptions) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            NSString* appName = item[@"appName"];
            if ([appName isKindOfClass:[NSString class]]) {
                [names addObject:appName];
            }
        }
    }

    if (names.count == 0) {
        [self.defaultBrowserPopup addItemWithTitle:@"(No browsers found)"];
        return;
    }

    [self.defaultBrowserPopup addItemsWithTitles:names];
    if (self.selectedDefaultBrowser.length > 0 && [names containsObject:self.selectedDefaultBrowser]) {
        [self.defaultBrowserPopup selectItemWithTitle:self.selectedDefaultBrowser];
    } else {
        [self.defaultBrowserPopup selectItemAtIndex:0];
        self.selectedDefaultBrowser = self.defaultBrowserPopup.titleOfSelectedItem ?: @"";
    }
}

- (NSArray<NSString*>*)sanitizePatterns:(NSString*)raw {
    if (![raw isKindOfClass:[NSString class]]) {
        return @[];
    }

    NSMutableArray<NSString*>* results = [[NSMutableArray alloc] init];
    NSCharacterSet* separators = [NSCharacterSet characterSetWithCharactersInString:@",\n"];
    NSArray* chunks = [raw componentsSeparatedByCharactersInSet:separators];

    for (NSString* chunk in chunks) {
        NSString* value = [chunk stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value.length == 0) {
            continue;
        }

        if (([value hasPrefix:@"\""] && [value hasSuffix:@"\""]) || ([value hasPrefix:@"'"] && [value hasSuffix:@"'"])) {
            if (value.length >= 2) {
                value = [value substringWithRange:NSMakeRange(1, value.length - 2)];
                value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
        }

        if (value.length > 0) {
            [results addObject:value];
        }
    }

    return results;
}

- (void)onRemoveRoute:(RouteButton*)sender {
    NSString* routeID = sender.routeID;
    if (![routeID isKindOfClass:[NSString class]]) {
        return;
    }

    NSIndexSet* indexes = [self.routeDrafts indexesOfObjectsPassingTest:^BOOL(RouteDraft* route, NSUInteger idx, BOOL* stop) {
        return [route.routeID isEqualToString:routeID];
    }];
    if (indexes.count > 0) {
        [self.routeDrafts removeObjectsAtIndexes:indexes];
    }

    [self ensureAtLeastOneRoute];
    [self rebuildRouteRows];
}

- (void)onRouteBrowserChanged:(RoutePopupButton*)sender {
    RouteDraft* route = [self routeForID:sender.routeID];
    if (!route) {
        return;
    }

    NSString* selected = sender.titleOfSelectedItem ?: @"";
    if ([selected isEqualToString:@"Select browser"]) {
        selected = @"";
    }

    route.browserName = selected;
    route.profile = @"";

    if ([self browserSupportsProfiles:selected] && self.onRequestChromiumProfiles) {
        self.onRequestChromiumProfiles();
    }

    [self rebuildRouteRows];
}

- (void)onRouteProfileChanged:(RoutePopupButton*)sender {
    RouteDraft* route = [self routeForID:sender.routeID];
    if (!route) {
        return;
    }

    NSMenuItem* item = sender.selectedItem;
    route.profile = [[item representedObject] description] ?: @"";
}

- (void)textDidChange:(NSNotification*)notification {
    id obj = notification.object;
    if (![obj isKindOfClass:[RoutePatternsTextView class]]) {
        return;
    }

    RoutePatternsTextView* textView = (RoutePatternsTextView*)obj;
    RouteDraft* route = [self routeForID:textView.routeID];
    if (route) {
        route.patterns = textView.string ?: @"";
    }
}

@end

@interface FinickyNativeOverviewView ()
@property(nonatomic, strong) NSTextField* configPathLabel;
@property(nonatomic, strong) NSTextField* defaultBrowserLabel;
@property(nonatomic, strong) NSTextField* handlersLabel;
@property(nonatomic, strong) NSButton* keepRunningToggle;
@property(nonatomic, strong) NSButton* hideIconToggle;
@property(nonatomic, strong) NSButton* logRequestsToggle;
@property(nonatomic, strong) NSButton* checkForUpdatesToggle;
@property(nonatomic, strong) FinickyNativeICloudCardView* cloudCard;
@property(nonatomic, strong) NSTextField* updateLabel;
@property(nonatomic, strong) NSTextField* updateDetailsLabel;
@property(nonatomic, strong) NSButton* releaseNotesButton;
@property(nonatomic, strong) NSButton* downloadButton;
@property(nonatomic, copy) NSString* releaseNotesURL;
@property(nonatomic, copy) NSString* downloadURL;
@end

@implementation FinickyNativeOverviewView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:self.bounds];
        scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        scroll.hasVerticalScroller = YES;

        NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width, 980)];
        content.autoresizingMask = NSViewWidthSizable;

        NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(20, 20, frameRect.size.width - 40, 940)];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.spacing = 16;
        stack.alignment = NSLayoutAttributeLeading;
        stack.autoresizingMask = NSViewWidthSizable;

        NSTextField* title = [NSTextField labelWithString:@"Configuration"];
        title.font = [NSFont boldSystemFontOfSize:22];
        [stack addArrangedSubview:title];

        NSTextField* subtitle = [NSTextField labelWithString:@"Current settings from your configuration file."];
        subtitle.textColor = [NSColor secondaryLabelColor];
        [stack addArrangedSubview:subtitle];

        NSBox* configCard = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 56, 112)];
        configCard.boxType = NSBoxCustom;
        configCard.borderType = NSLineBorder;
        configCard.borderColor = [NSColor separatorColor];
        configCard.cornerRadius = 12.0;
        configCard.fillColor = [NSColor controlBackgroundColor];
        configCard.contentViewMargins = NSMakeSize(14, 12);
        configCard.titlePosition = NSNoTitle;

        NSStackView* configStack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 84, 88)];
        configStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        configStack.spacing = 6;
        configStack.alignment = NSLayoutAttributeLeading;

        _configPathLabel = [NSTextField labelWithString:@"Config Path: loading..."];
        _configPathLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
        _configPathLabel.textColor = [NSColor tertiaryLabelColor];
        _configPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [configStack addArrangedSubview:_configPathLabel];

        _defaultBrowserLabel = [NSTextField labelWithString:@"Default Browser: loading..."];
        [configStack addArrangedSubview:_defaultBrowserLabel];

        _handlersLabel = [NSTextField labelWithString:@"Handlers: loading..."];
        [configStack addArrangedSubview:_handlersLabel];
        configCard.contentView = configStack;
        [stack addArrangedSubview:configCard];

        NSBox* optionsCard = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 56, 188)];
        optionsCard.boxType = NSBoxCustom;
        optionsCard.borderType = NSLineBorder;
        optionsCard.borderColor = [NSColor separatorColor];
        optionsCard.cornerRadius = 12.0;
        optionsCard.fillColor = [NSColor controlBackgroundColor];
        optionsCard.contentViewMargins = NSMakeSize(14, 12);
        optionsCard.titlePosition = NSNoTitle;

        NSStackView* optionsStack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 84, 164)];
        optionsStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        optionsStack.spacing = 10;
        optionsStack.alignment = NSLayoutAttributeLeading;

        NSTextField* optionsTitle = [NSTextField labelWithString:@"Options"];
        optionsTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        [optionsStack addArrangedSubview:optionsTitle];

        _keepRunningToggle = [self buildReadOnlyToggleRow:@"Keep running" hint:@"App stays open in the background"];
        _hideIconToggle = [self buildReadOnlyToggleRow:@"Hide icon" hint:@"Hide menu bar icon"];
        _logRequestsToggle = [self buildReadOnlyToggleRow:@"Log requests" hint:@"Log all URL handling to file"];
        _checkForUpdatesToggle = [self buildReadOnlyToggleRow:@"Check for updates" hint:@"Automatically check for new versions"];
        [optionsStack addArrangedSubview:_keepRunningToggle.superview];
        [optionsStack addArrangedSubview:_hideIconToggle.superview];
        [optionsStack addArrangedSubview:_logRequestsToggle.superview];
        [optionsStack addArrangedSubview:_checkForUpdatesToggle.superview];
        optionsCard.contentView = optionsStack;
        [stack addArrangedSubview:optionsCard];

        _cloudCard = [[FinickyNativeICloudCardView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 56, 176)];
        __unsafe_unretained typeof(self) weakSelf = self;
        _cloudCard.onToggleRequested = ^{
            if (weakSelf.onICloudToggleRequested) {
                weakSelf.onICloudToggleRequested();
            }
        };
        [stack addArrangedSubview:_cloudCard];

        NSBox* updateCard = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 56, 124)];
        updateCard.boxType = NSBoxCustom;
        updateCard.borderType = NSLineBorder;
        updateCard.borderColor = [NSColor separatorColor];
        updateCard.cornerRadius = 12.0;
        updateCard.fillColor = [NSColor controlBackgroundColor];
        updateCard.contentViewMargins = NSMakeSize(14, 12);
        updateCard.titlePosition = NSNoTitle;

        NSStackView* updateStack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 84, 100)];
        updateStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        updateStack.spacing = 8;
        updateStack.alignment = NSLayoutAttributeLeading;

        _updateLabel = [NSTextField labelWithString:@"Update status: loading..."];
        _updateLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        [updateStack addArrangedSubview:_updateLabel];

        _updateDetailsLabel = [NSTextField labelWithString:@""];
        _updateDetailsLabel.textColor = [NSColor secondaryLabelColor];
        _updateDetailsLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _updateDetailsLabel.usesSingleLineMode = NO;
        _updateDetailsLabel.maximumNumberOfLines = 3;
        [updateStack addArrangedSubview:_updateDetailsLabel];

        NSStackView* updateActionRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        updateActionRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        updateActionRow.spacing = 10;

        _releaseNotesButton = [NSButton buttonWithTitle:@"Release Notes" target:self action:@selector(onReleaseNotes:)];
        _downloadButton = [NSButton buttonWithTitle:@"Download Latest" target:self action:@selector(onDownload:)];

        _releaseNotesButton.hidden = YES;
        _downloadButton.hidden = YES;

        [updateActionRow addArrangedSubview:_releaseNotesButton];
        [updateActionRow addArrangedSubview:_downloadButton];
        [updateStack addArrangedSubview:updateActionRow];

        updateCard.contentView = updateStack;
        [stack addArrangedSubview:updateCard];

        [content addSubview:stack];
        scroll.documentView = content;
        [self addSubview:scroll];
    }
    return self;
}

- (NSButton*)buildReadOnlyToggleRow:(NSString*)title hint:(NSString*)hint {
    NSStackView* row = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 720, 34)];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 8;

    NSStackView* textStack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 640, 34)];
    textStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    textStack.spacing = 1;
    textStack.alignment = NSLayoutAttributeLeading;

    NSTextField* titleLabel = [NSTextField labelWithString:title];
    titleLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    [textStack addArrangedSubview:titleLabel];

    NSTextField* hintLabel = [NSTextField labelWithString:hint];
    hintLabel.textColor = [NSColor secondaryLabelColor];
    hintLabel.font = [NSFont systemFontOfSize:11];
    [textStack addArrangedSubview:hintLabel];

    NSButton* toggle = [NSButton checkboxWithTitle:@"" target:nil action:nil];
    toggle.enabled = NO;
    toggle.allowsMixedState = NO;

    [row addArrangedSubview:textStack];
    [row addArrangedSubview:toggle];
    return toggle;
}

- (void)updateConfigWithMessage:(NSDictionary*)configMessage {
    if (![configMessage isKindOfClass:[NSDictionary class]]) {
        self.configPathLabel.stringValue = @"Config Path: not loaded";
        self.defaultBrowserLabel.stringValue = @"Default Browser: N/A";
        self.handlersLabel.stringValue = @"Handlers: 0";
        return;
    }

    NSString* configPath = [configMessage[@"configPath"] isKindOfClass:[NSString class]] ? configMessage[@"configPath"] : @"";
    NSString* defaultBrowser = [configMessage[@"defaultBrowser"] isKindOfClass:[NSString class]] ? configMessage[@"defaultBrowser"] : @"";
    NSNumber* handlers = [configMessage[@"handlers"] isKindOfClass:[NSNumber class]] ? configMessage[@"handlers"] : @(0);

    self.configPathLabel.stringValue = [NSString stringWithFormat:@"Config Path: %@", configPath.length > 0 ? configPath : @"Not Found"];
    self.defaultBrowserLabel.stringValue = [NSString stringWithFormat:@"Default Browser: %@", defaultBrowser.length > 0 ? defaultBrowser : @"N/A"];
    self.handlersLabel.stringValue = [NSString stringWithFormat:@"Handlers: %@", handlers];

    NSDictionary* options = [configMessage[@"options"] isKindOfClass:[NSDictionary class]] ? configMessage[@"options"] : @{};
    BOOL keepRunning = [options[@"keepRunning"] boolValue];
    BOOL hideIcon = [options[@"hideIcon"] boolValue];
    BOOL logRequests = [options[@"logRequests"] boolValue];
    BOOL checkForUpdates = [options[@"checkForUpdates"] boolValue];

    self.keepRunningToggle.state = keepRunning ? NSControlStateValueOn : NSControlStateValueOff;
    self.hideIconToggle.state = hideIcon ? NSControlStateValueOn : NSControlStateValueOff;
    self.logRequestsToggle.state = logRequests ? NSControlStateValueOn : NSControlStateValueOff;
    self.checkForUpdatesToggle.state = checkForUpdates ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)updateICloudEnabled:(BOOL)enabled configPath:(NSString*)configPath cloudPath:(NSString*)cloudPath error:(NSString*)error {
    [self.cloudCard updateWithEnabled:enabled configPath:configPath cloudPath:cloudPath error:error];
}

- (void)setICloudToggleLoading:(BOOL)loading {
    [self.cloudCard setToggleLoading:loading];
}

- (void)setICloudResultMessage:(NSString*)message backupPath:(NSString*)backupPath error:(NSString*)error {
    [self.cloudCard updateResultMessage:message backupPath:backupPath error:error];
}

- (void)updateUpdateInfo:(NSDictionary*)updateInfo {
    if (![updateInfo isKindOfClass:[NSDictionary class]]) {
        self.updateLabel.stringValue = @"Update status: unavailable";
        self.updateDetailsLabel.stringValue = @"Unable to fetch update information.";
        self.releaseNotesButton.hidden = YES;
        self.downloadButton.hidden = YES;
        return;
    }

    BOOL hasUpdate = [updateInfo[@"hasUpdate"] boolValue];
    BOOL enabled = [updateInfo[@"updateCheckEnabled"] boolValue];
    NSString* version = [updateInfo[@"version"] isKindOfClass:[NSString class]] ? updateInfo[@"version"] : @"";

    if (!enabled) {
        self.updateLabel.stringValue = @"Update check is disabled";
        self.updateDetailsLabel.stringValue = @"Enable checkForUpdates in your config to receive new release notices.";
        self.releaseNotesButton.hidden = YES;
        self.downloadButton.hidden = YES;
        return;
    }

    if (hasUpdate) {
        self.updateLabel.stringValue = [NSString stringWithFormat:@"New Version Available: %@", version.length > 0 ? version : @"Latest"];
        self.updateDetailsLabel.stringValue = @"A newer Finicky release is ready to download.";
        self.releaseNotesButton.hidden = NO;
        self.downloadButton.hidden = NO;
        self.releaseNotesURL = [updateInfo[@"releaseUrl"] isKindOfClass:[NSString class]] ? updateInfo[@"releaseUrl"] : @"";
        self.downloadURL = [updateInfo[@"downloadUrl"] isKindOfClass:[NSString class]] ? updateInfo[@"downloadUrl"] : @"";
    } else {
        self.updateLabel.stringValue = @"Update status: up to date";
        self.updateDetailsLabel.stringValue = @"You are running the latest available version.";
        self.releaseNotesButton.hidden = YES;
        self.downloadButton.hidden = YES;
        self.releaseNotesURL = @"";
        self.downloadURL = @"";
    }
}

- (void)onReleaseNotes:(id)sender {
    NSString* releaseURL = self.releaseNotesURL ?: @"";
    if (releaseURL.length > 0) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:releaseURL]];
    }
}

- (void)onDownload:(id)sender {
    NSString* downloadURL = self.downloadURL ?: @"";
    if (downloadURL.length > 0) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:downloadURL]];
    }
}

@end
