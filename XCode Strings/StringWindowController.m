//
//  StringWindowController.m
//  StringManage
//
//  Created by kiwik on 1/13/16.
//  Copyright © 2016 Kiwik. All rights reserved.
//

#import "StringWindowController.h"
#import "StringModel.h"
#import "PreferencesWindowController.h"
#import "StringSetting.h"
#import "StringInfoViewController.h"
#import "NSButton+Extension.h"
#import "NSString+Extension.h"
#import "StringEditViewController.h"
#import "utils.h"
#import "NSTimer+GCD.h"

#define kStrKey @"key"
#define kRemove @"remove"
#define kInfo @"info"

#define kFont [NSFont systemFontOfSize:11]

@interface StringWindowController()

@property (nonatomic, strong)IBOutlet NSTableView *tableview;
@property (weak) IBOutlet NSButton *refreshBtn;
@property (weak) IBOutlet NSButton *saveBtn;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *tipsLabel;
@property (weak) IBOutlet NSTextField *recordLabel;
@property (weak) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSButton *addBtn;
@property (weak) IBOutlet NSButton *CheckBtn;
@property (weak) IBOutlet NSProgressIndicator *checkIndicator;
@property (weak) IBOutlet NSButton *showOnlyBtn;
@property (weak) IBOutlet NSButton *untranslatedBtn;
@property (weak) IBOutlet NSButton *unusedBtn;
@property (weak) IBOutlet NSButton *exportXMLBtn;

@property (nonatomic, strong) NSMutableArray *stringArray;
@property (nonatomic, strong) NSMutableArray *keyArray;
@property (nonatomic, strong) NSMutableArray *actionArray;
@property () PreferencesWindowController* prefsController;
@property (nonatomic, strong) NSArray *showArray;
@property (nonatomic, copy) NSString* projectPath;
@property (nonatomic, copy) NSString* projectName;
@property (nonatomic, strong) NSMutableDictionary* infoDict;
@property (nonatomic) BOOL isRefreshing;
@property (nonatomic, strong) NSMutableDictionary* keyDict;
@property (nonatomic) BOOL isChecking;
@property (nonatomic, strong) NSPopover* editPopOver;
@property (nonatomic, strong) NSPopover* infoPopOver;
@property (nonatomic) NSInteger selectedRow;
@property (nonatomic, strong) NSString *sortingCol;
@property (nonatomic) BOOL ascending;
@property (nonatomic, strong) NSMutableDictionary *columnTitleDict;

- (IBAction)addAction:(id)sender;
- (IBAction)saveAction:(id)sender;
- (IBAction)searchAnswer:(id)sender;
- (IBAction)checkAction:(id)sender;
@end

@implementation StringWindowController

#pragma mark - override

