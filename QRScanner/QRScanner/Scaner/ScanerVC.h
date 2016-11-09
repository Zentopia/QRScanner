//
//  ScanerVC.h
//  SuperScanner
//
//  Created by Jeans Huang on 10/19/15.
//  Copyright © 2015 gzhu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CommunityModel.h"
#import "UTViewController.h"
#import "UTViewController.h"

@class SentPackageModel;

@interface ScanerVC : UIViewController

@property (strong, nonatomic)CommunityModel *communityModel;
@property (strong, nonatomic)NSArray *submittingArray;
@property (assign, nonatomic)BOOL isQR;
@property (assign, nonatomic)BOOL isAddCommunity;
@property (assign, nonatomic)SentPackageModel *sentPackageModel;

@end
