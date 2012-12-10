#import "Document.h"
#import "Person.h"

static void *RMDocumentKVOContext;

@implementation Document

-(void) startObservingPerson:(Person *)p {
    [p addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionOld context:&RMDocumentKVOContext];
    [p addObserver:self forKeyPath:@"raise" options:NSKeyValueObservingOptionOld context:&RMDocumentKVOContext];
}

-(void)stopObservingPerson:(Person *)p {
    [p removeObserver:self forKeyPath:@"name"];
    [p removeObserver:self forKeyPath:@"raise"];
}

- (id)init
{
    self = [super init];
    if (self) {
        employees = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void)setEmployees:(NSMutableArray *)empl {
    if (employees != empl) {
        for (Person *p in employees) {
            [self stopObservingPerson:p];
        }
        employees = empl;
        for (Person *p in employees) {
            [self startObservingPerson:p];
        }
    }
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"Document";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    [[table window] endEditingFor:nil];
    return [NSKeyedArchiver archivedDataWithRootObject:employees];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    NSMutableArray *newArray = nil;
    @try {
        newArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (NSException *exception) {
        if (outError) {
            NSDictionary *d = [NSDictionary dictionaryWithObject:@"The file is invalid" forKey:NSLocalizedFailureReasonErrorKey];
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:d];
        }
        return NO;
    }
    [self setEmployees:newArray];
    return YES;
}

-(void)insertObject:(Person *)p inEmployeesAtIndex:(NSInteger)index {
    NSUndoManager *undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget:self] removeObjectFromEmployeesAtIndex:index];
    if (![undoManager isUndoing]) {
        [undoManager setActionName: [NSString stringWithFormat: @"Add %@", p.name]];
    }
    [self startObservingPerson:p];
    [employees insertObject:p atIndex:index];
}

-(void)removeObjectFromEmployeesAtIndex:(NSInteger)index {
    NSUndoManager *undoManager = [self undoManager];
    Person *p = [employees objectAtIndex:index];
    [[undoManager prepareWithInvocationTarget:self] insertObject:p inEmployeesAtIndex:index];
    if (![undoManager isUndoing]) {
        [undoManager setActionName: [NSString stringWithFormat: @"Remove %@", p.name]];
    }
    [self stopObservingPerson:p];
    [employees removeObjectAtIndex:index];
}

-(void)replaceObjectInEmployeesAtIndex:(NSInteger)index withObject:(Person *)newPerson {
    NSUndoManager *undoManager = [self undoManager];
    Person *oldPerson = [employees objectAtIndex:index];
    [[undoManager prepareWithInvocationTarget:self] replaceObjectInEmployeesAtIndex:index withObject:oldPerson];
    if (![undoManager isUndoing]) {
        [undoManager setActionName: [NSString stringWithFormat: @"Replace %@", oldPerson.name]];
    }
    [self stopObservingPerson:oldPerson];
    [employees replaceObjectAtIndex:index withObject:newPerson];
    [self startObservingPerson:newPerson];
}

-(void)changeKeyPath:(NSString *)keyPath ofObject:(id)object toValue:(id)newValue {
    [object setValue:newValue forKeyPath:keyPath];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != &RMDocumentKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    NSLog(@"chganged %@ from %@ to %@", keyPath, [change objectForKey:NSKeyValueChangeOldKey], [object valueForKeyPath:keyPath]);
    
    NSUndoManager *undoManager = [self undoManager];
    id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
    if (oldValue == [NSNull null]) {
        oldValue = nil;
    }
    [[undoManager prepareWithInvocationTarget:self] changeKeyPath:keyPath ofObject:object toValue:oldValue];
    [undoManager setActionName:@"Edit"];
}

-(void)saveSelectedItems:(id)sender {
    NSIndexSet *selectedIndexes = [table selectedRowIndexes];
    
    if ([selectedIndexes count] == 0) {
        [self showAlertWithMessageText:@"Hm!?" informativeText:@"Nothing is selected"];
        return;
    }
    
    NSMutableArray *selectedEmployees = [NSMutableArray array];
    [selectedIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        [selectedEmployees addObject:[employees objectAtIndex:index]];
    }];
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"edb"]];
    if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:selectedEmployees];
        [data writeToURL:[savePanel URL] atomically:YES];
    }
}

-(void)appendEmployeesFromFile:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"edb"]];
    if (![openPanel runModal] == NSFileHandlingPanelOKButton) {
        return;
    }
    
    NSData *dataToAppend = [NSData dataWithContentsOfURL:[openPanel URL]];
    if (dataToAppend == nil) {
        [self showAlertWithMessageText:@"Ops" informativeText:@"Cannot open the file"];
        return;
    }
    
    NSArray *employeesToAppend = nil;
    @try {
        employeesToAppend = [NSKeyedUnarchiver unarchiveObjectWithData:dataToAppend];
    }
    @catch (NSException *exception) {
        NSLog(@"Cannot unarchive data, caused by: %@", exception);
        [self showAlertWithMessageText:@"Ops" informativeText:@"File has invalid format"];
        return;
    }
    
    [self resetReplaceDialog];
    for(Person *employeeToAppend in employeesToAppend) {
        
        BOOL hasFoundPersonWithSameName = NO;
        for (NSInteger index = 0; index < [employees count]; index++) {
            Person *employee = [employees objectAtIndex:index];
            if ([employeeToAppend hasEqualNameTo:employee]) {
                hasFoundPersonWithSameName = YES;
                if (employee.raise != employeeToAppend.raise) {
                    if ([self userWantsToReplacePerson:employee with:employeeToAppend]) {
                        [self replaceObjectInEmployeesAtIndex:index withObject:[employeeToAppend copy]];
                    }
                }
            }
        }
        
        if (!hasFoundPersonWithSameName) {
            [self insertObject:employeeToAppend inEmployeesAtIndex:[employees count]];
        }
    }
}

-(void) resetReplaceDialog {
    if (replaceDialog == nil) {
        replaceDialog = [NSAlert alertWithMessageText:@"Persons with the same name found"
                                        defaultButton:@"Replace"
                                      alternateButton:@"Skip"
                                          otherButton:nil
                            informativeTextWithFormat:@""];
        [replaceDialog setShowsSuppressionButton:YES];
        [[replaceDialog suppressionButton] setTitle:@"Apply to all conflicting items from this file"];
    }
    [[replaceDialog suppressionButton] setState:NSOffState];
}

-(BOOL)userWantsToReplacePerson:(Person *)person with:(Person *)newPerson {
    if ([[replaceDialog suppressionButton] state] != NSOnState) {
        NSString *text = [NSString stringWithFormat:@"Do you want to replace %@ with %@?", person, newPerson];
        [replaceDialog setInformativeText:text];
        replaceDialogLastChoice = [replaceDialog runModal];
    }
    return replaceDialogLastChoice == NSAlertDefaultReturn;
}

-(void)showAlertWithMessageText:(NSString *)text informativeText:(NSString *)informativeText {
    NSAlert *alert = [NSAlert alertWithMessageText:text defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", informativeText];
    [alert runModal];
}

@end
