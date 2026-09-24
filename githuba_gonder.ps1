$ErrorActionPreference = "Stop"

$source = "C:\pazarcik_portal"
$target = "C:\pazarcik_portal_github_upload"

if (!(Test-Path $target)) {
  throw "GitHub upload klasoru bulunamadi: $target"
}

$files = @(
  "pubspec.yaml",
  "functions\index.js",
  "lib\main.dart",
  "lib\profil\profile.dart",
  "lib\profil\edit_profile.dart",
  "lib\profil\phone_verification_page.dart",
  "lib\services\phone_verification.dart",
  "test\phone_verification_test.dart",
  "lib\auth\auth.dart",
  "lib\views\cekgonder.dart",
  "lib\business\BusinessDetailPage.dart",
  "lib\isilani\job_detail_page.dart",
  "lib\admin\admin_panel.dart",
  "lib\admin\admin_notification_service.dart",
  "lib\admin\admin_store_orders_tab.dart",
  "lib\admin\admin_taxi_tab.dart",
  "lib\admin\admin_manual_job_tab.dart",
  "lib\esnaf_sistemi\lib\views\main\seller\dashboard.dart",
  "lib\esnaf_sistemi\lib\views\main\seller\dashboard_screens\upload_product.dart",
  "lib\esnaf_sistemi\lib\views\main\seller\dashboard_screens\edit_product.dart",
  "lib\esnaf_sistemi\lib\views\main\seller\dashboard_screens\manage_products.dart",
  "lib\esnaf_sistemi\lib\views\main\product\details.dart",
  "lib\esnaf_sistemi\lib\views\main\store\store_details.dart",
  "lib\esnaf_sistemi\lib\utils\food_compliance.dart",
  "lib\esnaf_sistemi\lib\models\cart.dart",
  "lib\esnaf_sistemi\lib\providers\cart.dart",
  "lib\esnaf_sistemi\lib\views\main\customer\cart.dart",
  "lib\esnaf_sistemi\lib\views\main\customer\order_summary.dart"
)

$welcomeFiles = @(
  "lib\onboarding\portal_welcome.dart",
  "test\portal_welcome_test.dart",
  "web\index.html",
  "ios\Runner\Info.plist",
  "ios\Runner\Base.lproj\LaunchScreen.storyboard"
)
foreach ($directory in @(
  "ios\Runner\Assets.xcassets\LaunchImage.imageset",
  "ios\Runner\Assets.xcassets\LaunchBackground.imageset",
  "web\splash"
)) {
  $welcomeFiles += Get-ChildItem -LiteralPath (Join-Path $source $directory) -Recurse -File |
    ForEach-Object { $_.FullName.Substring($source.Length + 1) }
}
$welcomeFiles += Get-ChildItem -LiteralPath (Join-Path $source "android\app\src\main\res") -Recurse -File |
  Where-Object { $_.Name -in @("splash.png", "android12splash.png", "background.png", "launch_background.xml", "styles.xml") } |
  ForEach-Object { $_.FullName.Substring($source.Length + 1) }
foreach ($image in @("assets\portal_splash_portrait.jpg", "assets\portal_splash_landscape.jpg")) {
  if (Test-Path -LiteralPath (Join-Path $source $image)) { $welcomeFiles += $image }
}
$files += $welcomeFiles

foreach ($file in $files) {
  $src = Join-Path $source $file
  $dst = Join-Path $target $file
  $dstDir = Split-Path $dst -Parent

  if (!(Test-Path $src)) {
    throw "Kaynak dosya bulunamadi: $src"
  }

  if (!(Test-Path $dstDir)) {
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
  }

  Copy-Item -LiteralPath $src -Destination $dst -Force
}

git -C $target status --short
git -C $target add `
  pubspec.yaml `
  functions/index.js `
  lib/main.dart `
  lib/profil/profile.dart `
  lib/profil/edit_profile.dart `
  lib/profil/phone_verification_page.dart `
  lib/services/phone_verification.dart `
  test/phone_verification_test.dart `
  lib/auth/auth.dart `
  lib/views/cekgonder.dart `
  lib/business/BusinessDetailPage.dart `
  lib/isilani/job_detail_page.dart `
  lib/admin/admin_panel.dart `
  lib/admin/admin_notification_service.dart `
  lib/admin/admin_store_orders_tab.dart `
  lib/admin/admin_taxi_tab.dart `
  lib/admin/admin_manual_job_tab.dart `
  lib/esnaf_sistemi/lib/views/main/seller/dashboard.dart `
  lib/esnaf_sistemi/lib/views/main/seller/dashboard_screens/upload_product.dart `
  lib/esnaf_sistemi/lib/views/main/seller/dashboard_screens/edit_product.dart `
  lib/esnaf_sistemi/lib/views/main/seller/dashboard_screens/manage_products.dart `
  lib/esnaf_sistemi/lib/views/main/product/details.dart `
  lib/esnaf_sistemi/lib/views/main/store/store_details.dart `
  lib/esnaf_sistemi/lib/utils/food_compliance.dart `
  lib/esnaf_sistemi/lib/models/cart.dart `
  lib/esnaf_sistemi/lib/providers/cart.dart `
  lib/esnaf_sistemi/lib/views/main/customer/cart.dart `
  lib/esnaf_sistemi/lib/views/main/customer/order_summary.dart
git -C $target add -- $welcomeFiles
git -C $target commit -m "Add welcome flow and latest portal updates"
git -C $target push origin main

git -C $target rev-parse --short HEAD
