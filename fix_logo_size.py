from PIL import Image
import os

def fix_logo_within_image(input_path, output_path, logo_scale=0.5):
    """
    Reduce logo size within the image while keeping image size unchanged.
    
    Args:
        input_path: Path to the original icon
        output_path: Path to save the fixed icon
        logo_scale: Scale factor for the logo (0.0 to 1.0). Default 0.5 means logo is 50% of image size
    """
    try:
        # Open the original image
        img = Image.open(input_path)
        original_size = img.size
        print(f"Original image size: {original_size[0]}x{original_size[1]}")
        
        img = img.convert('RGBA')
        
        # Create white background with original size
        background = Image.new('RGBA', original_size, (255, 255, 255, 255))
        
        # Calculate the new logo size based on scale
        max_logo_size = int(min(original_size) * logo_scale)
        print(f"Scaling logo to: {max_logo_size}x{max_logo_size}")
        
        # Resize the image while maintaining aspect ratio
        img_copy = img.copy()
        img_copy.thumbnail((max_logo_size, max_logo_size), Image.Resampling.LANCZOS)
        
        # Calculate position to center the logo
        offset_x = (original_size[0] - img_copy.width) // 2
        offset_y = (original_size[1] - img_copy.height) // 2
        
        # Paste the resized logo onto the background
        background.paste(img_copy, (offset_x, offset_y), img_copy)
        
        # Convert to RGB if needed
        if output_path.lower().endswith('.jpg'):
            background = background.convert('RGB')
        
        # Save with original size
        background.save(output_path, quality=95)
        print(f"✓ Fixed: {input_path}")
        print(f"  Image kept at original size: {original_size[0]}x{original_size[1]}")
        print(f"  Logo scaled to {max_logo_size}x{max_logo_size} and centered\n")
    except Exception as e:
        print(f"✗ Error processing {input_path}: {str(e)}")

# Configuration
assets_dir = "assets"

# Fix app icon - keep original size, reduce logo to 50% of image
fix_logo_within_image(
    input_path=os.path.join(assets_dir, "app_icon_new.png"),
    output_path=os.path.join(assets_dir, "app_icon_new.png"),
    logo_scale=0.5  # Logo will be 50% of image size
)

# Fix splash screen - keep original size, reduce logo to 50% of image
fix_logo_within_image(
    input_path=os.path.join(assets_dir, "app_icon_splash.png"),
    output_path=os.path.join(assets_dir, "app_icon_splash.png"),
    logo_scale=0.5  # Logo will be 50% of image size
)

print("✓ Done! Logos are now properly sized within their image frames.")
print("If logos are still too large, run the script again or adjust the logo_scale parameter.")
