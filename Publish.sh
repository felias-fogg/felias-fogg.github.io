#!/bin/bash

# Copy new index file to 'legacy' index file 
cp -f package_debug_enabled_index.json  package_debugging_index.json

# Now publish the new package index

echo "Commiting changes"
git commit -a -m "New version"

echo Uploading everything to the main website
git push

echo "Coppy index file to downloads repo"
cp -f package_debug_enabled_index.json ../downloads/

echo "Commit and upload"
cd ../downloads
git commit -a -m "New version"
git push