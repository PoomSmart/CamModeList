#import "../PS.h"
#import "PSCMLWYPopoverController.h"

@interface UIFont (Camera)
+ (UIFont *)cam_cameraFontOfSize:(CGFloat)size;
@end

NSString *const tweakKey = @"tweakEnabled";
NSString *const PREF_PATH = @"/var/mobile/Library/Preferences/com.PS.CamModeList.plist";
CFStringRef const PreferencesNotification = CFSTR("com.PS.CamModeList.prefs");
BOOL tweakEnabled;

CGFloat width = 180.0f;

static void addConstraintForDevice(NSObject <cameraViewDelegate> *cameraView, CAMBottomBar *bottomBar, UIView *backgroundView, UIView *btn, BOOL hasModeDial)
{
	if (cameraView.spec.modeDialOrientation != 0) {
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
		self.cameraView = newCameraController.delegate;
	}
	return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
    return [self.cameraController supportedCameraModes].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ModeIdent";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
		cell.accessoryType = UITableViewCellAccessoryNone;
    }
	cell.textLabel.font = [UIFont cam_cameraFontOfSize:15.0f];
	cell.textLabel.textColor = [UIColor whiteColor];
	NSString *title = [self.cameraView modeDial:nil titleForItemAtIndex:indexPath.row];
	NSString *correctTitle = [title stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	cell.textLabel.text = correctTitle;
	cell.backgroundColor = [UIColor clearColor];
	cell.contentView.backgroundColor = [UIColor clearColor];
	_UIBackdropView *blurView = [[_UIBackdropView alloc] initWithFrame:CGRectZero autosizesToFitSuperview:YES settings:[_UIBackdropViewSettings settingsForStyle:1]];
    cell.backgroundView = blurView;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	BOOL currentMode = (self.cameraController.cameraMode == [[self.cameraController supportedCameraModes][indexPath.row] intValue]);
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
	NSArray *modes = [self.cameraController supportedCameraModes];
	if (buttonIndex != modes.count) {
		NSUInteger currentIndex = [modes indexOfObject:@(self.cameraController.cameraMode)];
		if (currentIndex != buttonIndex)
			[self.cameraView _switchFromCameraModeAtIndex:currentIndex toCameraModeAtIndex:buttonIndex];
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

static void listTapped(NSObject <cameraViewDelegate> *self, UIButton *button)
{
	vc = [UIViewController new];
	NSObject <cameraControllerDelegate> *cameraController = %c(CAMCaptureController) ? (CAMCaptureController *)[%c(CAMCaptureController) sharedInstance] : (PLCameraController *)[%c(PLCameraController) sharedInstance];
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

static void createListButton(NSObject <cameraViewDelegate> *self)
{
	CAMModeDial *modeDial = self._modeDial;
	CAMBottomBar *bottomBar = self._bottomBar;
	btn = [%c(CAMShutterButton) smallShutterButton];
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

%end

%end

%hook CAMModeDial

- (void)setSelectedIndex:(NSUInteger)index animated:(BOOL)animated
{
	%orig;
	if (self.orientation == 0) {
		NSMutableArray *items = self._items;
		for (NSUInteger itemIndex = 0; itemIndex < items.count; itemIndex++) {
			CAMModeDialItem *item = items[itemIndex];
			if (isiOS8Up)
				[item cam_setHidden:itemIndex != index animated:animated];
			else
				[item pl_setHidden:itemIndex != index animated:animated];
		}
	}
}

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
	if (isiOS8Up) {
		%init(iOS8);
	} else {
		%init(preiOS8);
	}
  	[pool drain];
}
