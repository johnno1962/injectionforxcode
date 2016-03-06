### Tunable Parameters

**Note** - For Swift Projects, you need to have [patched your installation](patching_injection.md).

![Icon](http://injectionforxcode.johnholdsworth.com/params2.png)

Tunable parameters can be useful for tuning specific parts of your application fast. It makes it easy for you to include a value between 0 and _x_, and quickly have that value change at runtime.

To use tunable parameteres, you need to include the following code in the class using tunable parameters or your project's bridging header for Swift.

``` objc
#ifdef DEBUG
#define INJECTION_ENABLED

#import "/tmp/injectionforxcode/BundleInterface.h"
#endif
```

This exposes two arrays `INParameters` and `INColors` which can be "tuned" directly
from inside Xcode using the "Product/Injection Plugin/Tunable App Parameters" panel. 

In this case, you shouldn't rely on the `injection` class/instance methods, but work to this API:

``` objc
@interface NSObject(INParameters)
+ (INColor * INJECTION_STRONG *)inColors;
+ (INColor *)inColor:(int)tag;
+ (float *)inParameters;
+ (float)inParameter:(int)tag;
+ (void)inSetDelegate:(id)delegate forParameter:(int)tag;
+ (void)inSetTarget:(id)target action:(SEL)action forColor:(int)tag;
@end
```

Here's a full example, where changing the tunable parameters affects the text on a label:

```swift
import UIKit
import ORStackView
import Artsy_UILabels
import FLKAutoLayout

class NewViewController: UIViewController {
    let titleView = ARSansSerifLabel()
    let lorem = ARSerifLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .whiteColor()
        
        // Let this object receive callbacks for the first parameter
        NSObject.inSetDelegate(self, forParameter: 0)

        let stack = ORStackView()
        view.addSubview(stack)
        stack.alignLeading("0", trailing: "0", toView: view)
        stack.alignTopEdgeWithView(view, predicate: "20")

        titleView.text = "Injection Example"
        titleView.font = UIFont.sansSerifFontWithSize(32)
        stack.addSubview(titleView, withTopMargin: "0", sideMargin: "20")

        lorem.text = "Lorem Ipsum Text."
        stack.addSubview(lorem, withTopMargin: "12", sideMargin: "40")
    }

    override func inParameter(tag: Int32, hasChanged value: Float) {
        self.lorem.text = "\(value)"
    }
}
```