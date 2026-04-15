---
title: "refactor: AppState 단일 공유 + WindowState 분리"
type: refactor
date: 2026-04-09
---

# AppState 단일 공유 + WindowState 분리 리팩터링

## 배경

프로젝트 더블클릭으로 새 창을 열 때(ProjectWindowView) 현재는 각 창이 독립적인 `AppState`를 생성하여 다음 리스크가 존재한다:

- **파일 손상 위험**: `PersistenceService` 인스턴스가 창마다 따로 생겨 동일 파일에 동시 쓰기 가능
- **데이터 발산**: 한 창에서 세션을 시작해도 다른 창 히스토리에 반영 안 됨
- **리소스 낭비**: `ClaudeService`, `PermissionServer` 등이 창마다 중복 생성

## 목표 아키텍처

```
AppState (앱 단일 인스턴스)
 • PersistenceService     ← 파일 접근 단일화
 • GitHubService          ← OAuth 상태 단일화
 • MarketplaceService     ← 카탈로그 캐시 단일화
 • ClaudeService          ← CLI 프로세스 팩토리, 공유 가능
 • PermissionServer       ← 앱당 1개
 • projects               ← 공유
 • allSessionSummaries    ← 공유 (양쪽 창 히스토리 동기화)
 • sessionStates[id]      ← 세션 ID 키 → 창 무관하게 독립
 • isLoggedIn, selectedTheme, etc.

WindowState (창별 초경량 뷰 상태)
 • selectedProject: Project?
 • currentSessionId: String?
 • inputText: String
 • attachments: [Attachment]
 • draftTexts: [String: String]
 • pendingPermissions: [PermissionRequest]
 • interactiveTerminal: InteractiveTerminalState?
 • inspectorFile / diffFile
 • showMarketplace / showModelPicker
 • isInitialized: Bool
```

**핵심 설계 원리**: `sessionStates`가 이미 세션 ID를 키로 한 딕셔너리이므로, 여러 창이 AppState를 공유하면서도 각자 다른 `currentSessionId`를 가지면 자연스럽게 독립적 스트리밍이 가능하다.

---

## 구현 계획

### Phase 1 — `WindowState` 신규 파일 생성

**파일**: `Clarc/App/WindowState.swift` (신규)

```swift
@Observable
@MainActor
final class WindowState {
    // 이 창이 보고 있는 프로젝트/세션
    var selectedProject: Project?
    var currentSessionId: String?

    // 이 창의 입력 상태
    var inputText = ""
    var attachments: [Attachment] = []
    var draftTexts: [String: String] = [:]

    // 이 창의 권한 요청 큐 (currentSessionId 기준 필터)
    var pendingPermissions: [PermissionRequest] = []

    // 이 창의 UI 상태
    var interactiveTerminal: InteractiveTerminalState?
    var inspectorFile: PreviewFile?
    var diffFile: PreviewFile?
    var showMarketplace = false
    var showModelPicker = false
    var requestInputFocus = false
    var registryVersion = 0
    var isInitialized = false
    var errorMessage: String?
    var showError = false
    var lastSessionPerProject: [UUID: String] = [:]
    private var sessionSwitchTask: Task<Void, Never>?
}
```

**책임**: 이 창이 무엇을 보고 있는지, 무엇을 입력하고 있는지. 데이터나 서비스는 소유하지 않음.

---

### Phase 2 — `AppState` 리팩터링

**파일**: `Clarc/App/AppState.swift` (수정)

#### 2a. 창별 상태 프로퍼티 제거

`WindowState`로 이동하는 프로퍼티 제거:
- `var selectedProject`, `var currentSessionId`
- `var inputText`, `var attachments`, `var draftTexts`
- `var pendingPermissions`
- `var interactiveTerminal`, `var inspectorFile`, `var diffFile`
- `var showMarketplace`, `var showModelPicker`, `var requestInputFocus`
- `var registryVersion`, `var isInitialized`, `var errorMessage`, `var showError`
- `var lastSessionPerProject`, `var sessionSwitchTask`
- `var isIsolatedProjectWindow` (불필요)

#### 2b. `sessionStates` — AppState에 유지

```swift
// 세션 ID 키 → 창과 무관하게 독립 관리됨
// 창 A가 session-1을 스트리밍하는 동안 창 B가 session-2를 스트리밍해도 충돌 없음
var sessionStates: [String: SessionStreamState] = [:]
```

