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
@property(nonatomic, strong) NSTextField* statusLabel;
@property(nonatomic, strong) NSButton* actionButton;
@end

@implementation FinickyNativeICloudCardView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSBox* card = [[NSBox alloc] initWithFrame:self.bounds];
        card.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        card.title = @"iCloud Sync";
        card.contentViewMargins = NSMakeSize(12, 10);

        NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, self.bounds.size.width - 24, self.bounds.size.height - 30)];

        _statusLabel = [NSTextField labelWithString:@"Status: loading..."];
        _statusLabel.frame = NSMakeRect(0, 30, self.bounds.size.width - 220, 20);

        _actionButton = [NSButton buttonWithTitle:@"Enable iCloud Sync" target:self action:@selector(onToggle:)];
        _actionButton.frame = NSMakeRect(0, 0, 180, 28);

        [content addSubview:_statusLabel];
        [content addSubview:_actionButton];
        card.contentView = content;

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
    NSMutableArray<NSString*>* lines = [[NSMutableArray alloc] init];
    [lines addObject:[NSString stringWithFormat:@"Status: %@", enabled ? @"Enabled" : @"Disabled"]];
    if (configPath.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"Config: %@", configPath]];
    }
    if (cloudPath.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"iCloud: %@", cloudPath]];
    }
    if (error.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"Error: %@", error]];
    }

    self.statusLabel.stringValue = [lines componentsJoinedByString:@" | "];
    self.actionButton.title = enabled ? @"Disable iCloud Sync" : @"Enable iCloud Sync";
}

@end

@interface FinickyNativePreviewPanelView ()
@property(nonatomic, strong) NSTextView* textView;
@end

@implementation FinickyNativePreviewPanelView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSStackView* stack = [[NSStackView alloc] initWithFrame:self.bounds];
        stack.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.spacing = 8;
        stack.alignment = NSLayoutAttributeLeading;

        NSTextField* title = [NSTextField labelWithString:@"Config Preview"];
        title.font = [NSFont boldSystemFontOfSize:14];
        [stack addArrangedSubview:title];

        NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height - 30)];
        scroll.hasVerticalScroller = YES;
        scroll.hasHorizontalScroller = YES;

        _textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height - 30)];
        _textView.editable = NO;
        _textView.automaticQuoteSubstitutionEnabled = NO;
        _textView.font = [NSFont userFixedPitchFontOfSize:12];
        scroll.documentView = _textView;

        [stack addArrangedSubview:scroll];
        [self addSubview:stack];
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

        NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width, 1200)];
        content.autoresizingMask = NSViewWidthSizable;

        NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(20, 20, frameRect.size.width - 40, 1140)];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.spacing = 12;
        stack.alignment = NSLayoutAttributeLeading;
        stack.autoresizingMask = NSViewWidthSizable;

        NSTextField* title = [NSTextField labelWithString:@"Config Builder (Native)"];
        title.font = [NSFont boldSystemFontOfSize:20];
        [stack addArrangedSubview:title];

        _configPathLabel = [NSTextField labelWithString:@"Generated file path: (loading...)"];
        _configPathLabel.textColor = [NSColor secondaryLabelColor];
        [stack addArrangedSubview:_configPathLabel];

        NSStackView* defaultRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        defaultRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        defaultRow.spacing = 10;

        NSTextField* defaultLabel = [NSTextField labelWithString:@"Default Browser:"];
        [defaultRow addArrangedSubview:defaultLabel];

        _defaultBrowserPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 280, 26) pullsDown:NO];
        [_defaultBrowserPopup setTarget:self];
        [_defaultBrowserPopup setAction:@selector(onDefaultBrowserChanged:)];
        [defaultRow addArrangedSubview:_defaultBrowserPopup];
        [stack addArrangedSubview:defaultRow];

        _cloudCard = [[FinickyNativeICloudCardView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 40, 80)];
        __unsafe_unretained typeof(self) weakSelf = self;
        _cloudCard.onToggleRequested = ^{
            if (weakSelf.onICloudToggleRequested) {
                weakSelf.onICloudToggleRequested();
            }
        };
        [stack addArrangedSubview:_cloudCard];

        NSStackView* routeHeader = [[NSStackView alloc] initWithFrame:NSZeroRect];
        routeHeader.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        routeHeader.spacing = 10;

        NSTextField* routeTitle = [NSTextField labelWithString:@"Routes"];
        routeTitle.font = [NSFont boldSystemFontOfSize:14];
        [routeHeader addArrangedSubview:routeTitle];

        NSButton* addRouteButton = [NSButton buttonWithTitle:@"Add Route" target:self action:@selector(onAddRoute:)];
        [routeHeader addArrangedSubview:addRouteButton];
        [stack addArrangedSubview:routeHeader];

        _routeRowsContainer = [[NSStackView alloc] initWithFrame:NSZeroRect];
        _routeRowsContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
        _routeRowsContainer.spacing = 10;
        [stack addArrangedSubview:_routeRowsContainer];

        NSStackView* actionRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        actionRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        actionRow.spacing = 10;

        _formatButton = [NSButton buttonWithTitle:@"Format" target:self action:@selector(onFormat:)];
        _saveButton = [NSButton buttonWithTitle:@"Save and Activate" target:self action:@selector(onSave:)];
        _saveButton.bezelColor = [NSColor controlAccentColor];

        [actionRow addArrangedSubview:_formatButton];
        [actionRow addArrangedSubview:_saveButton];
        [stack addArrangedSubview:actionRow];

        _builderErrorLabel = [NSTextField labelWithString:@""];
        _builderErrorLabel.textColor = [NSColor systemRedColor];
        [stack addArrangedSubview:_builderErrorLabel];

        _builderStatusLabel = [NSTextField labelWithString:@""];
        _builderStatusLabel.textColor = [NSColor systemGreenColor];
        [stack addArrangedSubview:_builderStatusLabel];

        _previewPanel = [[FinickyNativePreviewPanelView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 60, 320)];
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

