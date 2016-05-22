#import "../PS.h"
#import "PSCMLWYPopoverController.h"

@interface UIFont (Camera)
+ (UIFont *)cam_cameraFontOfSize:(CGFloat)size;
+ (UIFont *)cui_cameraFontOfSize:(CGFloat)size;
@end

@interface PLCameraView (CamModeList)
- (BOOL)cml_shouldHideListButtonForMode:(int)mode;
- (BOOL)_shouldEnableListButton;
@end

@interface CAMCameraView (CamModeList)
- (BOOL)cml_shouldHideListButtonForMode:(int)mode;
- (BOOL)_shouldEnableListButton;
@end

@interface CAMViewfinderViewController (CamModeList)
- (BOOL)cml_shouldHideListButtonForMode:(int)mode;
- (BOOL)_shouldEnableListButton;
@end

NSString *const tweakKey = @"tweakEnabled";
NSString *const PREF_PATH = @"/var/mobile/Library/Preferences/com.PS.CamModeList.plist";
CFStringRef const PreferencesNotification = CFSTR("com.PS.CamModeList.prefs");
BOOL tweakEnabled;

CGFloat width = 180.0f;

static void addConstraintForDevice(NSObject <cameraViewDelegate> *cameraView, CAMBottomBar *bottomBar, UIView *backgroundView, UIView *btn, BOOL hasModeDial)
{
	BOOL pad = NO;
	if ([%c(CAMModeDial) respondsToSelector:@selector(wantsVerticalModeDialForTraitCollection:)])
		pad = [%c(CAMModeDial) wantsVerticalModeDialForTraitCollection:bottomBar.traitCollection];
	else if ([cameraView respondsToSelector:@selector(spec)])
		pad = cameraView.spec.modeDialOrientation != 0;
	if (pad) {
		NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:btn attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:backgroundView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0f];
		NSLayoutConstraint *topInset = [NSLayoutConstraint constraintWithItem:btn attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:backgroundView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:-65.0f];
		[bottomBar addConstraints:@[topInset, centerX]];
	} else {
		NSLayoutConstraint *rightInset = [NSLayoutConstraint constraintWithItem:btn attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:backgroundView attribute:NSLayoutAttributeRight multiplier:1.0 constant:-55.0f];
		NSLayoutConstraint *topInset = [NSLayoutConstraint constraintWithItem:btn attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:backgroundView attribute:NSLayoutAttributeTop multiplier:1.0 constant:(hasModeDial ? -5.0f : -22.0f)];
		[bottomBar addConstraints:@[rightInset, topInset]];
	}
}

CAMShutterButton *btn;

UIViewController *vc;
UITableView *tb;
PSCMLWYPopoverController *popover;

static int cameraMode(NSObject <cameraControllerDelegate> *cameraController)
{
	if ([cameraController respondsToSelector:@selector(_currentMode)])
		return ((CAMViewfinderViewController *)cameraController)._currentMode;
	return cameraController.cameraMode;
}

static NSArray *supportedCameraModes(NSObject <cameraControllerDelegate> *cameraController)
{
	if ([cameraController respondsToSelector:@selector(modesForModeDial:)])
		return [cameraController modesForModeDial:nil];
	return [cameraController supportedCameraModes];
}

@interface CamModeListTableDataSource : NSObject <UITableViewDataSource, UITableViewDelegate> {
	NSObject <cameraControllerDelegate> *cameraController;
	NSObject <cameraViewDelegate> *cameraView;
}
- (id)initWithCameraController:(NSObject <cameraControllerDelegate> *)newCameraController;
@property(retain, nonatomic) NSObject <cameraControllerDelegate> *cameraController;
@property(retain, nonatomic) NSObject <cameraViewDelegate> *cameraView;
@end

@implementation CamModeListTableDataSource
@synthesize cameraController;
@synthesize cameraView;

