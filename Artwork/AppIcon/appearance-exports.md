# App icon appearance exports

`AppIconLight` and `AppIconDark` in `Resources/Images.xcassets` are static exports
of `Resources/AppIcon.icon`, made with Icon Composer from Xcode 26.6. They let a
user keep one appearance independently of the system icon style.

Regenerate both images whenever the Icon Composer source changes. From the
repository root:

```sh
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Resources/AppIcon.icon --export-image --output-file Resources/Images.xcassets/AppIconLight.imageset/Light.png --platform macOS --rendition Default --width 512 --height 512 --scale 2
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Resources/AppIcon.icon --export-image --output-file Resources/Images.xcassets/AppIconDark.imageset/Dark.png --platform macOS --rendition Dark --width 512 --height 512 --scale 2
```

The exports contain the icon shape without outer padding. `SAAppIconController`
adds the standard transparent macOS margins when supplying the image to AppKit.
System mode continues to use the original layered icon and native tinting.