- (void)setBrowserOptions:(NSArray*)browserOptions {
    self.browserOptions = [browserOptions isKindOfClass:[NSArray class]] ? browserOptions : @[];
    [self refreshDefaultBrowserPopup];
    [self rebuildRouteRows];
}

- (void)setChromiumProfileGroups:(NSArray*)profileGroups {
    self.chromiumProfileGroups = [profileGroups isKindOfClass:[NSArray class]] ? profileGroups : @[];
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
            route.profile = [profile isKindOfClass:[NSString class]] ? profile : @"";

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
        NSBox* routeCard = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 860, 210)];
        routeCard.contentViewMargins = NSMakeSize(12, 10);

        NSStackView* cardStack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 820, 190)];
        cardStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        cardStack.spacing = 8;
        cardStack.alignment = NSLayoutAttributeLeading;

        NSStackView* header = [[NSStackView alloc] initWithFrame:NSZeroRect];
        header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        header.spacing = 10;

        NSTextField* routeTitle = [NSTextField labelWithString:[NSString stringWithFormat:@"Route %ld", (long)rowIndex]];
        routeTitle.font = [NSFont boldSystemFontOfSize:13];
        [header addArrangedSubview:routeTitle];

        RouteButton* removeButton = [[RouteButton alloc] initWithFrame:NSMakeRect(0, 0, 76, 24)];
        removeButton.title = @"Remove";
        removeButton.target = self;
        removeButton.action = @selector(onRemoveRoute:);
        removeButton.routeID = route.routeID;
        [header addArrangedSubview:removeButton];
        [cardStack addArrangedSubview:header];

        NSTextField* patternsLabel = [NSTextField labelWithString:@"Website patterns (comma or newline separated)"];
        [cardStack addArrangedSubview:patternsLabel];

        NSScrollView* patternsScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 800, 64)];
        patternsScroll.hasVerticalScroller = YES;

        RoutePatternsTextView* patternsText = [[RoutePatternsTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, 64)];
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

        RoutePopupButton* browserPopup = [[RoutePopupButton alloc] initWithFrame:NSMakeRect(0, 0, 220, 24) pullsDown:NO];
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

            RoutePopupButton* profilePopup = [[RoutePopupButton alloc] initWithFrame:NSMakeRect(0, 0, 320, 24) pullsDown:NO];
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
@property(nonatomic, strong) NSTextField* configStateLabel;
@property(nonatomic, strong) NSTextField* optionsLabel;
@property(nonatomic, strong) FinickyNativeICloudCardView* cloudCard;
@property(nonatomic, strong) NSTextField* updateLabel;
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

        NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width, 700)];
        content.autoresizingMask = NSViewWidthSizable;

        NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(20, 20, frameRect.size.width - 40, 640)];
        stack.orientation = NSUserInterfaceLayoutOrientationVertical;
        stack.spacing = 12;
        stack.alignment = NSLayoutAttributeLeading;
        stack.autoresizingMask = NSViewWidthSizable;

        NSTextField* title = [NSTextField labelWithString:@"Overview (Native)"];
        title.font = [NSFont boldSystemFontOfSize:20];
        [stack addArrangedSubview:title];

        _configStateLabel = [NSTextField labelWithString:@"Config: loading..."];
        [stack addArrangedSubview:_configStateLabel];

        _optionsLabel = [NSTextField labelWithString:@"Options: loading..."];
        _optionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _optionsLabel.usesSingleLineMode = NO;
        _optionsLabel.maximumNumberOfLines = 3;
        [stack addArrangedSubview:_optionsLabel];

        _cloudCard = [[FinickyNativeICloudCardView alloc] initWithFrame:NSMakeRect(0, 0, frameRect.size.width - 40, 80)];
        __unsafe_unretained typeof(self) weakSelf = self;
        _cloudCard.onToggleRequested = ^{
            if (weakSelf.onICloudToggleRequested) {
                weakSelf.onICloudToggleRequested();
            }
        };
        [stack addArrangedSubview:_cloudCard];

        _updateLabel = [NSTextField labelWithString:@"Update status: loading..."];
        _updateLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _updateLabel.usesSingleLineMode = NO;
        _updateLabel.maximumNumberOfLines = 4;
        [stack addArrangedSubview:_updateLabel];

        NSStackView* updateActionRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        updateActionRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        updateActionRow.spacing = 10;

        _releaseNotesButton = [NSButton buttonWithTitle:@"Release Notes" target:self action:@selector(onReleaseNotes:)];
        _downloadButton = [NSButton buttonWithTitle:@"Download Latest" target:self action:@selector(onDownload:)];

        _releaseNotesButton.hidden = YES;
        _downloadButton.hidden = YES;

        [updateActionRow addArrangedSubview:_releaseNotesButton];
        [updateActionRow addArrangedSubview:_downloadButton];
        [stack addArrangedSubview:updateActionRow];

        [content addSubview:stack];
        scroll.documentView = content;
        [self addSubview:scroll];
    }
    return self;
}

