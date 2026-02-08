#import "window.h"

static WindowController* windowController = nil;
static NSString* htmlContent = nil;
static NSMutableDictionary* fileContents = nil;

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

void SetHTMLContent(const char* content) {
    if (content) {
        htmlContent = [NSString stringWithUTF8String:content];
    }
}

void SetFileContent(const char* path, const char* content) {
    if (!fileContents) {
        fileContents = [[NSMutableDictionary alloc] init];
    }
    if (path && content) {
        NSString* pathStr = [NSString stringWithUTF8String:path];
        if ([pathStr hasSuffix:@".png"]) {
            SetFileContentWithLength(path, content, strlen(content));
        } else {
            NSString* contentStr = [NSString stringWithUTF8String:content];
            fileContents[pathStr] = contentStr;
        }
    }
}

void SetFileContentWithLength(const char* path, const char* content, size_t length) {
    if (!fileContents) {
        fileContents = [[NSMutableDictionary alloc] init];
    }
    if (path && content) {
        NSString* pathStr = [NSString stringWithUTF8String:path];
        NSData* data = [[NSData alloc] initWithBytes:content length:length];
        fileContents[pathStr] = data;
    }
}

@implementation WindowController {
    NSWindow* window;
    NSTabView* tabView;
    WKWebView* webView;

    NSPopUpButton* defaultBrowserPopup;
    NSTextField* configPathLabel;
    NSStackView* routeRowsContainer;
    NSTextView* previewTextView;
    NSTextField* builderErrorLabel;
    NSTextField* builderStatusLabel;
    NSButton* formatButton;
    NSButton* saveButton;

    NSTextField* cloudSyncStatusLabel;
    NSButton* cloudSyncActionButton;

    NSArray* browserOptions;
    NSArray* chromiumProfileGroups;
    NSMutableArray<RouteDraft*>* routeDrafts;
    NSString* selectedDefaultBrowser;
    NSString* configBuilderPath;
    BOOL cloudSyncEnabled;
    BOOL saveInFlight;
    BOOL previewInFlight;
}

- (id)init {
    self = [super init];
    if (self) {
        browserOptions = @[];
        chromiumProfileGroups = @[];
        routeDrafts = [[NSMutableArray alloc] init];
        selectedDefaultBrowser = @"";
        configBuilderPath = @"";
        cloudSyncEnabled = NO;
        saveInFlight = NO;
        previewInFlight = NO;

        if ([NSThread isMainThread]) {
            [self setupWindow];
            [self setupMenu];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self setupWindow];
                [self setupMenu];
            });
        }
    }
    return self;
}

- (void)setupWindow {
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 980, 700)
                                         styleMask:NSWindowStyleMaskTitled |
                                                   NSWindowStyleMaskClosable |
                                                   NSWindowStyleMaskMiniaturizable |
                                                   NSWindowStyleMaskResizable
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setTitle:@"Finicky"];
    [window center];
    [window setReleasedWhenClosed:NO];
    [window setBackgroundColor:[NSColor windowBackgroundColor]];
    [window setMinSize:NSMakeSize(860, 560)];
    [window setMaxSize:NSMakeSize(1400, 1000)];

    NSView* rootView = [[NSView alloc] initWithFrame:window.contentView.bounds];
    rootView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    tabView = [[NSTabView alloc] initWithFrame:rootView.bounds];
    tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    NSTabViewItem* configTab = [[NSTabViewItem alloc] initWithIdentifier:@"configNative"];
    configTab.label = @"Config";
    configTab.view = [self buildNativeConfigViewWithFrame:tabView.bounds];
    [tabView addTabViewItem:configTab];

    NSTabViewItem* webTab = [[NSTabViewItem alloc] initWithIdentifier:@"webLegacy"];
    webTab.label = @"Web (Legacy)";
    webTab.view = [self buildWebViewContainerWithFrame:tabView.bounds];
    [tabView addTabViewItem:webTab];

    [rootView addSubview:tabView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:window];

    window.contentView = rootView;

    [self requestNativeInitialData];
}