-(instancetype)init{
    if(self = [super initWithWindowNibName:@"StringWindowController"]) {
        //perform any initializations
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib {
    self.prefsController = [[PreferencesWindowController alloc] init];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self.window setTitle:@"XCode Strings"];
    self.window.level = NSNormalWindowLevel;
    self.window.movableByWindowBackground = YES;
    self.window.hidesOnDeactivate = NO;
    
    self.sortingCol = kStrKey;
    self.ascending = YES;
    
    self.columnTitleDict = [[NSMutableDictionary alloc] init];
    self.actionArray=[[NSMutableArray alloc]init];
    self.stringArray = [[NSMutableArray alloc]init];
    self.keyArray = [[NSMutableArray alloc]init];
    self.infoDict = [[NSMutableDictionary alloc]init];
    self.keyDict = [[NSMutableDictionary alloc]init];
    
    self.tableview.delegate = self;
    self.tableview.dataSource = self;
    self.tableview.action = @selector(cellClicked:);//点击编辑
    self.tableview.doubleAction = @selector(doubleAction:);//双击撤销修改
    [self.window makeFirstResponder:self.tableview];
    
    [self.showOnlyBtn setTitle:NSLocalizedString(@"OnlyShowModified", nil)];
    [self.untranslatedBtn setTitle:NSLocalizedString(@"Untranslated", nil)];
    [self.unusedBtn setTitle:NSLocalizedString(@"Unused", nil)];
    [self.searchField setPlaceholderString:NSLocalizedString(@"Search", nil)];
    [self.saveBtn setTitle:NSLocalizedString(@"Save", nil)];
    [self.refreshBtn setTitle:NSLocalizedString(@"Refresh", nil)];
    [self.CheckBtn setTitle:NSLocalizedString(@"Check", nil)];
    [self.tipsLabel setStringValue:NSLocalizedString(@"UseTips", nil)];
    [self.addBtn setTitle:NSLocalizedString(@"Add", nil)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(projectSettingChanged:)  name:kNotifyProjectSettingChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:self];
}

#pragma mark - Private
- (void)setSearchRootDir:(NSString*)searchRootDir projectName:(NSString*)projectName {
    self.projectPath = searchRootDir;
    self.projectName = projectName;
    self.prefsController.projectPath = searchRootDir;
    self.prefsController.projectName = projectName;
}

-(void)setIsRefreshing:(BOOL)isRefreshing {
    _isRefreshing = isRefreshing;
    [self.refreshBtn setEnabled:!isRefreshing];
    [self.addBtn setEnabled:!isRefreshing];
    if(isRefreshing)
        [self.progressIndicator startAnimation:nil];
    else
        [self.progressIndicator stopAnimation:nil];
}

-(void)setIsChecking:(BOOL)isChecking{
    _isChecking = isChecking;
    [self.refreshBtn setEnabled:!isChecking];
    [self.addBtn setEnabled:!isChecking];
    [self.CheckBtn setEnabled:!isChecking];
    [self.checkIndicator setHidden:!isChecking];
    if(isChecking)
        [self.checkIndicator startAnimation:nil];
    else
        [self.checkIndicator stopAnimation:nil];
}

-(void)refreshTableView {
    NSArray *columns = [self.tableview.tableColumns copy];
    for (NSTableColumn *column in columns) {
        [self.tableview removeTableColumn:column];
    }
    
    float columnWidth = (self.tableview.bounds.size.width - 160.0)/(_stringArray.count+1);
    
    NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:kStrKey];
    self.columnTitleDict[kStrKey] = kStrKey;
    [column setWidth:columnWidth];
    [self.tableview addTableColumn:column];
    
    for (StringModel *model in _stringArray) {
        NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:model.identifier];
        self.columnTitleDict[model.identifier] = model.identifier;
        [column setWidth:columnWidth];
        [self.tableview addTableColumn:column];
    }
    
    NSTableColumn * lastcolumn = [[NSTableColumn alloc] initWithIdentifier:kRemove];
    self.columnTitleDict[kRemove] = NSLocalizedString(@"Remove", nil);
    [lastcolumn setWidth:80];
    [lastcolumn setMinWidth:60];
    [lastcolumn setMaxWidth:100];
    [self.tableview addTableColumn:lastcolumn];
    NSTableColumn * infocolumn = [[NSTableColumn alloc] initWithIdentifier:kInfo];
    self.columnTitleDict[kInfo] = NSLocalizedString(@"FoundNum", nil);
    [infocolumn setWidth:80];
    [infocolumn setMinWidth:60];
    [infocolumn setMaxWidth:100];
    [self.tableview addTableColumn:infocolumn];
    
    [self refreshTableColumn];
    [self searchAnswer:nil];
}

-(void)refreshTableColumn{
    NSArray *columns = [NSArray arrayWithArray:self.tableview.tableColumns];
    for (NSTableColumn *column in columns) {
        NSString *cid = column.identifier;
        if ([cid isEqualToString:_sortingCol]) {
            column.title = [NSString stringWithFormat:@"%@ %@", self.columnTitleDict[cid], _ascending?@"▲":@"▼"];
        } else{
            column.title = self.columnTitleDict[cid];
        }
    }
}

