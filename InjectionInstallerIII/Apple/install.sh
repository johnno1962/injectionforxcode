#!/bin/bash

echo "mkdir -p ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins/ && cp -rf /Applications/Injection\ Plugin.app/Contents/Resources/InjectionPlugin.xcplugin ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins/" | sudo -u $USER /bin/bash

