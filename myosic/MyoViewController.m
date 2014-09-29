//
//  MyoViewController.m
//  Example
//
//  Created by Mathieu Dutour on 31/03/2014.
//  Copyright (c) 2014 Gangverk. All rights reserved.
//

#import "MyoViewController.h"
#import <MyoKit/MyoKit.h>

@interface MyoViewController ()
@property (weak, nonatomic) IBOutlet UILabel *emptyLabel;
@property (weak, nonatomic) IBOutlet UITableView *table;
@end

@implementation MyoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
- (IBAction)scanMyo:(id)sender {
    TLMSettingsViewController *settings = [[TLMSettingsViewController alloc] init];
    
    [self.navigationController pushViewController:settings animated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    self.navigationController.navigationBarHidden = NO;
    
    if ([[[TLMHub sharedHub] myoDevices] count] == 0) {
        self.emptyLabel.hidden = NO;
        self.table.hidden = YES;
    } else {
        self.emptyLabel.hidden = YES;
        self.table.hidden = NO;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[TLMHub sharedHub] myoDevices] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"myoCell"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"myoCell"];
    }
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@",[[[TLMHub sharedHub] myoDevices][indexPath.row] name]];
    return cell;
}

@end