-(NSString*)titleWithKey:(NSString*)key identifier:(NSString*)identifier {
    if(key.length==0 || identifier.length == 0)
        return @"";
    if([identifier isEqualToString:kStrKey]) {
        return key;
    }
    ActionModel *action = [self findActionWith:key identify:identifier];
    if(action){
        return action.value.length==0 ? @"" : action.value;
    }
    return [self valueInRaw:key identifier:identifier];
}

-(NSString*)valueInRaw:(NSString*)key identifier:(NSString*)identifier {
    if([identifier isEqualToString:kStrKey]) {
        return key;
    }
    StringModel *model = [self findStringModelWithIdentifier:identifier];
    if(model){
        NSString *value = model.stringDictionary[key];
        return value.length==0 ? @"" : value;
    }
    return @"";
}

-(ActionModel *)findActionWith:(NSString*)key identify:(NSString*)identify {
    for (ActionModel *model in _actionArray) {
        if([model.key isEqualToString:key] && [model.identifier isEqualToString:identify]){
            return model;
        }
    }
    return nil;
}

-(StringModel*)findStringModelWithIdentifier:(NSString*)identifier {
    for (StringModel *model in _stringArray) {
        if([model.identifier isEqualToString:identifier]){
            return model;
        }
    }
    return nil;
}

-(BOOL)validateKey:(NSString*)key {
    if([key isBlank])
        return NO;
    if([_keyArray containsObject:key]) {
        NSAlert *alert = [[NSAlert alloc]init];
        [alert setMessageText: NSLocalizedString(@"InputIsExist", nil)];
        [alert addButtonWithTitle: NSLocalizedString(@"OK", nil)];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return NO;
    }
    StringSetting *setting = [StringModel projectSettingByProjectPath:self.projectPath projectName:self.projectName];
    if (setting.language == swift) {
        NSString *regex = @"[_a-zA-Z][_a-zA-Z0-9]*";
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
        return [predicate evaluateWithObject:key];
    }
    return YES;
}

-(void)changeWithKey:(NSString*)key identifier:(NSString*)identifier newValue:(NSString*)newValue {
    NSString *rawValue = [self valueInRaw:key identifier:identifier];
    NSString *oldValue = [self titleWithKey:key identifier:identifier];
    if([oldValue isEqualToString:newValue])
        return;
    ActionType type = (newValue.length==0) ? ActionTypeRemove:ActionTypeAdd;
    NSString *value = (newValue.length==0) ? rawValue : newValue;
    ActionModel *action = [self findActionWith:key identify:identifier];
    if(action){
        if([rawValue isEqualToString:newValue]){
            [_actionArray removeObject:action];
        } else{
            action.actionType = type;
            action.value = value;
        }
    } else {
        ActionModel *action = [[ActionModel alloc]initWithType:type key:key identifier:identifier value:value];
        [_actionArray addObject:action];
    }
    [self searchAnswer:nil];
}

- (void)showPreferencesPanel:(id)sender {
    if(self.isRefreshing || self.isChecking)
        return;
    [self.prefsController loadWindow];
    NSRect windowFrame = [[self window] frame], prefsFrame = [[self.prefsController window] frame];
    prefsFrame.origin = NSMakePoint(windowFrame.origin.x + (windowFrame.size.width - prefsFrame.size.width) / 2.0,
                                    NSMaxY(windowFrame) - NSHeight(prefsFrame) - 20.0);
    [[self.prefsController window] setFrame:prefsFrame display:NO];
    [self.prefsController showWindow:sender];
}