- (NSView*)buildWebViewContainerWithFrame:(NSRect)frame {
    NSView* container = [[NSView alloc] initWithFrame:frame];
    container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
    [config.userContentController addScriptMessageHandler:self name:@"finicky"];
    [config setURLSchemeHandler:self forURLScheme:@"finicky-assets"];

    webView = [[WKWebView alloc] initWithFrame:container.bounds configuration:config];
    webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    webView.navigationDelegate = self;

    [webView.configuration.preferences setValue:@true forKey:@"developerExtrasEnabled"];

    if (htmlContent) {
        NSURL* baseURL = [NSURL URLWithString:@"finicky-assets://local/"];
        [webView loadHTMLString:htmlContent baseURL:baseURL];
    } else {
        NSLog(@"Warning: HTML content not set");
    }

    [container addSubview:webView];
    return container;
}

- (NSView*)buildNativeConfigViewWithFrame:(NSRect)frame {
    NSView* container = [[NSView alloc] initWithFrame:frame];
    container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:container.bounds];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = NO;
    scroll.borderType = NSNoBorder;

    NSView* content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 1200)];
    content.autoresizingMask = NSViewWidthSizable;

    NSStackView* stack = [[NSStackView alloc] initWithFrame:NSMakeRect(20, 20, frame.size.width - 40, 1120)];
    stack.orientation =NSUserInterfaceLayoutOrientationVertical;
    stack.spacing = 12;
    stack.alignment = NSLayoutAttributeLeading;
    stack.autoresizingMask = NSViewWidthSizable;

    NSTextField* title = [NSTextField labelWithString:@"Config Builder (Native)"];
    title.font = [NSFont boldSystemFontOfSize:20];
    [stack addArrangedSubview:title];

    configPathLabel = [NSTextField labelWithString:@"Generated file path: (loading...)"];
    configPathLabel.textColor = [NSColor secondaryLabelColor];
    [stack addArrangedSubview:configPathLabel];

    NSStackView* defaultRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
    defaultRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    defaultRow.spacing = 10;

    NSTextField* defaultLabel = [NSTextField labelWithString:@"Default Browser:"];
    defaultLabel.frame = NSMakeRect(0, 0, 120, 24);
    [defaultRow addArrangedSubview:defaultLabel];

    defaultBrowserPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 280, 26) pullsDown:NO];
    [defaultBrowserPopup setTarget:self];
    [defaultBrowserPopup setAction:@selector(onDefaultBrowserChanged:)];
    [defaultRow addArrangedSubview:defaultBrowserPopup];
    [stack addArrangedSubview:defaultRow];

    NSBox* cloudBox = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width - 40, 80)];
    cloudBox.title = @"iCloud Sync";
    cloudBox.contentViewMargins = NSMakeSize(12, 10);
    cloudBox.boxType = NSBoxCustom;
    cloudBox.borderType = NSLineBorder;
    cloudBox.cornerRadius = 8;
    cloudBox.frame = NSMakeRect(0, 0, frame.size.width - 40, 80);

    NSView* cloudInner = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width - 100, 60)];
    cloudSyncStatusLabel = [NSTextField labelWithString:@"Status: loading..."];
    cloudSyncStatusLabel.frame = NSMakeRect(0, 30, frame.size.width - 300, 20);

    cloudSyncActionButton = [NSButton buttonWithTitle:@"Enable iCloud Sync" target:self action:@selector(onCloudSyncAction:)];
    cloudSyncActionButton.frame = NSMakeRect(0, 0, 180, 28);

    [cloudInner addSubview:cloudSyncStatusLabel];
    [cloudInner addSubview:cloudSyncActionButton];
    cloudBox.contentView = cloudInner;
    [stack addArrangedSubview:cloudBox];

    NSStackView* routeHeader = [[NSStackView alloc] initWithFrame:NSZeroRect];
    routeHeader.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    routeHeader.spacing = 10;

    NSTextField* routeTitle = [NSTextField labelWithString:@"Routes"];
    routeTitle.font = [NSFont boldSystemFontOfSize:14];
    [routeHeader addArrangedSubview:routeTitle];

    NSButton* addRouteButton = [NSButton buttonWithTitle:@"Add Route" target:self action:@selector(onAddRoute:)];
    [routeHeader addArrangedSubview:addRouteButton];
    [stack addArrangedSubview:routeHeader];

    routeRowsContainer = [[NSStackView alloc] initWithFrame:NSZeroRect];
    routeRowsContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
    routeRowsContainer.spacing = 10;
    [stack addArrangedSubview:routeRowsContainer];

    NSStackView* actionRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
    actionRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actionRow.spacing = 10;

    formatButton = [NSButton buttonWithTitle:@"Format" target:self action:@selector(onFormat:)];
    saveButton = [NSButton buttonWithTitle:@"Save and Activate" target:self action:@selector(onSave:)];
    saveButton.bezelColor = [NSColor controlAccentColor];

    [actionRow addArrangedSubview:formatButton];
    [actionRow addArrangedSubview:saveButton];
    [stack addArrangedSubview:actionRow];

    builderErrorLabel = [NSTextField labelWithString:@""];
    builderErrorLabel.textColor = [NSColor systemRedColor];
    [stack addArrangedSubview:builderErrorLabel];

    builderStatusLabel = [NSTextField labelWithString:@""];
    builderStatusLabel.textColor = [NSColor systemGreenColor];
    [stack addArrangedSubview:builderStatusLabel];

    NSTextField* previewLabel = [NSTextField labelWithString:@"Config Preview"];
    previewLabel.font = [NSFont boldSystemFontOfSize:14];
    [stack addArrangedSubview:previewLabel];

    NSScrollView* previewScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width - 70, 300)];
    previewScroll.hasVerticalScroller = YES;
    previewScroll.hasHorizontalScroller = YES;
    previewScroll.borderType = NSBezelBorder;

    previewTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width - 90, 300)];
    previewTextView.editable = NO;
    previewTextView.automaticQuoteSubstitutionEnabled = NO;
    previewTextView.font = [NSFont userFixedPitchFontOfSize:12];
    previewScroll.documentView = previewTextView;

    [stack addArrangedSubview:previewScroll];

    [content addSubview:stack];
    scroll.documentView = content;
    [container addSubview:scroll];

    [self ensureAtLeastOneRoute];
    [self rebuildRouteRows];

    return container;
}

