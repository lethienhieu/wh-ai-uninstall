# WH-AI Uninstall

Gỡ sạch **WOHHUP x AI (WH-AI)** khỏi máy: app + add-in Revit (2025/2026/2027) + dữ liệu + registry + shortcut. **Chỉ xóa WH-AI, không đụng add-in/app khác. Không cần đăng nhập, không cần cập nhật app.**

## Cách 1 — chạy 1 dòng (khuyến nghị)

Mở **PowerShell** (nếu máy còn bản cũ ở `C:\Program Files` thì mở **PowerShell as Administrator**), dán và Enter:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/lethienhieu/wh-ai-uninstall/main/Cleanup-WH-AI.ps1')))
```

- Sẽ hỏi `YES` trước khi xóa.
- Xem trước, **không xóa gì**: thêm ` -DryRun` vào cuối dòng.
- Bỏ hỏi xác nhận: thêm ` -Yes` vào cuối dòng.

## Cách 2 — tải file rồi chạy

Tải `Cleanup-WH-AI.ps1` về, mở PowerShell tại thư mục đó:

```powershell
powershell -ExecutionPolicy Bypass -File Cleanup-WH-AI.ps1
```

## ⚠️ Lưu ý

- **ĐÓNG Revit trước khi chạy** — nếu không, file add-in bị khoá và báo `FAILED` (đóng Revit rồi chạy lại).
- Script chỉ nhắm đúng WH-AI (tên cố định + AddInId), **không** đụng `WohhupMainApp`, `THBIM`, `TH Tools`… hay bất kỳ file lạ nào.