- (IBAction)refresh:(id)sender {
    self.isRefreshing = YES;
    [_actionArray removeAllObjects];
    [self.saveBtn setEnabled:NO];
    
    [NSTimer backgroundTask:^{
        StringSetting *setting = [StringModel projectSettingByProjectPath:self.projectPath projectName:self.projectName];
        NSArray *lprojDirectorys = [StringModel lprojDirectoriesWithProjectSetting:setting project:self.projectPath];
        if (lprojDirectorys.count == 0) {
            [NSTimer mainTask:^{
                NSAlert *alert = [[NSAlert alloc]init];
                [alert setMessageText: NSLocalizedString(@"NoLocalizedFiles", nil)];
                [alert addButtonWithTitle: NSLocalizedString(@"OK", nil)];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                    self.isRefreshing = NO;
                }];
            }];
        } else {
            [self.stringArray removeAllObjects];
            [self.keyArray removeAllObjects];
            [self.keyDict removeAllObjects];
            
            NSMutableSet *keySet = [NSMutableSet set];
            for (NSString *path in lprojDirectorys) {
                StringModel *model = [[StringModel alloc]initWithPath:path projectSetting:setting];
                if (model) {
                    [self.stringArray addObject:model];
                    NSSet *set = [NSSet setWithArray:model.stringDictionary.allKeys];
                    [keySet unionSet:set];
                }
            }
            
            NSArray *tmp = [[NSArray alloc]initWithArray:keySet.allObjects];
            NSArray *sortedArray = [tmp sortedArrayUsingSelector:@selector(compare:)];
            [self.keyArray addObjectsFromArray:sortedArray];
            
            [NSTimer mainTask:^{
                [self refreshTableView];
                self.isRefreshing = NO;
            }];
        }
    }];
}

- (IBAction)searchAnswer:(id)sender {
    NSSet *keys = [NSSet setWithArray:[self.infoDict allKeys]];
    NSMutableSet *set1 = [[NSMutableSet alloc] initWithArray:_keyArray];
    [set1 unionSet:keys];
    
    NSString *searchString = _searchField.stringValue;
    NSMutableArray *tmp2 = [NSMutableArray array];
    if(self.showOnlyBtn.state){
        for (ActionModel *model in _actionArray) {
            if (![tmp2 containsObject:model.key]) {
                [tmp2 addObject:model.key];
            }
        }
    }else{
        [tmp2 addObjectsFromArray:[set1 allObjects]];
    }
    
    for (NSString *string in [tmp2 copy]) {
        if(self.unusedBtn.state){
            NSArray *arr = self.infoDict[string];
            if (arr.count > 0) {
                [tmp2 removeObject:string];
            }
        }
        BOOL exist = YES;
        BOOL found = searchString.length==0 || [string contain:searchString];
        for (StringModel *model in _stringArray) {
            NSString *str2 = model.stringDictionary[string];
            ActionModel *action = [self findActionWith:string identify:model.identifier];
            exist &= str2.length || (action && action.value.length);
            found |= [str2 contain:searchString] || (action && [action.value contain:searchString]);
        }
        if (!found || (found && self.untranslatedBtn.state && exist)) {
            [tmp2 removeObject:string];
        }
    }
    
    if ([kStrKey isEqualToString:_sortingCol] || [kRemove isEqualToString:_sortingCol]){
        self.showArray = [tmp2 sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return _ascending ? [obj1 compare:obj2] : [obj2 compare:obj1];
        }];
    } else if ([kInfo isEqualToString:_sortingCol]){
        self.showArray = [tmp2 sortedArrayUsingComparator:^NSComparisonResult(NSString * _Nonnull key1, NSString * _Nonnull key2) {
            NSArray *items1 = self.infoDict[key1];
            NSArray *items2 = self.infoDict[key2];
            return _ascending ? items1.count - items2.count : items2.count - items1.count;
        }];
    } else {
        self.showArray = [tmp2 sortedArrayUsingComparator:^NSComparisonResult(NSString * _Nonnull key1, NSString * _Nonnull key2) {
            NSString *rawValue1 = [self titleWithKey:key1 identifier:_sortingCol];
            NSString *rawValue2 = [self titleWithKey:key2 identifier:_sortingCol];
            return _ascending ? [rawValue1 compare:rawValue2] : [rawValue2 compare:rawValue1];
        }];
    }
    
    self.recordLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"RecordNumMsg", nil),self.showArray.count];
    [self.saveBtn setEnabled:(_actionArray.count>0 && !self.isChecking)];
    [self.tableview reloadData];
}

