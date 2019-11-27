# regex

Pony library that brings Perl compatible regular expressions to Pony. Requires libpcre2. See installation for more details.

## Status

[![Actions Status](https://github.com/ponylang/regex/workflows/vs-ponyc-latest/badge.svg)](https://github.com/ponylang/regex/actions)

Production ready.

## Installation

* Install [pony-stable](https://github.com/ponylang/pony-stable)
* Update your `bundle.json`

```json
{
  "deps": [
    { "type": "github",
      "repo": "ponylang/regex",
      "tag": "1.0.0"
    }
  ]
}
```

* `stable fetch` to fetch your dependencies
* `use "regex"` to include this package
* `stable env ponyc` to compile your application

## Dependencies

`regex` requires the libpcre2 library in order to operate. You'll need to install it within your environment of choice, either via your package manager or from source.

### Installing on APT based Linux distributions

```
sudo apt-get install -y libpcre2-dev
```

### Installing on Alpine Linux

```
apk add --update pcre2-dev
```

### Installing on Arch Linux

```
pacman -S pcre2

```

### Installing on DragonFly

```
sudo pkg install pcre2
```

### Installing on FreeBSD

```
sudo pkg install pcre2
```

### Installing on macOS with Homebrew

```
brew update
brew install pcre2
```

#### Installing on macOS with MacPorts

```
sudo port install pcre2
```

### Installing on OpenBSD

```
doas pkg_add pcre2
```

### Installing on RPM based Linux distributions with dnf

```
sudo dnf install pcre2-devel
```

### Installing on RPM based Linux distributions with yum

```
sudo yum install pcre2-devel
```

### Installing on RPM based Linux distributions with zypper

```
sudo zypper install pcre2-devel
```
### Installing on Windows

Download a prebuilt binary from [http://www.pcre.org/](http://www.pcre.org/).

### Building PCRE2 from source

```
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.21.tar.bz2
tar xvf pcre2-10.21.tar.bz2
cd pcre2-10.21
./configure --prefix=/usr
make
sudo make install
```
