#import <Cocoa/Cocoa.h>
@class Person;

@interface Document : NSDocument {
    NSMutableArray *employees;
    IBOutlet NSTableView *table;
    NSAlert *replaceDialog;
    NSInteger replaceDialogLastChoice;
}

-(void)setEmployees:(NSMutableArray *)empl;
-(void)insertObject:(Person *)p inEmployeesAtIndex:(NSInteger)index;
-(void)removeObjectFromEmployeesAtIndex:(NSInteger)index;
-(void)replaceObjectInEmployeesAtIndex:(NSInteger)index withObject:(Person *)newPerson;

-(IBAction)saveSelectedItems:(id)sender;
-(IBAction)appendEmployeesFromFile:(id)sender;

@end