#### 2c. 메서드 시그니처에 WindowState 추가

창별 상태에 의존하는 메서드들에 `WindowState` 파라미터 추가:

```swift
// 기존:
func send() async
func selectProject(_ project: Project) async
func selectSession(id: String)
func startNewChat()
func cancelStreaming() async

// 변경:
func send(in window: WindowState) async
func selectProject(_ project: Project, in window: WindowState) async
func selectSession(id: String, in window: WindowState)
func startNewChat(in window: WindowState)
func cancelStreaming(in window: WindowState) async
```

이 메서드들은 `window.currentSessionId`, `window.selectedProject` 등을 읽고 수정한다.

#### 2d. `currentStreamState` 헬퍼 수정

```swift
// 기존: AppState 내부 상태로 접근
private var currentStreamState: SessionStreamState {
    get { sessionStates[currentSessionId ?? newSessionKey] ?? SessionStreamState() }
}

// 변경: window 파라미터 버전 + 내부용 모두 지원
func currentStreamState(for window: WindowState) -> SessionStreamState {
    sessionStates[window.currentSessionId ?? newSessionKey] ?? SessionStreamState()
}
```

#### 2e. `initialize()` 분리

```swift
// AppState: 앱당 1회 (서비스 시작, 데이터 로드)
func initialize() async {
    // 1. 테마 복원
    // 2. Claude 바이너리 탐색 + 버전 확인
    // 3. 프로젝트 목록 로드
    // 4. GitHub 사용자 복원
    // 5. 전체 세션 서머리 로드
    // 6. 온보딩 상태 확인
    // 7. PermissionServer 시작
    // 8. Permission 리스너 Task 시작 — 요청은 windowState로 라우팅
}

// WindowState: 창별 (어떤 프로젝트/세션을 볼지)
extension AppState {
    func initializeWindow(_ window: WindowState, selectingProjectId: UUID? = nil) async {
        // 지정 프로젝트 또는 마지막 프로젝트 선택
        // session 히스토리 로드
        window.isInitialized = true
    }
}
```

---

### Phase 3 — PermissionServer 라우팅

PermissionServer는 AppState에 단 하나. 권한 요청이 들어오면 어느 창에 보낼지 결정해야 한다.

**방법 A: sessionId 기반 라우팅 (권장)**

`PermissionRequest`에 `sessionId: String?` 추가. 각 창이 `pendingPermissions`를 `windowState.currentSessionId`로 필터링.

```swift
// AppState의 permission 리스너
permissionListenerTask = Task { [weak self] in
    for await request in permission.permissionRequests {
        // 요청의 sessionId와 일치하는 창의 windowState에 추가
        // (모든 열린 창의 windowState를 순회하거나,
        //  현재 activeWindowState 프로퍼티로 라우팅)
        self?.routePermissionRequest(request)
    }
}
```

**방법 B: 단순화 — 항상 메인 창에 표시**

구현 복잡도 최소화. 프로젝트 창에서 실행한 Claude도 권한 요청이 메인 창에 뜸. 추후 A로 개선 가능.

> **1차 구현은 방법 B로**, 이후 필요 시 A로 업그레이드.

---

### Phase 4 — `ClarcApp.swift` 수정

**파일**: `Clarc/App/ClarcApp.swift`

```swift
@main
struct ClarcApp: App {
    @State private var appState = AppState()       // 앱 단일 인스턴스

    var body: some Scene {
        WindowGroup {
            MainWindowRoot(appState: appState)
                .focusable(false)
        }
        .defaultSize(width: 1000, height: 700)
        .defaultLaunchBehavior(.presented)
        .commands { ... }

        WindowGroup(id: "project-window", for: UUID.self) { $projectId in
            if let id = projectId {
                ProjectWindowRoot(appState: appState, projectId: id)
                    .focusable(false)
            }
        }
        .defaultSize(width: 1000, height: 700)
    }
}

struct MainWindowRoot: View {
    let appState: AppState
    @State private var windowState = WindowState()

    var body: some View {
        MainView()
            .environment(appState)
            .environment(windowState)
            .task {
                await appState.initialize()                     // 앱당 1회
                await appState.initializeWindow(windowState)    // 창별
            }
    }
}

struct ProjectWindowRoot: View {
    let appState: AppState
    let projectId: UUID
    @State private var windowState = WindowState()

    var body: some View {
        ProjectWindowView(projectId: projectId)
            .environment(appState)
            .environment(windowState)
            .task {
                // appState는 이미 initialize() 완료 상태
                await appState.initializeWindow(windowState, selectingProjectId: projectId)
            }
    }
}
```

