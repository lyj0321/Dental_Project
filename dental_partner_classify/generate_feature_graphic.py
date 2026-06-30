from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1024, 500
img = Image.new("RGBA", (W, H))
draw = ImageDraw.Draw(img)

# 배경: 위아래 그라데이션 (진한 파랑 → 중간 파랑)
for y in range(H):
    ratio = y / H
    r = int(15 * (1 - ratio) + 37 * ratio)
    g = int(23 * (1 - ratio) + 99 * ratio)
    b = int(99 * (1 - ratio) + 200 * ratio)
    draw.line([(0, y), (W - 1, y)], fill=(r, g, b, 255))

# 폰트
font_title = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 90)
font_sub = ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 36)

# 앱 아이콘 (app_icon_512.png) 왼쪽에 배치
icon_path = "app_icon_512.png"
if os.path.exists(icon_path):
    icon = Image.open(icon_path).convert("RGBA")
    icon = icon.resize((200, 200), Image.LANCZOS)
    img.paste(icon, (80, 150), icon)

# 텍스트: 오른쪽 영역
tx = 330

# 메인 타이틀
draw.text((tx, 130), "DentalFind", font=font_title, fill=(255, 255, 255, 255))

# 서브타이틀
draw.text((tx, 240), "Partner", font=font_title, fill=(100, 200, 255, 255))

# 설명
draw.text((tx, 360), "치과 파트너 전용 예약·병원 관리 앱", font=font_sub, fill=(200, 220, 255, 200))

img.save("feature_graphic.png")
print("Done: feature_graphic.png")
