import sys
from PIL import Image, ImageDraw

def render_logo(input_txt, output_png, color_hex, cell_w=8, cell_h=16, target_w=None, target_h=None):
    with open(input_txt, "r", encoding="utf-8") as f:
        lines = [line.rstrip("\n") for line in f.readlines()]
    
    # Filter empty lines at start and end
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
        
    if not lines:
        print("Empty input file")
        sys.exit(1)
        
    max_cols = max(len(line) for line in lines)
    rows = len(lines)
    
    img_w = max_cols * cell_w
    img_h = rows * cell_h
    
    # Create transparent image
    img = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Parse color
    color_hex = color_hex.lstrip("#")
    r = int(color_hex[0:2], 16)
    g = int(color_hex[2:4], 16)
    b = int(color_hex[4:6], 16)
    fill_color = (r, g, b, 255)
    
    for row, line in enumerate(lines):
        for col, char in enumerate(line):
            x = col * cell_w
            y = row * cell_h
            
            if char == "█":
                # Full block
                draw.rectangle([x, y, x + cell_w - 1, y + cell_h - 1], fill=fill_color)
            elif char == "▀":
                # Upper half block
                draw.rectangle([x, y, x + cell_w - 1, y + (cell_h // 2) - 1], fill=fill_color)
            elif char == "▄":
                # Lower half block
                draw.rectangle([x, y + (cell_h // 2), x + cell_w - 1, y + cell_h - 1], fill=fill_color)
                
    # Trim transparent borders
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        
    if target_w and target_h:
        # Create a new transparent canvas of target size
        canvas = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
        # Center the cropped image
        x_offset = (target_w - img.width) // 2
        y_offset = (target_h - img.height) // 2
        canvas.paste(img, (x_offset, y_offset))
        img = canvas
        
    img.save(output_png)
    print(f"Saved rendered logo to {output_png} (size: {img.width}x{img.height})")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python3 render_logo.py <input_txt> <output_png> <color_hex> [cell_w] [cell_h] [target_w] [target_h]")
        sys.exit(1)
        
    input_txt = sys.argv[1]
    output_png = sys.argv[2]
    color_hex = sys.argv[3]
    cell_w = int(sys.argv[4]) if len(sys.argv) > 4 else 8
    cell_h = int(sys.argv[5]) if len(sys.argv) > 5 else 16
    target_w = int(sys.argv[6]) if len(sys.argv) > 6 else None
    target_h = int(sys.argv[7]) if len(sys.argv) > 7 else None
    
    render_logo(input_txt, output_png, color_hex, cell_w, cell_h, target_w, target_h)
