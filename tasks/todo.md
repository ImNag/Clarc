# 동시 세션 스트리밍 버그 수정 계획

## 문제 요약

1. **스트리밍 중 세션 전환 시 "Claude returned an error"** — 응답이 끊김
2. **히스토리 중복/꼬임** — 세션 메시지가 섞임
3. **독립 동시 스트리밍 불가** — 세션 A 응답 중 세션 B에서 새 대화 시작 시 정상 동작해야 함

## 근본 원인

### 원인 1: ClaudeService 단일 프로세스 (`ClaudeService.swift:14-17`)

```swift
private var process: Process?      // ← 하나만 저장
private var stdinPipe: Pipe?
private var stdoutPipe: Pipe?
private var stderrPipe: Pipe?
```

- `send()` 호출마다 `self.process`를 덮어씀 (line 144-146, 370)
- 세션 A 스트리밍 중 세션 B에서 `send()` 호출 → 세션 A의 프로세스 참조 유실
- `cancel()`이 항상 마지막 프로세스만 종료 → 잘못된 프로세스 kill 가능

### 원인 2: cancelStreaming()이 잘못된 프로세스를 죽임 (`AppState.swift:1284-1306`)

```swift
func cancelStreaming() async {
    ...
    await claude.cancel()  // ← 마지막으로 저장된 process를 kill
}
```

- 세션 전환 후 새 스트림 시작 → `self.process`가 세션 B 것으로 교체됨
- 세션 A의 백그라운드 스트림이 끝날 때 정리 불가

### 원인 3: 백그라운드 스트림 → UI 실시간 반영 없음 (`AppState.swift:543-551`)

```swift
if !isOwner {
    backgroundMessages = detachedStreamMessages.removeValue(forKey: streamId) ?? messages
    wasOwner = false
}
```

- 스트림이 백그라운드로 전환되면 `backgroundMessages` 로컬 변수에만 씀
- `liveBackgroundMessages[sid]`는 업데이트하지만, 사용자가 해당 세션을 보고 있어도 `self.messages`는 갱신 안 됨
- 세션 복귀 시 `resumeSession()`에서 한 번 로드하지만 이후 라이브 업데이트 없음

## 수정 계획

### Step 1: ClaudeService 멀티 프로세스 지원

**파일**: `ClaudeService.swift`

변경:
- [ ] `process: Process?` → `processes: [UUID: Process]` 딕셔너리로 변경
- [ ] `stdinPipe/stdoutPipe/stderrPipe` 단일 저장 제거 (각 `send()` 호출의 로컬 변수로 충분)
- [ ] `send(prompt:...) → send(streamId:prompt:...)` — streamId 파라미터 추가
- [ ] `spawnProcess()`에서 `self.process = proc` → `self.processes[streamId] = proc`
- [ ] `cancel()` → `cancel(streamId:)` — 특정 프로세스만 종료
- [ ] `isRunning` → `isRunning(streamId:)` 또는 제거
- [ ] `cleanup()`에서 모든 프로세스 정리
- [ ] 프로세스 종료 시 `terminationHandler`에서 딕셔너리에서 자동 제거

**주의**: `sendMessage()`는 현재 사용되지 않거나 단일 프로세스 기준 — 멀티 프로세스에 맞게 `sendMessage(streamId:text:)`로 변경하거나 사용처 확인

### Step 2: AppState에서 streamId 전달

**파일**: `AppState.swift`

변경:
- [ ] `processStream()`에서 `claude.send()` 호출 시 `streamId` 전달
- [ ] `cancelStreaming()`에서 `claude.cancel(streamId: activeStreamId)` 호출
- [ ] `activeStreamId`를 cancel 전에 캡처해둬야 함 (nil로 설정하기 전에)

```swift
// Before
func cancelStreaming() async {
    activeStreamId = nil
    ...
    await claude.cancel()
}

// After
func cancelStreaming() async {
    let streamToCancel = activeStreamId
    activeStreamId = nil
    ...
    if let streamToCancel {
        await claude.cancel(streamId: streamToCancel)
    }
}
```

### Step 3: 백그라운드 스트림 라이브 UI 동기화

**파일**: `AppState.swift` — `processStream()` 내부

변경:
- [ ] 백그라운드 이벤트 처리 후 `currentSessionId == backgroundSessionId`이면 `self.messages`도 갱신

```swift
// 기존: 백그라운드에서만 업데이트
if let sid = backgroundSessionId {
    liveBackgroundMessages[sid] = backgroundMessages
}

// 수정: 현재 보고 있는 세션이면 UI도 갱신
if let sid = backgroundSessionId {
    liveBackgroundMessages[sid] = backgroundMessages
    if currentSessionId == sid {
        self.messages = backgroundMessages
    }
}
```

이 패턴을 `.assistant`, `.user`, `.result` 이벤트의 `!isOwner` 분기 모두에 적용

### Step 4: 에러 전파 방어

**파일**: `AppState.swift`

현재 `.result` 핸들러에서 `isOwner`일 때만 에러 표시 (line 715-718) — 이건 이미 올바름.
하지만 추가 방어:
- [ ] `detachCurrentStream()` 후 `showError`/`errorMessage` 초기화하여 이전 스트림 에러 잔존 방지

```swift
private func detachCurrentStream() {
    ...
    // 이전 스트림의 에러 상태 초기화
    showError = false
    errorMessage = nil
}
```

## 수정 순서

1. **Step 1** (ClaudeService) → 2. **Step 2** (AppState 전달) → 컴파일 확인
3. **Step 3** (라이브 동기화) → 4. **Step 4** (에러 방어) → 최종 빌드

## 리스크

| 리스크 | 대응 |
|--------|------|
| 기존 단일 스트리밍 깨짐 | Step 1-2를 atomic하게 적용, 컴파일 확인 |
| 프로세스 좀비 | terminationHandler에서 딕셔너리 정리 + cleanup()에서 전체 종료 |
| 메시지 배열 레이스 | 모든 코드가 @MainActor — 동기적 실행 보장됨 |
| liveBackgroundMessages ↔ messages 이중 쓰기 | Step 3에서 조건부 동기화만 적용, 소유권 전환 시점 정확히 관리 |
