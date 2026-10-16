PC Optimizer — Final Electron Icon Pack

Included:
- pc-optimizer-final-1024.png — master PNG, 1024x1024
- pc-optimizer-final-512.png — PNG, 512x512
- pc-optimizer-final-256.png — PNG, 256x256
- pc-optimizer-final.ico — Windows icon with multiple resolutions

Example electron-builder configuration in package.json:
{
  "build": {
    "win": {
      "icon": "build/pc-optimizer-final.ico"
    },
    "linux": {
      "icon": "build/pc-optimizer-final-512.png"
    }
  }
}

Copy the icon files into your project's build/ directory.
For a BrowserWindow, use the PNG path in the BrowserWindow options:
icon: path.join(__dirname, "build/pc-optimizer-final-512.png")

Note: macOS app packaging generally uses an .icns file.
