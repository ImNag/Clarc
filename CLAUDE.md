# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

Clarc는 Claude Code CLI의 네이티브 macOS 데스크톱 클라이언트입니다. Swift + SwiftUI로 작성되었으며 SwiftTerm(터미널 에뮬레이션) 외 외부 의존성이 없습니다.

## 작성 규칙

- 코드 주석, 커밋 메시지, PR 설명, 로그 메시지 등 **프로젝트에 커밋되는 모든 텍스트는 영어로 작성**한다. 사용자와의 채팅 응답은 한국어를 유지.

## 빌드 및 실행

```bash
# Xcode에서 열기 (Cmd+R로 빌드/실행)
open Clarc.xcodeproj

# CLI 빌드
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Debug build

# 릴리즈 빌드
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Release build
```

- 최소 배포 대상: macOS 26.2+
- 테스트 스위트 없음 (UI 앱)
- 번들 ID: `com.idealapp.Clarc`

## 아키텍처

### 핵심 패턴

- **Observable AppState** (`App/AppState.swift`): `@MainActor @Observable` 단일 상태 컨테이너. 프로젝트, 세션, 채팅, 권한 승인 등 모든 앱 상태를 관리
- **Actor 기반 서비스**: 모든 서비스가 `actor`로 구현되어 동시성 안전. 락 없이 격리
- **SwiftUI 전용**: Storyboard/XIB 없음. 100% 선언적 UI

### 서비스 레이어 (`Services/`)

| 서비스 | 역할 |
|--------|------|
| `ClaudeService` | Claude CLI를 subprocess로 생성, stdout NDJSON 스트림 파싱, 텍스트 델타 50ms 버퍼링 |
| `PermissionServer` | Network 프레임워크 기반 로컬 HTTP 서버(포트 19836~19846). CLI의 PreToolUse 훅 요청을 수신하고 UI 승인까지 커넥션 홀드 |
| `GitHubService` | OAuth Device Flow 인증, Keychain 토큰 저장, SSH 키 생성/등록, 레포 클론 |
| `PersistenceService` | `~/Library/Application Support/Clarc/`에 JSON 파일 기반 영속화. 프로젝트/세션별 디렉토리 구조 |
| `MarketplaceService` | Anthropic GitHub 4개 레포에서 플러그인 카탈로그 병렬 페치, 5분 캐시 |
| `RateLimitService` | Anthropic 사용량 API 조회, OAuth 토큰 갱신, 사용량 추적 |

### 데이터 흐름

1. 사용자 입력 → `AppState.send()` → `ClaudeService.send()`가 CLI subprocess 생성
2. CLI stdout → NDJSON `AsyncStream<StreamEvent>` → `processStream()`에서 이벤트별 처리
3. 텍스트 델타는 50ms 간격으로 버퍼링하여 SwiftUI 업데이트 스래싱 방지
4. 도구 실행 시 PermissionServer가 HTTP 요청 수신 → UI 승인 모달 → 응답 반환
5. 프로젝트 전환 시 진행 중 스트림은 백그라운드 Task로 분리, 완료 후 디스크 저장

### 뷰 구조 (`Views/`)

- `MainView`: NavigationSplitView (사이드바 + 디테일)
- `Chat/`: 메인 채팅 UI, 메시지 스트리밍, 슬래시 커맨드, 첨부, 마켓플레이스, 파일 diff, 상태라인
- `Sidebar/`: 프로젝트 목록, 세션 히스토리, 파일 트리, Git 상태, 파일 프리뷰
- `Onboarding/`: 초기 설정 플로우, GitHub 로그인
- `Permission/`: 위험도(Safe/Moderate/High) 기반 도구 승인 모달
- `Terminal/`: SwiftTerm 기반 내장 터미널

### 컴파일러 설정

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — 기본 MainActor 격리
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- App Sandbox 비활성화 (시스템 통합 필요)

### 테마

`Theme/ClaudeTheme.swift` + `Theme/AppTheme.swift` — 테라코타 액센트(#D97757), 라이트/다크 모드, 색상 팔레트, 타이포그래피, 코너 반경 상수(8/12/16/20)

