# Project Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 채팅뷰 상단 툴바의 정적 프로젝트명을 클릭 가능한 프로젝트 탭으로 교체하고, 프로젝트별 마지막 세션을 기억한다.

**Architecture:** `AppState`에 `lastSessionPerProject: [UUID: String]`을 추가해 프로젝트 전환 시 마지막 세션 ID를 저장/복원한다. `ChatView.toolbarArea`의 정적 텍스트를 수평 스크롤 탭으로 교체한다. `MainView` 사이드바의 프로젝트 드롭다운은 제거한다.

**Tech Stack:** SwiftUI, Swift, `@Observable AppState` (MainActor)

---

### Task 1: AppState — lastSessionPerProject 추가 및 selectProject 수정

**Files:**
- Modify: `Clarc/App/AppState.swift`

**변경 상세:**

`AppState`에 `lastSessionPerProject: [UUID: String]` 프로퍼티를 추가한다.
`selectProject()` 함수 안에서:
1. 전환 전 현재 프로젝트의 `currentSessionId`를 `lastSessionPerProject`에 저장
2. `loadSessionHistory()` 완료 후, 저장된 세션 ID가 현재 프로젝트 세션 목록에 존재하면 해당 세션으로 복귀

- [ ] **Step 1: `lastSessionPerProject` 프로퍼티 추가**

`AppState.swift`의 기존 `var sessions: [ChatSession] = []` 근처 프로퍼티 선언부(약 line 205)에 추가:

```swift
// 프로젝트별 마지막 세션 ID 기억
var lastSessionPerProject: [UUID: String] = [:]
```

- [ ] **Step 2: `selectProject()` 수정 — 현재 세션 저장**

`selectProject()` 함수(line 1318)에서 `selectedProject = project` 라인 **직전**에 추가:

```swift
// 현재 프로젝트의 마지막 세션 기억
if let outgoingProject = selectedProject,
   let sessionId = currentSessionId {
    lastSessionPerProject[outgoingProject.id] = sessionId
}
```

- [ ] **Step 3: `selectProject()` 수정 — 마지막 세션 복귀**

`selectProject()` 함수 마지막의 `await loadSessionHistory()` 호출 후(현재 함수 끝)에 추가:

```swift
// 마지막 세션으로 복귀
if let savedSessionId = lastSessionPerProject[project.id],
   let session = sessions.first(where: { $0.id == savedSessionId }) {
    await resumeSession(session)
}
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: 커밋**

```bash
git add Clarc/App/AppState.swift
git commit -m "feat: 프로젝트별 마지막 세션 기억"
```

---

### Task 2: ChatView — toolbarArea를 프로젝트 탭으로 교체

**Files:**
- Modify: `Clarc/Views/Chat/ChatView.swift`

**현재 toolbarArea** (`ChatView.swift` line 154-192):
```swift
private var toolbarArea: some View {
    HStack(spacing: 12) {
        if let project = appState.selectedProject {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(ClaudeTheme.accent)
                Text(project.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClaudeTheme.textPrimary)
            }
        }
        Spacer()
        // ... 볼트 버튼, 모델 피커
    }
}
```

- [ ] **Step 1: `toolbarArea`의 정적 프로젝트 표시 부분을 탭 ScrollView로 교체**

`toolbarArea`에서 아래 블록을 교체한다:

교체 전:
```swift
if let project = appState.selectedProject {
    HStack(spacing: 6) {
        Image(systemName: "folder.fill")
            .font(.system(size: 13))
            .foregroundStyle(ClaudeTheme.accent)
        Text(project.name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(ClaudeTheme.textPrimary)

    }
}
```

교체 후:
```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 4) {
        ForEach(appState.projects) { project in
            let isSelected = appState.selectedProject?.id == project.id
            Button {
                Task { await appState.selectProject(project) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? ClaudeTheme.textOnAccent : ClaudeTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected ? ClaudeTheme.accent : ClaudeTheme.surfaceSecondary,
                    in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 커밋**

```bash
git add Clarc/Views/Chat/ChatView.swift
git commit -m "feat: 채팅뷰 상단 프로젝트 탭 추가"
```

---

### Task 3: MainView — 사이드바 프로젝트 드롭다운 제거

**Files:**
- Modify: `Clarc/Views/MainView.swift`

**현재 사이드바 헤더** (line 126-195)에 GitHub 버튼, 프로젝트 드롭다운 Menu, 프로젝트 추가(+) 버튼이 있다.

제거 대상: 프로젝트 드롭다운 Menu 블록 (line 138-173):
```swift
Menu {
    ForEach(appState.projects) { project in
        Button {
            Task { await appState.selectProject(project) }
        } label: {
            HStack {
                Text(project.name)
                if appState.selectedProject?.id == project.id {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    if appState.projects.isEmpty {
        Text("프로젝트 없음")
    }
} label: {
    HStack(spacing: 5) {
        Image(systemName: "folder.fill")
            .font(.system(size: 12))
            .foregroundStyle(ClaudeTheme.accent)
        Text(appState.selectedProject?.name ?? "프로젝트 선택")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ClaudeTheme.textPrimary)
            .lineLimit(1)
        Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(ClaudeTheme.textTertiary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(ClaudeTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
}
.menuStyle(.borderlessButton)
.fixedSize()
```

유지 대상: GitHub 버튼, 프로젝트 추가(+) 버튼, `Spacer()`

- [ ] **Step 1: 프로젝트 드롭다운 Menu 블록 제거**

`MainView.swift` sidebarContent의 HStack(spacing: 8) 내부에서 위 Menu 블록 전체를 삭제한다. GitHub 버튼과 `+` 버튼, Spacer()만 남긴다.

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 커밋**

```bash
git add Clarc/Views/MainView.swift
git commit -m "refactor: 사이드바 프로젝트 드롭다운 제거 (탭으로 대체)"
```

---

## 완료 기준

1. 채팅뷰 상단에 모든 프로젝트가 탭으로 표시되고, 선택된 탭은 액센트 컬러로 강조됨
2. 탭 클릭 시 해당 프로젝트로 전환되며, 이전에 보던 세션으로 자동 복귀
3. 사이드바 프로젝트 드롭다운이 제거됨
4. 빌드 성공
