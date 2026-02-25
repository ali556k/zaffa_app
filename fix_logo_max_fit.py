from PIL import Image
import os

def fit_logo_max_inside(input_path, output_path):
    """
    Scale the logo to fill the image as much as possible without cropping, keeping the logo fully visible and centered.
    Args:
        input_path: Path to the original icon
        output_path: Path to save the fixed icon
    """
    try:
        img = Image.open(input_path)
        original_size = img.size
        img = img.convert('RGBA')

        # Create a white background with the same size
        background = Image.new('RGBA', original_size, (255, 255, 255, 255))

        # Find the bounding box of the non-white (logo) area
        bbox = img.getbbox()
        if bbox is None:
            print(f"No logo detected in {input_path}")
            return
        logo = img.crop(bbox)

        # Resize logo to fit inside the original image (contain)
        logo.thumbnail(original_size, Image.Resampling.LANCZOS)

        # Center the logo
        offset_x = (original_size[0] - logo.width) // 2
        offset_y = (original_size[1] - logo.height) // 2
        background.paste(logo, (offset_x, offset_y), logo)

        # Save
        background.save(output_path, quality=95)
        print(f"✓ Fixed: {input_path} → {output_path}")
    except Exception as e:
        print(f"✗ Error processing {input_path}: {str(e)}")

assets_dir = "assets"
fit_logo_max_inside(os.path.join(assets_dir, "app_icon_new.png"), os.path.join(assets_dir, "app_icon_new.png"))
fit_logo_max_inside(os.path.join(assets_dir, "app_icon_splash.png"), os.path.join(assets_dir, "app_icon_splash.png"))
print("✓ Done! Logo now fills the image as much as possible without cropping.")
