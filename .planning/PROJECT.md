# VoiceType

## What This Is

macOS menu bar app cho phép người dùng nói tiếng Việt và tự động chuyển thành text tại vị trí con trỏ đang focus. Chạy hoàn toàn offline với local speech recognition model, tối ưu cho Apple Silicon. Thiết kế cho developer muốn "vibe code" — nói prompt cho AI hoặc viết documentation mà không cần gõ phím.

## Core Value

Nói tiếng Việt, ra text chính xác, không cần internet.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Nhấn hotkey bắt đầu ghi âm, nói tiếng Việt, thả ra có text
- [ ] Hỗ trợ 2 mode: hold-to-talk và toggle on/off
- [ ] Text được insert vào ô đang focus (bất kỳ app nào)
- [ ] Chạy offline với local model (không cần internet)
- [ ] Menu bar app với icon trạng thái
- [ ] Floating indicator khi đang recording
- [ ] Cài đặt hotkey tuỳ chỉnh
- [ ] Độ chính xác cao cho tiếng Việt

### Out of Scope

- Real-time streaming display (từng từ hiện ra khi nói) — ưu tiên accuracy, chờ xong mới hiển thị
- Dịch tự động sang tiếng Anh — phase sau
- Mobile app — macOS only
- Windows/Linux — macOS only
- Cloud-based STT — phải offline

## Context

**Use case chính:** Vibe coding — developer nói tiếng Việt để:
1. Chat với AI (Claude, Cursor) bằng prompt tiếng Việt
2. Viết comments, documentation trong code

**Tại sao offline:** Không muốn phụ thuộc internet, lo ngại privacy, muốn response nhanh không có network latency.

**Hardware:** Apple Silicon Mac (M1/M2/M3/M4) — có thể tận dụng Metal acceleration cho inference nhanh.

## Constraints

- **Platform**: macOS only (Apple Silicon optimized)
- **Connectivity**: Must work 100% offline
- **Cost**: Free/open-source model only
- **Language**: Vietnamese speech recognition (primary)
- **Privacy**: Audio không được gửi ra ngoài

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Ưu tiên accuracy hơn real-time | User muốn text chuẩn, chờ 1-2s OK | — Pending |
| Hỗ trợ cả hold-to-talk và toggle | Linh hoạt cho nhiều tình huống | — Pending |
| Menu bar + floating indicator | Minimal UI, không chiếm desktop space | — Pending |

---
*Last updated: 2025-01-17 after initialization*
