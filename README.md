# docker-base-images

Base images for Docker

## Usage

Clone the repository:

    git clone https://github.com/kaorimatz/docker-base-images
    cd docker-base-images

Create a Docker base image by running one of the `make-image-*.sh`:

    ./make-image-dnf.sh --os-name=fedora --os-version=22 fedora

## Example

Create a Fedora Rawhide Docker base image using DNF:

    ./make-image-dnf.sh --os-name=fedora --os-version=rawhide fedora

Create a Arch Linux Docker base image using Pacman:

    ./make-image-pacman.sh archlinux

Create a CentOS 7 Docker base image using Yum:

    ./make-image-yum.sh --os-name=centos --os-version=7 centos
