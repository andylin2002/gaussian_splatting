#!/usr/bin/env python3
"""
resize_images.py

這個腳本會將指定資料夾內的所有圖片檔案，依照比例調整為寬度為 1000 像素
使用範例：
    python resize_images.py input_folder output_folder
"""
import os
import sys
from PIL import Image

def resize_images(input_dir, output_dir, target_width=1000):
    # 檢查輸出資料夾是否存在，若不存在則建立
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # 支援的圖檔副檔名
    image_extensions = ('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff')
    # 走訪輸入資料夾
    for filename in os.listdir(input_dir):
        if filename.lower().endswith(image_extensions):
            input_path = os.path.join(input_dir, filename)
            # 開啟圖片
            try:
                with Image.open(input_path) as img:
                    # 計算新的高度，使比例固定
                    width_percent = target_width / float(img.size[0])
                    new_height = int((float(img.size[1]) * float(width_percent)))
                    # 調整尺寸
                    resized_img = img.resize((target_width, new_height), Image.LANCZOS)
                    # 儲存到輸出資料夾，保留原始檔名
                    output_path = os.path.join(output_dir, filename)
                    resized_img.save(output_path)
                    print(f"Resized '{filename}' -> {target_width}x{new_height}")
            except Exception as e:
                print(f"無法處理 {filename}: {e}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("用法: python resize_images.py <input_folder> <output_folder>")
        sys.exit(1)

    input_folder = sys.argv[1]
    output_folder = sys.argv[2]
    resize_images(input_folder, output_folder)
