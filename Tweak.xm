#import "../PS.h"
#import "WYPopoverController.h"

NSString *const tweakKey = @"tweakEnabled";
NSString *const PREF_PATH = @"/var/mobile/Library/Preferences/com.PS.CamModeList.plist";
CFStringRef const PreferencesNotification = CFSTR("com.PS.CamModeList.prefs");
BOOL tweakEnabled;

/*%hook CAMCameraView

- (BOOL)_isSwipeToModeSwitchAllowed
{
	return NO;
}

- (void)_setSwipeToModeSwitchEnabled:(BOOL)enabled
{
	%orig(NO);
}

%end*/

UIViewController *vc;
UITableView *tb;
WYPopoverController *popover;

@interface CamModeListTableDataSource : NSObject <UITableViewDataSource, UITableViewDelegate> {
	id <cameraControllerDelegate> cameraController;
	id <cameraViewDelegate> cameraView;
}
- (id)initWithCameraController:(id <cameraControllerDelegate>)newCameraController;
@property id <cameraControllerDelegate> cameraController;
@property id <cameraViewDelegate> cameraView;
@end

@implementation CamModeListTableDataSource
@synthesize cameraController;
@synthesize cameraView;

- (id)initWithCameraController:(id <cameraControllerDelegate>)newCameraController
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
	cell.textLabel.font = [UIFont fontWithName:@"Bold" size:20.0f];
	cell.textLabel.textColor = [UIColor whiteColor];
	NSString *title = [self.cameraView modeDial:self.cameraView._modeDial titleForItemAtIndex:indexPath.row];
	cell.textLabel.text = title;
	cell.backgroundColor = [UIColor clearColor];
	cell.contentView.backgroundColor = [UIColor clearColor];
	_UIBackdropView *blurView = [[_UIBackdropView alloc] initWithFrame:CGRectZero autosizesToFitSuperview:YES settings:[_UIBackdropViewSettings settingsForStyle:1]];
    cell.backgroundView = blurView;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	BOOL currentMode = self.cameraController.cameraMode == [[self.cameraController supportedCameraModes][indexPath.row] intValue];
	cell.accessoryType = currentMode ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
    	cell.layoutMargins = UIEdgeInsetsZero;
    	cell.preservesSuperviewLayoutMargins = NO;
    }
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSUInteger buttonIndex = indexPath.row;
	if (buttonIndex != [self.cameraController supportedCameraModes].count) {
		NSUInteger currentIndex = self.cameraView._modeDial.selectedIndex;
		if (currentIndex != buttonIndex)
			[self.cameraView _switchFromCameraModeAtIndex:currentIndex toCameraModeAtIndex:buttonIndex];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	for (NSUInteger row = 0; row < [self tableView:tableView numberOfRowsInSection:0]; row++) {
		[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]].accessoryType = row == indexPath.row ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	}
	[popover dismissPopoverAnimated:YES];
}

- (void)popoverController:(WYPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
	[popoverController dismissPopoverAnimated:NO];
}

@end

CamModeListTableDataSource *ds;

static void listTapped(id <cameraViewDelegate> self, UIButton *button)
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
	NSUInteger currentIndex = self._modeDial.selectedIndex;
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentIndex inSection:0];
	tb.allowsMultipleSelection = NO;
	[tb reloadData];
	[tb cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
	CGFloat height = CGRectGetMaxY([tb rectForSection:[tb numberOfSections] - 1]);
	vc.view = tb;
	popover = [[WYPopoverController alloc] initWithContentViewController:vc];
	[popover beginThemeUpdates];
	popover.theme.dimsBackgroundViewsTintColor = NO;
	popover.theme.fillTopColor = [UIColor clearColor];
	popover.theme.fillBottomColor = [UIColor systemYellowColor];
	popover.theme.innerStrokeColor = [UIColor systemYellowColor];
	[popover endThemeUpdates];
	popover.wantsDefaultContentAppearance = NO;
	popover.popoverContentSize = CGSizeMake(200.0f, height);
	[popover presentPopoverFromRect:button.bounds inView:button permittedArrowDirections:WYPopoverArrowDirectionAny animated:YES];
}

static void createListButton(NSObject <cameraViewDelegate> *self)
{
	CAMModeDial *modeDial = self._modeDial;
	CAMBottomBar *bottomBar = self._bottomBar;
	UIButton *btn = (UIButton *)[%c(CAMShutterButton) smallShutterButton];
	btn.transform = CGAffineTransformMakeScale(0.5f, 0.5f);
	MSHookIvar<UIView *>(btn, "__innerView").backgroundColor = [UIColor systemYellowColor];
	MSHookIvar<UIView *>(btn, "__outerView").layer.borderWidth = 3.0f;
	btn.translatesAutoresizingMaskIntoConstraints = NO;
	btn.userInteractionEnabled = YES;
	[btn addTarget:self action:@selector(listTapped:) forControlEvents:UIControlEventTouchUpInside];
	if (modeDial == nil)
		[bottomBar insertSubview:btn aboveSubview:[bottomBar respondsToSelector:@selector(backgroundView)] ? [bottomBar backgroundView] : bottomBar];
	else
		[bottomBar insertSubview:btn aboveSubview:modeDial];
	NSLayoutConstraint *rightInset = [NSLayoutConstraint constraintWithItem:btn attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:bottomBar attribute:NSLayoutAttributeRight multiplier:1.0 constant:-55.0f];
	NSLayoutConstraint *topInset = [NSLayoutConstraint constraintWithItem:btn attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:bottomBar attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.5f];
	//NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:btn attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:bottomBar attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0f];
	//[bottomBar addConstraints:@[rightInset, centerY]];
	[bottomBar addConstraints:@[rightInset, topInset]];
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

%end

%end

%hook CAMModeDial

/*- (void)touchesEnded:(id)arg1 withEvent:(id)arg2
{

}*/

- (void)setSelectedIndex:(NSUInteger)index animated:(BOOL)animated
{
	%orig;
	NSMutableArray *items = self._items;
	for (NSUInteger itemIndex = 0; itemIndex < items.count; itemIndex++) {
		CAMModeDialItem *item = items[itemIndex];
		item.alpha = itemIndex != index ? 0.0f : 1.0f;
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
	@autoreleasepool {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &reloadSettings, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
		reloadSettings(NULL, NULL, NULL, NULL, NULL);
		%init;
		if (isiOS8Up) {
			%init(iOS8);
		} else {
			%init(preiOS8);
		}
  	}
}
