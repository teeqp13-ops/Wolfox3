#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WFActivationViewController : UIViewController
@property (nonatomic, copy, nullable) void (^completion)(BOOL success);
@property (nonatomic, copy, nullable) NSString *noticeMessage;
@property (nonatomic, copy, nullable) NSString *updateURL;
@end

NS_ASSUME_NONNULL_END
