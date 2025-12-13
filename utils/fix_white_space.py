#!/usr/bin/env python3
"""
Post-process screenshots to remove white space at the bottom
Ensures output is exactly 1242 × 2688px by extending the background gradient
"""

from PIL import Image
import sys
import os

def remove_white_space(image_path, target_width=None, target_height=None):
    """Remove white space and ensure exact dimensions"""
    # Default to iPhone size if not specified
    if target_width is None:
        target_width = 1242
    if target_height is None:
        target_height = 2688
    
    img = Image.open(image_path)
    width, height = img.size
    
    # Convert to RGB if needed
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    # Always ensure exact dimensions first
    if width != target_width or height != target_height:
        img = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
        img.save(image_path)
        print(f"     📐 Resized to {target_width} × {target_height}px")
        # Reload after resize
        img = Image.open(image_path)
        if img.mode != 'RGB':
            img = img.convert('RGB')
        width, height = img.size
    
    # Find the last row with actual content (not white)
    # Search from bottom up, looking for where white space starts
    content_bottom = None
    
    # Check if bottom row is white
    bottom_row = img.crop((0, height - 1, width, height))
    bottom_pixels = list(bottom_row.getdata())
    bottom_avg = sum(sum(p) for p in bottom_pixels) / (len(bottom_pixels) * 3)
    bottom_white = sum(1 for p in bottom_pixels if p[0] > 250 and p[1] > 250 and p[2] > 250)
    bottom_white_ratio = bottom_white / len(bottom_pixels)
    
    # If bottom is white, find where content actually ends
    if bottom_avg > 240 or bottom_white_ratio > 0.8:
        # Search up to 100 rows to find content
        for y in range(height - 1, max(0, height - 100), -1):
            row = img.crop((0, y, width, y + 1))
            row_pixels = list(row.getdata())
            
            avg_r = sum(p[0] for p in row_pixels) / len(row_pixels)
            avg_g = sum(p[1] for p in row_pixels) / len(row_pixels)
            avg_b = sum(p[2] for p in row_pixels) / len(row_pixels)
            avg_brightness = (avg_r + avg_g + avg_b) / 3
            
            white_count = sum(1 for p in row_pixels if p[0] > 250 and p[1] > 250 and p[2] > 250)
            white_ratio = white_count / len(row_pixels)
            
            # If this row is NOT white (content), this is where we should extend from
            if avg_brightness < 240 and white_ratio < 0.8:
                content_bottom = y + 1
                break
    
    # If we found white space, extend the image
    if content_bottom and content_bottom < target_height:
        # Create new image
        new_img = Image.new('RGB', (target_width, target_height))
        
        # Copy content
        content_img = img.crop((0, 0, width, content_bottom))
        new_img.paste(content_img, (0, 0))
        
        # Sample background color from the last 20 rows of actual content
        sample_start = max(0, content_bottom - 20)
        sample_area = img.crop((0, sample_start, width, content_bottom))
        sample_pixels = list(sample_area.getdata())
        
        # Get background pixels (exclude very bright and very dark)
        bg_pixels = [p for p in sample_pixels if 50 < sum(p) < 600]
        
        if len(bg_pixels) > 50:
            # Use median for robustness
            all_r = sorted([p[0] for p in bg_pixels])
            all_g = sorted([p[1] for p in bg_pixels])
            all_b = sorted([p[2] for p in bg_pixels])
            mid = len(all_r) // 2
            bg_color = (all_r[mid], all_g[mid], all_b[mid])
        else:
            # Fallback: use median of all pixels
            all_r = sorted([p[0] for p in sample_pixels])
            all_g = sorted([p[1] for p in sample_pixels])
            all_b = sorted([p[2] for p in sample_pixels])
            mid = len(all_r) // 2
            bg_color = (all_r[mid], all_g[mid], all_b[mid])
        
        # Fill remaining space with background color
        fill_height = target_height - content_bottom
        if fill_height > 0:
            fill_img = Image.new('RGB', (target_width, fill_height), bg_color)
            new_img.paste(fill_img, (0, content_bottom))
            
            new_img.save(image_path)
            print(f"     ✂️  Removed {fill_height}px white space, extended to {target_width} × {target_height}px")
            return True
    
    # Already correct
    return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: fix_white_space.py <image_path> [target_width] [target_height]")
        sys.exit(1)
    
    image_path = sys.argv[1]
    if not os.path.exists(image_path):
        print(f"Error: File not found: {image_path}")
        sys.exit(1)
    
    # Get target dimensions from command line if provided
    target_w = int(sys.argv[2]) if len(sys.argv) > 2 else None
    target_h = int(sys.argv[3]) if len(sys.argv) > 3 else None
    
    remove_white_space(image_path, target_w, target_h)
