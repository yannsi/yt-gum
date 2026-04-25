# Maintainer: Your Name <your@email.com>
pkgname=yt-gum
pkgver=1.0.0
pkgrel=1
pkgdesc="YouTube TUI powered by gum and yt-dlp"
arch=('any')
url="https://github.com/yannsi/yt-gum"
license=('MIT')
depends=('gum' 'yt-dlp' 'mpv' 'ffmpeg')
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$srcdir/$pkgname-$pkgver"
    install -Dm755 yt-gum.sh "$pkgdir/usr/bin/yt-gum"
}
