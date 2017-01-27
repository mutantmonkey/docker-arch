# docker-arch

Tools for building an Arch Linux base image for Docker.

# Building

Building the base image requires zsh, expect, and arch-install-scripts. Run `./mkimage.sh` to generate the rootfs. Then run `docker build .`.
