//
//  ScanerVC.m
//  SuperScanner
//
//  Created by Jeans Huang on 10/19/15.
//  Copyright © 2015 gzhu. All rights reserved.
//

#import "ScanerVC.h"
#import "ScanerView.h"
#import "NewArrivalViewController.h"
#import "SentPackageService.h"
#import "UTCommon.h"
#import <UIView+Toast.h>
#import <Masonry.h>
#import "LoginService.h"

@import AVFoundation;

@interface ScanerVC ()<AVCaptureMetadataOutputObjectsDelegate,UIAlertViewDelegate>

//! 加载中视图
@property (weak, nonatomic) IBOutlet UIView *loadingView;

//! 扫码区域动画视图
@property (strong, nonatomic) ScanerView *scanerView;

//AVFoundation
//! AV协调器
@property (strong,nonatomic) AVCaptureSession *session;
//! 取景视图
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation ScanerVC

- (void)viewDidLoad {
    [super viewDidLoad];
//    [self setExtendedLayoutIncludesOpaqueBars:YES];
    [self createView];
       //设置扫描区域边长
    self.scanerView.scanAreaEdgeLength = [[UIScreen mainScreen] bounds].size.width - 2 * 50;
    
    if (!self.isQR) {
//        [self setLeftNavigationItem];
        self.title = @"请扫描快递条形码";
    } else {
        self.title = @"请扫描社区二维码";
    }
    
    if (!self.isAddCommunity) {
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(reloadScanVC) name:PopToPreviousVC object:nil];
    }

}

- (void)createView{
    
    CGRect rect = self.view.bounds;
    rect.origin.y = self.navigationController.navigationBarHidden ? 0 : 64;

    self.scanerView = [[ScanerView alloc]initWithFrame:rect];
    self.scanerView.alpha = 0;
    [self.view addSubview:self.scanerView];
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];

}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    self.tabBarController.tabBar.hidden = YES;
    
    DDLogVerbose(@"ScanVC did appear");
    
    if (!self.session){
        //初始化扫码
        [self setupAVFoundation];
        
        //调整摄像头取景区域
        CGRect rect = self.view.bounds;
        rect.origin.y = self.navigationController.navigationBarHidden ? 0 : 64;
        self.previewLayer.frame = rect;
        
        self.loadingView.hidden = NO;
        [UIView animateWithDuration:0.5 animations:^{
        } completion:^(BOOL finished) {
            self.loadingView.hidden = YES;
            self.scanerView.alpha = 1;
            
            if (!self.isQR) {
                [self setLeftNavigationItem];
            }
        }];
        

    }
    
}

//! 初始化扫码
- (void)setupAVFoundation{
    //创建会话
    self.session = [[AVCaptureSession alloc] init];
    [self.session setSessionPreset:AVCaptureSessionPresetHigh];
    
    //获取摄像头设备
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    
    //创建输入流
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if(input) {
        [self.session addInput:input];
    } else {
        //出错处理
        DDLogError(@"%@", error);
        NSString *msg = [NSString stringWithFormat:@"请在手机【设置】-【隐私】-【相机】选项中，允许【%@】访问您的相机",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"]];
        
        UIAlertView *av = [[UIAlertView alloc]initWithTitle:@"提醒"
                                                    message:msg
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles: nil];
        [av show];
        return;
    }
    
    //创建输出流
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    [self.session addOutput:output];
    
    //设置扫码类型
    
    if (self.isQR) {
        output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode,
                                      ];

    } else {
        output.metadataObjectTypes = @[
                                       AVMetadataObjectTypeCode128Code,
                                       AVMetadataObjectTypeCode39Code,
                                       AVMetadataObjectTypeCode93Code,
                                       
                                       AVMetadataObjectTypeEAN13Code,
                                       AVMetadataObjectTypeEAN8Code,
                                       AVMetadataObjectTypeUPCECode
                                       ];
    }
    
    //设置代理，在主线程刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    //创建摄像头取景区域
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    
    if ([self.previewLayer connection].isVideoOrientationSupported)
        [self.previewLayer connection].videoOrientation = AVCaptureVideoOrientationPortrait;

    __weak typeof(self) weakSelf = self;
    
    [[NSNotificationCenter defaultCenter]addObserverForName:AVCaptureInputPortFormatDescriptionDidChangeNotification
                                                     object:nil
                                                      queue:[NSOperationQueue mainQueue]
                                                 usingBlock:^(NSNotification * _Nonnull note) {
                                                     if (weakSelf){
                                                         //调整扫描区域
                                                         AVCaptureMetadataOutput *output = weakSelf.session.outputs.firstObject;
                                                         
                                                         CGRect scanCrop = [weakSelf getScanCrop:weakSelf.scanerView.scanAreaRect readerViewBounds:self.view.frame];
                                                         output.rectOfInterest = scanCrop;
                                                     }
                                                 }];
    
    //开始扫码
    [self.session startRunning];
}

#pragma mark-> 获取扫描区域的比例关系
-(CGRect)getScanCrop:(CGRect)rect readerViewBounds:(CGRect)readerViewBounds{
    CGFloat x,y,width,height;
    
    x = (CGRectGetHeight(readerViewBounds)-CGRectGetHeight(rect))/2/CGRectGetHeight(readerViewBounds);
    y = (CGRectGetWidth(readerViewBounds)-CGRectGetWidth(rect))/2/CGRectGetWidth(readerViewBounds);
    width = CGRectGetHeight(rect)/CGRectGetHeight(readerViewBounds);
    height = CGRectGetWidth(rect)/CGRectGetWidth(readerViewBounds);
    
    return CGRectMake(x, y, width, height);
    
}

