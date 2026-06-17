<!--
{
  "availability" : [
    "iOS: 15.0.0 -",
    "iPadOS: 15.0.0 -",
    "macCatalyst: 15.0.0 -",
    "macOS: 12.0.0 -",
    "tvOS: 15.0.0 -",
    "visionOS: 1.0.0 -",
    "watchOS: 8.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "SwiftUI",
  "identifier" : "/documentation/SwiftUI/AsyncImage",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "SwiftUI"
    ],
    "preciseIdentifier" : "s:7SwiftUI10AsyncImageV"
  },
  "title" : "AsyncImage"
}
-->

# AsyncImage

A view that asynchronously loads and displays an image.

```
nonisolated struct AsyncImage<Content> where Content : View
```

## Overview

This view uses the shared
<doc://com.apple.documentation/documentation/Foundation/URLSession>
instance to load an image from a URL that you specify, and then display it.
For example, you can display an icon that’s stored on a server:

```
AsyncImage(url: URL(string: "https://example.com/icon.png"))
    .frame(width: 200, height: 200)
```

Until the image loads, the view displays a standard placeholder that
fills the available space. After the load completes successfully, the view
updates to display the image. In the example above, the icon is smaller
than the frame, and so appears smaller than the placeholder.

![A diagram that shows a grey box on the left, the SwiftUI icon on the](images/com.apple.SwiftUI/AsyncImage-1~dark@2x.png)

> Important: You can’t apply image-specific modifiers, like
> ``doc://com.apple.SwiftUI/documentation/SwiftUI/Image/resizable(capInsets:resizingMode:)``, directly to an `AsyncImage`.
> Instead, apply them to the ``doc://com.apple.SwiftUI/documentation/SwiftUI/Image`` instance that your `content`
> closure gets when defining the view’s appearance.

You can manipulate the loaded image in the `content` parameter using
[`init(url:scale:content:placeholder:)`](/documentation/SwiftUI/AsyncImage/init(url:scale:content:placeholder:)). For example, you can add a modifier to make the loaded image resizable:

```
AsyncImage(url: URL(string: "https://example.com/icon.png")) { image in
    image.resizable()
} placeholder: {
    ProgressView()
}
.frame(width: 50, height: 50)
```

With this initializer, you can also specify a custom placeholder. In the code in the previous example, SwiftUI shows a [`ProgressView`](/documentation/SwiftUI/ProgressView) first, and then the image scaled to fit in the specified frame:

![A diagram that shows a progress view on the left, the SwiftUI icon on the](images/com.apple.SwiftUI/AsyncImage-2@2x.png)

If you use an [`Image`](/documentation/SwiftUI/Image) as a placeholder view and it doesn’t load, SwiftUI doesn’t show anything as a placeholder and doesn’t report an error.

To gain more control over the loading process, use the
[`init(url:scale:transaction:content:)`](/documentation/SwiftUI/AsyncImage/init(url:scale:transaction:content:)) initializer, which takes a
`content` closure that receives an [`AsyncImagePhase`](/documentation/SwiftUI/AsyncImagePhase) to indicate
the state of the loading operation. Return a view that’s appropriate
for the current phase:

```
AsyncImage(url: URL(string: "https://example.com/icon.png")) { phase in
    if let image = phase.image {
        image // Displays the loaded image.
    } else if phase.error != nil {
        Color.red // Indicates an error.
    } else {
        Color.blue // Acts as a placeholder.
    }
}
```

In iOS 27, macOS 27, watchOS 27, tvOS 27, and visionOS 27 and later,
`AsyncImage` caches downloaded image data following the transport
protocol. The system creates the cache with a default <doc://com.apple.documentation/documentation/Foundation/URLSessionConfiguration>.
To change the cache policy, specify the change in <doc://com.apple.documentation/documentation/Foundation/URLRequest>, and pass it to
[`init(request:scale:transaction:content:)`](/documentation/SwiftUI/AsyncImage/init(request:scale:transaction:content:)). To customize the
download process in a specific view hierarchy, use [`asyncImageURLSession(_:)`](/documentation/SwiftUI/View/asyncImageURLSession(_:)) to specify a
<doc://com.apple.documentation/documentation/Foundation/URLSession>. `AsyncImage` uses this session to perform data tasks when downloading the image data.

## Topics

### Loading an image

[`init(url:scale:)`](/documentation/SwiftUI/AsyncImage/init(url:scale:))

Loads and displays an image from the specified URL.

[`init(url:scale:content:placeholder:)`](/documentation/SwiftUI/AsyncImage/init(url:scale:content:placeholder:))

Loads and displays a modifiable image from the specified URL using
a custom placeholder until the image loads.

### Loading an image in phases

[`init(url:scale:transaction:content:)`](/documentation/SwiftUI/AsyncImage/init(url:scale:transaction:content:))

Loads and displays a modifiable image from the specified URL in phases.

### Loading an image with a URL request

[`init(request:scale:)`](/documentation/SwiftUI/AsyncImage/init(request:scale:))

Loads and displays an image from the specified URL load request.

[`init(request:scale:content:placeholder:)`](/documentation/SwiftUI/AsyncImage/init(request:scale:content:placeholder:))

Loads and displays a modifiable image from the specified URL load request using a custom placeholder until the image loads.

[`init(request:scale:transaction:content:)`](/documentation/SwiftUI/AsyncImage/init(request:scale:transaction:content:))

Loads and displays a modifiable image from the specified URL load request in phases.



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
