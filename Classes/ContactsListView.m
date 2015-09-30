/* ContactsViewController.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "PhoneMainView.h"
#import <AddressBook/ABPerson.h>

@implementation ContactSelection

static ContactSelectionMode sSelectionMode = ContactSelectionModeNone;
static NSString *sAddAddress = nil;
static NSString *sSipFilter = nil;
static BOOL sEnableEmailFilter = FALSE;
static NSString *sNameOrEmailFilter;

+ (void)setSelectionMode:(ContactSelectionMode)selectionMode {
	sSelectionMode = selectionMode;
}

+ (ContactSelectionMode)getSelectionMode {
	return sSelectionMode;
}

+ (void)setAddAddress:(NSString *)address {
	if (sAddAddress != nil) {
		sAddAddress = nil;
	}
	if (address != nil) {
		sAddAddress = address;
	}
}

+ (NSString *)getAddAddress {
	return sAddAddress;
}

+ (void)setSipFilter:(NSString *)domain {
	sSipFilter = domain;
}

+ (NSString *)getSipFilter {
	return sSipFilter;
}

+ (void)enableEmailFilter:(BOOL)enable {
	sEnableEmailFilter = enable;
}

+ (BOOL)emailFilterEnabled {
	return sEnableEmailFilter;
}

+ (void)setNameOrEmailFilter:(NSString *)fuzzyName {
	sNameOrEmailFilter = fuzzyName;
}

+ (NSString *)getNameOrEmailFilter {
	return sNameOrEmailFilter;
}

@end

@implementation ContactsListView

@synthesize tableController;
@synthesize allButton;
@synthesize linphoneButton;
@synthesize backButton;
@synthesize addButton;
@synthesize topBar;

typedef enum _HistoryView { History_All, History_Linphone, History_Search, History_MAX } HistoryView;

#pragma mark - Lifecycle Functions

- (id)init {
	return [super initWithNibName:NSStringFromClass(self.class) bundle:[NSBundle mainBundle]];
}

#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription {
	if (compositeDescription == nil) {
		compositeDescription = [[UICompositeViewDescription alloc] init:self.class
															  statusBar:StatusBarView.class
																 tabBar:TabBarView.class
															 fullscreen:false
														  landscapeMode:LinphoneManager.runningOnIpad
														   portraitMode:true];
	}
	return compositeDescription;
}

- (UICompositeViewDescription *)compositeViewDescription {
	return self.class.compositeViewDescription;
}

#pragma mark - ViewController Functions

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

- (void)relayoutTableView {
	CGRect subViewFrame = self.view.frame;
	// let the top bar be visible
	subViewFrame.origin.y += self.topBar.frame.size.height;
	subViewFrame.size.height -= self.topBar.frame.size.height;
	[UIView animateWithDuration:0.2
					 animations:^{
					   self.tableController.tableView.frame = subViewFrame;
					 }];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	_searchBar.showsCancelButton = (_searchBar.text.length > 0);
	CGRect frame = _searchBar.frame;
	frame.origin.y = topBar.frame.origin.y + topBar.frame.size.height;
	_searchBar.frame = frame;

	[self update];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (![FastAddressBook isAuthorized]) {
		UIAlertView *error = [[UIAlertView alloc]
				initWithTitle:NSLocalizedString(@"Address book", nil)
					  message:NSLocalizedString(@"You must authorize the application to have access to address book.\n"
												 "Toggle the application in Settings > Privacy > Contacts",
												nil)
					 delegate:nil
			cancelButtonTitle:NSLocalizedString(@"Continue", nil)
			otherButtonTitles:nil];
		[error show];
		[PhoneMainView.instance changeCurrentView:DialerView.compositeViewDescription];
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self changeView:History_All];
}

#pragma mark -

- (void)changeView:(HistoryView)view {
	if (view == History_All) {
		[ContactSelection setSipFilter:nil];
		[ContactSelection enableEmailFilter:FALSE];
		[tableController loadData];
		allButton.selected = TRUE;
	} else {
		allButton.selected = FALSE;
	}

	if (view == History_Linphone) {
		[ContactSelection setSipFilter:[LinphoneManager instance].contactFilter];
		[ContactSelection enableEmailFilter:FALSE];
		[tableController loadData];
		linphoneButton.selected = TRUE;
	} else {
		linphoneButton.selected = FALSE;
	}
}

- (void)refreshButtons {
	switch ([ContactSelection getSelectionMode]) {
		case ContactSelectionModePhone:
		case ContactSelectionModeMessage:
			[addButton setHidden:TRUE];
			[backButton setHidden:FALSE];
			break;
		default:
			[addButton setHidden:FALSE];
			[backButton setHidden:TRUE];
			break;
	}
	if ([ContactSelection getSipFilter]) {
		allButton.selected = FALSE;
		linphoneButton.selected = TRUE;
	} else {
		allButton.selected = TRUE;
		linphoneButton.selected = FALSE;
	}
}

- (void)update {
	[self refreshButtons];
	[tableController loadData];
}

#pragma mark - Action Functions

- (IBAction)onAllClick:(id)event {
	[self changeView:History_All];
}

- (IBAction)onLinphoneClick:(id)event {
	[self changeView:History_Linphone];
}

- (IBAction)onAddContactClick:(id)event {
	// Go to Contact details view
	ContactDetailsView *view = VIEW(ContactDetailsView);
	[PhoneMainView.instance changeCurrentView:view.compositeViewDescription push:TRUE];
	if ([ContactSelection getAddAddress] == nil) {
		[view newContact];
	} else {
		[view newContact:[ContactSelection getAddAddress]];
	}
}

- (IBAction)onBackClick:(id)event {
	[PhoneMainView.instance popCurrentView];
}

- (IBAction)onEditClick:(id)sender {
	[tableController setEditing:!tableController.isEditing animated:TRUE];
	_deleteButton.hidden = !tableController.isEditing;
	addButton.hidden = !_deleteButton.hidden;
}

- (IBAction)onDeleteClick:(id)sender {
	NSString *msg =
		[NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to delete %d contacts?", nil),
								   tableController.selectedItems.count];
	[UIConfirmationDialog ShowWithMessage:msg
							onCancelClick:nil
					  onConfirmationClick:^() {
						[tableController removeSelection];
						[tableController loadData];
					  }];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[self searchBar:searchBar textDidChange:@""];
	[searchBar resignFirstResponder];
}

#pragma mark - Rotation handling

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	// the searchbar overlaps the subview in most rotation cases, we have to re-layout the view manually:
	[self relayoutTableView];
}

#pragma mark - ABPeoplePickerDelegate

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
	[PhoneMainView.instance popCurrentView];
	return;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	return true;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person
								property:(ABPropertyID)property
							  identifier:(ABMultiValueIdentifier)identifier {

	CFTypeRef multiValue = ABRecordCopyValue(person, property);
	CFIndex valueIdx = ABMultiValueGetIndexForIdentifier(multiValue, identifier);
	NSString *phoneNumber = (NSString *)CFBridgingRelease(ABMultiValueCopyValueAtIndex(multiValue, valueIdx));
	// Go to dialer view
	DialerView *view = VIEW(DialerView);
	[PhoneMainView.instance changeCurrentView:view.compositeViewDescription];
	[view call:phoneNumber displayName:(NSString *)CFBridgingRelease(ABRecordCopyCompositeName(person))];
	CFRelease(multiValue);
	return false;
}

#pragma mark - searchBar delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	// display searchtext in UPPERCASE
	// searchBar.text = [searchText uppercaseString];
	searchBar.showsCancelButton = (searchText.length > 0);
	[ContactSelection setNameOrEmailFilter:searchText];
	[tableController loadData];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:FALSE animated:TRUE];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:TRUE animated:TRUE];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)viewDidUnload {
	[self setTopBar:nil];
	[super viewDidUnload];
}
@end