- (void)requestNativeInitialData {
    [self sendNativeMessage:@{ @"type": @"getICloudSyncStatus" }];
    [self sendNativeMessage:@{ @"type": @"getConfigBuilderData" }];
}

- (void)sendNativeMessage:(NSDictionary*)message {
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
    if (!data || error) {
        NSLog(@"Failed to encode native message: %@", error);
        return;
    }

    NSString* jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    extern void HandleWebViewMessage(const char* message);
    HandleWebViewMessage([jsonString UTF8String]);
}

- (void)showWindow {
    if ([NSThread isMainThread]) {
        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:true];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [window makeKeyAndOrderFront:nil];
            [NSApp activateIgnoringOtherApps:true];
        });
    }
}

- (void)closeWindow {
    if ([NSThread isMainThread]) {
        [window close];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [window close];
        });
    }
}

- (void)sendMessageToWebView:(NSString *)message {
    [self applyIncomingBackendMessage:message];

    NSString *escapedMessage = [[message stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                                        stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *js = [NSString stringWithFormat:@"finicky.receiveMessage(\"%@\")", escapedMessage];

    if ([NSThread isMainThread]) {
        if (webView && !webView.loading) {
            [webView evaluateJavaScript:js completionHandler:nil];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (webView && !webView.loading) {
                [webView evaluateJavaScript:js completionHandler:nil];
            }
        });
    }
}

- (void)applyIncomingBackendMessage:(NSString*)message {
    NSData* data = [message dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return;
    }

    NSError* error = nil;
    NSDictionary* obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!obj || error || ![obj isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSString* type = obj[@"type"];
    id payload = obj[@"message"];
    if (![type isKindOfClass:[NSString class]]) {
        return;
    }

    if ([type isEqualToString:@"configBuilderData"] && [payload isKindOfClass:[NSDictionary class]]) {
        [self handleConfigBuilderData:(NSDictionary*)payload];
        return;
    }

    if ([type isEqualToString:@"chromiumProfiles"] && [payload isKindOfClass:[NSDictionary class]]) {
        NSArray* groups = payload[@"groups"];
        if ([groups isKindOfClass:[NSArray class]]) {
            chromiumProfileGroups = groups;
            [self rebuildRouteRows];
        }
        return;
    }

    if ([type isEqualToString:@"previewGeneratedConfigResult"] && [payload isKindOfClass:[NSDictionary class]]) {
        previewInFlight = NO;
        [formatButton setEnabled:YES];
        BOOL ok = [payload[@"ok"] boolValue];
        if (ok) {
            NSString* content = payload[@"content"];
            if ([content isKindOfClass:[NSString class]]) {
                previewTextView.string = content;
            }
            builderErrorLabel.stringValue = @"";
        } else {
            NSString* errMsg = payload[@"error"];
            builderErrorLabel.stringValue = [errMsg isKindOfClass:[NSString class]] ? errMsg : @"Format failed";
        }
        return;
    }

    if ([type isEqualToString:@"saveGeneratedConfigResult"] && [payload isKindOfClass:[NSDictionary class]]) {
        saveInFlight = NO;
        [saveButton setEnabled:YES];

        BOOL ok = [payload[@"ok"] boolValue];
        if (ok) {
            NSString* msg = payload[@"message"];
            builderStatusLabel.stringValue = [msg isKindOfClass:[NSString class]] ? msg : @"Saved";
            builderErrorLabel.stringValue = @"";
            [self sendNativeMessage:@{ @"type": @"getConfigBuilderData" }];
        } else {
            NSString* errMsg = payload[@"error"];
            builderErrorLabel.stringValue = [errMsg isKindOfClass:[NSString class]] ? errMsg : @"Save failed";
            builderStatusLabel.stringValue = @"";
        }
        return;
    }

    if ([type isEqualToString:@"cloudSyncStatus"] && [payload isKindOfClass:[NSDictionary class]]) {
        [self handleCloudSyncStatus:(NSDictionary*)payload];
        return;
    }

    if ([type isEqualToString:@"cloudSyncResult"] && [payload isKindOfClass:[NSDictionary class]]) {
        BOOL ok = [payload[@"ok"] boolValue];
        if (ok) {
            [self sendNativeMessage:@{ @"type": @"getICloudSyncStatus" }];
        } else {
            NSString* errMsg = payload[@"error"];
            cloudSyncStatusLabel.stringValue = [NSString stringWithFormat:@"Cloud sync error: %@", [errMsg isKindOfClass:[NSString class]] ? errMsg : @"unknown"];
        }
        return;
    }
}

- (void)handleConfigBuilderData:(NSDictionary*)payload {
    NSArray* browsers = payload[@"browsers"];
    if ([browsers isKindOfClass:[NSArray class]]) {
        browserOptions = browsers;
    }

    NSArray* profiles = payload[@"profiles"];
    if ([profiles isKindOfClass:[NSArray class]]) {
        chromiumProfileGroups = profiles;
    }

    NSString* path = payload[@"configPath"];
    if ([path isKindOfClass:[NSString class]]) {
        configBuilderPath = path;
    } else {
        configBuilderPath = @"";
    }

    NSDictionary* draft = payload[@"draft"];
    if ([draft isKindOfClass:[NSDictionary class]]) {
        [self hydrateDraft:draft];
    }

    NSString* errMsg = payload[@"error"];
    if ([errMsg isKindOfClass:[NSString class]] && errMsg.length > 0) {
        builderErrorLabel.stringValue = errMsg;
    }

    [self refreshDefaultBrowserPopup];
    [self rebuildRouteRows];
    [self refreshConfigMetaLabels];
}

- (void)handleCloudSyncStatus:(NSDictionary*)payload {
    cloudSyncEnabled = [payload[@"enabled"] boolValue];
    NSString* configPath = payload[@"configPath"];
    NSString* cloudPath = payload[@"cloudPath"];

    NSMutableArray<NSString*>* lines = [[NSMutableArray alloc] init];
    [lines addObject:[NSString stringWithFormat:@"Status: %@", cloudSyncEnabled ? @"Enabled" : @"Disabled"]];
    if ([configPath isKindOfClass:[NSString class]] && configPath.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"Config: %@", configPath]];
    }
    if ([cloudPath isKindOfClass:[NSString class]] && cloudPath.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"iCloud: %@", cloudPath]];
    }

    cloudSyncStatusLabel.stringValue = [lines componentsJoinedByString:@" | "];
    cloudSyncActionButton.title = cloudSyncEnabled ? @"Disable iCloud Sync" : @"Enable iCloud Sync";
}

