#!/bin/bash

echo "Building syslic.go into syslic.bin for Linux x86_64..."

GOOS=linux GOARCH=amd64 go build -o syslic.bin syslic.go

if [ $? -eq 0 ]; then
  echo "✅ Build successful: syslic.bin created."

  echo "Adding syslic.bin to Git staging..."
  git add syslic.bin

  echo "Committing syslic.bin..."
  git commit -m "Auto-build: added syslic.bin"

  echo "Pushing to origin..."
  git push origin main

  echo "✅ syslic.bin committed and pushed to GitHub."
else
  echo "❌ Build failed."
fi