- (id)initWithCameraController:(NSObject <cameraControllerDelegate> *)newCameraController
{
	if (self == [super init]) {
		self.cameraController = newCameraController;
		self.cameraView = isiOS9Up ? nil : newCameraController.delegate;
	}
	return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
    return supportedCameraModes(self.cameraController).count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ModeIdent";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
		cell.accessoryType = UITableViewCellAccessoryNone;
    }
	cell.textLabel.font = isiOS9Up ? [UIFont cui_cameraFontOfSize:15.0f] : [UIFont cam_cameraFontOfSize:15.0f];
	cell.textLabel.textColor = [UIColor whiteColor];
	NSString *title = isiOS9Up ? [[(id)(self.cameraController) _modeDial] _titleForMode:[supportedCameraModes(self.cameraController)[indexPath.row] intValue]] : [self.cameraView modeDial:nil titleForItemAtIndex:indexPath.row];
	NSString *correctTitle = [title stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	cell.textLabel.text = correctTitle;
	cell.backgroundColor = [UIColor clearColor];
	cell.contentView.backgroundColor = [UIColor clearColor];
	_UIBackdropView *blurView = [[_UIBackdropView alloc] initWithFrame:CGRectZero autosizesToFitSuperview:YES settings:[_UIBackdropViewSettings settingsForStyle:1]];
    cell.backgroundView = blurView;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	BOOL currentMode = (cameraMode(self.cameraController) == [supportedCameraModes(self.cameraController)[indexPath.row] intValue]);
	cell.accessoryType = currentMode ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
    	cell.layoutMargins = UIEdgeInsetsZero;
    	cell.preservesSuperviewLayoutMargins = NO;
    }
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
   return 35.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSUInteger buttonIndex = indexPath.row;
	NSArray *modes = supportedCameraModes(self.cameraController);
	if (buttonIndex != modes.count) {
		if (isiOS9Up) {
			[[self.cameraController _modeDial] setSelectedMode:[modes[indexPath.row] intValue] animated:YES];
			[[self.cameraController _modeDial] sendActionsForControlEvents:0x1000];
		} else {
			NSUInteger currentIndex = [modes indexOfObject:@(cameraMode(self.cameraController))];
			if (currentIndex != buttonIndex)
				[self.cameraView _switchFromCameraModeAtIndex:currentIndex toCameraModeAtIndex:buttonIndex];
		}
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	for (NSUInteger row = 0; row < [self tableView:tableView numberOfRowsInSection:0]; row++) {
		BOOL currentMode = (row == indexPath.row);
		[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]].accessoryType = currentMode ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	}
	[popover dismissPopoverAnimated:YES options:PSCMLWYPopoverAnimationOptionFade];
}

@end

CamModeListTableDataSource *ds;

static void listTapped(UIView <cameraViewDelegate> *self, UIButton *button)
{
	vc = [UIViewController new];
	NSObject <cameraControllerDelegate> *cameraController;
	if (isiOS9Up)
		cameraController = (id)self;
	else if (%c(CAMCaptureController))
		cameraController = (CAMCaptureController *)[%c(CAMCaptureController) sharedInstance];
	else
		cameraController = (PLCameraController *)[%c(PLCameraController) sharedInstance];
	ds = [[CamModeListTableDataSource alloc] initWithCameraController:cameraController];
	tb = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
	tb.dataSource = ds;
	tb.delegate = ds;
	tb.backgroundColor = [UIColor clearColor];
	tb.separatorInset = UIEdgeInsetsZero;
	tb.scrollEnabled = NO;
	tb.allowsMultipleSelection = NO;
	[tb reloadData];
	CGFloat height = CGRectGetMaxY([tb rectForSection:[tb numberOfSections] - 1]);
	vc.view = tb;
	popover = [[PSCMLWYPopoverController alloc] initWithContentViewController:vc];
	[popover beginThemeUpdates];
	popover.theme.dimsBackgroundViewsTintColor = NO;
	popover.theme.fillTopColor = [UIColor clearColor];
	popover.theme.innerStrokeColor = [UIColor systemBlueColor];
	[popover endThemeUpdates];
	popover.wantsDefaultContentAppearance = NO;
	popover.popoverContentSize = CGSizeMake(width, height);
	[popover presentPopoverFromRect:button.bounds inView:button permittedArrowDirections:PSCMLWYPopoverArrowDirectionAny animated:YES options:PSCMLWYPopoverAnimationOptionFade];
}

static void createListButton(UIView <cameraViewDelegate> *self)
{
	CAMModeDial *modeDial = self._modeDial;
	CAMBottomBar *bottomBar = self._bottomBar;
	btn = isiOS9Up ? [%c(CUShutterButton) smallShutterButton] : [%c(CAMShutterButton) smallShutterButton];
	btn.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
	MSHookIvar<UIView *>(btn, "__innerView").backgroundColor = [UIColor systemBlueColor];
	MSHookIvar<UIView *>(btn, "__outerView").layer.borderWidth = 3.0f;
	btn.translatesAutoresizingMaskIntoConstraints = NO;
	btn.userInteractionEnabled = YES;
	[btn addTarget:self action:@selector(listTapped:) forControlEvents:UIControlEventTouchUpInside];
	UIView *backgroundView = [bottomBar respondsToSelector:@selector(backgroundView)] ? [bottomBar backgroundView] : bottomBar;
	if (modeDial == nil)
		[bottomBar insertSubview:btn aboveSubview:backgroundView];
	else
		[bottomBar insertSubview:btn aboveSubview:modeDial];
	addConstraintForDevice(self, bottomBar, backgroundView, btn, modeDial != nil);
}

static void cleanup()
{
	if (popover) {
		[popover dismissPopoverAnimated:YES];
		[popover release];
		popover = nil;
	}
	if (vc) {
		[vc release];
		vc = nil;
	}
	if (tb) {
		[tb release];
		tb = nil;
	}
}

static void _showOrHideListButtonIfNecessary(UIView <cameraViewDelegate> *self, BOOL hidden, BOOL animated)
{
	if ([btn respondsToSelector:@selector(cam_setHidden:animated:)])
		[btn cam_setHidden:hidden animated:animated];
	else if ([btn respondsToSelector:@selector(pl_setHidden:animated:)])
		[btn pl_setHidden:hidden animated:animated];
	else
		btn.hidden = hidden;
}

