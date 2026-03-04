# Justfile for zirconium-extend
IMAGE_NAME := "zirconium-extend"

# Build the container locally
build:
    podman build -t {{IMAGE_NAME}} -f Containerfile .

# Run the container for testing
run:
    podman run -it --rm {{IMAGE_NAME}}

# Push to a registry (requires LOGIN/REGISTRY info)
push:
    podman push {{IMAGE_NAME}}

# Clean local images
clean:
    podman rmi {{IMAGE_NAME}}
