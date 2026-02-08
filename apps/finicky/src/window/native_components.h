#ifndef NATIVE_COMPONENTS_H
#define NATIVE_COMPONENTS_H

#import <Cocoa/Cocoa.h>

@interface FinickyNativeTabContainerView : NSView
- (void)addTabWithIdentifier:(NSString*)identifier label:(NSString*)label view:(NSView*)view;
@end

@interface FinickyNativeICloudCardView : NSView
@property(nonatomic, copy) void (^onToggleRequested)(void);
- (void)updateWithEnabled:(BOOL)enabled configPath:(NSString*)configPath cloudPath:(NSString*)cloudPath error:(NSString*)error;
@end

@interface FinickyNativePreviewPanelView : NSView
- (void)setContent:(NSString*)content;
@end

@interface FinickyNativeConfigFormView : NSView
@property(nonatomic, copy) void (^onRequestChromiumProfiles)(void);
@property(nonatomic, copy) void (^onFormatRequested)(void);
@property(nonatomic, copy) void (^onSaveRequested)(void);
@property(nonatomic, copy) void (^onICloudToggleRequested)(void);

- (void)setBrowserOptions:(NSArray*)browserOptions;
- (void)setChromiumProfileGroups:(NSArray*)profileGroups;
- (void)setConfigPath:(NSString*)configPath;
- (void)applyDraft:(NSDictionary*)draft;

- (void)setBuilderError:(NSString*)errorText;
- (void)setBuilderStatus:(NSString*)statusText;
- (void)setPreviewLoading:(BOOL)loading;
- (void)setSaveLoading:(BOOL)loading;
- (void)updateICloudWithEnabled:(BOOL)enabled configPath:(NSString*)configPath cloudPath:(NSString*)cloudPath error:(NSString*)error;

- (void)setPreviewContent:(NSString*)content;
- (NSDictionary*)buildRequestPayloadWithError:(NSString*__autoreleasing*)errorMessage;
@end

@interface FinickyNativeOverviewView : NSView
@property(nonatomic, copy) void (^onICloudToggleRequested)(void);

- (void)updateConfigWithMessage:(NSDictionary*)configMessage;
- (void)updateICloudEnabled:(BOOL)enabled configPath:(NSString*)configPath cloudPath:(NSString*)cloudPath error:(NSString*)error;
- (void)updateUpdateInfo:(NSDictionary*)updateInfo;
@end

#endif
