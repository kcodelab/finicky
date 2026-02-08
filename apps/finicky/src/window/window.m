#import "window.h"
#import "native_components.h"

static WindowController* windowController = nil;
static NSString* htmlContent = nil;
static NSMutableDictionary* fileContents = nil;

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
    WKWebView* webView;

    FinickyNativeTabContainerView* tabContainer;
    FinickyNativeConfigFormView* configView;

    BOOL cloudSyncEnabled;
    BOOL saveInFlight;
    BOOL previewInFlight;
}

- (id)init {
    self = [super init];
    if (self) {
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

    tabContainer = [[FinickyNativeTabContainerView alloc] initWithFrame:rootView.bounds];
    tabContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    __unsafe_unretained typeof(self) weakSelf = self;
    configView = [[FinickyNativeConfigFormView alloc] initWithFrame:tabContainer.bounds];
    configView.onICloudToggleRequested = ^{
        [weakSelf onCloudSyncAction:nil];
    };
    configView.onRequestChromiumProfiles = ^{
        [weakSelf sendNativeMessage:@{ @"type": @"getChromiumProfiles" }];
    };
    configView.onFormatRequested = ^{
        [weakSelf onFormat:nil];
    };
    configView.onSaveRequested = ^{
        [weakSelf onSave:nil];
    };

    [tabContainer addTabWithIdentifier:@"configNative" label:@"Config" view:configView];
    [tabContainer addTabWithIdentifier:@"webLegacy" label:@"Web (Legacy)" view:[self buildWebViewContainerWithFrame:tabContainer.bounds]];

    [rootView addSubview:tabContainer];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:window];

    window.contentView = rootView;

    [self requestNativeInitialData];

    extern void WindowIsReady(void);
    WindowIsReady();
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
        NSDictionary* dict = (NSDictionary*)payload;
        [configView setBrowserOptions:dict[@"browsers"]];
        [configView setChromiumProfileGroups:dict[@"profiles"]];
        [configView setConfigPath:[dict[@"configPath"] isKindOfClass:[NSString class]] ? dict[@"configPath"] : @""];

        NSDictionary* draft = [dict[@"draft"] isKindOfClass:[NSDictionary class]] ? dict[@"draft"] : @{};
        [configView applyDraft:draft];

        NSString* errMsg = [dict[@"error"] isKindOfClass:[NSString class]] ? dict[@"error"] : @"";
        [configView setBuilderError:errMsg];
        return;
    }

    if ([type isEqualToString:@"chromiumProfiles"] && [payload isKindOfClass:[NSDictionary class]]) {
        NSArray* groups = [payload[@"groups"] isKindOfClass:[NSArray class]] ? payload[@"groups"] : @[];
        [configView setChromiumProfileGroups:groups];
        return;
    }

    if ([type isEqualToString:@"previewGeneratedConfigResult"] && [payload isKindOfClass:[NSDictionary class]]) {
        previewInFlight = NO;
        [configView setPreviewLoading:NO];

        BOOL ok = [payload[@"ok"] boolValue];
        if (ok) {
            [configView setPreviewContent:[payload[@"content"] isKindOfClass:[NSString class]] ? payload[@"content"] : @""];
            [configView setBuilderError:@""];
        } else {
            [configView setBuilderError:[payload[@"error"] isKindOfClass:[NSString class]] ? payload[@"error"] : @"Format failed"];
        }
        return;
    }

    if ([type isEqualToString:@"saveGeneratedConfigResult"] && [payload isKindOfClass:[NSDictionary class]]) {
        saveInFlight = NO;
        [configView setSaveLoading:NO];

        BOOL ok = [payload[@"ok"] boolValue];
        if (ok) {
            [configView setBuilderStatus:[payload[@"message"] isKindOfClass:[NSString class]] ? payload[@"message"] : @"Saved"];
            [configView setBuilderError:@""];
            [self sendNativeMessage:@{ @"type": @"getConfigBuilderData" }];
        } else {
            [configView setBuilderStatus:@""];
            [configView setBuilderError:[payload[@"error"] isKindOfClass:[NSString class]] ? payload[@"error"] : @"Save failed"];
        }
        return;
    }

    if ([type isEqualToString:@"cloudSyncStatus"] && [payload isKindOfClass:[NSDictionary class]]) {
        [self handleCloudSyncStatus:(NSDictionary*)payload error:@""];
        return;
    }

    if ([type isEqualToString:@"cloudSyncResult"] && [payload isKindOfClass:[NSDictionary class]]) {
        BOOL ok = [payload[@"ok"] boolValue];
        if (ok) {
            [self sendNativeMessage:@{ @"type": @"getICloudSyncStatus" }];
        } else {
            NSString* errMsg = [payload[@"error"] isKindOfClass:[NSString class]] ? payload[@"error"] : @"unknown";
            [self handleCloudSyncStatus:@{ @"enabled": @(cloudSyncEnabled) } error:errMsg];
        }
        return;
    }
}

- (void)handleCloudSyncStatus:(NSDictionary*)status error:(NSString*)error {
    cloudSyncEnabled = [status[@"enabled"] boolValue];
    NSString* configPath = [status[@"configPath"] isKindOfClass:[NSString class]] ? status[@"configPath"] : @"";
    NSString* cloudPath = [status[@"cloudPath"] isKindOfClass:[NSString class]] ? status[@"cloudPath"] : @"";

    [configView updateICloudWithEnabled:cloudSyncEnabled configPath:configPath cloudPath:cloudPath error:error ?: @""];
}

- (void)onFormat:(id)sender {
    if (previewInFlight) {
        return;
    }

    NSString* errorMessage = nil;
    NSDictionary* payload = [configView buildRequestPayloadWithError:&errorMessage];
    if (!payload) {
        [configView setBuilderError:errorMessage ?: @"Invalid request"];
        return;
    }

    previewInFlight = YES;
    [configView setPreviewLoading:YES];

    NSMutableDictionary* msg = [[NSMutableDictionary alloc] initWithDictionary:payload];
    msg[@"type"] = @"previewGeneratedConfig";
    [self sendNativeMessage:msg];
}

- (void)onSave:(id)sender {
    if (saveInFlight) {
        return;
    }

    NSString* errorMessage = nil;
    NSDictionary* payload = [configView buildRequestPayloadWithError:&errorMessage];
    if (!payload) {
        [configView setBuilderError:errorMessage ?: @"Invalid request"];
        return;
    }

    saveInFlight = YES;
    [configView setSaveLoading:YES];

    NSMutableDictionary* msg = [[NSMutableDictionary alloc] initWithDictionary:payload];
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
