# Vimac Revival — Tình trạng & Kế hoạch

Tài liệu này ghi lại tình trạng thực tế của project tính đến thời điểm hiện tại (2026-08-25) và
kế hoạch hồi sinh nó để dùng cá nhân, sau khi project bị bỏ hoang từ 2021 (commit gần nhất có ý
nghĩa: `Update to v0.3.19` tháng 4/2021; commit sau đó chỉ sửa README vào 2022).

## Bối cảnh

- Tác giả gốc đã ngừng phát triển Vimac, chuyển sang bán app kế nhiệm trả phí [Homerow](https://homerow.app).
- Mục tiêu: hồi sinh và tự host/tự build Vimac để dùng riêng, custom theo ý mình, không phụ thuộc
  Homerow.
- Máy dev: Apple Silicon, macOS 26 (Tahoe), Xcode 26.6, Swift 6.3 toolchain — cách xa môi trường gốc
  project được viết (macOS 10.14 target, Swift 5.0, Xcode ~12).

## Phase 0 — Đưa project build được (✅ HOÀN THÀNH)

Mục tiêu: chỉ cần build ra được `.app` chạy trên máy hiện tại.

| # | Vấn đề gặp phải | Cách xử lý |
|---|---|---|
| 1 | Máy chưa có Xcode, CocoaPods, Carthage | Cài Xcode 26.6 qua App Store (đã có sẵn), accept license (`sudo xcodebuild -license`), cài `cocoapods` + `carthage` qua Homebrew |
| 2 | Xcode lần đầu thiếu components (CoreSimulator...) | `sudo xcodebuild -runFirstLaunch` |
| 3 | `DEVELOPMENT_TEAM` trong `project.pbxproj` là Team ID của tác giả gốc (`LQ2VH8VB84`) | Đăng nhập Apple ID cá nhân vào Xcode → đổi Team trong Signing & Capabilities → Team ID mới `M88K22723D`, cert tự tạo |
| 4 | **Segment Analytics SDK (pod `Analytics` 4.1.3, ~2019) không build được trên Xcode 26** — code trộn `#import` header hệ thống private và `@import` module, hai cách xung khắc khi patch 1 chiều (đã thử `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES` và `CLANG_ENABLE_MODULES=NO`, cả hai đều không ổn) | **Gỡ bỏ hoàn toàn** pod `Analytics` + mọi lời gọi `Analytics.shared().track(...)`, hàm `reportConfiguration()`, và tính năng "PMF Survey" (popup xin feedback sau 350 lần dùng, phụ thuộc anon-id của Segment) khỏi `AppDelegate.swift`, `ModeCoordinator.swift`, `HintModeController.swift`, `ScrollModeViewController.swift`, `ScrollModeActiveViewController.swift` |
| 5 | Các pod cũ (RxSwift 5.1.1...) tự khai `MACOSX_DEPLOYMENT_TARGET` thấp hơn API họ dùng (vd. RxSwift khai 10.9 nhưng dùng `Date` cần 10.10) → lỗi biên dịch nghiêm ngặt hơn trên Xcode mới | Thêm `post_install` hook trong `Podfile` ép tất cả pod dùng chung `MACOSX_DEPLOYMENT_TARGET` với target chính (10.14, sau đó nâng lên 10.15 — xem Phase 1) |
| 6 | Carthage build ra `.xcframework` (`--use-xcframeworks`) nhưng project trỏ đường dẫn cũ `Carthage/Build/Mac/*.framework` | Build lại Carthage **không** kèm `--use-xcframeworks` |
| 7 | `HideCursorGlobally.m` gọi `CGDisplayHideCursor`/`CGMainDisplayID` mà không import đúng header — Clang cũ dễ dãi bỏ qua, Clang mới coi là lỗi | Thêm `#import <CoreGraphics/CoreGraphics.h>` |
| 8 | Script `grant-accessibility-permission-dev.scpt` (AppleScript tự động re-grant quyền Accessibility sau mỗi build) gọi UI của "System Preferences" — **đã đổi tên/thiết kế lại thành "System Settings" từ macOS Ventura**, script chắc chắn không còn chạy được và làm cả build fail | Sửa Run Script phase trong `project.pbxproj`: cho phép script fail mà không chặn build (log warning thay vì `exit` lỗi). Quyền Accessibility giờ phải cấp **thủ công** 1 lần qua System Settings → Privacy & Security → Accessibility |

Kết quả: `xcodebuild ... build` chạy sạch, `Vimac.app` mở được, Hint-mode/Scroll-mode hoạt động
trên UI native. Đã verify thực tế bằng cách mở app và dùng thử Hint-mode.

## Phase 1 — Dọn phần đã "chết"/không cần cho bản cá nhân

### Đã xong
- ✅ Gỡ Segment Analytics (xong ở Phase 0 vì nó chặn build).
- ✅ **Gỡ hẳn Sparkle auto-update**: xóa pod `Sparkle`, `checkForUpdatesInBackground()` +
  `SUUpdaterDelegate` conformance trong `AppDelegate.swift`, menu item "Check for updates" trong
  `StatusItemManager.swift`, `SUFeedURL`/`SUPublicEDKey` (trỏ vào `api.appcenter.ms` — **Visual
  Studio App Center đã bị Microsoft khai tử từ 31/3/2025**, nên auto-update chắc chắn không hoạt
  động) khỏi `Info.plist`, và xóa hẳn `appcenter-post-build.sh`. Build + chạy lại app đã verify OK.
- ✅ **Thay `MASShortcut` (pod ObjC ngừng cập nhật) bằng `KeyboardShortcuts`** (sindresorhus, SPM,
  đang active):
  - Thêm SPM package `https://github.com/sindresorhus/KeyboardShortcuts` (v2.4.0) vào target `Vimac`
    bằng cách chỉnh `project.pbxproj` trực tiếp qua gem `xcodeproj` (Ruby script, không dùng Xcode
    GUI) — resolve/build thành công.
  - Đổi tên class wrapper riêng của Vimac từ `KeyboardShortcuts` → `VimacShortcuts`
    (`Bindings/KeyboardShortcuts.swift`) để tránh đụng namespace với package; định nghĩa
    `KeyboardShortcuts.Name` tĩnh (`.hintMode`, `.scrollMode`) kèm default shortcut ngay trong code
    thay vì gọi `registerDefaults()` runtime như MASShortcut.
  - `Bindings/BindingsPreferenceViewController.swift`: thay 2 `MASShortcutView` bằng
    `KeyboardShortcuts.RecorderCocoa(for:)`.
  - Gỡ `#import <MASShortcut/Shortcut.h>` khỏi `VimacBridgingHeader.h`, gỡ pod `MASShortcut` khỏi
    `Podfile`, gỡ `import MASShortcut` không dùng trong `Utils.swift`/`AppDelegate.swift`.
  - **Tác dụng phụ phải xử lý**: bridging header trước đây âm thầm kéo theo `Carbon` (qua
    `MASShortcut/Shortcut.h`) nên 4 file dùng hằng số `kVK_*` (`ScrollModeInputListener.swift`,
    `Modes/HintModeController.swift`, `ViewControllers/ScrollModeViewController.swift`,
    `ViewControllers/ScrollModeActiveViewController.swift`) build lỗi "cannot find kVK_Escape in
    scope" sau khi gỡ — phải thêm `import Carbon.HIToolbox` tường minh vào từng file.
  - **Yêu cầu nâng `MACOSX_DEPLOYMENT_TARGET`**: package `KeyboardShortcuts` yêu cầu tối thiểu macOS
    10.15 → đã nâng target chính + `Podfile` từ 10.14 lên **10.15** (thay đổi nhỏ, không đụng tới
    quyết định nâng lớn hơn ở Phase 2).
  - Build + chạy lại app đã verify OK; **còn cần user tự tay thử ghi shortcut mới trong Preferences
    → Bindings để xác nhận UI recorder hoạt động đúng** (chưa test tương tác UI này).

### Còn cần làm
- ⬜ Nâng `LaunchAtLogin` (hiện tại v4.0.0 qua Carthage, dùng cơ chế login-item cũ) lên bản mới hơn
  dùng `SMAppService` (API macOS 13+), chuyển hẳn sang SPM. **Cố tình hoãn lại** — package
  `LaunchAtLogin-Modern` yêu cầu `MACOSX_DEPLOYMENT_TARGET` 13+, một quyết định lớn hơn nên gộp
  chung với việc nâng deployment target ở Phase 2 thay vì làm rời rạc từng phần.

## Phase 2 — Hiện đại hoá dependency & build

- ⬜ Gộp toàn bộ dependency về Swift Package Manager, bỏ hẳn CocoaPods (`Podfile`, `Pods/`) và
  Carthage (`Cartfile`, `Carthage/`). `KeyboardShortcuts` đã là SPM (xong ở Phase 1) — còn lại
  `AXSwift`, `RxSwift`/`RxCocoa`, `Preferences` (CocoaPods) và `LaunchAtLogin` (Carthage).
- ⬜ Nâng `MACOSX_DEPLOYMENT_TARGET` lên mức hợp lý hơn nữa cho máy cá nhân (vd. 13/14). Đã nâng một
  bước nhỏ từ 10.14 → **10.15** ở Phase 1 (yêu cầu tối thiểu của `KeyboardShortcuts`); việc nâng lên
  13+ (để dùng `LaunchAtLogin-Modern`/`SMAppService`) là quyết định lớn hơn, làm cùng lúc với việc
  gỡ Carthage.
- ⬜ Dọn cảnh báo build còn sót (vd. `@_functionBuilder` đã đổi tên thành `@resultBuilder` trong pod
  `Preferences` — chỉ là warning, không chặn build).

## Phase 3 — Kiểm tra lại hành vi Accessibility trên macOS/trình duyệt hiện tại

`docs/state-of-non-native-support.md` được viết năm 2021, mô tả hành vi Chromium AX đã lỗi thời.
Qua quá trình test thực tế trên trang web nội bộ (Base Enterprise, chạy trong Arc browser), đã
xác nhận bằng Accessibility Inspector + log runtime:

- **Đã fix**: `ElementTree.isActionable()` từng liệt `AXShowMenu` vào danh sách action bị bỏ qua
  hoàn toàn — khiến các phần tử chỉ có action này (phổ biến với clickable `<div>` không dùng ARIA
  chuẩn) không bao giờ được hint dù nằm trong nhánh duyệt cây generic (`TraverseGenericElementService`).
  Đã gỡ `AXShowMenu` khỏi danh sách ignore — fix này **an toàn, giữ nguyên**, không gây flood.
- **Đã xác nhận nhưng CHƯA fix được** (đã thử và revert): với các trang dùng nhánh
  `TraverseSearchPredicateCompatibleWebAreaElementService` (khi `AXWebArea` hỗ trợ
  `AXUIElementsForSearchPredicate`), Chromium/Arc **không bao giờ trả về** các `AXGroup` clickable
  tùy biến (role generic + JS click handler, không dùng ARIA `role="button"`/`role="link"`) qua bất
  kỳ search key chuẩn nào (`AXButtonSearchKey`, `AXControlSearchKey`, v.v. — đã verify bằng log,
  109 elements trả về, 0 cái khớp `AXGroup+AXShowMenu`). Thử thêm `AXAnyTypeSearchKey` để bắt được
  các phần tử này thì lại flood hint vào từng đoạn text/hình ảnh có thể chọn trên toàn trang (vì
  hầu như mọi text/image selectable đều có action tương tự ở tầng trình duyệt). Thử loại trừ riêng
  `AXStaticText`/`AXImage` khỏi hintable vẫn không đủ để hết flood → đã **revert về trạng thái an
  toàn** (không có `AXAnyTypeSearchKey`).
  - **Trade-off đã chấp nhận**: một số phần tử clickable không dùng ARIA chuẩn trong các trang web
    phức tạp (vd. dòng kênh chat cụ thể trong Base Enterprise) sẽ không hint được, đổi lại Hint-mode
    không bị flood trên các trang khác.
  - Việc còn tồn đọng đã sửa (giữ lại, không revert): nhánh
    `TraverseSearchPredicateCompatibleWebAreaElementService.getRecursiveChildrenThroughSearchPredicate()`
    trước đây có "fast path" gộp nhiều search key vào 1 query, chỉ fallback sang chạy từng key riêng
    khi kết quả gộp = 0 — theo đúng comment trong code, đây là cách né 1 bug lịch sử của Chromium
    (~2021). Đã đổi thành luôn chạy từng key riêng rồi union kết quả (chắc chắn đúng hơn, đổi lại
    chậm hơn 1 chút do gọi AX API nhiều lần hơn) — fix này **an toàn, giữ nguyên**.
- ⬜ **Việc còn mở**: nếu sau này thực sự cần hint được các phần tử clickable non-semantic kiểu này
  (chỉ trên 1 vài trang cụ thể), hướng khả thi nhất là làm **toggle riêng theo domain/app**
  (giống cơ chế `AXEnhancedUserInterfaceActivator`/`AXManualAccessibilityActivator` đã có sẵn cho
  Chromium/Electron) — bật `AXAnyTypeSearchKey` + lọc bớt theo kích thước/khoảng cách giữa các
  candidate chỉ khi user chủ động bật cho 1 site cụ thể, thay vì bật mặc định toàn cục.

## Vệ sinh repo (không thuộc phase cụ thể, phát hiện khi review `.gitignore`)

- ✅ `.gitignore` cũ thiếu/sai nhiều chỗ, đã sửa:
  - **`Carthage/Checkouts/` (3.3MB, 25 file, gồm cả `.zip` binary) đang bị commit vào repo** — source
    checkout của dependency bên thứ 3, regenerate được bằng `carthage bootstrap`, không nên track.
  - **`xcuserdata/` của 2 máy dev khác (`macintosh`, `robin` — không phải máy hiện tại) đang bị
    commit** — state UI cá nhân của Xcode (breakpoints, UI state). `.gitignore` cũ chỉ chặn
    `*.xcworkspace/xcuserdata/`, thiếu `*.xcodeproj/xcuserdata/`.
  - `Carthage/Build/` trước đây chỉ "may mắn" bị ignore vì trùng khớp tình cờ với pattern `build/`
    (chữ thường) do filesystem macOS mặc định không phân biệt hoa/thường — trên Linux/CI (phân biệt
    hoa thường) sẽ bị track nhầm. Đã thêm rule tường minh.
  - Thêm `.build/` (SwiftPM CLI), `*.xcuserstate`, dọn dòng `Pods/` bị lặp 2 lần.
  - Đã `git rm --cached` 29 file matched các rule mới (file vẫn còn nguyên trên đĩa, chỉ gỡ khỏi git
    index) — cần **commit riêng** trước khi commit các thay đổi code khác.
  - Không đụng tới `**/xcshareddata/swiftpm/Package.resolved` (2 file, do thêm SPM package
    `KeyboardShortcuts` ở Phase 1) — các file này **nên được track** để lock version dependency.

## Phase 4 — Custom theo ý cá nhân

Làm sau khi nền tảng đã ổn định. Ví dụ: đổi phím tắt mặc định, thêm mode mới, tối ưu UI hint, thêm
toggle riêng cho Base Enterprise (xem Phase 3).

---

## Ghi chú vận hành (quan trọng khi tiếp tục dev)

- Build: `pod install && carthage build` (không kèm `--use-xcframeworks`) rồi
  `xcodebuild -workspace Vimac.xcworkspace -scheme Vimac -configuration Debug -destination 'platform=macOS' -allowProvisioningUpdates build`,
  hoặc mở `Vimac.xcworkspace` trong Xcode và Run trực tiếp.
- Sau khi build xong lần đầu/đổi signing: cấp quyền Accessibility **thủ công** cho `Vimac.app` (và
  Xcode, nếu cần) qua System Settings → Privacy & Security → Accessibility — script tự động cũ đã
  hỏng vĩnh viễn trên macOS hiện tại (xem Phase 0, mục 8).
- Debug hint-mode trên 1 trang cụ thể: dùng **Accessibility Inspector** (`Xcode.app/Contents/Applications/Accessibility Inspector.app`)
  ở chế độ Point mode để xem Role/Actions/Frame thực tế của phần tử, và `log stream --predicate 'subsystem CONTAINS "dexterleng"'`
  để xem log runtime của Vimac (`os_log` trong `Log.accessibility`).