#pragma mark - AVCaptureMetadataOutputObjects Delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    @WeakObj(self);
    
    for (AVMetadataMachineReadableCodeObject *metadata in metadataObjects) {
        if ([metadata.type isEqualToString:AVMetadataObjectTypeQRCode]) {
            @StrongObj(self);
            
            [self.session stopRunning];

            if (self.isAddCommunity) {
                [[LoginService sharedInstance]addCommunityWithScanResult:metadata.stringValue success:^(CommunityModel *communityModel) {
                    DDLogInfo(@"communityModel: %@", communityModel.location);
                    
                    [[SentPackageService sharedInstance].communityArray addObject:communityModel];
                    [self.view makeToast:@"社区添加成功" duration:1.0 position:CSToastPositionCenter title:nil image:nil style:nil completion:^(BOOL didTap) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:UTNotificationCommunityUpdated object:nil userInfo:nil];
                        [selfWeak.navigationController popViewControllerAnimated:YES];
                        
                    }];
                } failure:^{
                    [self.view makeToast:@"无法绑定该社区" duration:1.0 position:CSToastPositionCenter title:nil image:nil style:nil completion:^(BOOL didTap) {
                       
                        [selfWeak.navigationController popViewControllerAnimated:YES];
                        
                    }];

                }];
            } else {
                if (self.sentPackageModel) {
                    //录入界面直接提交
                    [[SentPackageService sharedInstance]inputPackage:self.sentPackageModel withType:SubmitTypeQRSubmitted withQR:metadata.stringValue completed:^{
                        [selfWeak.tabBarController setSelectedIndex:0];
                        [selfWeak.navigationController popToRootViewControllerAnimated:NO];
                    } failure:^{
                        
                    }];
                    
                } else {
                    //送件页面删除提交
                    [[SentPackageService sharedInstance] operatePackageWithOperationType:OperationTypeSubmit packageArray:self.submittingArray scanResult:metadata.stringValue completed:^{
                        [selfWeak.navigationController popToRootViewControllerAnimated:YES];
                    } failure:^{
                        
                    }];
                }
            }
            
            break;
        }else{
            //扫描快递条形码
            if ([metadata.type isEqualToString:AVMetadataObjectTypeCode128Code] || [metadata.type isEqualToString:AVMetadataObjectTypeCode39Code] || [metadata.type isEqualToString:AVMetadataObjectTypeCode93Code] || [metadata.type isEqualToString:AVMetadataObjectTypeEAN13Code] || [metadata.type isEqualToString:AVMetadataObjectTypeEAN8Code] || [metadata.type isEqualToString:AVMetadataObjectTypeUPCECode]) {
                [self.session stopRunning];
                
                [self.view makeToast:metadata.stringValue duration:1 position:CSToastPositionCenter];
                NewArrivalViewController *navc = [NewArrivalViewController new];
                navc.expressNumber = metadata.stringValue;
                navc.communityModel = self.communityModel;
                self.hidesBottomBarWhenPushed = YES;
                [self.navigationController pushViewController:navc animated:YES];
                self.hidesBottomBarWhenPushed = NO;
                break;
            }
        }
    }
}

#pragma mark - UIAlertView Delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)setLeftNavigationItem{
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"手输" style:UIBarButtonItemStylePlain target:self action:@selector(backAction:)];
    [self.navigationItem setRightBarButtonItem:backItem animated:YES];
    
}

- (void)backAction:(id)sender{
    //手动输入包裹信息
    NewArrivalViewController *navc = [NewArrivalViewController new];
    navc.communityModel = self.communityModel;
    [self.navigationController pushViewController:navc animated:YES];
}

- (void)setIsQR:(BOOL)isQR{

    _isQR = isQR;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    DDLogVerbose(@"ScanVC will appear");
    self.tabBarController.tabBar.hidden = YES;
    self.navigationItem.rightBarButtonItem.enabled = NO;

    //重写加载视图
    [self.scanerView setNeedsDisplay];
    [self.loadingView setNeedsDisplay];
    [self.view setNeedsDisplay];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    DDLogVerbose(@"ScanVC will disappear");
    
    [self.session stopRunning];
    self.session = nil;
    [self.previewLayer removeFromSuperlayer];
}

- (void)reloadScanVC {
    [self.session stopRunning];
    self.session = nil;
    [self.view makeToast:@"包裹社区与扫码社区不一致" duration:1.5 position:CSToastPositionCenter title:nil image:nil style:nil completion:^(BOOL didTap) {
        [self.scanerView setNeedsDisplay];
        [self.loadingView setNeedsDisplay];
        [self.view setNeedsDisplay];
        [self.previewLayer removeFromSuperlayer];
        
        if (!self.session) {
            [self setupAVFoundation];
        }
        
        //调整摄像头取景区域
        CGRect rect = self.view.bounds;
        rect.origin.y = self.navigationController.navigationBarHidden ? 0 : 64;
        self.previewLayer.frame = rect;
    }];

}

@end
