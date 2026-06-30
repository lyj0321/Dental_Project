from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 512
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 단색 배경
draw.rounded_rectangle([0, 0, SIZE, SIZE], radius=100, fill=(79, 70, 229))

# 폰트
font = None
for fp in ["C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/calibrib.ttf"]:
    if os.path.exists(fp):
        font = ImageFont.truetype(fp, 230)
        break

# "DF" 중앙 정렬
bbox = draw.textbbox((0, 0), "DF", font=font)
x = (SIZE - (bbox[2] - bbox[0])) // 2 - bbox[0]
y = (SIZE - (bbox[3] - bbox[1])) // 2 - bbox[1]
draw.text((x, y), "DF", font=font, fill=(255, 255, 255))

img.save("app_icon_512.png")
img.resize((1024, 1024), Image.LANCZOS).save("app_icon_1024.png")
print("Done")