- (void)hydrateDraft:(NSDictionary*)draft {
    NSString* defaultBrowser = draft[@"defaultBrowser"];
    if ([defaultBrowser isKindOfClass:[NSString class]]) {
        selectedDefaultBrowser = defaultBrowser;
    }

    [routeDrafts removeAllObjects];
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
                for (id p in patterns) {
                    if ([p isKindOfClass:[NSString class]]) {
                        [cleaned addObject:(NSString*)p];
                    }
                }
                route.patterns = [cleaned componentsJoinedByString:@", "];
            } else {
                route.patterns = @"";
            }

            [routeDrafts addObject:route];
        }
    }

    [self ensureAtLeastOneRoute];
}

- (void)refreshConfigMetaLabels {
    if (configBuilderPath.length > 0) {
        configPathLabel.stringValue = [NSString stringWithFormat:@"Generated file path: %@", configBuilderPath];
    } else {
        configPathLabel.stringValue = @"Generated file path: (will use default path)";
    }
}

- (void)refreshDefaultBrowserPopup {
    [defaultBrowserPopup removeAllItems];

    NSMutableArray<NSString*>* names = [[NSMutableArray alloc] init];
    for (id item in browserOptions) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString* appName = item[@"appName"];
        if ([appName isKindOfClass:[NSString class]]) {
            [names addObject:appName];
        }
    }

    if (names.count == 0) {
        [defaultBrowserPopup addItemWithTitle:@"(No browsers found)"];
        return;
    }

    [defaultBrowserPopup addItemsWithTitles:names];

    if (selectedDefaultBrowser.length > 0 && [names containsObject:selectedDefaultBrowser]) {
        [defaultBrowserPopup selectItemWithTitle:selectedDefaultBrowser];
    } else {
        [defaultBrowserPopup selectItemAtIndex:0];
        selectedDefaultBrowser = defaultBrowserPopup.titleOfSelectedItem ?: @"";
    }
}

