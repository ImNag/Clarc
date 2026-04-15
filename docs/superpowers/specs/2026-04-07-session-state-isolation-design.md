# Session State Isolation Design

## 문제

현재 AppState는 모든 세션 관련 상태(`messages`, `isStreaming`, `isThinking` 등)를 단일 값으로 관리한다.
세션 A가 스트리밍 중일 때 세션 B로 전환하면:
- 세션 A의 스트리밍 상태가 초기화됨
- 세션 B에서 새 메시지 전송 시 세션 A의 프로세스 참조 유실
- 세션 전환 후 돌아오면 상태(isThinking, 통계, pendingAssistantMessage 등) 복원 안 됨
- 히스토리 목록에 중복 항목 생성

## 목표

각 히스토리(세션)가 완전히 독립적으로 동작해야 한다:
- 세션 A 스트리밍 중 세션 B 전환 → 세션 A 백그라운드 계속, 세션 B 즉시 사용 가능
- 세션 B에서 돌아와도 세션 A의 모든 상태(메시지, 스트리밍 표시, 통계) 정확 복원
- 어떤 세션 전환 패턴에서도 메시지 유실/중복/혼합 없음

## 설계

### 1. SessionStreamState 구조체

세션별로 독립적인 모든 상태를 하나의 구조체에 캡슐화:

```swift
struct SessionStreamState {
    // 메시지
    var messages: [ChatMessage] = []
    var pendingAssistantMessage: ChatMessage?
    var pendingPrompt: PendingPrompt?

    // 스트리밍
    var isStreaming = false
    var isThinking = false
    var hasStreamedTextDelta = false
    var awaitingNewTurn = false
    var activeStreamId: UUID?
    var streamingStartDate: Date?
    var streamTask: Task<Void, Never>?

    // 에이전트
    var activeAgentToolUseId: String?
    var agentInternalMessages: [ChatMessage] = []

    // 세션 통계
    var costUsd: Double = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var durationMs: Double = 0
    var turns: Int = 0
    var lastTurnContextTokens: Int = 0
    var lastTurnContextUsedPercentage: Double?
    var activeModelName: String?
}
```

### 2. AppState 저장소

```swift
// 새로 추가
private var sessionStates: [String: SessionStreamState] = [:]

// "new" 키: currentSessionId가 nil일 때 (새 세션 시작 전) 사용
private let newSessionKey = "__new__"
```

### 3. Computed Property 프록시

기존 뷰 코드 변경을 최소화하기 위해, 기존 프로퍼티들을 computed property로 전환:

```swift
var messages: [ChatMessage] {
    get { currentStreamState.messages }
    set { currentStreamState.messages = newValue }
}

var isStreaming: Bool {
    get { currentStreamState.isStreaming }
    set { currentStreamState.isStreaming = newValue }
}

// ... 나머지 프로퍼티도 동일 패턴

private var currentStreamState: SessionStreamState {
    get { sessionStates[currentSessionId ?? newSessionKey] ?? SessionStreamState() }
    set { sessionStates[currentSessionId ?? newSessionKey, default: SessionStreamState()] = newValue }
}
```

### 4. @Observable 갱신 보장

`@Observable` 매크로는 stored property 접근을 추적한다. computed property는 내부에서 접근하는 stored property의 변경을 추적하므로:
- `sessionStates` 딕셔너리 변경 → `messages` computed property 읽는 뷰 갱신
- `currentSessionId` 변경 → 모든 computed property가 다른 세션 상태를 반환 → 뷰 갱신

### 5. 세션 전환 단순화

```swift
func startNewChat() {
    saveDraft()
    currentSessionId = nil
    // sessionStates[newSessionKey]가 비어있으므로 자동으로 빈 상태
    inputText = draftTexts["new"] ?? ""
}

func resumeSession(_ session: ChatSession) async {
    saveDraft()
    currentSessionId = session.id
    // sessionStates[session.id]에 이미 모든 상태 존재 → 자동 복원
    inputText = draftTexts[session.id] ?? ""
}
```

