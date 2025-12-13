#!/bin/bash
# Capture App Store screenshots for both iPhone and iPad
# iPhone: 1242 × 2688px
# iPad: 2064 × 2752px

IPHONE_WIDTH=1242
IPHONE_HEIGHT=2688
IPAD_WIDTH=2064
IPAD_HEIGHT=2752
ORIGINAL_WIDTH=1290
ORIGINAL_HEIGHT=2796
PORT=8000
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HTML_DIR="$BASE_DIR/website/app-store-materials"
IPHONE_OUTPUT_DIR="$BASE_DIR/media/screenshots/iphone"
IPAD_OUTPUT_DIR="$BASE_DIR/media/screenshots/ipad"
TEMP_DIR="$BASE_DIR/website/temp-screenshots"

# Find Chrome
if [ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif command -v google-chrome &> /dev/null; then
    CHROME="google-chrome"
elif command -v chromium &> /dev/null; then
    CHROME="chromium"
else
    echo "❌ Chrome/Chromium not found. Please install Google Chrome."
    exit 1
fi

# Create directories
mkdir -p "$IPHONE_OUTPUT_DIR"
mkdir -p "$IPAD_OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# Function to scale a pixel value
scale_value() {
    local value=$1
    local scale=$2
    echo "scale=0; ($value * $scale) / 1" | bc
}

# Function to extract background gradient from original HTML
get_background_gradient() {
    local file=$1
    grep -o "background: linear-gradient[^;]*" "$file" | head -1 | sed 's/background: //'
}

# Function to create responsive HTML file that fills exactly
create_responsive_html() {
    local original_file=$1
    local responsive_file=$2
    local target_width=$3
    local target_height=$4
    
    # Calculate scale factors
    local scale_x=$(echo "scale=6; $target_width / $ORIGINAL_WIDTH" | bc)
    local scale_y=$(echo "scale=6; $target_height / $ORIGINAL_HEIGHT" | bc)
    
    # Get the background gradient from the original
    BG_GRADIENT=$(get_background_gradient "$original_file")
    if [ -z "$BG_GRADIENT" ]; then
        # Default gradient if not found
        BG_GRADIENT="linear-gradient(165deg, #667eea 0%, #764ba2 50%, #1a1a3e 100%)"
    fi
    
    # Calculate scaled values
    PADDING_TOP=$(scale_value 160 $scale_y)
    PADDING_SIDES=$(scale_value 100 $scale_x)
    
    # Read original file and replace dimensions
    cat "$original_file" | \
    sed "s/width: ${ORIGINAL_WIDTH}px/width: ${target_width}px/g; \
         s/height: ${ORIGINAL_HEIGHT}px/height: ${target_height}px/g; \
         s/width=${ORIGINAL_WIDTH}/width=${target_width}/g; \
         s/height=${ORIGINAL_HEIGHT}/height=${target_height}/g; \
         s/${ORIGINAL_WIDTH}px/${target_width}px/g; \
         s/${ORIGINAL_HEIGHT}px/${target_height}px/g" > "$responsive_file"
    
    # Update viewport meta tag
    sed -i '' "s/width=${ORIGINAL_WIDTH}, height=${ORIGINAL_HEIGHT}/width=${target_width}, height=${target_height}/g" "$responsive_file" 2>/dev/null || \
    sed -i "s/width=${ORIGINAL_WIDTH}, height=${ORIGINAL_HEIGHT}/width=${target_width}, height=${target_height}/g" "$responsive_file"
    
    # Insert comprehensive CSS overrides before closing </style> tag
    if grep -q "</style>" "$responsive_file"; then
        awk -v width="$target_width" -v height="$target_height" -v pad_top="$PADDING_TOP" -v pad_sides="$PADDING_SIDES" -v bg="$BG_GRADIENT" '
            /<\/style>/ {
                print "/* Force fill entire frame - absolutely no white space */"
                print "* {"
                print "    margin: 0 !important;"
                print "    padding: 0 !important;"
                print "    box-sizing: border-box !important;"
                print "}"
                print ""
                print "html {"
                print "    width: " width "px !important;"
                print "    height: " height "px !important;"
                print "    margin: 0 !important;"
                print "    padding: 0 !important;"
                print "    overflow: hidden !important;"
                print "    background: " bg " !important;"
                print "    display: block !important;"
                print "}"
                print ""
                print "body {"
                print "    width: " width "px !important;"
                print "    height: " height "px !important;"
                print "    margin: 0 !important;"
                print "    padding: 0 !important;"
                print "    overflow: hidden !important;"
                print "    background: " bg " !important;"
                print "    display: block !important;"
                print "    position: relative !important;"
                print "}"
                print ""
                print ".promo-slide {"
                print "    width: " width "px !important;"
                print "    height: " height "px !important;"
                print "    min-height: " height "px !important;"
                print "    max-height: " height "px !important;"
                print "    margin: 0 !important;"
                print "    padding: " pad_top "px " pad_sides "px !important;"
                print "    box-sizing: border-box !important;"
                print "    position: relative !important;"
                print "    background: " bg " !important;"
                print "    display: flex !important;"
                print "}"
            }
            { print }
        ' "$responsive_file" > "${responsive_file}.tmp" && mv "${responsive_file}.tmp" "$responsive_file"
    else
        # Append if no </style> tag found
        cat >> "$responsive_file" <<EOF

<style>
/* Force fill entire frame - absolutely no white space */
* {
    margin: 0 !important;
    padding: 0 !important;
    box-sizing: border-box !important;
}

html {
    width: ${target_width}px !important;
    height: ${target_height}px !important;
    margin: 0 !important;
    padding: 0 !important;
    overflow: hidden !important;
    background: ${BG_GRADIENT} !important;
    display: block !important;
}

body {
    width: ${target_width}px !important;
    height: ${target_height}px !important;
    margin: 0 !important;
    padding: 0 !important;
    overflow: hidden !important;
    background: ${BG_GRADIENT} !important;
    display: block !important;
    position: relative !important;
}

.promo-slide {
    width: ${target_width}px !important;
    height: ${target_height}px !important;
    min-height: ${target_height}px !important;
    max-height: ${target_height}px !important;
    margin: 0 !important;
    padding: ${PADDING_TOP}px ${PADDING_SIDES}px !important;
    box-sizing: border-box !important;
    position: relative !important;
    background: ${BG_GRADIENT} !important;
    display: flex !important;
}
</style>
EOF
    fi
}

# Function to capture screenshots for a specific device
capture_screenshots() {
    local device_name=$1
    local target_width=$2
    local target_height=$3
    local output_dir=$4
    
    echo ""
    echo "📱 Capturing ${device_name} Screenshots"
    echo "=================================="
    echo "📐 Target size: ${target_width} × ${target_height}px"
    
    # Calculate scale factors for display
    local scale_x=$(echo "scale=6; $target_width / $ORIGINAL_WIDTH" | bc)
    local scale_y=$(echo "scale=6; $target_height / $ORIGINAL_HEIGHT" | bc)
    echo "📐 Scale factors: X=${scale_x}, Y=${scale_y}"
    echo ""
    
    # Capture each screenshot
    for i in {1..6}; do
        HTML_FILE="screenshot-${i}.html"
        RESPONSIVE_FILE="$TEMP_DIR/${device_name}-${HTML_FILE}"
        OUTPUT_FILE="$output_dir/screenshot-${i}.png"
        URL="http://localhost:$PORT/temp-screenshots/${device_name}-${HTML_FILE}"
        
        echo "  → Capturing $HTML_FILE..."
        
        # Create responsive version
        create_responsive_html "$HTML_DIR/$HTML_FILE" "$RESPONSIVE_FILE" "$target_width" "$target_height"
        
        # Wait a moment for file system
        sleep 0.5
        
        # Capture screenshot with exact dimensions
        "$CHROME" --headless \
            --disable-gpu \
            --window-size=${target_width},${target_height} \
            --hide-scrollbars \
            --disable-dev-shm-usage \
            --no-sandbox \
            --virtual-time-budget=3000 \
            --screenshot="$OUTPUT_FILE" \
            "$URL" 2>/dev/null
        
        if [ -f "$OUTPUT_FILE" ]; then
            # Verify dimensions
            ACTUAL_WIDTH=$(sips -g pixelWidth "$OUTPUT_FILE" 2>/dev/null | tail -1 | awk '{print $2}')
            ACTUAL_HEIGHT=$(sips -g pixelHeight "$OUTPUT_FILE" 2>/dev/null | tail -1 | awk '{print $2}')
            
            # If dimensions don't match exactly, resize
            if [ "$ACTUAL_WIDTH" != "$target_width" ] || [ "$ACTUAL_HEIGHT" != "$target_height" ]; then
                sips -z $target_height $target_width "$OUTPUT_FILE" > /dev/null 2>&1
                echo "     ⚠️  Resized to ${target_width} × ${target_height}px"
            fi
            
            # Post-process to remove any white space using Python script
            if command -v python3 &> /dev/null && [ -f "$BASE_DIR/utils/fix_white_space.py" ]; then
                python3 "$BASE_DIR/utils/fix_white_space.py" "$OUTPUT_FILE" "$target_width" "$target_height" > /dev/null 2>&1
            fi
            
            echo "     ✅ Saved to $OUTPUT_FILE (${target_width} × ${target_height}px)"
        else
            echo "     ❌ Failed to capture $HTML_FILE"
        fi
    done
}

# Start local server in background
cd "$BASE_DIR/website"
python3 -m http.server $PORT > /dev/null 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 2

echo "📱 App Store Screenshot Generator"
echo "=================================="

# Capture iPhone screenshots
capture_screenshots "iphone" "$IPHONE_WIDTH" "$IPHONE_HEIGHT" "$IPHONE_OUTPUT_DIR"

# Capture iPad screenshots
capture_screenshots "ipad" "$IPAD_WIDTH" "$IPAD_HEIGHT" "$IPAD_OUTPUT_DIR"

# Cleanup
rm -rf "$TEMP_DIR"

# Stop server
kill $SERVER_PID 2>/dev/null

echo ""
echo "✅ All screenshots captured!"
echo "   📱 iPhone: $IPHONE_OUTPUT_DIR"
echo "   📱 iPad: $IPAD_OUTPUT_DIR"
echo ""
echo "💡 To regenerate screenshots, run: ./utils/capture_screenshots.sh"
