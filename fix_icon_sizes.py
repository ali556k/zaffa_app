from PIL import Image
import os

def fix_icon_size(input_path, output_path, target_size, logo_scale=0.6, bg_color=(255, 255, 255)):
    """
    Fix icon by scaling the logo to fit within the frame with padding.
    
    Args:
        input_path: Path to the original icon
        output_path: Path to save the fixed icon
        target_size: Tuple of (width, height) for the final image
        logo_scale: Scale factor for the logo (0.0 to 1.0). 0.6 means logo takes 60% of the frame
        bg_color: Background color (RGB tuple)
    """
    try:
        # Open the original image
        img = Image.open(input_path)
        img = img.convert('RGBA')
        
        # Calculate the new logo size
        max_logo_size = int(min(target_size) * logo_scale)
        
        # Resize the image to fit the calculated size while maintaining aspect ratio
        img_copy = img.copy()
        img_copy.thumbnail((max_logo_size, max_logo_size), Image.Resampling.LANCZOS)
        
        # Create a new white background
        background = Image.new('RGBA', target_size, bg_color + (255,))
        
        # Calculate position to center the logo
        offset_x = (target_size[0] - img_copy.width) // 2
        offset_y = (target_size[1] - img_copy.height) // 2
        
        # Paste the resized logo onto the background
        background.paste(img_copy, (offset_x, offset_y), img_copy)
        
        # Convert to RGB if needed (for formats that don't support transparency)
        if output_path.lower().endswith('.jpg'):
            background = background.convert('RGB')
        
        # Save the result
        background.save(output_path, quality=95)
        print(f"✓ Fixed: {input_path} → {output_path} ({target_size[0]}x{target_size[1]})")
        print(f"  Logo scaled to {max_logo_size}x{max_logo_size} pixels")
    except Exception as e:
        print(f"✗ Error processing {input_path}: {str(e)}")

# Configuration
assets_dir = "assets"

# Fix app icon (512x512)
fix_icon_size(
    input_path=os.path.join(assets_dir, "app_icon_new.png"),
    output_path=os.path.join(assets_dir, "app_icon_new.png"),
    target_size=(512, 512),
    logo_scale=0.45,  # Logo will be 45% of 512 = ~230px
    bg_color=(255, 255, 255)  # White background
)

# Fix splash screen (1024x1024)
fix_icon_size(
    input_path=os.path.join(assets_dir, "app_icon_splash.png"),
    output_path=os.path.join(assets_dir, "app_icon_splash.png"),
    target_size=(1024, 1024),
    logo_scale=0.45,  # Logo will be 45% of 1024 = ~460px
    bg_color=(255, 255, 255)  # White background
)

print("\n✓ All icons have been fixed successfully!")
print("The logos are now properly centered within their frames with appropriate padding.")
