#!/bin/bash

gpu_idx=0

# --- 腳本參數檢查 ---
if [ -z "$1" ]; then
    echo "使用方式: $0 <圖片資料夾名稱>"
    echo "範例: $0 test"
    echo "注意: 腳本預期在同一目錄下找到指定的圖片資料夾。"
    exit 1
fi

# 獲取使用者傳入的圖片資料夾名稱 (例如: test)
original_input_folder_name="$1"

# 獲取腳本本身的絕對路徑 (即 gaussian_splatting 資料夾的路徑)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 構建輸入資料夾的絕對路徑 (腳本所在目錄 + 傳入的資料夾名稱)
input_folder="${SCRIPT_DIR}/${original_input_folder_name}"

# **關鍵修改：將所有路徑轉換為絕對路徑**
# 確保 realpath 命令存在，如果不存在則通常需要安裝 coreutils 或 findutils
if ! command -v realpath &> /dev/null
then
    echo "錯誤: 'realpath' 命令未找到。請安裝 coreutils 或 findutils 套件 (例如: sudo apt install coreutils)。"
    exit 1
fi

input_folder=$(realpath "$input_folder")

# 檢查輸入資料夾是否存在
if [ ! -d "$input_folder" ]; then
    echo "錯誤: 輸入資料夾 '$input_folder' 不存在。請確認 '$original_input_folder_name' 資料夾與腳本位於同一目錄下。"
    exit 1
fi

# 從絕對路徑中獲取資料夾名稱 (例如: /path/to/test 會得到 test)
folder_name=$(basename "$input_folder")

# --- 定義所有資料夾路徑 ---
# 中間處理資料夾的名稱 (例如: temp)
temp_colmap_folder="temp"
temp_output_path="${SCRIPT_DIR}/${temp_colmap_folder}" # temp 資料夾直接在 SCRIPT_DIR 下

# 去畸變輸出資料夾的名稱 (直接在 SCRIPT_DIR 下)
undistorted_folder_name="undistorted"
undistorted_output_path="${SCRIPT_DIR}/${undistorted_folder_name}"

# 最終輸出資料夾的名稱 (去畸變後重新命名為 test_colmap)
final_output_colmap_name="${folder_name}_colmap"
final_output_colmap_path="${SCRIPT_DIR}/${final_output_colmap_name}"

---

### **步驟 1: 建立中間處理資料夾 `temp`**

echo "--- 步驟 1: 建立中間處理資料夾 ($temp_colmap_folder) ---"
mkdir -p "$temp_output_path"

if [ $? -eq 0 ]; then
    echo "✅ 成功建立資料夾: $temp_output_path"
else
    echo "❌ 錯誤: 無法建立資料夾 '$temp_output_path'。請檢查權限或路徑。"
    exit 1
fi

---

### **步驟 2: 複製所有內容到中間處理資料夾內的 `images`**

echo "--- 步驟 2: 複製所有內容到中間處理資料夾內的 images ---"

# 定義目標 images 資料夾的絕對路徑
target_images_path="${temp_output_path}/images"

# 建立 images 資料夾
mkdir -p "$target_images_path"

if [ $? -eq 0 ]; then
    echo "✅ 成功建立 images 資料夾: $target_images_path"
else
    echo "❌ 錯誤: 無法建立 images 資料夾 '$target_images_path'。請檢查權限。"
    exit 1
fi

