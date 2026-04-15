# Lessons

[2026-04-07] 문제: 세션별 상태(messages, isStreaming, 통계 등)가 단일 stored property로 공유되어 세션 전환 시 상태 엉킴, 히스토리 중복, "Claude returned an error" 발생 → 해결: SessionStreamState 구조체 + sessionStates 딕셔너리로 세션별 격리. computed proxy로 뷰 코드 변경 최소화. **세션 관련 상태는 반드시 세션 키로 격리해야 하며, 글로벌 stored property로 관리하면 안 됨.**

[2026-04-06] 문제: LazyVStack + struct 배열의 onChange가 스트리밍 중 매 델타마다 전체 cachedMessageItems를 재빌드하여 스크롤 프리징 → 해결: isNearBottom이 false일 때(사용자가 위로 스크롤) content-only 변경 시 재빌드 스킵. 구조 변경(count)이나 스트리밍 종료 시에만 재빌드. **스크롤 성능 문제는 업데이트 빈도를 줄이는 것이 우선.**

[2026-04-03] 문제: 스트리밍 중 세션 전환 시 backgroundMessages = messages가 이미 새 세션 메시지를 캡처해 세션 데이터 덮어씌워짐 → 해결: detachCurrentStream()에서 activeStreamId 클리어 전에 detachedStreamMessages[streamId]에 스냅샷 저장, processStream에서 해당 스냅샷 사용. liveBackgroundMessages로 백그라운드 세션 복귀 시 최신 상태 표시.

[2026-04-03] 문제: 터미널 슬래시 커맨드 실행 중 세션 전환 시 스냅샷 유실 — saveTerminalSnapshot이 self.messages만 검색하고 세션 전환 후에는 못 찾음 → 해결: resumeSession()에서 세션 전환 전 현재 messages를 sessions[outgoing].messages에 동기화(백그라운드 스트리밍 세션 제외), saveTerminalSnapshot에서 sessions 배열 전체 fallback 검색 추가.

[2026-04-02] 문제: 텍스트 선택 영역 확장을 위해 NSTextView(NSViewRepresentable)를 도입했으나 스크롤 성능이 심각하게 저하됨. `.frame(maxWidth: .infinity)`로 SwiftUI Text의 히트 영역을 확장하면 충분했음 → 해결: NSTextView 제거, SwiftUI Text + frame 확장으로 교체. **항상 가장 단순한 해법을 먼저 시도할 것. AppKit 브릿지는 최후의 수단.**
