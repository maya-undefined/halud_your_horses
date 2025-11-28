Halud Your Horses is a small containerized development workflow designed to reduce exposure to supply-chain attacks in the 
JavaScript and Node.js ecosystem. Every project runs inside an isolated container with its own node_modules volume. Nothing from 
npm executes directly on the host machine. The tools are simple shell scripts that create, enter, and fork project-specific 
development images.

## 1. Installation
 

### Initializing a Project
 
```
git clone <repo-url> jsdev
```

Add the directory to your PATH. For example:

```
export PATH="$PWD/jsdev:$PATH"
```

## Basic Usage


### Initializing a Project


Run `jsdev-init.sh` inside the project directory or pass the directory as an argument:


```
jsdev-init.sh
jsdev-init.sh myproject
```


This creates a Dockerfile, initializes the development image, and sets up a separate persistent node_modules volume.


### Starting a Development Shell


To enter the containerized environment for a project:


```
jsdev-shell.sh
jsdev-shell.sh .
jsdev-shell.sh path/to/project
```


The script automatically mounts the project source and attaches the project’s node_modules volume.


### Forking an Image


To create a new development image derived from an existing project image:


```
jsdev-fork.sh . newimagename
```


This produces a separate image that inherits the environment from the project’s current image.


## Using Dockerfile Extensions


Users can optionally append custom instructions to all generated project Dockerfiles. First, define a Dockerfile extension 
file (for example `~/.jsdev/Dockerfile.ext`):


```
RUN apt-get update && apt-get install -y tmux
```


Enable it in the configuration file:


```
JSDEV_DOCKERFILE_EXT="$HOME/.jsdev/Dockerfile.ext"
```


To override the extension file for a single run:


```
JSDEV_DOCKERFILE_EXT=./Dockerfile.ext jsdev-init.sh .
```


## Troubleshooting Podman Rootless Mode


Some distributions require user namespace ranges to be configured for rootless Podman. If you encounter errors involving UID 
or GID mapping when building images, add subuid and subgid ranges:


```
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
```


After modifying these files, reset Podman’s storage:


```
podman system reset
```


This clears old state and regenerates user namespace mappings.


## Notes

Developers can extend their environment using `Dockerfile.ext`, override settings temporarily with environment variables, and 
maintain clean separation across projects via stable hashed volumes.

The purpose of Halud Your Horses is to avoid direct execution of untrusted npm packages on the host system. By isolating 
dependencies, the system limits the impact of future supply-chain attacks similar to the shai haluud incident. All core 
functionality is handled by minimal shell scripts, keeping the system transparent and easy to audit.


