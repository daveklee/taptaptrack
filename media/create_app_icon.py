#!/usr/bin/env python3
"""
Generate App Store icon for Tap Tap Track
Creates a 1024x1024 PNG with gradient background and centered logo
"""

from PIL import Image, ImageDraw
import os

# Configuration
ICON_SIZE = 1024
LOGO_SIZE = 920  # Size of logo on the icon (increased to fill more of the square)
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
LOGO_PATH = os.path.join(OUTPUT_DIR, "taptaptrack_logo.png")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "AppIcon_1024x1024.png")

# Gradient colors (matching app theme)
GRADIENT_START = (102, 126, 234)  # #667eea
GRADIENT_END = (118, 75, 162)     # #764ba2


def create_gradient(size, start_color, end_color):
    """Create a diagonal gradient image."""
    image = Image.new('RGB', (size, size))
    
    for y in range(size):
        for x in range(size):
            # Diagonal gradient (top-left to bottom-right)
            ratio = (x + y) / (2 * size)
            r = int(start_color[0] * (1 - ratio) + end_color[0] * ratio)
            g = int(start_color[1] * (1 - ratio) + end_color[1] * ratio)
            b = int(start_color[2] * (1 - ratio) + end_color[2] * ratio)
            image.putpixel((x, y), (r, g, b))
    
    return image


def convert_blue_to_white(logo):
    """
    Convert blue parts of logo to white, and white background to transparent.
    This handles logos with white backgrounds and colored (blue) designs.
    """
    # Convert to RGBA if not already
    if logo.mode != 'RGBA':
        logo = logo.convert('RGBA')
    
    pixels = logo.load()
    width, height = logo.size
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            
            # Calculate how "white" the pixel is (close to 255,255,255)
            # White or very light pixels become transparent
            brightness = (r + g + b) / 3
            
            if brightness > 240:  # Nearly white - make transparent
                pixels[x, y] = (255, 255, 255, 0)
            else:
                # Has color - make it white but keep some anti-aliasing
                # The darker/more colored the pixel, the more opaque
                opacity = int(255 - brightness)
                opacity = min(255, int(opacity * 1.5))  # Boost opacity
                pixels[x, y] = (255, 255, 255, opacity)
    
    return logo


def convert_to_white_preserve_shape(logo):
    """
    Alternative method: detect the logo shape by finding non-white pixels
    and convert them to white on transparent background.
    """
    # Convert to RGBA
    if logo.mode != 'RGBA':
        logo = logo.convert('RGBA')
    
    pixels = logo.load()
    width, height = logo.size
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            
            # Check if this pixel is part of the logo (not white background)
            # Logo appears to be blue, so we check for blue-ish pixels
            is_white_bg = (r > 245 and g > 245 and b > 245)
            
            if is_white_bg:
                # Background - make transparent
                pixels[x, y] = (0, 0, 0, 0)
            else:
                # Logo part - calculate opacity based on how far from white
                # More saturated/darker = more opaque
                max_diff = max(255 - r, 255 - g, 255 - b)
                avg_diff = (255 - r + 255 - g + 255 - b) / 3
                
                # Use the blue channel difference for logos that are primarily blue
                blue_intensity = max(0, b - max(r, g))  # How blue is it
                
                # Opacity based on how "not white" the pixel is
                opacity = int(min(255, avg_diff * 2))
                
                if opacity > 10:  # Only keep visible pixels
                    pixels[x, y] = (255, 255, 255, opacity)
                else:
                    pixels[x, y] = (0, 0, 0, 0)
    
    return logo


def main():
    print("🎨 Creating Tap Tap Track App Icon...")
    
    # Check if logo exists
    if not os.path.exists(LOGO_PATH):
        print(f"❌ Logo not found at: {LOGO_PATH}")
        return
    
    # Create gradient background
    print("  → Creating gradient background...")
    background = create_gradient(ICON_SIZE, GRADIENT_START, GRADIENT_END)
    
    # Load logo
    print("  → Loading logo...")
    logo = Image.open(LOGO_PATH)
    print(f"     Original size: {logo.size}, mode: {logo.mode}")
    
    # Convert logo: blue parts to white, white background to transparent
    print("  → Converting logo (blue → white, background → transparent)...")
    logo_white = convert_to_white_preserve_shape(logo)
    
    # Resize logo to fit
    print(f"  → Resizing logo to {LOGO_SIZE}x{LOGO_SIZE}...")
    # Maintain aspect ratio
    logo_white.thumbnail((LOGO_SIZE, LOGO_SIZE), Image.Resampling.LANCZOS)
    
    # Calculate position to center logo
    logo_x = (ICON_SIZE - logo_white.width) // 2
    logo_y = (ICON_SIZE - logo_white.height) // 2
    
    # Convert background to RGBA for compositing
    background = background.convert('RGBA')
    
    # Paste logo onto background using alpha channel as mask
    print("  → Compositing icon...")
    background.paste(logo_white, (logo_x, logo_y), logo_white)
    
    # Convert back to RGB (no transparency for App Store)
    background = background.convert('RGB')
    
    # Save the icon
    print(f"  → Saving to {OUTPUT_PATH}...")
    background.save(OUTPUT_PATH, 'PNG')
    
    print(f"\n✅ App icon created successfully!")
    print(f"   📁 {OUTPUT_PATH}")
    print(f"   📐 Size: {ICON_SIZE}x{ICON_SIZE} pixels")
    print(f"\n📱 Next steps:")
    print(f"   1. Open Xcode")
    print(f"   2. Go to TapTapTrack → Assets.xcassets → AppIcon")
    print(f"   3. Drag {os.path.basename(OUTPUT_PATH)} into the 'App Store iOS 1024pt' slot")


if __name__ == "__main__":
    main()
