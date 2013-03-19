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

// Activity indicator for page load
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

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
    self.errorMessageLabel.text = @"";
    self.webView.delegate = self;
    
    NSURL *url = [NSURL URLWithString:@"http://chipk215.github.com/keyfobsimulation/"];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [self.activityIndicator startAnimating];
    
    dispatch_queue_t webQueue = dispatch_queue_create("download", NULL);
    dispatch_async(webQueue, ^{
        
        [self.webView loadRequest:request];
        
    });

   
	    
   
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.webView.delegate = nil;
    self.errorMessageLabel.text = @"";
}

#pragma mark- UIWebViewDelegate Protocol

// Page loaded stop the activity indicator
-(void)webViewDidFinishLoad:(UIWebView *)webView
{
    DLog(@"Web page loaded");
    [self.activityIndicator stopAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [self.activityIndicator stopAnimating];
    NSString *errorMessage = [NSString stringWithFormat:@"Web page failed to load.  Error:  %@",error];
    
    self.errorMessageLabel.text = errorMessage;
    
}


@end
