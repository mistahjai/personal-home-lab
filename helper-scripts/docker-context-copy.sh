#!/bin/bash
set -eo pipefail

# Define container name 
CONT_NAME="your-container-name"

# Define the source and destination contexts
SRC_CTX="default"
DEST_CTX="nspawn"

# create and switch context
docker context create "$DEST_CTX" --docker "host=tcp://$CONT_NAME:2375"
docker context use "$DEST_CTX"   

# TRANSFER IMAGES
# Get all tagged images (filtering out untagged/dangling '<none>:<none>' images)
IMAGES=$(docker --context $SRC_CTX images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>')

if [ -z "$IMAGES" ]; then
  echo "No tagged images found to migrate."
  exit 0
fi

echo "Found images to migrate:"
echo "$IMAGES"
echo "---------------------------------"

for img in $IMAGES; do
  echo "Migrating image: $img"
  
  # Stream the image archive directly from source to destination daemon
  docker --context $SRC_CTX save "$img" | docker --context $DEST_CTX load
  
  echo "  -> Done"
done

echo "---------------------------------"
echo "All images successfully migrated to the nspawn sandbox!"


# TRANSFER NAMED VOLUMES
# Ensure alphine images exist at both contexts
docker --context $SRC_CTX pull alpine
docker --context $DEST_CTX pull alpine

echo "⚠️  Ensure all containers using these volumes in the '$SRC_CTX' context are STOPPED before proceeding."
read -p "Press Enter to continue or Ctrl+C to abort..."

# Get all volumes, filtering out 64-character anonymous volumes
VOLUMES=$(docker --context $SRC_CTX volume ls -q | grep -vE '^[0-9a-f]{64}$')

if [ -z "$VOLUMES" ]; then
  echo "No named volumes found to migrate."
  exit 0
fi

echo "Found volumes to migrate:"
echo "$VOLUMES"
echo "---------------------------------"

for vol in $VOLUMES; do
  echo "Migrating volume: $vol"
  
  # 1. Create the empty named volume on the destination daemon
  docker --context $DEST_CTX volume create "$vol" > /dev/null
  
  # 2. Stream the tar archive directly from source to destination in memory
  # Added -p to the destination tar to strictly preserve file permissions
  docker --context $SRC_CTX run --rm -v "$vol":/source alpine tar -C /source -cf - . | \
  docker --context $DEST_CTX run --rm -i -v "$vol":/target alpine tar -C /target -xpf -
  
  echo "  -> Done"
done

echo "---------------------------------"
echo "All named volumes successfully migrated to the nspawn sandbox!"