`detachCurrentStream()` 대폭 단순화:
- 기존: messages 스냅샷, backgroundStreamingSessions, liveBackgroundMessages 등 수동 저장
- 신규: 이미 sessionStates에 저장되어 있으므로 UI 상태 초기화만 필요 없음. 사실상 detach 자체가 불필요해짐

### 6. processStream 변경

```swift
private func processStream(streamId: UUID, ..., sessionId: String?, ...) async {
    // streamId → sessionId 매핑 (system 이벤트에서 결정)
    var resolvedSessionId: String? = sessionId

    for await event in stream {
        // 현재 이 스트림의 세션 상태에 직접 쓰기
        let key = resolvedSessionId ?? newSessionKey

        switch event {
        case .system(let sys):
            if let sid = sys.sessionId {
                resolvedSessionId = sid
                // placeholder 교체 등
            }

        case .assistant(let msg):
            sessionStates[key]?.pendingAssistantMessage = ...
            // currentSessionId == key면 SwiftUI 자동 반영

        case .result(let result):
            sessionStates[key]?.isStreaming = false
            await saveSession(key)
        }
    }
}
```

### 7. 제거되는 상태

| 기존 | 대체 |
|------|------|
| `backgroundStreamingSessions: Set<String>` | `sessionStates[sid]?.isStreaming` |
| `liveBackgroundMessages: [String: [ChatMessage]]` | `sessionStates[sid]?.messages` |
| `backgroundStreamingStartDates: [String: Date]` | `sessionStates[sid]?.streamingStartDate` |
| `detachedStreamMessages: [UUID: [ChatMessage]]` | 불필요 — sessionStates에 항상 최신 |
| 개별 `isStreaming`, `isThinking`, `messages` stored property | computed proxy |

### 8. 세션 정리

```swift
// 세션 완료 후 (스트리밍 종료 + 디스크 저장 완료)
// 메모리 절약을 위해 완료된 세션은 messages만 유지, 나머지 초기화
private func cleanupSessionState(_ sessionId: String) {
    sessionStates[sessionId]?.streamTask = nil
    sessionStates[sessionId]?.pendingAssistantMessage = nil
    sessionStates[sessionId]?.agentInternalMessages.removeAll()
}
```

프로젝트 전환 시:
```swift
func selectProject(_ project: Project) async {
    // 현재 프로젝트의 비스트리밍 세션 상태 제거 (메모리 절약)
    for (key, state) in sessionStates where !state.isStreaming {
        sessionStates.removeValue(forKey: key)
    }
    // 스트리밍 중인 세션은 유지 — 백그라운드 계속
}
```

## 영향 범위

| 파일 | 변경 수준 | 내용 |
|------|----------|------|
| AppState.swift | 대 | SessionStreamState 도입, stored→computed 전환, processStream 리팩토링, 기존 딕셔너리 제거 |
| MessageListView.swift | 소 | StreamingMessageView가 appState.messages 참조 — 변경 없음 (computed proxy) |
| ChatView.swift | 소 | appState.isStreaming 등 참조 — 변경 없음 (computed proxy) |
| 기타 뷰 | 없음 | computed proxy 덕분에 투명 |

## 리스크

| 리스크 | 대응 |
|--------|------|
| @Observable이 딕셔너리 값 변경을 누락 | computed property가 sessionStates 접근을 보장. 빌드 후 수동 테스트 |
| 새 세션(currentSessionId=nil) 시 상태 키 충돌 | `__new__` 전용 키 사용, system 이벤트 시 실제 ID로 마이그레이션 |
| 메모리 — 많은 세션 상태 누적 | 프로젝트 전환 시 비활성 세션 정리, 스트리밍 완료 시 불필요 상태 제거 |
| processStream 동시성 — 여러 스트림이 sessionStates 동시 수정 | @MainActor 보장으로 순차 실행 |
