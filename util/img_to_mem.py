import sys
from pathlib import Path
from PIL import Image, ImageOps
import os

BRIGHTNESS = 0.25          # 30% max brightness (tweak this)

def scale_channel(c):
    # c is 0–255
    # first map 0–255 → 0–63, then apply brightness
    return int((c / 4.0)*BRIGHTNESS)

def fix_image(image_in):
    #want to take in image, and compress it to 32x32 if it is not
    w, h = image_in.size
    if(w!=32 or h!=32):
        image = ImageOps.fit(
            image_in,
            (32, 32),
            method=Image.Resampling.LANCZOS,  # high-quality downsampling
            centering=(0.5, 0.5)              # crop equally from all sides if needed
        )
    else:
        image = image_in
    
    pixels = list(image.getdata())   #list of (r,g,b) tuples
    
    #clip pixel intensity for led board
    for index, pixel in enumerate(pixels):
        (r, g, b) = pixel
        new_r, new_g, new_b = r, g, b
        new_r = scale_channel(r)
        new_g = scale_channel(g)
        new_b = scale_channel(b)
        pixels[index] = (new_r, new_g, new_b)
    
    # Mirror every other row
    mirrored_pixels = []
    for row in range(32):
        row_start = row * 32
        row_end = row_start + 32
        row_pixels = pixels[row_start:row_end]
        
        if row % 2 == 1: 
            row_pixels = row_pixels[::-1]
        
        mirrored_pixels.extend(row_pixels)
    
    return mirrored_pixels[::-1]

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: {0} <image to convert>".format(sys.argv[0]))
    else:
        extensions = ['*.jpg', '*.png', '*.jpeg']
        folder = Path(sys.argv[1])
        
        if not folder.is_dir():
            print(f"Error: {folder} is not a directory")
            sys.exit(1)
        
        image_paths = []
        for ext in extensions:
            image_paths.extend(folder.glob(ext))

        image_paths = sorted(image_paths)
        
        all_image_pixels = []
        num_images = len(image_paths)
        
        for img_path in image_paths:
            image_in = Image.open(img_path)
            image_in = image_in.convert('RGB')
            #gets you image scaled to 32x32 and dimmed
            pixels = fix_image(image_in)
            all_image_pixels.extend(pixels)
        
        img = Image.new("RGB", (32, num_images*32))
        img.putdata(all_image_pixels)
        image_in = img
        
        num_colors_out = 256
        w, h = image_in.size
        
        image_out = image_in.copy()
        
        # Palettize the image
        image_out = image_out.convert(mode='P', palette=1, colors=num_colors_out)
        image_out.save('preview.png')
        print('Output image preview saved at preview.png')
        
        palette = image_out.getpalette() or []
        it = iter(palette)
        rgb_tuples = list(zip(it, it, it))[:256]  # cap at 256 colors
        
        # Save pallete
        with open(f'palette.mem', 'w') as f:
            f.write( '\n'.join( [f'{r:02x}{g:02x}{b:02x}' for r, g, b in rgb_tuples] ) )
        print('Output image pallete saved at palette.mem')
        
        # Save the image itself
        with open(f'image.mem', 'w') as f:
            for y in range(h):
                for x in range(w):
                    f.write(f'{image_out.getpixel((x,y)):02x}\n')
        print('Output image saved at image.mem')