- (IBAction)checkAction:(id)sender {
    if(self.showArray.count==0)
        return;
    
    self.isChecking = YES;
    [self.infoDict removeAllObjects];
    [self searchAnswer:nil];
    
    __weak __typeof(self) weakSelf = self;
    [NSTimer backgroundTask:^{
        StringSetting *settings = [StringModel projectSettingByProjectPath:weakSelf.projectPath projectName:weakSelf.projectName];
        NSDictionary *dict = [StringModel findItemsWithProjectSetting:settings projectPath:weakSelf.projectPath findStrings:weakSelf.showArray block:^(float progress) {
            [NSTimer mainTask:^{
                weakSelf.checkIndicator.doubleValue = progress;
            }];
        }];
        [NSTimer mainTask:^{
            weakSelf.isChecking=NO;
            [weakSelf.infoDict addEntriesFromDictionary:dict];
            [weakSelf searchAnswer:nil];
        }];
    }];
}

- (IBAction)addAction:(id)sender {
    NSAlert *alert = [[NSAlert alloc]init];
    [alert setMessageText: NSLocalizedString(@"InputKeyMsg", nil)];
    [alert addButtonWithTitle: NSLocalizedString(@"OK", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
    [alert setAccessoryView:input];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode == NSAlertFirstButtonReturn) {
            NSString *text = input.stringValue;
            if(![self validateKey:text])
                return;
            [_keyArray addObject:text];
            [_keyDict setObject:@(KeyTypeAdd) forKey:text];
            
            for (StringModel *model in _stringArray) {
                ActionModel *action = [[ActionModel alloc]initWithType:ActionTypeAdd key:text identifier:model.identifier value:@""];
                [_actionArray addObject:action];
            }
            
            [self.searchField setStringValue:@""];
            [self searchAnswer:nil];
            
            [_tableview scrollRowToVisible:[_showArray indexOfObject:text]];
        }
    }];
}

- (IBAction)saveAction:(id)sender {
    if(_actionArray.count==0)
        return;
    StringSetting *setting = [StringModel projectSettingByProjectPath:self.projectPath projectName:self.projectName];
    for (StringModel *model in _stringArray) {
        NSPredicate *predicte = [NSPredicate predicateWithFormat:@"identifier == %@",model.identifier];
        NSArray *arr = [self.actionArray filteredArrayUsingPredicate:predicte];
        [model doAction:arr projectSetting:setting];
    }
    [_actionArray removeAllObjects];
    
    [self refresh:nil];
}

- (IBAction)exportXMLAction:(id)sender {
    [utils exportXML:self.projectName stringArray:_stringArray];
}

