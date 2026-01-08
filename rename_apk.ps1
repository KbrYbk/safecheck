$version = "1.0.0"  # версия из pubspec.yaml
$path = "build\app\outputs\flutter-apk"

$files = @(
    "app-arm64-v8a-release.apk",
    "app-armeabi-v7a-release.apk",
    "app-x86_64-release.apk"
)

foreach ($file in $files) {
    $source = "$path\$file"
    if (Test-Path $source) {
        # определяем архитектуру
        if ($file -like "*arm64*") { $arch = "arm64" }
        elseif ($file -like "*armeabi*") { $arch = "armeabi-v7a" }
        elseif ($file -like "*x86_64*") { $arch = "x86_64" }
        else { $arch = "unknown" }

        $dest = "$path\SafeCheck-$version-$arch.apk"

        # удаляем старый файл, если есть
        if (Test-Path $dest) { Remove-Item $dest -Force }

        Rename-Item $source $dest
        Write-Host "Переименован $file → SafeCheck-$version-$arch.apk"
    } else {
        Write-Host "Файл $file не найден, пропускаем"
    }
}