`appState`는 ClarcApp에서 하나만 생성되어 모든 창에 동일 인스턴스가 전달된다.

---

### Phase 5 — 뷰 업데이트

뷰에서 `@Environment(AppState.self)` 사용 방식 변경:

```swift
// 기존:
@Environment(AppState.self) private var appState
// appState.selectedProject
// appState.inputText
// appState.isStreaming
// appState.send()

// 변경:
@Environment(AppState.self) private var appState
@Environment(WindowState.self) private var windowState
// windowState.selectedProject
// windowState.inputText
// appState.isStreaming(for: windowState)
// appState.send(in: windowState)
```

**영향 받는 뷰 파일:**

| 파일 | 변경 내용 |
|------|---------|
| `Views/MainView.swift` | `@Environment(WindowState.self)` 추가, `selectedProject` → `windowState.selectedProject` |
| `Views/Chat/ChatView.swift` | 동일. `send()` → `send(in: windowState)` |
| `Views/Sidebar/HistoryListView.swift` | `sessions` / `currentSessionId` → `windowState` 참조 |
| `Views/Sidebar/FileTreeView.swift` | `selectedProject` → `windowState.selectedProject` |
| `Views/Chat/StatusLineView.swift` | `isStreaming`, `selectedProject` → `windowState` 참조 |
| `Views/Chat/MessageListView.swift` | `messages`, `isStreaming` → `appState.messages(for: windowState)` |
| `Views/Permission/PermissionModal.swift` | `pendingPermissions` → `windowState.pendingPermissions` |
| `Views/ProjectWindowView.swift` | `@State appState` 제거, `@Environment` 사용 |

---

### Phase 6 — `AppState.sessions` → Summary 메모리 최적화

현재 `sessions: [ChatSession]`은 전체 메시지를 포함한다. 사이드바는 메타데이터만 필요하다.

```swift
// AppState
var sessions: [ChatSession.Summary] = []   // messages 없는 경량 타입으로 교체

// 현재 세션의 전체 메시지는 sessionStates[id].messages에만 존재
// resumeSession() 에서 디스크에서 on-demand 로드 (이미 이렇게 동작 중)
```

`sessionsForSelectedProject` 반환 타입: `[ChatSession]` → `[ChatSession.Summary]`  
`HistoryListView.currentProjectSessions`가 사용하는 `DisplaySession`은 이미 title/updatedAt/isPinned만 쓰므로 영향 없음.

---

## 검수 기준

- [ ] 프로젝트 창에서 시작한 세션이 메인 창 히스토리에 즉시 반영
- [ ] 두 창에서 동시에 서로 다른 세션 스트리밍 가능
- [ ] 한 창에서 세션 삭제 시 다른 창 히스토리 즉시 반영
- [ ] 프로젝트 창에서 권한 요청 발생 시 메인 창에 모달 표시 (Phase 3 방법 B)
- [ ] `xcodebuild` 빌드 에러 없음
- [ ] 앱 재시작 후 마지막 선택 프로젝트 복원 정상

---

## 영향 파일 목록

| 파일 | 변경 규모 |
|------|---------|
| `App/WindowState.swift` | 신규 (~80줄) |
| `App/AppState.swift` | 대규모 (창별 프로퍼티 제거, 메서드 시그니처 변경) |
| `App/ClarcApp.swift` | 중간 (Root 뷰 패턴, AppState 단일화) |
| `Views/ProjectWindowView.swift` | 소규모 (AppState 직접 생성 제거) |
| 뷰 파일 8개 | 소규모 각각 (`windowState` Environment 추가 + 접근 경로 변경) |

---

## 리스크

| 리스크 | 대응 |
|--------|------|
| 메서드 시그니처 변경으로 컴파일 에러 다수 | Phase별로 빌드 확인하며 진행 |
| `isStreaming` 등 AppState computed proxy → windowState 이동으로 뷰 변경 범위 큼 | Phase 5에서 파일별로 처리 |
| AppState.initialize() 레이스 컨디션 (다중 창 동시 열기) | `isInitialized` 가드로 1회만 실행 보장 |
| PermissionServer 라우팅 미완 | Phase 3 방법 B로 단순화, 이후 개선 |
