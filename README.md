## T2 LTS kernel Ubuntu

**Ubuntu longterm (LTS) Kernel** with T2 patches built-in. This project is inspired by **t2linux/T2-Debian-and-Ubuntu-Kernel** to/and continue with the LTS Kernel that continues with official support.

## Installation

### Build kernel with this Repository

- Build in the main System

```bash
$ git clone https://github.com/bluerapik/t2-linux-kernel.git
$ sudo ./build.sh
```

- or in Docker with docker-compose. "codename" is **focal**, **jammy** or **noble**. If n

```bash
$ docker compose -f docker-compose.yml up <codename>
```

- Install the kernel

```bash
$ sudo dpkg -i workspace/release/linux-headers*.deb && sudo dpkg -i workspace/release/linux-image*.deb
```

### Download package from this Repository

Download the **.deb** packages of **linux-headers** and **linux-image** from the
[releases](https://github.com/bluerapik/t2-linux-kernel.git/releases)
section and install the kernel with:

```bash
$ sudo dpkg -i linux-headers*.deb && sudo dpkg -i linux-image*.deb
```

## Uninstall

- List all kernel in the system

```bash
$ dpkg -l linux-image*
```

- Remove the kernel

```bash
$ apt purge linux-{image,headers}-<version>*
```

## Thanks

Special Thanks to @AdityaGarg8 for maintaining the main project [T2 Debian and Ubuntu kernels](https://github.com/t2linux/T2-Debian-and-Ubuntu-Kernel.git)
