# Hướng Dẫn Tích Hợp Figma Trực Tiếp Vào Flutter Project Qua MCP & Công Cụ Khác

Chào bạn! Hiện tại, bạn đã có một **base Flutter project** (`Gymtelligent`) và một bản vẽ **Figma**. Bạn muốn tìm cách đưa thẳng thiết kế Figma này vào dự án thông qua **MCP (Model Context Protocol)** hoặc các giải pháp tự động hóa.

Dưới đây là hướng dẫn chi tiết giúp bạn sửa lỗi lệnh terminal vừa gặp, đồng thời cung cấp giải pháp tối ưu nhất để kết nối Figma trực tiếp với Flutter project của bạn.

---

## 1. Sửa Lỗi Lệnh `gemini : The term 'gemini' is not recognized`

Lỗi xảy ra do **Gemini CLI** (`@google/gemini-cli`) chưa được cài đặt toàn cục (global) trên máy Windows của bạn hoặc chưa được thêm vào biến môi trường `PATH`.

### Cách 1: Sử dụng `npx` để chạy trực tiếp (Không cần cài đặt global)
Thay vì cài đặt global, bạn có thể sử dụng `npx` để tải và thực thi lệnh tức thì:
```powershell
npx -y @google/gemini-cli extensions install https://github.com/figma/mcp-server-guide
```

### Cách 2: Cài đặt Gemini CLI Toàn Cục
Nếu bạn muốn sử dụng lệnh `gemini` trực tiếp ở mọi thư mục, hãy chạy:
```powershell
npm install -g @google/gemini-cli
```
*Sau khi cài đặt thành công, hãy khởi động lại PowerShell/Terminal để cập nhật biến môi trường, sau đó chạy lại lệnh ban đầu của bạn.*

---

## 2. Các Cách MCP / Tích Hợp Figma Trực Tiếp Vào Flutter

Để AI (như Gemini hoặc các trợ lý mã nguồn khác) có thể đọc bản vẽ Figma và code trực tiếp giao diện Flutter cho bạn, dưới đây là **3 giải pháp chính**:

### Giải pháp A: Sử dụng Figma MCP Server (Khuyên Dùng Cho AI Agents)
Figma đã ra mắt **Figma MCP Server** chính thức. Khi được cấu hình, nó cho phép các AI hỗ trợ lập trình (như Cursor, VS Code Cline/Roo Code, Claude Desktop, v.v.) tự động đọc các frame, component, variables và layout trực tiếp từ file Figma của bạn để sinh mã Flutter cực kỳ chính xác.

#### Các bước cài đặt:
1. **Lấy Token Figma:**
   - Truy cập Figma -> **Settings** -> **Personal access tokens** -> Chọn **Generate new token**.
   - Lưu lại Token này (ví dụ: `figma_pat_xxx`).

2. **Cấu hình Client (Ví dụ cho VS Code / Cursor / Cline):**
   Nếu bạn sử dụng tiện ích mở rộng hỗ trợ MCP trên IDE (như Cline hoặc Roo Code trong VS Code), hãy thêm cấu hình sau vào file cấu hình MCP của bạn (`mcp_config.json`):
   ```json
   {
     "mcpServers": {
       "figma": {
         "command": "npx",
         "args": ["-y", "@figma/mcp-server"],
         "env": {
           "FIGMA_ACCESS_TOKEN": "YOUR_FIGMA_PERSONAL_ACCESS_TOKEN"
         }
       }
     }
   }
   ```

3. **Cách Sử Dụng:**
   Trong khung chat với AI, bạn chỉ cần copy link của một Frame hoặc Component trên Figma và gán vào:
   > *"Hãy chuyển Frame Figma này thành một Widget Flutter responsive: https://www.figma.com/design/XXXX/Gymtelligent?node-id=YYY"*
   AI sẽ tự động gọi MCP Server của Figma để lấy cấu trúc JSON (spacing, colors, text styles, autolayout) và tạo widget tương ứng trong thư mục `lib/` của bạn.

---

### Giải pháp B: Đưa Hình Ảnh Thiết Kế / Tài Nguyên Figma Để Antigravity Sinh Code
Nếu bạn đang tương tác trực tiếp với tôi (**Antigravity**):
1. **Chụp ảnh màn hình (Screenshot):** Bạn có thể chụp ảnh màn hình giao diện Figma cần code và gửi trực tiếp vào ô chat. Với khả năng xử lý hình ảnh mạnh mẽ, tôi có thể phân tích cấu trúc giao diện, màu sắc, font chữ và viết code Flutter tương ứng cho bạn.
2. **Xuất cấu trúc Figma thành mã JSON:** Bạn có thể bật **Dev Mode** trong Figma, sao chép các thông số CSS/Flutter hoặc xuất thông tin JSON của element đó và gửi cho tôi. Tôi sẽ giúp bạn thiết kế kiến trúc widget Flutter tối ưu (sử dụng Column, Row, Stack, Padding hợp lý).

---

### Giải pháp C: Sử Dụng Các Plugin Figma-to-Flutter Chuyên Dụng
Nếu bạn muốn sinh mã Flutter tự động 100% từ Figma mà không cần qua MCP:
* **Figma Code Connect (Chính thức từ Figma):** Giúp kết nối thiết kế Figma trực tiếp với các Widget Flutter có sẵn trong codebase của bạn. Khi designer kéo widget trong Figma, dev sẽ thấy đúng code Flutter của widget đó trong Dev Mode.
* **Locofy.ai hoặc Builder.io (Plugins):** Đây là các plugin cực tốt trên Figma giúp convert trực tiếp từ thiết kế sang Flutter Widget hoàn chỉnh (đã tối ưu responsive, layout) chỉ với vài cú click.

---

## 3. Gợi Ý Các Bước Tiếp Theo Cho Dự Án `Gymtelligent`

1. **Setup thư mục tài nguyên:** Trước khi code giao diện, bạn nên định nghĩa hệ thống Design System của Figma vào Flutter:
   - Tạo file `lib/theme.dart` để chứa: Colors, Typography, Border Radius đồng bộ với Figma.
2. **Bắt đầu sinh code:**
   - Bạn có thể gửi ảnh chụp màn hình hoặc link Figma của màn hình đầu tiên (ví dụ: Splash Screen hoặc Login Screen).
   - Tôi sẽ tạo các widget tương ứng trong `lib/` và cập nhật file `lib/main.dart` để bạn chạy thử ngay lập tức!