-(void)cellClicked:(id)sender {
    if (self.isChecking)
        return;
    
    NSInteger column = _tableview.clickedColumn;
    NSInteger row = _tableview.clickedRow;
    if (_selectedRow != row) {
        self.selectedRow = row;
    } else {
        if(column <= 0 || column > self.stringArray.count + 1)
            return;
        if(row < 0 || row > self.showArray.count)
            return;
        NSString *key = _showArray[row];
        NSInteger status = [_keyDict[key] integerValue];
        if(status == KeyTypeRemove) {
            return;
        }
        StringModel *smodel = _stringArray[column-1];
        NSString *identifier = smodel.identifier;
        if (self.infoPopOver && self.infoPopOver.isShown) {
            [self.infoPopOver close],self.infoPopOver = nil;
        }
        if (self.editPopOver && self.editPopOver.isShown) {
            StringEditViewController *editVC = (StringEditViewController*)[self.editPopOver contentViewController];
            [self.editPopOver close],self.editPopOver = nil;
            if ([key isEqualToString:editVC.key] && [identifier isEqualToString:editVC.identifier]) {
                return;
            }
        }
        __weak __typeof(self) weakSelf = self;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.3f * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            NSString *title = nil;
            ActionModel *action = [weakSelf findActionWith:key identify:identifier];
            if(action){
                title = action.actionType==ActionTypeRemove ? @"" : action.value;
            } else {
                title = [weakSelf valueInRaw:key identifier:identifier];
            }
            StringEditViewController* viewController = [[StringEditViewController alloc] initWithKey:key identifier:identifier value:title];
            [viewController setFinishBlock:^{
                if (weakSelf.editPopOver && weakSelf.editPopOver.isShown) {
                    [weakSelf.editPopOver close],weakSelf.editPopOver = nil;
                }
            }];
            weakSelf.editPopOver = [[NSPopover alloc] init];
            weakSelf.editPopOver.delegate = self;
            weakSelf.editPopOver.behavior = NSPopoverBehaviorSemitransient;
            [weakSelf.editPopOver setContentViewController:viewController];
            [weakSelf.editPopOver showRelativeToRect:[_tableview frameOfCellAtColumn:column row:row] ofView:_tableview preferredEdge:NSRectEdgeMinY];
        });
        
    }
}

-(void)doubleAction:(id)sender {
    if (self.isChecking)
        return;

    NSInteger column = _tableview.clickedColumn;
    NSInteger row = _tableview.clickedRow;
    if(column < 0 || column > self.stringArray.count + 1)
        return;
    if(row < 0 || row > self.showArray.count)
        return;
    [[NSObject class] cancelPreviousPerformRequestsWithTarget:self];
    NSString *key = _showArray[row];
    NSString *identifier = nil;
    if(column == 0){
        identifier = kStrKey;
    }else{
        StringModel *smodel = _stringArray[column-1];
        identifier = smodel.identifier;
    }
    NSInteger status = [_keyDict[key] integerValue];
    if(status == KeyTypeRemove) {
        return;
    }
    ActionModel *action = [self findActionWith:key identify:identifier];
    if(action){
        [_actionArray removeObject:action];
        [self searchAnswer:nil];
    }
    
    NSString *value = [self valueInRaw:key identifier:identifier];
    
    if (column == 0) {
        StringSetting *setting = [StringModel projectSettingByProjectPath:self.projectPath projectName:self.projectName];
        if (setting.language == swift)
            value = [NSString stringWithFormat:@"\"%@\"",value];
        else
            value = [NSString stringWithFormat:@"@\"%@\"",value];
        
        NSString *wrapper = [NSString stringWithString:setting.doubleClickWrapper];
        NSRange start = [wrapper rangeOfString:@"("];
        NSRange end = [wrapper rangeOfString:@")"];
        if (start.location != NSNotFound && end.location != NSNotFound && end.location > start.location) {
            NSRange range = NSMakeRange(start.location, end.location-start.location);
            NSRange keyRange = [wrapper rangeOfString:@"KEY" options:NSCaseInsensitiveSearch range:range];
            if (keyRange.location != NSNotFound)
                value = [wrapper stringByReplacingCharactersInRange:keyRange withString:value];
        }
    }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
    [pasteboard setString:value forType:NSStringPboardType];
    
    NSTextField *textField = (NSTextField *)[self.window.contentView viewWithTag:1111];
    if (textField) {
        [textField removeFromSuperview];
    }
    NSString *tmp = [NSString stringWithFormat:NSLocalizedString(@"CopyToPasteboard", nil),value];
    CGRect rect = [tmp sizeWithWidth:self.window.contentView.frame.size.width-100 font:[NSFont systemFontOfSize:24.0]];
    rect.size.width += 15.0f;
    rect.size.height += 5.0f;
    rect.origin = CGPointMake(CGRectGetMidX(self.window.contentView.bounds) - CGRectGetMidX(rect), 70.0f);
    NSTextField *toastLabel = [[NSTextField alloc] initWithFrame:rect];
    toastLabel.backgroundColor = [NSColor blueColor];
    toastLabel.font = [NSFont systemFontOfSize:24.0];
    toastLabel.textColor = [NSColor whiteColor];
    toastLabel.stringValue = tmp;
    toastLabel.tag = 1111;
    toastLabel.editable = NO;
    [self.window.contentView addSubview:toastLabel];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2.0f * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [toastLabel removeFromSuperview];
    });
}

