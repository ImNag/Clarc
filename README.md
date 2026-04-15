# Clarc

**Claude Code의 네이티브 macOS 데스크톱 클라이언트**

터미널 기반 CLI를 벗어나, 직관적인 GUI로 Claude Code의 모든 기능을 활용하세요.

![Platform](https://img.shields.io/badge/platform-macOS%2026.2%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-Apache%202.0-green)

---

## 스크린샷

> 스크린샷 추가 예정

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **대화형 채팅** | Claude Code와 실시간 스트리밍 대화. Markdown 렌더링, 도구 호출 시각화 |
| **멀티 프로젝트** | 여러 프로젝트를 등록하고 자유롭게 전환. 프로젝트별 세션 히스토리 |
| **GitHub 연동** | OAuth 인증, SSH 키 관리, 레포지토리 브라우징 및 클론 |
| **파일 첨부** | 드래그앤드롭으로 이미지/파일 첨부. 긴 텍스트 자동 첨부 변환 |
| **슬래시 커맨드** | 확장 가능한 커맨드 시스템 |
| **권한 관리** | 도구 실행 전 위험도별 승인/거부 UI |
| **스킬 마켓플레이스** | Anthropic 공식 플러그인 탐색 및 설치 |
| **모델 선택** | claude-opus-4-6, claude-sonnet-4-6, claude-haiku-4-5 중 선택 |
| **사용량 추적** | 세션별 토큰, 비용, 소요 시간 확인 |
| **내장 터미널** | SwiftTerm 기반 터미널 에뮬레이터 |
| **파일 탐색** | 프로젝트 파일 트리, Git 상태 확인, 파일 프리뷰 |

---

## 요구 사항

- **macOS 26.2** 이상
- **[Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)** 설치 필요
- **Xcode 16** 이상 (빌드 시)

---

## 설치

### 직접 빌드

```bash
git clone https://github.com/fineapptech/clarc.git
cd clarc
open Clarc.xcodeproj
```

Xcode에서 `Cmd+R`로 빌드 및 실행합니다.

### CLI 빌드

```bash
# Debug 빌드
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Debug build

# Release 빌드
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Release build
```

---

## 아키텍처

```
Clarc/
├── App/              # 앱 진입점, AppState
├── Models/           # 데이터 모델 (ChatMessage, Project, StreamEvent 등)
├── Services/         # 비즈니스 로직 (Actor 기반)
│   ├── ClaudeService       # Claude CLI 프로세스 관리, NDJSON 스트리밍
│   ├── GitHubService       # GitHub OAuth, SSH, 레포 관리
│   ├── PersistenceService  # 파일 기반 JSON 영속화
│   ├── PermissionServer    # 도구 실행 승인 HTTP 서버
│   ├── MarketplaceService  # 플러그인 카탈로그 관리
│   └── RateLimitService    # 사용량 추적, 토큰 갱신
├── Views/            # SwiftUI 뷰
│   ├── Chat/         # 채팅 UI, 메시지 버블, 입력창, 마켓플레이스
│   ├── Sidebar/      # 프로젝트 목록, 세션 히스토리, 파일 트리, Git 상태
│   ├── Onboarding/   # 초기 설정 플로우
│   ├── Permission/   # 권한 승인 모달
│   └── Terminal/     # 내장 터미널 (SwiftTerm)
├── Theme/            # 커스텀 테마 (라이트/다크 모드)
├── Resources/        # 한국어 로컬라이제이션
└── Utilities/        # Git 헬퍼, SSH 키 매니저, Keychain 등
```

**기술 스택:** Swift 6 + SwiftUI, Swift Concurrency (async/await, Actor), SwiftTerm

---

## 기여하기

기여를 환영합니다! 버그 리포트, 기능 제안, PR 모두 좋습니다.

1. 이 레포지토리를 포크합니다.
2. 기능 브랜치를 만듭니다. (`git checkout -b feat/my-feature`)
3. 변경사항을 커밋합니다. (`git commit -m 'feat: add my feature'`)
4. 브랜치에 푸시합니다. (`git push origin feat/my-feature`)
5. Pull Request를 열어주세요.

버그 리포트나 기능 요청은 [GitHub Issues](https://github.com/fineapptech/clarc/issues)를 이용해 주세요.

---

## 라이선스

Apache License 2.0 — 자세한 내용은 [LICENSE](LICENSE) 파일을 참고하세요.