- (void)updateConfigWithMessage:(NSDictionary*)configMessage {
    if (![configMessage isKindOfClass:[NSDictionary class]]) {
        self.configStateLabel.stringValue = @"Config: not loaded";
        return;
    }

    NSString* configPath = [configMessage[@"configPath"] isKindOfClass:[NSString class]] ? configMessage[@"configPath"] : @"";
    NSString* defaultBrowser = [configMessage[@"defaultBrowser"] isKindOfClass:[NSString class]] ? configMessage[@"defaultBrowser"] : @"";
    NSNumber* handlers = [configMessage[@"handlers"] isKindOfClass:[NSNumber class]] ? configMessage[@"handlers"] : @(0);

    self.configStateLabel.stringValue = [NSString stringWithFormat:@"Config: %@ | Default: %@ | Handlers: %@", configPath.length > 0 ? configPath : @"Not Found", defaultBrowser.length > 0 ? defaultBrowser : @"N/A", handlers];

    NSDictionary* options = [configMessage[@"options"] isKindOfClass:[NSDictionary class]] ? configMessage[@"options"] : @{};
    BOOL keepRunning = [options[@"keepRunning"] boolValue];
    BOOL hideIcon = [options[@"hideIcon"] boolValue];
    BOOL logRequests = [options[@"logRequests"] boolValue];
    BOOL checkForUpdates = [options[@"checkForUpdates"] boolValue];

    self.optionsLabel.stringValue = [NSString stringWithFormat:@"Options: keepRunning=%@, hideIcon=%@, logRequests=%@, checkForUpdates=%@", keepRunning ? @"true" : @"false", hideIcon ? @"true" : @"false", logRequests ? @"true" : @"false", checkForUpdates ? @"true" : @"false"];
}

- (void)updateICloudEnabled:(BOOL)enabled configPath:(NSString*)configPath cloudPath:(NSString*)cloudPath error:(NSString*)error {
    [self.cloudCard updateWithEnabled:enabled configPath:configPath cloudPath:cloudPath error:error];
}

- (void)updateUpdateInfo:(NSDictionary*)updateInfo {
    if (![updateInfo isKindOfClass:[NSDictionary class]]) {
        self.updateLabel.stringValue = @"Update status: unavailable";
        self.releaseNotesButton.hidden = YES;
        self.downloadButton.hidden = YES;
        return;
    }

    BOOL hasUpdate = [updateInfo[@"hasUpdate"] boolValue];
    BOOL enabled = [updateInfo[@"updateCheckEnabled"] boolValue];
    NSString* version = [updateInfo[@"version"] isKindOfClass:[NSString class]] ? updateInfo[@"version"] : @"";

    if (!enabled) {
        self.updateLabel.stringValue = @"Update status: check disabled";
        self.releaseNotesButton.hidden = YES;
        self.downloadButton.hidden = YES;
        return;
    }

    if (hasUpdate) {
        self.updateLabel.stringValue = [NSString stringWithFormat:@"Update available: %@", version.length > 0 ? version : @"new version"];
        self.releaseNotesButton.hidden = NO;
        self.downloadButton.hidden = NO;
        self.releaseNotesURL = [updateInfo[@"releaseUrl"] isKindOfClass:[NSString class]] ? updateInfo[@"releaseUrl"] : @"";
        self.downloadURL = [updateInfo[@"downloadUrl"] isKindOfClass:[NSString class]] ? updateInfo[@"downloadUrl"] : @"";
    } else {
        self.updateLabel.stringValue = @"Update status: up to date";
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