-(void)removeAction:(NSButton*)button {
    if (self.isChecking)
        return;
    NSString *key = button.identifier;
    NSInteger status = [_keyDict[key] integerValue];
    for (ActionModel *action in [_actionArray copy]) {
        if ([action.key isEqualToString:key]) {
            [_actionArray removeObject:action];
        }
    }
    if(status != KeyTypeDefult) {
        [_keyDict removeObjectForKey:key];
        if(status == KeyTypeAdd){
            [_keyArray removeObject:key];
        }
    } else {
        for (StringModel *model in _stringArray) {
            NSString *value = [self valueInRaw:key identifier:model.identifier];
            ActionModel *action = [[ActionModel alloc]initWithType:ActionTypeRemove key:key identifier:model.identifier value:value];
            [_actionArray addObject:action];
        }
        [_keyDict setObject:@(KeyTypeRemove) forKey:key];
    }
    [self searchAnswer:nil];
}

-(void)infoAction:(NSButton *)button {
    if (self.isChecking)
        return;
    
    NSString *key = button.identifier;
    if(self.infoDict && key.length>0){
        if (self.editPopOver && self.editPopOver.isShown) {
            [self.editPopOver close],self.editPopOver = nil;
        }
        if (self.infoPopOver && self.infoPopOver.isShown) {
            StringInfoViewController *infoVC = (StringInfoViewController*)[self.infoPopOver contentViewController];
            [self.infoPopOver close], self.infoPopOver = nil;
            if ([key isEqualToString:infoVC.key]) {
                return;
            }
        }
        NSArray *infos = self.infoDict[key];
        if(infos.count > 0) {
            StringInfoViewController* viewController = [[StringInfoViewController alloc] initWithArray:infos key:key];
            self.infoPopOver = [[NSPopover alloc] init];
            self.infoPopOver.behavior = NSPopoverBehaviorSemitransient;
            [self.infoPopOver setContentViewController:viewController];
            [self.infoPopOver showRelativeToRect:button.bounds ofView:button preferredEdge:NSMinXEdge];
        }
    }
}

#pragma mark - Notification
- (void)projectSettingChanged:(NSNotification*)notification {
    [self.infoDict removeAllObjects];
    [self refresh:nil];
}

- (void)windowDidResize:(NSNotification *)notification {
    [_tableview reloadData];
}

