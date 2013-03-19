//
//  KFBAboutViewController.m
//  KeyFobSimulation
//
//  Created by Chip Keyes on 3/19/13.
//  Copyright (c) 2013 Chip Keyes. All rights reserved.
//

#import "KFBAboutViewController.h"

@interface KFBAboutViewController ()
@property (strong, nonatomic) IBOutlet UIWebView *webView;
- (IBAction)backButtonHandler:(UIBarButtonItem *)sender;

@property (weak, nonatomic) IBOutlet UILabel *errorMessageLabel;

@end

@implementation KFBAboutViewController


- (IBAction)backButtonHandler:(UIBarButtonItem *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    NSURL *url = [NSURL URLWithString:@"http://chipk215.github.com/keyfobsimulation/"];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    
    [self.webView loadRequest:request];
	// Do any additional setup after loading the view.
      
    
    
   
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