- (RouteDraft*)routeForID:(NSString*)routeID {
    for (RouteDraft* route in routeDrafts) {
        if ([route.routeID isEqualToString:routeID]) {
            return route;
        }
    }
    return nil;
}

- (void)ensureAtLeastOneRoute {
    if (routeDrafts.count > 0) {
        return;
    }

    RouteDraft* route = [[RouteDraft alloc] init];
    route.routeID = [[NSUUID UUID] UUIDString];
    route.patterns = @"";
    route.browserName = @"";
    route.profile = @"";
    [routeDrafts addObject:route];
}

- (BOOL)browserSupportsProfiles:(NSString*)browserName {
    for (id item in browserOptions) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString* name = item[@"appName"];
        if (![name isKindOfClass:[NSString class]]) {
            continue;
        }
        if ([name isEqualToString:browserName]) {
            return [item[@"supportsProfiles"] boolValue];
        }
    }
    return NO;
}

- (NSArray*)profilesForBrowser:(NSString*)browserName {
    for (id item in chromiumProfileGroups) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString* appName = item[@"appName"];
        if (![appName isKindOfClass:[NSString class]]) {
            continue;
        }
        if ([appName isEqualToString:browserName]) {
            NSArray* profiles = item[@"profiles"];
            if ([profiles isKindOfClass:[NSArray class]]) {
                return profiles;
            }
        }
    }
    return @[];
}