#pragma mark - NSPopoverDelegate
- (void)popoverDidClose:(NSNotification*)notification {
    NSPopover* popOver = [notification object];
    if ([popOver isKindOfClass:[NSPopover class]] == NO) {
        return;
    }
    id controller = [popOver contentViewController];
    if ([controller isKindOfClass:[StringEditViewController class]] == NO) {
        return;
    }
    StringEditViewController* editViewController = (StringEditViewController*)controller;
    NSString *string1 = editViewController.textView.string;
    NSString *string2 = [string1 stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    NSString *string3 = [string2 stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    [self changeWithKey:editViewController.key identifier:editViewController.identifier newValue:string3];
}

#pragma mark - NSTableViewDelegate & NSTableViewDataSource
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.showArray.count;
}

- (void)tableViewColumnDidResize:(NSNotification *)notification{
    [_tableview reloadData];
}

-(CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    float height = 17;
    NSString *key = self.showArray[row];
    for (ActionModel *action in _actionArray) {
        if ([action.key isEqualToString:key]) {
            NSTableColumn *column = [_tableview tableColumnWithIdentifier:action.identifier];
            float tmpHeight = ceilf([action.value sizeWithWidth:column.width font:kFont].size.height);
            height = MAX(height, tmpHeight);
        }
    }
    for (StringModel *smodel in _stringArray) {
        NSString *tmp = smodel.stringDictionary[key];
        NSTableColumn *column = [_tableview tableColumnWithIdentifier:smodel.identifier];
        float tmpHeight = ceilf([tmp sizeWithWidth:column.width font:kFont].size.height);
        height = MAX(height, tmpHeight);
    }
    return height;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = [tableColumn identifier];
    NSString *key = self.showArray[row];
    if([identifier isEqualToString:kRemove]){
        NSButton *aView = [tableView makeViewWithIdentifier:identifier owner:self];
        if(!aView) {
            aView = [[NSButton alloc]initWithFrame:NSZeroRect];
            [aView setButtonType:NSToggleButton];
            [aView setTitle:NSLocalizedString(@"Remove", nil) textColor:[NSColor textColor]];
            [aView setAlternateTitle:NSLocalizedString(@"Revoke", nil) textColor:[NSColor redColor]];
            [aView setAction:@selector(removeAction:)];
            [aView setTarget:self];
        }
        NSInteger status = [_keyDict[key] integerValue];
        [aView setHighlighted:status];
        [aView setTag:row];
        [aView setIdentifier:key];
        return aView;
    }else if([identifier isEqualToString:kInfo]){
        NSArray *items = self.infoDict[key];
        NSButton *aView = [tableView makeViewWithIdentifier:identifier owner:self];
        if(!aView) {
            aView = [[NSButton alloc]initWithFrame:NSZeroRect];
            [aView setAction:@selector(infoAction:)];
            [aView setTarget:self];
            [aView setState:1];
        }
        [aView setTag:row];
        [aView setIdentifier:key];
        [aView setTitle:[@(items.count) stringValue]];
        return aView;
    }else {
        NSTextField *aView = [tableView makeViewWithIdentifier:@"MYCell" owner:self];
        if(!aView) {
            aView = [[NSTextField alloc]initWithFrame:NSZeroRect];
            [aView setTextColor:[NSColor textColor]];
            [aView setBordered:NO];
            [aView setFont:kFont];
            [aView setEditable:NO];
            [aView setLineBreakMode:NSLineBreakByWordWrapping];
        }
        if([identifier isEqualToString:kStrKey]){
            NSInteger status = [_keyDict[key] integerValue];
            if(status == KeyTypeRemove){
                [aView setBackgroundColor:[NSColor redColor]];
            }else if (status == KeyTypeAdd) {
                [aView setBackgroundColor: [NSColor colorWithRed:0 green:0.8 blue:0 alpha:1.0]];
            }else{
                [aView setBackgroundColor: [NSColor clearColor]];
            }
            [aView setStringValue:_showArray[row]];
        }else{
            ActionModel *action = [self findActionWith:key identify:identifier];
            NSString *rawValue = [self valueInRaw:key identifier:identifier];
            if (action) {
                if(action.actionType == ActionTypeRemove){
                    [aView setBackgroundColor:[NSColor redColor]];
                }else{
                    if (rawValue.length==0) {
                        [aView setBackgroundColor: [NSColor colorWithRed:0 green:0.8 blue:0 alpha:1.0]];
                    }else{
                        [aView setBackgroundColor: [NSColor blueColor]];
                    }
                }
                [aView setStringValue:action.value];
            }else{
                [aView setBackgroundColor: [NSColor clearColor]];
                [aView setStringValue:rawValue];
            }
        }
        [aView setTag:row];
        [aView setIdentifier:identifier];
        return aView;
    }
}

-(void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn{
    NSString *identifier=[tableColumn identifier];
    if ([identifier isEqualToString:kRemove]) {
        return;
    }
    if ([identifier isEqualToString:_sortingCol]) {
        self.ascending = !self.ascending;
    } else {
        self.ascending = YES;
    }
    self.sortingCol = identifier;
    [self refreshTableColumn];
    [self searchAnswer:nil];
}
@end