static void showOrHideListButtonIfNecessary(UIView <cameraViewDelegate> *self, BOOL animated)
{
	BOOL hidden = [(id)self cml_shouldHideListButtonForMode:cameraMode((id)self)];
	_showOrHideListButtonIfNecessary(self, hidden, animated);
}

%group iOS9

%hook CAMViewfinderViewController

%new
- (void)listTapped:(UIButton *)button
{
	listTapped((UIView <cameraViewDelegate> *)self, button);
}

- (void)loadView
{
	%orig;
	createListButton((UIView <cameraViewDelegate> *)self);
}

- (void)_rotateTopBarAndControlsToOrientation:(UIInterfaceOrientation)orientation shouldAnimate:(BOOL)animated
{
	%orig;
	cleanup();
}

%new
- (BOOL)_shouldEnableListButton
{
	return [self _shouldEnableModeDial];
}

%new
- (BOOL)cml_shouldHideListButtonForMode:(int)mode
{
	return [self _shouldHideModeDialForMode:mode device:self._currentDevice];
}

- (void)_updateEnabledControlsWithReason:(id)arg1 forceLog:(BOOL)log
{
	%orig;
	_showOrHideListButtonIfNecessary((UIView <cameraViewDelegate> *)self, ![self _shouldEnableListButton], YES);
}

- (void)_showControlsForMode:(int)mode device:(int)device animated:(BOOL)animated
{
	%orig;
	showOrHideListButtonIfNecessary((UIView <cameraViewDelegate> *)self, animated);
}

- (void)_hideControlsForMode:(int)mode device:(int)device animated:(BOOL)animated
{
	%orig;
	showOrHideListButtonIfNecessary((UIView <cameraViewDelegate> *)self, animated);
}

%end

%hook CAMModeDial

- (void)_commonCAMModeDialInitialization
{
	%orig;
	self.userInteractionEnabled = NO;
}

- (void)setSelectedMode:(int)mode animated:(BOOL)animated
{
	%orig;
	NSDictionary *items = MSHookIvar<NSDictionary *>(self, "__items");
	for (NSNumber *_mode in items) {
		CAMModeDialItem *item = items[_mode];
		[item cam_setHidden:![item isSelected] animated:animated];
	}
}

%end

%end

%group iOS8

%hook CAMCameraView

%new
- (void)listTapped:(UIButton *)button
{
	listTapped(self, button);
}

- (void)_createDefaultControlsIfNecessary
{
	%orig;
	createListButton(self);
}

- (void)_rotateCameraControlsAndInterface
{
	%orig;
	cleanup();
}

%new
- (BOOL)_shouldEnableListButton
{
	return [self _shouldEnableModeDial];
}

%new
- (BOOL)cml_shouldHideListButtonForMode:(int)mode
{
	return [self _shouldHideModeDialForMode:mode];
}

- (void)_updateEnabledControlsWithReason:(id)arg1 forceLog:(BOOL)log
{
	%orig;
	_showOrHideListButtonIfNecessary(self, ![self _shouldEnableListButton], YES);
}

- (void)_showControlsForCapturingVideoAnimated:(BOOL)animated
{
	%orig;
	showOrHideListButtonIfNecessary(self, animated);
}

- (void)_hideControlsForCapturingVideoAnimated:(BOOL)animated
{
	%orig;
	showOrHideListButtonIfNecessary(self, animated);
}

%end

%end

%group preiOS8

%hook PLCameraView

%new
- (void)listTapped:(UIButton *)button
{
	listTapped(self, button);
}

- (void)_createDefaultControlsIfNecessary
{
	%orig;
	createListButton(self);
}

- (void)_rotateCameraControlsAndInterface
{
	%orig;
	cleanup();
}

%new
- (BOOL)_shouldEnableListButton
{
	return [self _shouldEnableModeDial];
}

%end

%end

%group preiOS9

%hook CAMModeDial

- (void)setSelectedIndex:(NSUInteger)index animated:(BOOL)animated
{
	%orig;
	if (self.orientation == 0) {
		NSMutableArray *items = self._items;
		for (NSUInteger itemIndex = 0; itemIndex < items.count; itemIndex++) {
			CAMModeDialItem *item = items[itemIndex];
			BOOL hidden = (itemIndex != index);
			if ([item respondsToSelector:@selector(cam_setHidden:animated:)])
				[item cam_setHidden:hidden animated:animated];
			else if ([item respondsToSelector:@selector(pl_setHidden:animated:)])
				[item pl_setHidden:hidden animated:animated];
			else
				item.hidden = hidden;
		}
	}
}

%end

%end

static void reloadSettings(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	CFPreferencesAppSynchronize(CFSTR("com.PS.CamModeList"));
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
	tweakEnabled = prefs[tweakKey] ? [prefs[tweakKey] boolValue] : YES;
}

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &reloadSettings, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	reloadSettings(NULL, NULL, NULL, NULL, NULL);
	%init;
	if (isiOS9Up) {
		%init(iOS9);
	} else {
		%init(preiOS9);
		if (isiOS8) {
			%init(iOS8);
		} else {
			%init(preiOS8);
		}
	}
  	[pool drain];
}