- (void)clearRouteRowsView {
    NSArray* current = [routeRowsContainer.arrangedSubviews copy];
    for (NSView* view in current) {
        [routeRowsContainer removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

- (void)rebuildRouteRows {
    [self clearRouteRowsView];

    NSInteger rowIndex = 1;
    for (RouteDraft* route in routeDrafts) {
        NSBox* routeCard = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 860, 210)];
        routeCard.boxType = NSBoxCustom;
        routeCard.borderType = NSLineBorder;
        routeCard.cornerRadius = 8;
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
        patternsScroll.borderType = NSBezelBorder;

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

        NSTextField* browserLabel = [NSTextField labelWithString:@"Browser:"];
        [browserRow addArrangedSubview:browserLabel];

        RoutePopupButton* browserPopup = [[RoutePopupButton alloc] initWithFrame:NSMakeRect(0, 0, 220, 24) pullsDown:NO];
        browserPopup.routeID = route.routeID;
        [browserPopup setTarget:self];
        [browserPopup setAction:@selector(onRouteBrowserChanged:)];

        [browserPopup addItemWithTitle:@"Select browser"];
        for (id item in browserOptions) {
            if (![item isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSString* appName = item[@"appName"];
            if ([appName isKindOfClass:[NSString class]]) {
                [browserPopup addItemWithTitle:appName];
            }
        }

        if (route.browserName.length > 0) {
            [browserPopup selectItemWithTitle:route.browserName];
        } else {
            [browserPopup selectItemAtIndex:0];
        }
        [browserRow addArrangedSubview:browserPopup];

        BOOL supportsProfiles = [self browserSupportsProfiles:route.browserName];
        if (supportsProfiles) {
            NSTextField* profileLabel = [NSTextField labelWithString:@"Profile:"];
            [browserRow addArrangedSubview:profileLabel];

            RoutePopupButton* profilePopup = [[RoutePopupButton alloc] initWithFrame:NSMakeRect(0, 0, 320, 24) pullsDown:NO];
            profilePopup.routeID = route.routeID;
            [profilePopup setTarget:self];
            [profilePopup setAction:@selector(onRouteProfileChanged:)];

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

                NSString* label = [NSString stringWithFormat:@"%@ (%@)", name, path];
                [profilePopup addItemWithTitle:label];
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
        [routeRowsContainer addArrangedSubview:routeCard];
        rowIndex += 1;
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

        if (([value hasPrefix:@"\""] && [value hasSuffix:@"\""]) ||
            ([value hasPrefix:@"'"] && [value hasSuffix:@"'"])) {
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

- (NSDictionary*)buildGeneratedConfigRequestPayload {
    NSString* defaultBrowser = defaultBrowserPopup.titleOfSelectedItem ?: @"";
    defaultBrowser = [defaultBrowser stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    builderErrorLabel.stringValue = @"";
    builderStatusLabel.stringValue = @"";

    if (defaultBrowser.length == 0 || [defaultBrowser isEqualToString:@"(No browsers found)"]) {
        builderErrorLabel.stringValue = @"Default browser is required";
        return nil;
    }

    NSMutableArray* routes = [[NSMutableArray alloc] init];
    for (RouteDraft* route in routeDrafts) {
        NSString* browser = [route.browserName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSArray* patterns = [self sanitizePatterns:route.patterns ?: @""];

        if (browser.length == 0 || patterns.count == 0) {
            continue;
        }

        NSMutableDictionary* routePayload = [[NSMutableDictionary alloc] init];
        routePayload[@"patterns"] = patterns;
        routePayload[@"browser"] = browser;
        routePayload[@"profile"] = route.profile ?: @"";
        [routes addObject:routePayload];
    }

    if (routes.count == 0) {
        builderErrorLabel.stringValue = @"Add at least one valid route rule";
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
    selectedDefaultBrowser = defaultBrowserPopup.titleOfSelectedItem ?: @"";
}

- (void)onAddRoute:(id)sender {
    RouteDraft* route = [[RouteDraft alloc] init];
    route.routeID = [[NSUUID UUID] UUIDString];
    route.patterns = @"";
    route.browserName = @"";
    route.profile = @"";
    [routeDrafts addObject:route];
    [self rebuildRouteRows];
}

- (void)onRemoveRoute:(RouteButton*)sender {
    NSString* routeID = sender.routeID;
    if (![routeID isKindOfClass:[NSString class]]) {
        return;
    }

    NSIndexSet* indexes = [routeDrafts indexesOfObjectsPassingTest:^BOOL(RouteDraft* route, NSUInteger idx, BOOL* stop) {
        return [route.routeID isEqualToString:routeID];
    }];

    if (indexes.count > 0) {
        [routeDrafts removeObjectsAtIndexes:indexes];
    }

    [self ensureAtLeastOneRoute];
    [self rebuildRouteRows];
}

- (void)onRouteBrowserChanged:(RoutePopupButton*)sender {
    NSString* routeID = sender.routeID;
    RouteDraft* route = [self routeForID:routeID];
    if (!route) {
        return;
    }

    NSString* selected = sender.titleOfSelectedItem ?: @"";
    if ([selected isEqualToString:@"Select browser"]) {
        selected = @"";
    }

    route.browserName = selected;
    route.profile = @"";

    if ([self browserSupportsProfiles:selected]) {
        [self sendNativeMessage:@{ @"type": @"getChromiumProfiles" }];
    }

    [self rebuildRouteRows];
}

- (void)onRouteProfileChanged:(RoutePopupButton*)sender {
    NSString* routeID = sender.routeID;
    RouteDraft* route = [self routeForID:routeID];
    if (!route) {
        return;
    }

    NSMenuItem* item = sender.selectedItem;
    NSString* profilePath = [[item representedObject] description] ?: @"";
    route.profile = profilePath;
}

- (void)onFormat:(id)sender {
    if (previewInFlight) {
        return;
    }

    NSDictionary* requestPayload = [self buildGeneratedConfigRequestPayload];
    if (!requestPayload) {
        return;
    }

    previewInFlight = YES;
    [formatButton setEnabled:NO];

    NSMutableDictionary* msg = [[NSMutableDictionary alloc] initWithDictionary:requestPayload];
    msg[@"type"] = @"previewGeneratedConfig";
    [self sendNativeMessage:msg];
}

- (void)onSave:(id)sender {
    if (saveInFlight) {
        return;
    }

    NSDictionary* requestPayload = [self buildGeneratedConfigRequestPayload];
    if (!requestPayload) {
        return;
    }

    saveInFlight = YES;
    [saveButton setEnabled:NO];

    NSMutableDictionary* msg = [[NSMutableDictionary alloc] initWithDictionary:requestPayload];
    msg[@"type"] = @"saveGeneratedConfig";
    [self sendNativeMessage:msg];
}

- (void)onCloudSyncAction:(id)sender {
    if (cloudSyncEnabled) {
        [self sendNativeMessage:@{ @"type": @"disableICloudSync" }];
    } else {
        [self sendNativeMessage:@{ @"type": @"enableICloudSync" }];
    }
}

- (void)textDidChange:(NSNotification*)notification {
    id obj = notification.object;
    if (![obj isKindOfClass:[RoutePatternsTextView class]]) {
        return;
    }

    RoutePatternsTextView* textView = (RoutePatternsTextView*)obj;
    RouteDraft* route = [self routeForID:textView.routeID];
    if (!route) {
        return;
    }

    route.patterns = textView.string ?: @"";
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isKindOfClass:[NSString class]]) {
        extern void HandleWebViewMessage(const char* message);
        NSString *messageString = (NSString *)message.body;
        HandleWebViewMessage([messageString UTF8String]);
    } else if ([message.body isKindOfClass:[NSDictionary class]]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message.body options:0 error:&error];
        if (jsonData && !error) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            extern void HandleWebViewMessage(const char* message);
            HandleWebViewMessage([jsonString UTF8String]);
        }
    }
}

#pragma mark - WKURLSchemeHandler

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
    NSURLRequest *request = urlSchemeTask.request;
    NSString *path = request.URL.path;
    if ([path hasPrefix:@"/"]) {
        path = [path substringFromIndex:1];
    }

    if ([path hasPrefix:@"local/"]) {
        path = [path substringFromIndex:6];
    }

    id content = fileContents[path];
    if (content) {
        NSData *data;
        if ([content isKindOfClass:[NSData class]]) {
            data = (NSData *)content;
        } else {
            data = [(NSString *)content dataUsingEncoding:NSUTF8StringEncoding];
        }

        NSString *mimeType = @"text/plain";
        if ([path hasSuffix:@".css"]) {
            mimeType = @"text/css";
        } else if ([path hasSuffix:@".js"]) {
            mimeType = @"application/javascript";
        } else if ([path hasSuffix:@".png"]) {
            mimeType = @"image/png";
        }

        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                          MIMEType:mimeType
                                             expectedContentLength:data.length
                                                  textEncodingName:nil];

        [urlSchemeTask didReceiveResponse:response];
        [urlSchemeTask didReceiveData:data];
        [urlSchemeTask didFinish];
    } else {
        NSLog(@"Asset not found: %@", path);
        [urlSchemeTask didFailWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                            code:NSURLErrorResourceUnavailable
                                                        userInfo:nil]];
    }
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    extern void WindowIsReady(void);
    WindowIsReady();
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;

    if ([url.scheme isEqualToString:@"finicky-assets"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        [[NSWorkspace sharedWorkspace] openURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)windowWillClose:(NSNotification *)notification {
    extern void WindowDidClose(void);
    WindowDidClose();
}

- (void)setupMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    [NSApp setMainMenu:mainMenu];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenuItem setSubmenu:appMenu];

    NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                          action:@selector(terminate:)
                                                   keyEquivalent:@"q"];
    [quitMenuItem setTarget:NSApp];
    [appMenu addItem:quitMenuItem];

    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:fileMenuItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenuItem setSubmenu:fileMenu];

    NSMenuItem *closeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Close Window"
                                                           action:@selector(performClose:)
                                                    keyEquivalent:@"w"];
    [closeMenuItem setTarget:window];
    [fileMenu addItem:closeMenuItem];

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenuItem setSubmenu:editMenu];

    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
}

@end

void ShowWindow(void) {
    if (!windowController) {
        windowController = [[WindowController alloc] init];
    }
    [windowController showWindow];
}

void CloseWindow(void) {
    if (windowController) {
        [windowController closeWindow];
    }
}

void SendMessageToWebView(const char* message) {
    if (windowController) {
        NSString *nsMessage = [NSString stringWithUTF8String:message];
        [windowController sendMessageToWebView:nsMessage];
    }
}