# 複製原始資料夾內的所有內容
echo "正在從 '$input_folder' 複製所有內容到 '$target_images_path'..."
cp -r "$input_folder"/* "$target_images_path"/

# 檢查複製操作是否成功
if [ $? -eq 0 ]; then
    echo "✅ 所有內容已成功複製到 '$target_images_path'。"
else
    echo "❌ 警告: 複製內容時可能發生錯誤。請檢查原始資料夾和目標資料夾的內容。"
fi

---

### **步驟 3: 在中間處理資料夾內建立 `database` 和 `sparse` 空資料夾**

echo "--- 步驟 3: 建立 database 和 sparse 資料夾 ---"

# 建立 database 資料夾
mkdir -p "${temp_output_path}/database"
if [ $? -eq 0 ]; then
    echo "✅ 成功建立資料夾: ${temp_output_path}/database"
else
    echo "❌ 錯誤: 無法建立資料夾 '${temp_output_path}/database'。"
fi

# 建立 sparse 資料夾
mkdir -p "${temp_output_path}/sparse"
if [ $? -eq 0 ]; then
    echo "✅ 成功建立資料夾: ${temp_output_path}/sparse"
else
    echo "❌ 錯誤: 無法建立資料夾 '${temp_output_path}/sparse'。"
fi

---

### **步驟 4: 執行 Docker COLMAP `help` 檢查 (可選預檢)**

echo "--- 步驟 4: 執行 Docker COLMAP 'help' 檢查 ---"
echo "這將測試 Docker 容器和 COLMAP 命令是否正常運行。"

sudo docker run --rm my-colmap-image colmap --help > /dev/null 2>&1


if [ $? -eq 0 ]; then
    echo "✅ COLMAP 幫助訊息已成功顯示，表示 Docker 容器和 COLMAP 命令正常。"
else
    echo "❌ 錯誤: 無法執行 COLMAP 幫助命令。請檢查 Docker 影像名稱 ('my-colmap-image') 或 Docker 環境設定。"
    exit 1 # 如果幫助命令失敗，則終止腳本
fi

---

### **步驟 5: 執行 COLMAP `feature_extractor`**

echo "--- 步驟 5: 執行 COLMAP 特徵提取 (feature_extractor) ---"

# Docker 掛載使用中間處理資料夾的路徑
sudo docker run -it --rm --gpus all \
    --user $(id -u):$(id -g) \
    -v "$temp_output_path":/data \
    my-colmap-image \
    colmap feature_extractor \
        --image_path /data/images \
        --database_path /data/database/database.db \
        --SiftExtraction.use_gpu 1 \
        --SiftExtraction.gpu_index $gpu_idx

if [ $? -eq 0 ]; then
    echo "✅ COLMAP 特徵提取 (feature_extractor) 已成功執行。database.db 內應有圖片對之間的對應 feature。"
else
    echo "❌ 錯誤: COLMAP 特徵提取執行失敗。請檢查 Docker 影像 ('my-colmap-image')、環境設定或錯誤訊息。"
    echo "請查看上方 Docker 容器輸出的詳細錯誤訊息。"
    exit 1 # 如果此步驟失敗，則終止腳本
fi

---

### **步驟 6: 執行 COLMAP `exhaustive_matcher`**

echo "--- 步驟 6: 執行 COLMAP 窮舉匹配 (exhaustive_matcher) ---"

# Docker 掛載使用中間處理資料夾的路徑
sudo docker run -it --rm --gpus all \
    --user $(id -u):$(id -g) \
    -v "$temp_output_path":/data \
    my-colmap-image \
    colmap exhaustive_matcher \
        --database_path /data/database/database.db \
        --SiftMatching.use_gpu 1 \
        --SiftMatching.gpu_index $gpu_idx

if [ $? -eq 0 ]; then
    echo "✅ COLMAP 窮舉匹配 (exhaustive_matcher) 已成功執行。database.db 內應有圖片對之間的對應 feature。"
else
    echo "❌ 錯誤: COLMAP 窮舉匹配執行失敗。請檢查 Docker 影像、環境設定或錯誤訊息。"
    exit 1 # 如果此步驟失敗，則終止腳本
fi

---

### **步驟 7: 執行 COLMAP `mapper` (稀疏重建)**

echo "--- 步驟 7: 執行 COLMAP 稀疏重建 (mapper) ---"

# Docker 掛載使用中間處理資料夾的路徑
sudo docker run -it --rm --gpus all \
--user $(id -u):$(id -g) \
-v "$temp_output_path":/data \
my-colmap-image \
colmap mapper \
--image_path /data/images \
--database_path /data/database/database.db \
--output_path /data/sparse

if [ $? -eq 0 ]; then
    echo "✅ COLMAP 稀疏重建 (mapper) 已成功執行。"
    echo "在 '$temp_output_path/sparse/' 中應該會出現一個名為 '0' 的資料夾，裡面包含 cameras.bin, images.bin, points3D.bin。"
else
    echo "❌ 錯誤: COLMAP 稀疏重建執行失敗。請檢查 Docker 影像、環境設定或錯誤訊息。"
    exit 1 # 如果此步驟失敗，則終止腳本
fi

---

### **步驟 8: 執行 COLMAP `image_undistorter` 並調整資料夾結構**

echo "--- 步驟 8: 執行 COLMAP 圖像去畸變 (image_undistorter) ---"

# 建立 undistorted 資料夾 (直接在 SCRIPT_DIR 下)
mkdir -p "$undistorted_output_path"
if [ $? -ne 0 ]; then
    echo "❌ 錯誤: 無法建立資料夾 '$undistorted_output_path'。"
    exit 1
fi

# 注意：這裡 `-v` 掛載了兩個不同的路徑
# 1. $temp_output_path:/data/input_colmap (輸入數據源，來自 temp 資料夾)
# 2. $undistorted_output_path:/data/output_undistorted (去畸變後的輸出目標)
sudo docker run -it --rm --gpus all \
--user $(id -u):$(id -g) \
-v "$temp_output_path":/data/input_colmap \
-v "$undistorted_output_path":/data/output_undistorted \
my-colmap-image \
colmap image_undistorter \
--image_path /data/input_colmap/images \
--input_path /data/input_colmap/sparse/0 \
--output_path /data/output_undistorted \
--output_type COLMAP

if [ $? -eq 0 ]; then
    echo "✅ COLMAP 圖像去畸變 (image_undistorter) 已成功執行。"
else
    echo "❌ 錯誤: COLMAP 圖像去畸變執行失敗。請檢查 Docker 影像、環境設定或錯誤訊息。"
    exit 1 # 如果此步驟失敗，則終止腳本
fi

echo "--- 調整 undistorted 資料夾內部 sparse 結構 ---"

### **步驟 9: 最後調整 **

# --- 更改 undistorted 資料夾的所有權和權限 ---
echo "--- 更改 '$undistorted_output_path' 資料夾的所有權和權限 ---"
# 請確認您有 sudo 權限。這裡可能會提示您輸入密碼。
sudo chown -R "$USER":"$USER" "$undistorted_output_path"
sudo chmod -R u+rwx,g+rwx,o+rwx "$undistorted_output_path"
if [ $? -eq 0 ]; then
    echo "✅ '$undistorted_output_path' 資料夾的所有權和權限已成功更改。"
else
    echo "❌ 錯誤: 無法更改 '$undistorted_output_path' 資料夾的所有權和權限。請檢查 sudo 權限並手動嘗試：\n  sudo chown -R $USER:$USER $undistorted_output_path\n  sudo chmod -R u+rwx,g+rwx,o+rwx $undistorted_output_path"
    exit 1
fi

# --- 調整 undistorted 資料夾內部 sparse 結構 ---
sparse_root="${undistorted_output_path}/sparse"

if [ -d "$sparse_root" ]; then
    # 如果內部本來就有 0 目錄就不用再動
    if [ -d "$sparse_root/0" ]; then
        echo "✅ sparse/0 已存在，跳過搬移。"
    else
        mkdir -p "$sparse_root/0"
        # 只搬非目錄檔案；避免把資料夾搬進自己
        shopt -s nullglob
        for f in "$sparse_root"/*; do
            [ -d "$f" ] && continue   # 跳過子目錄
            mv "$f" "$sparse_root/0/"
        done
        shopt -u nullglob
        echo "✅ 已將 *.bin *.txt 等檔案搬到 sparse/0。"
    fi
else
    echo "⚠️ 找不到 sparse 目錄，跳過。"
fi

# --- 清理中間資料夾並重命名最終輸出資料夾 ---
echo "--- 清理中間資料夾並重命名最終輸出資料夾 ---"

# 檢查 undistorted 資料夾是否存在，確保去畸變步驟成功生成了結果
if [ -d "$undistorted_output_path" ]; then
    echo "正在刪除中間處理資料夾: '$temp_output_path'..."
    # 刪除中間的 temp 資料夾 (其中現在只剩下 images, database 和原始 sparse)
    rm -rf "$temp_output_path"
    if [ $? -eq 0 ]; then
        echo "✅ 中間處理資料夾 '$temp_output_path' 已成功刪除。"
    else
        echo "❌ 錯誤: 無法刪除中間處理資料夾 '$temp_output_path'。請檢查權限。"
        exit 1
    fi

    echo "正在將去畸變後的資料夾重新命名為: '$final_output_colmap_name'..."
    # 將 undistorted 資料夾改名為最終的 test_colmap 名稱
    mv "$undistorted_output_path" "$final_output_colmap_path"
    if [ $? -eq 0 ]; then
        echo "✅ 資料夾已成功重新命名為 '$final_output_colmap_name'。"
    else
        echo "❌ 錯誤: 無法將 '$undistorted_output_path' 重新命名為 '$final_output_colmap_name'。請檢查權限。"
        exit 1
    fi
else
    echo "❌ 錯誤: 去畸變後的資料夾 '$undistorted_output_path' 不存在，無法進行清理和重命名。請檢查日誌或手動檢查檔案系統。"
    exit 1
fi

echo "--- 所有後續處理步驟完成 ---"
echo "最終結果位於資料夾結構中："
echo "${final_output_colmap_path}/"
echo "├── images/         (去畸變後的圖片)"
echo "└── sparse/         (複製並調整結構後的稀疏模型，現在是 0/cameras.bin 等)"
echo ""
echo "原始圖片資料夾 '$input_folder' 保持不變。"
